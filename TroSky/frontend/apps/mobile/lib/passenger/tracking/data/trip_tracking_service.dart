import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_core/trosky_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Where realtime updates came from on a given tick. The UI shows a thin
/// banner when the stream is in [pollFallback] and clears it as soon as
/// [webSocket] takes over again.
enum TripTrackingSource { webSocket, pollFallback }

/// One point the service emits to the UI, carrying provenance.
class TripTrackingUpdate {
  const TripTrackingUpdate({required this.location, required this.source});

  final LiveLocationResponse location;
  final TripTrackingSource source;
}

/// Opens a realtime channel for a trip and picks between WebSocket and
/// polling based on what the backend lets through.
///
/// Strategy:
///   1. Try WebSocket first with ``?token=<access>`` auth (the backend
///      requires query-param auth because WS handshakes can't carry an
///      Authorization header).
///   2. On any connect error, or if the socket drops twice within 30 s,
///      fall back to polling ``GET /trips/{id}/location`` every 5 s and
///      stay on polling until the backoff retries WebSocket.
///   3. Retry WebSocket once a minute while polling.
///   4. Exponential backoff with jitter (1 s → 30 s cap) on every
///      WebSocket reconnect attempt.
///
/// Call [start] to begin, [pause] to stop both pipes while the screen is
/// backgrounded, [resume] to come back online, and [dispose] to tear
/// down. Updates land on the returned [Stream] as [TripTrackingUpdate]s.
///
/// Injected into [TrackTripScreen] via a provider so tests can swap in a
/// [_FakeTripTrackingService] without opening a real socket.
abstract interface class TripTrackingService {
  Stream<TripTrackingUpdate> start(String tripId);
  void pause();
  void resume();
  void dispose();
}

typedef TripTrackingSocketOpener = WebSocketChannel Function(Uri uri);

WebSocketChannel _defaultOpener(Uri uri) => WebSocketChannel.connect(uri);

class LiveTripTrackingService implements TripTrackingService {
  LiveTripTrackingService({
    required this.env,
    required TrackingRepository repository,
    required this.accessToken,
    this.openSocket = _defaultOpener,
    this.pollInterval = const Duration(seconds: 5),
    this.webSocketRetryEvery = const Duration(seconds: 60),
    this.wsConnectTimeout = const Duration(seconds: 5),
    this.dropWindow = const Duration(seconds: 30),
    this.dropsToTriggerFallback = 2,
    Random? random,
  }) : _repo = repository,
       _random = random ?? Random.secure();

  final Env env;
  final TrackingRepository _repo;
  final Future<String?> Function() accessToken;
  final TripTrackingSocketOpener openSocket;
  final Duration pollInterval;
  final Duration webSocketRetryEvery;
  final Duration wsConnectTimeout;
  final Duration dropWindow;
  final int dropsToTriggerFallback;
  final Random _random;

  late final StreamController<TripTrackingUpdate> _out =
      StreamController<TripTrackingUpdate>.broadcast(onCancel: dispose);

  String? _tripId;
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _pollTimer;
  Timer? _wsRetryTimer;
  Timer? _backoffTimer;
  final List<DateTime> _recentDrops = [];
  int _backoffAttempt = 0;
  bool _paused = false;
  bool _disposed = false;

  @override
  Stream<TripTrackingUpdate> start(String tripId) {
    _tripId = tripId;
    _attemptWebSocket();
    return _out.stream;
  }

  @override
  void pause() {
    if (_disposed) return;
    _paused = true;
    _teardownSocket();
    _pollTimer?.cancel();
    _pollTimer = null;
    _wsRetryTimer?.cancel();
    _wsRetryTimer = null;
    _backoffTimer?.cancel();
    _backoffTimer = null;
  }

  @override
  void resume() {
    if (_disposed || _tripId == null) return;
    _paused = false;
    _attemptWebSocket();
  }

  @override
  void dispose() {
    _disposed = true;
    _teardownSocket();
    _pollTimer?.cancel();
    _wsRetryTimer?.cancel();
    _backoffTimer?.cancel();
    _out.close();
  }

  Uri _wsUri(String tripId, String token) {
    final base = env.wsBaseUrl;
    // base is like "wss://host/api/v1" — append the WS path.
    return Uri.parse('$base/ws/trips/$tripId/track?token=$token');
  }

  Future<void> _attemptWebSocket() async {
    if (_paused || _disposed || _tripId == null) return;
    final token = await accessToken();
    if (token == null || token.isEmpty) {
      _switchToPolling();
      return;
    }
    try {
      final channel = openSocket(_wsUri(_tripId!, token));
      // Treat the ready future as a connect timeout.
      await channel.ready.timeout(wsConnectTimeout);
      if (_paused || _disposed) {
        await channel.sink.close();
        return;
      }
      _teardownSocket();
      _pollTimer?.cancel();
      _pollTimer = null;
      _socket = channel;
      _backoffAttempt = 0;
      _wsRetryTimer?.cancel();
      _wsRetryTimer = null;
      _socketSub = channel.stream.listen(
        _onSocketMessage,
        onError: (_) => _onSocketClosed(),
        onDone: _onSocketClosed,
        cancelOnError: true,
      );
    } on Object catch (error, stack) {
      // H5: redact the error string so a WS URL that ever carries a
      // ?token= query (deprecated path, see backend B1) does not leak
      // the token through the dev log channel.
      developer.log(
        'ws_connect_failed',
        name: 'trosky.tracking',
        error: troskyRedactor.redactString(error.toString()),
        stackTrace: stack,
      );
      _switchToPolling();
      _scheduleBackoff();
    }
  }

  void _onSocketMessage(dynamic data) {
    if (data is! String) return;
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      _emit(LiveLocationResponse.fromJson(map), TripTrackingSource.webSocket);
    } on Object {
      // Malformed frame: ignore (don't drop the socket).
    }
  }

  void _onSocketClosed() {
    _teardownSocket();
    final now = DateTime.now();
    _recentDrops
      ..add(now)
      ..removeWhere((t) => now.difference(t) > dropWindow);
    if (_recentDrops.length >= dropsToTriggerFallback) {
      _switchToPolling();
      _scheduleWsRetry();
    } else {
      _scheduleBackoff();
    }
  }

  void _teardownSocket() {
    _socketSub?.cancel();
    _socketSub = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      socket.sink.close();
    }
  }

  void _switchToPolling() {
    if (_pollTimer != null || _paused || _disposed) return;
    _pollNow();
    _pollTimer = Timer.periodic(pollInterval, (_) => _pollNow());
  }

  Future<void> _pollNow() async {
    if (_paused || _disposed || _tripId == null) return;
    final result = await _repo.tripLocation(_tripId!);
    if (result case Ok(:final value)) {
      _emit(value, TripTrackingSource.pollFallback);
    }
  }

  void _scheduleBackoff() {
    if (_paused || _disposed) return;
    _backoffAttempt += 1;
    final base = 1 << (_backoffAttempt - 1).clamp(0, 5); // 1,2,4,8,16,32
    final delay = Duration(
      milliseconds:
          (base * 1000).clamp(1000, 30000) +
          _random.nextInt(500), // jitter 0–500 ms
    );
    _backoffTimer?.cancel();
    _backoffTimer = Timer(delay, _attemptWebSocket);
  }

  void _scheduleWsRetry() {
    if (_paused || _disposed) return;
    _wsRetryTimer?.cancel();
    _wsRetryTimer = Timer.periodic(
      webSocketRetryEvery,
      (_) => _attemptWebSocket(),
    );
  }

  void _emit(LiveLocationResponse location, TripTrackingSource source) {
    if (_out.isClosed) return;
    _out.add(TripTrackingUpdate(location: location, source: source));
  }
}
