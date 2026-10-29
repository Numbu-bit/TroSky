// Payments, the wallet and saved payment methods, field for field as in
// backend/app/schemas/payment.py.

import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_decimal.dart';

part 'payment_dto.freezed.dart';
part 'payment_dto.g.dart';

/// `PaymentChannel` (backend/app/providers/payments/base.py). Only
/// [mtnMomo] and [wallet] are live; the others answer that the channel is
/// unavailable (G11). A channel added later reads as [card].
@JsonEnum(fieldRename: FieldRename.snake)
enum PaymentChannel { mtnMomo, telecelCash, airteltigoMoney, card, wallet }

/// `PaymentStatus` (backend/app/models/payments.py). A mobile money
/// payment is [processing] until its provider answers.
@JsonEnum(fieldRename: FieldRename.snake)
enum PaymentStatus {
  pending,
  processing,
  successful,
  failed,
  cancelled,
  refunded,
  partiallyRefunded,
}

@JsonEnum(fieldRename: FieldRename.snake)
enum PaymentPurpose { bookingPayment, walletTopup }

/// `PaymentResponse`. Money stays exactly as sent ("16.50").
@freezed
abstract class PaymentResponse with _$PaymentResponse {
  const factory PaymentResponse({
    required String id,
    String? bookingId,
    @JsonKey(unknownEnumValue: PaymentPurpose.bookingPayment)
    required PaymentPurpose purpose,
    @JsonKey(unknownEnumValue: PaymentChannel.card)
    required PaymentChannel channel,
    @JsonKey(unknownEnumValue: PaymentStatus.processing)
    required PaymentStatus status,
    @JsonKey(fromJson: decimalString) required String amount,
    required String currency,
    @JsonKey(fromJson: decimalString) required String refundedAmount,
    String? providerReference,

    /// Why it failed ("Customer declined the payment prompt.").
    String? failureReason,
    DateTime? initiatedAt,
    DateTime? completedAt,
    required DateTime createdAt,
  }) = _PaymentResponse;

  factory PaymentResponse.fromJson(Map<String, dynamic> json) =>
      _$PaymentResponseFromJson(json);
}

/// `PayBookingRequest` for `POST /bookings/{id}/pay`: a saved method, or a
/// channel (with the number to charge for mobile money).
@freezed
abstract class PayBookingRequest with _$PayBookingRequest {
  const factory PayBookingRequest({
    String? paymentMethodId,
    PaymentChannel? channel,
    String? payerPhoneNumber,
  }) = _PayBookingRequest;

  factory PayBookingRequest.fromJson(Map<String, dynamic> json) =>
      _$PayBookingRequestFromJson(json);
}

/// `WalletResponse` from `GET /wallet`.
@freezed
abstract class WalletResponse with _$WalletResponse {
  const factory WalletResponse({
    @JsonKey(fromJson: decimalString) required String balance,
    required String currency,
  }) = _WalletResponse;

  factory WalletResponse.fromJson(Map<String, dynamic> json) =>
      _$WalletResponseFromJson(json);
}

/// `PaymentMethodResponse`: a saved mobile money number.
@freezed
abstract class PaymentMethodResponse with _$PaymentMethodResponse {
  const factory PaymentMethodResponse({
    required String id,
    @JsonKey(unknownEnumValue: PaymentChannel.card)
    required PaymentChannel channel,

    /// "+23324•••4567".
    required String maskedNumber,
    String? label,
    required bool isDefault,
    required DateTime createdAt,
  }) = _PaymentMethodResponse;

  factory PaymentMethodResponse.fromJson(Map<String, dynamic> json) =>
      _$PaymentMethodResponseFromJson(json);
}

/// `PaymentMethodCreateRequest` for `POST /users/me/payment-methods`.
@freezed
abstract class PaymentMethodCreateRequest with _$PaymentMethodCreateRequest {
  const factory PaymentMethodCreateRequest({
    required PaymentChannel channel,
    required String phoneNumber,
    String? label,
    @Default(false) bool isDefault,
  }) = _PaymentMethodCreateRequest;

  factory PaymentMethodCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$PaymentMethodCreateRequestFromJson(json);
}
