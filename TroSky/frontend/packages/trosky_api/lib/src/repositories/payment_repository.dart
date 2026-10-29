import 'package:dio/dio.dart';
import 'package:trosky_core/trosky_core.dart';

import '../client/api_client.dart';
import '../dto/paginated.dart';
import '../dto/payment_dto.dart';

/// Paying for bookings, the wallet and saved mobile money numbers
/// (backend/app/api/v1/bookings.py `pay`, payments.py, users.py).
abstract interface class PaymentRepository {
  /// `POST /bookings/{id}/pay` for a booking that is `pending` (accepted,
  /// not paid). The wallet is debited at once: `successful`, the booking
  /// `confirmed`. Mobile money answers `processing`, the booking is
  /// `payment_pending`, until the payer approves; poll [sync].
  /// [idempotencyKey] makes a retry of the same tap return the same
  /// payment.
  ///
  /// 402 `INSUFFICIENT_WALLET_BALANCE`, 409 `BOOKING_NOT_PAYABLE` (not
  /// `pending`: already paying, paid, or ended), 404, 422.
  Future<Result<PaymentResponse>> pay(
    String bookingId,
    PayBookingRequest request, {
    required String idempotencyKey,
  });

  /// `POST /payments/{id}/sync`: asks the provider now. A failed payment
  /// puts its booking back to `pending`, to be paid again.
  Future<Result<PaymentResponse>> sync(String paymentId);

  /// `GET /payments`: the signed-in user's payments, newest first.
  Future<Result<Paginated<PaymentResponse>>> list({
    int limit = 20,
    int offset = 0,
  });

  /// `GET /wallet`.
  Future<Result<WalletResponse>> wallet();

  /// `GET /users/me/payment-methods`: saved mobile money numbers.
  Future<Result<List<PaymentMethodResponse>>> methods();

  /// `POST /users/me/payment-methods`. 422 `VALIDATION_ERROR` for a number
  /// that isn't a valid mobile money number, 409 `CONFLICT` when it is
  /// saved already.
  Future<Result<PaymentMethodResponse>> addMethod(
    PaymentMethodCreateRequest request,
  );
}

/// [PaymentRepository] against the backend.
class LivePaymentRepository implements PaymentRepository {
  LivePaymentRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<PaymentResponse>> pay(
    String bookingId,
    PayBookingRequest request, {
    required String idempotencyKey,
  }) => apiCall(
    () => _dio.post<Object?>(
      '/bookings/$bookingId/pay',
      data: request.toJson(),
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
    (data) => PaymentResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<PaymentResponse>> sync(String paymentId) => apiCall(
    () => _dio.post<Object?>('/payments/$paymentId/sync'),
    (data) => PaymentResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<Paginated<PaymentResponse>>> list({
    int limit = 20,
    int offset = 0,
  }) => apiCall(
    () => _dio.get<Object?>(
      '/payments',
      queryParameters: {'limit': limit, 'offset': offset},
    ),
    (data) => Paginated.fromJson(jsonObject(data), PaymentResponse.fromJson),
  );

  @override
  Future<Result<WalletResponse>> wallet() => apiCall(
    () => _dio.get<Object?>('/wallet'),
    (data) => WalletResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<List<PaymentMethodResponse>>> methods() => apiCall(
    () => _dio.get<Object?>('/users/me/payment-methods'),
    (data) => [
      for (final item in data! as List<Object?>)
        PaymentMethodResponse.fromJson(jsonObject(item)),
    ],
  );

  @override
  Future<Result<PaymentMethodResponse>> addMethod(
    PaymentMethodCreateRequest request,
  ) => apiCall(
    () =>
        _dio.post<Object?>('/users/me/payment-methods', data: request.toJson()),
    (data) => PaymentMethodResponse.fromJson(jsonObject(data)),
  );
}
