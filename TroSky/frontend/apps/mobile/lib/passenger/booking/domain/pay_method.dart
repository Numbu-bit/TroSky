import 'package:flutter/foundation.dart';
import 'package:trosky_api/trosky_api.dart';

/// How Payment pays: from the TroSky Wallet, or with a saved MTN MoMo
/// number (`payment_method_id`; a new number is saved first).
@immutable
sealed class PayMethod {
  const PayMethod();

  /// What the device keeps to offer it again: "wallet", or the number's id.
  String get key;

  /// `POST /bookings/{id}/pay`'s body.
  PayBookingRequest get request;
}

/// The TroSky Wallet: debited at once.
final class WalletPay extends PayMethod {
  const WalletPay();

  static const String walletKey = 'wallet';

  @override
  String get key => walletKey;

  @override
  PayBookingRequest get request =>
      const PayBookingRequest(channel: PaymentChannel.wallet);

  @override
  bool operator ==(Object other) => other is WalletPay;

  @override
  int get hashCode => walletKey.hashCode;
}

/// A saved MTN MoMo number: the payer approves a prompt on their phone.
final class MomoPay extends PayMethod {
  const MomoPay(this.method);

  final PaymentMethodResponse method;

  @override
  String get key => method.id;

  @override
  PayBookingRequest get request =>
      PayBookingRequest(paymentMethodId: method.id);

  @override
  bool operator ==(Object other) => other is MomoPay && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// A masked number as Ghanaians write it, the Wallet's "055 *** 8821" (P9):
/// "+23324•••4567" gives "024 *** 4567". Other forms come back unchanged.
String localMasked(String masked) {
  final match = RegExp(r'^\+233(\d{2})\D+(\d{4})$').firstMatch(masked);
  if (match == null) return masked;
  return '0${match[1]} *** ${match[2]}';
}

/// [amount] ("16.50") in pesewas, so money is compared without doubles.
int pesewas(String amount) {
  final negative = amount.startsWith('-');
  final digits = negative ? amount.substring(1) : amount;
  final parts = digits.split('.');
  final fraction = (parts.length > 1 ? parts[1] : '').padRight(2, '0');
  final value =
      int.parse(parts[0].isEmpty ? '0' : parts[0]) * 100 +
      int.parse(fraction.substring(0, 2));
  return negative ? -value : value;
}
