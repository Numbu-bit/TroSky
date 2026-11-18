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

  /// `POST /wallet/topups`: starts a top-up, through MoMo in sandbox
  /// (PR #53). `successful` or `processing` as for [pay]. 404 when the
  /// backend predates PR #53 (the tester menu hides the button then).
  Future<Result<PaymentResponse>> topUpWallet(
    WalletTopupRequest request, {
    required String idempotencyKey,
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

  /// `PATCH /users/me/payment-methods/{id}`: rename a method or make it
  /// the default. To change the default, set `isDefault: true` on the
  /// new method; the backend clears the flag on the previous one.
  Future<Result<PaymentMethodResponse>> updateMethod(
    String methodId,
    PaymentMethodUpdateRequest request,
  );

  /// `DELETE /users/me/payment-methods/{id}`. If the removed one was the
  /// default, the backend promotes the newest remaining method.
  Future<Result<void>> deleteMethod(String methodId);

  /// `GET /wallet/transactions`: the signed-in user's wallet ledger,
  /// newest first. Optional [referenceType] narrows to one kind
  /// (`walletTopup`, `bookingPayment`, `refund`, …).
  Future<Result<Paginated<WalletTransactionResponse>>> transactions({
    WalletReferenceType? referenceType,
    int limit = 20,
    int offset = 0,
  });
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
  Future<Result<PaymentResponse>> topUpWallet(
    WalletTopupRequest request, {
    required String idempotencyKey,
  }) => apiCall(
    () => _dio.post<Object?>(
      '/wallet/topups',
      data: request.toJson(),
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
    (data) => PaymentResponse.fromJson(jsonObject(data)),
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

  @override
  Future<Result<PaymentMethodResponse>> updateMethod(
    String methodId,
    PaymentMethodUpdateRequest request,
  ) => apiCall(
    () => _dio.patch<Object?>(
      '/users/me/payment-methods/$methodId',
      data: request.toJson(),
    ),
    (data) => PaymentMethodResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<void>> deleteMethod(String methodId) => apiCall(
    () => _dio.delete<Object?>('/users/me/payment-methods/$methodId'),
    (_) {},
  );

  @override
  Future<Result<Paginated<WalletTransactionResponse>>> transactions({
    WalletReferenceType? referenceType,
    int limit = 20,
    int offset = 0,
  }) => apiCall(
    () => _dio.get<Object?>(
      '/wallet/transactions',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (referenceType != null)
          'reference_type': _referenceTypeParam(referenceType),
      },
    ),
    (data) =>
        Paginated.fromJson(jsonObject(data), WalletTransactionResponse.fromJson),
  );
}

/// Snake-case value for `reference_type` query param. Keeps the DTO's
/// enum map internal; the backend expects the literal snake_case value.
String _referenceTypeParam(WalletReferenceType type) => switch (type) {
  WalletReferenceType.bookingPayment => 'booking_payment',
  WalletReferenceType.walletTopup => 'wallet_topup',
  WalletReferenceType.refund => 'refund',
  WalletReferenceType.adminAdjustment => 'admin_adjustment',
  WalletReferenceType.tripEarning => 'trip_earning',
  WalletReferenceType.withdrawal => 'withdrawal',
};
