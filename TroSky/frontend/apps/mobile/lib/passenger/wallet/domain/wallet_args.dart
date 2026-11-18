import 'package:trosky_api/trosky_api.dart';

/// Compile-time flag for the whole Wallet feature (P-17/P-18). On in
/// staging and demo (`env/staging.json`), off on prod until Maher-007
/// reviews the top-up sandbox round.
const bool walletEnabled = bool.fromEnvironment('WALLET_ENABLED');

/// Where the user came from, for the `wallet_opened` event.
enum WalletEntryPoint { profile, tester, tripsOverflow, addMethod }

/// Opens P-18 (Top up). `method` is the preselected saved method;
/// `presetAmount` lets the tester menu jump straight to a ₵100 top-up.
class TopUpArgs {
  const TopUpArgs({required this.method, this.presetAmount});

  final PaymentMethodResponse method;
  final String? presetAmount;
}

/// How we classify a wallet transaction's "kind" for icon + copy on P-17.
/// Mirrors [WalletReferenceType] but keeps the UI mapping in one place.
TransactionKind kindFor(WalletTransactionResponse txn) =>
    switch ((txn.referenceType, txn.entryType)) {
      (WalletReferenceType.walletTopup, _) => TransactionKind.topUp,
      (WalletReferenceType.bookingPayment, _) => TransactionKind.trip,
      (WalletReferenceType.refund, _) => TransactionKind.refund,
      (WalletReferenceType.tripEarning, _) => TransactionKind.earning,
      (WalletReferenceType.withdrawal, _) => TransactionKind.withdrawal,
      (WalletReferenceType.adminAdjustment, _) => TransactionKind.adjustment,
    };

enum TransactionKind { topUp, trip, refund, earning, withdrawal, adjustment }

/// The chip filter on the expanded transactions list.
enum TransactionFilter { all, topUps, trips, refunds }

/// Does [filter] include [kind]?
bool filterIncludes(TransactionFilter filter, TransactionKind kind) =>
    switch (filter) {
      TransactionFilter.all => true,
      TransactionFilter.topUps => kind == TransactionKind.topUp,
      TransactionFilter.trips => kind == TransactionKind.trip,
      TransactionFilter.refunds => kind == TransactionKind.refund,
    };
