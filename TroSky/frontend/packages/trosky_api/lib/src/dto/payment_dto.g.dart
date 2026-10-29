// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PaymentResponse _$PaymentResponseFromJson(Map<String, dynamic> json) =>
    _PaymentResponse(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String?,
      purpose: $enumDecode(
        _$PaymentPurposeEnumMap,
        json['purpose'],
        unknownValue: PaymentPurpose.bookingPayment,
      ),
      channel: $enumDecode(
        _$PaymentChannelEnumMap,
        json['channel'],
        unknownValue: PaymentChannel.card,
      ),
      status: $enumDecode(
        _$PaymentStatusEnumMap,
        json['status'],
        unknownValue: PaymentStatus.processing,
      ),
      amount: decimalString(json['amount']),
      currency: json['currency'] as String,
      refundedAmount: decimalString(json['refunded_amount']),
      providerReference: json['provider_reference'] as String?,
      failureReason: json['failure_reason'] as String?,
      initiatedAt: json['initiated_at'] == null
          ? null
          : DateTime.parse(json['initiated_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$PaymentResponseToJson(_PaymentResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'booking_id': ?instance.bookingId,
      'purpose': _$PaymentPurposeEnumMap[instance.purpose]!,
      'channel': _$PaymentChannelEnumMap[instance.channel]!,
      'status': _$PaymentStatusEnumMap[instance.status]!,
      'amount': instance.amount,
      'currency': instance.currency,
      'refunded_amount': instance.refundedAmount,
      'provider_reference': ?instance.providerReference,
      'failure_reason': ?instance.failureReason,
      'initiated_at': ?instance.initiatedAt?.toIso8601String(),
      'completed_at': ?instance.completedAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$PaymentPurposeEnumMap = {
  PaymentPurpose.bookingPayment: 'booking_payment',
  PaymentPurpose.walletTopup: 'wallet_topup',
};

const _$PaymentChannelEnumMap = {
  PaymentChannel.mtnMomo: 'mtn_momo',
  PaymentChannel.telecelCash: 'telecel_cash',
  PaymentChannel.airteltigoMoney: 'airteltigo_money',
  PaymentChannel.card: 'card',
  PaymentChannel.wallet: 'wallet',
};

const _$PaymentStatusEnumMap = {
  PaymentStatus.pending: 'pending',
  PaymentStatus.processing: 'processing',
  PaymentStatus.successful: 'successful',
  PaymentStatus.failed: 'failed',
  PaymentStatus.cancelled: 'cancelled',
  PaymentStatus.refunded: 'refunded',
  PaymentStatus.partiallyRefunded: 'partially_refunded',
};

_PayBookingRequest _$PayBookingRequestFromJson(Map<String, dynamic> json) =>
    _PayBookingRequest(
      paymentMethodId: json['payment_method_id'] as String?,
      channel: $enumDecodeNullable(_$PaymentChannelEnumMap, json['channel']),
      payerPhoneNumber: json['payer_phone_number'] as String?,
    );

Map<String, dynamic> _$PayBookingRequestToJson(_PayBookingRequest instance) =>
    <String, dynamic>{
      'payment_method_id': ?instance.paymentMethodId,
      'channel': ?_$PaymentChannelEnumMap[instance.channel],
      'payer_phone_number': ?instance.payerPhoneNumber,
    };

_WalletResponse _$WalletResponseFromJson(Map<String, dynamic> json) =>
    _WalletResponse(
      balance: decimalString(json['balance']),
      currency: json['currency'] as String,
    );

Map<String, dynamic> _$WalletResponseToJson(_WalletResponse instance) =>
    <String, dynamic>{
      'balance': instance.balance,
      'currency': instance.currency,
    };

_PaymentMethodResponse _$PaymentMethodResponseFromJson(
  Map<String, dynamic> json,
) => _PaymentMethodResponse(
  id: json['id'] as String,
  channel: $enumDecode(
    _$PaymentChannelEnumMap,
    json['channel'],
    unknownValue: PaymentChannel.card,
  ),
  maskedNumber: json['masked_number'] as String,
  label: json['label'] as String?,
  isDefault: json['is_default'] as bool,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$PaymentMethodResponseToJson(
  _PaymentMethodResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'channel': _$PaymentChannelEnumMap[instance.channel]!,
  'masked_number': instance.maskedNumber,
  'label': ?instance.label,
  'is_default': instance.isDefault,
  'created_at': instance.createdAt.toIso8601String(),
};

_PaymentMethodCreateRequest _$PaymentMethodCreateRequestFromJson(
  Map<String, dynamic> json,
) => _PaymentMethodCreateRequest(
  channel: $enumDecode(_$PaymentChannelEnumMap, json['channel']),
  phoneNumber: json['phone_number'] as String,
  label: json['label'] as String?,
  isDefault: json['is_default'] as bool? ?? false,
);

Map<String, dynamic> _$PaymentMethodCreateRequestToJson(
  _PaymentMethodCreateRequest instance,
) => <String, dynamic>{
  'channel': _$PaymentChannelEnumMap[instance.channel]!,
  'phone_number': instance.phoneNumber,
  'label': ?instance.label,
  'is_default': instance.isDefault,
};
