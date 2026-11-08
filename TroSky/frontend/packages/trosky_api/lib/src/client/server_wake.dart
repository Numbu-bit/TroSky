import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'api_client.dart';

/// What the app knows about the server.
enum ServerState {
  /// It answered recently, or nothing has asked it anything yet.
  awake,

  /// Waiting for it to answer. Staging runs on Render's free plan, which
  /// stops the server after 15 minutes without requests; the next request
  /// waits while it starts again (88 s measured on 2026-10-26).
  waking,

  /// The phone has no internet.
  offline,

  /// The phone has internet, but the server didn't answer within
  /// [ServerWake.giveUpAfter]. It is still asked quietly in the background.
  unreachable,
}

/// Makes sure the server is up before requests are sent to it.
///
/// Before the first request, and before any request after [idleAfter]
/// without an answer, [ready] asks `GET /health/live` and waits for the
/// answer, asking again every [retryEvery] for up to [giveUpAfter] in all.
/// Requests made meanwhile wait for the same answer, so none of them times
/// out on a sleeping server. A server that answers within [showAfter] is
/// never reported as [ServerState.waking].
///
/// When an ask fails, [hasInternet] tells a sleeping server from a phone
/// without internet; it must fail twice, [confirmOfflineAfter] apart,
/// before the state is [ServerState.offline].
///
/// A wake that ends offline or unreachable goes on quietly: every
/// [recheckEvery] it checks the internet (offline) or asks the server
/// (unreachable), and wakes it again once it can. Meanwhile [ready]
/// returns at once, so screens show what they have instead of waiting;
/// [retry] starts a full wake again.
class ServerWake {
  ServerWake({
    required this._ping,
    required this._hasInternet,
    this.idleAfter = const Duration(minutes: 10),
    this.giveUpAfter = const Duration(minutes: 3),
    this.showAfter = const Duration(seconds: 2),
    this.retryEvery = const Duration(seconds: 3),
    this.confirmOfflineAfter = const Duration(seconds: 2),
    this.recheckEvery = const Duration(seconds: 10),
    this._now = DateTime.now,
    this._onDispose,
  });

  /// Asks `/health/live` next to [apiBaseUrl] (which ends in `/api/v1`),
  /// and checks the internet by looking up its host.
  factory ServerWake.forApi(String apiBaseUrl, {HttpClientAdapter? adapter}) {
    final health = Uri.parse(apiBaseUrl).replace(path: '/health/live');
    final dio = Dio(
      BaseOptions(
        connectTimeout: connectTimeout,
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
      ),
    );
    if (adapter != null) dio.httpClientAdapter = adapter;
    return ServerWake(
      ping: (timeout) async {
        try {
          final response = await dio.getUri<Object?>(
            health,
            options: Options(receiveTimeout: timeout),
          );
          // Render's proxy answers 502 or 503 while the server can't.
          return (response.statusCode ?? 500) < 500;
        } on DioException {
          return false;
        }
      },
      // Either name found is internet: offline means really none.
      hasInternet: () async =>
          await canLookUp(health.host) || await canLookUp('google.com'),
      onDispose: dio.close,
    );
  }

  /// How long the server stays trusted to be awake after an answer. Render
  /// stops it after 15 idle minutes.
  final Duration idleAfter;

  /// How long one wake keeps asking before it lets requests go anyway.
  final Duration giveUpAfter;

  /// How long an ask can take before the state is [ServerState.waking].
  final Duration showAfter;

  /// The pause between failed asks.
  final Duration retryEvery;

  /// The pause before the internet is checked a second time.
  final Duration confirmOfflineAfter;

  /// How often a failed wake checks again in the background.
  final Duration recheckEvery;

  /// Asks the server, waiting at most `timeout`; true if it answered.
  final Future<bool> Function(Duration timeout) _ping;
  final Future<bool> Function() _hasInternet;
  final DateTime Function() _now;
  final void Function()? _onDispose;
  final _changes = StreamController<ServerState>.broadcast();
  ServerState _state = ServerState.awake;
  DateTime? _heard;
  Future<void>? _waking;

  /// The last wake ended offline or unreachable; [_recheck] goes on.
  bool _failed = false;
  Timer? _recheck;
  /// The current wake's [showAfter] timer, cancelled on [dispose].
  Timer? _slow;
  /// The current wait between failed asks, cancelled on [dispose].
  Timer? _retryWait;
  bool _disposed = false;

  ServerState get state => _state;

  /// Every change of [state].
  Stream<ServerState> get changes => _changes.stream;

  /// Completes when requests can be sent: at once if the server answered
  /// within [idleAfter], otherwise once it answers, the phone turns out to
  /// be offline, or [giveUpAfter] has passed. It never fails: a request
  /// sent after a failed wake fails on its own.
  Future<void> ready() {
    final heard = _heard;
    if (heard != null && _now().difference(heard) < idleAfter) {
      return Future.value();
    }
    if (_waking case final waking?) return waking;
    // Still trying in the background: requests fail now, not in 3 minutes.
    if (_failed) return Future.value();
    return _start();
  }

  /// Retry: a full wake again, [giveUpAfter] from now.
  Future<void> retry() {
    _recheck?.cancel();
    _failed = false;
    return _waking ?? _start();
  }

  /// Notes an answer from the server.
  void heard() {
    _heard = _now();
    _failed = false;
    _recheck?.cancel();
    _set(ServerState.awake);
  }

  void dispose() {
    _disposed = true;
    _recheck?.cancel();
    _slow?.cancel();
    _retryWait?.cancel();
    _onDispose?.call();
    unawaited(_changes.close());
  }

  Future<void> _start() => _waking = _wake().whenComplete(() {
    _waking = null;
    if (_disposed) return;
    if (_state == ServerState.offline || _state == ServerState.unreachable) {
      _failed = true;
      _scheduleRecheck();
    }
  });

  void _scheduleRecheck() {
    _recheck?.cancel();
    if (_disposed) return;
    _recheck = Timer(recheckEvery, () => unawaited(_checkAgain()));
  }

  /// Offline: is the internet back? Then wake again (with the bar).
  /// Unreachable: one quiet ask.
  Future<void> _checkAgain() async {
    if (_disposed || !_failed || _waking != null) return;
    if (_state == ServerState.offline) {
      if (await _hasInternet()) {
        if (_disposed || !_failed || _waking != null) return;
        _failed = false;
        unawaited(_start());
        return;
      }
    } else if (await _ping(recheckEvery * 2)) {
      heard();
      return;
    }
    if (_failed) _scheduleRecheck();
  }

  /// No internet, checked twice.
  Future<bool> _offline() async {
    if (await _hasInternet()) return false;
    await Future<void>.delayed(confirmOfflineAfter);
    return !await _hasInternet();
  }

  Future<void> _wake() async {
    final started = _now();
    _slow?.cancel();
    _slow = Timer(showAfter, () => _set(ServerState.waking));
    try {
      while (!_disposed) {
        final left = giveUpAfter - _now().difference(started);
        if (left <= Duration.zero) {
          _set(ServerState.unreachable);
          return;
        }
        if (await _ping(left)) {
          if (_disposed) return;
          heard();
          return;
        }
        if (_disposed) return;
        if (await _offline()) {
          if (_disposed) return;
          _set(ServerState.offline);
          return;
        }
        if (_disposed) return;
        _set(ServerState.waking);
        final gate = Completer<void>();
        _retryWait?.cancel();
        _retryWait = Timer(retryEvery, () {
          if (!gate.isCompleted) gate.complete();
        });
        await gate.future;
        _retryWait = null;
      }
    } finally {
      _slow?.cancel();
      _slow = null;
    }
  }

  void _set(ServerState next) {
    if (next == _state) return;
    _state = next;
    if (!_changes.isClosed) _changes.add(next);
  }
}

/// Whether the phone can look [host] up: false without a network, and on a
/// network with no way out.
Future<bool> canLookUp(String host) async {
  try {
    final found = await InternetAddress.lookup(
      host,
    ).timeout(const Duration(seconds: 5));
    return found.isNotEmpty;
  } on Object {
    return false;
  }
}

/// Holds every request until [ServerWake.ready], and tells it about every
/// answer.
class ServerWakeInterceptor extends Interceptor {
  ServerWakeInterceptor(this._wake);

  final ServerWake _wake;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await _wake.ready();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    _wake.heard();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // A 5xx may come from Render's proxy rather than the server.
    if ((err.response?.statusCode ?? 500) < 500) _wake.heard();
    handler.next(err);
  }
}
