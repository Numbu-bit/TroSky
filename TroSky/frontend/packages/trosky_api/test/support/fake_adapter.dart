import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// What a [FakeAdapter] answers: a status and a JSON body, or an exception
/// to throw (e.g. a connection error).
class FakeReply {
  const FakeReply(this.status, [this.body, this.headers = const {}])
    : error = null;

  const FakeReply.fail(Object this.error)
    : status = 0,
      body = null,
      headers = const {};

  final int status;
  final Object? body;
  final Map<String, List<String>> headers;
  final Object? error;
}

/// An [HttpClientAdapter] that answers from [handler] and records every
/// request it saw.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Future<FakeReply> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  /// The headers of each request as sent. Retries reuse and change the
  /// same [RequestOptions], so [requests] only shows the last state.
  final List<Map<String, Object?>> sentHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    sentHeaders.add(Map.of(options.headers));
    final reply = await handler(options);
    if (reply.error != null) throw reply.error!;
    return ResponseBody.fromString(
      reply.body == null ? '' : jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...reply.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// The backend's error envelope.
Map<String, Object?> errorBody(String code, [Map<String, Object?>? details]) =>
    {
      'error': {
        'code': code,
        'message': code,
        'details': details ?? const {},
        'request_id': 'req-1',
      },
    };
