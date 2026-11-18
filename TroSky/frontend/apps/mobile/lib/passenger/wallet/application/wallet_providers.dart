import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trosky_api/trosky_api.dart';
import 'package:trosky_auth/trosky_auth.dart';
import 'package:trosky_core/trosky_core.dart';

import '../domain/wallet_args.dart';

/// Saved payment methods, newest-default first. Keep-alive so moving
/// between tabs doesn't re-fetch. Invalidate after add / update / delete.
final paymentMethodsProvider =
    FutureProvider<Result<List<PaymentMethodResponse>>>((ref) async {
      return ref.read(paymentRepositoryProvider).methods();
    });

/// Recent transactions for the home card: the last 5 (newest first).
final recentTransactionsProvider =
    FutureProvider<Result<Paginated<WalletTransactionResponse>>>((ref) async {
      return ref.read(paymentRepositoryProvider).transactions(limit: 5);
    });

/// Which filter chip the user has active on the expanded list.
class TransactionFilterController extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => TransactionFilter.all;
  void set(TransactionFilter filter) => state = filter;
}

final transactionFilterProvider =
    NotifierProvider<TransactionFilterController, TransactionFilter>(
      TransactionFilterController.new,
    );

/// Expanded transactions: a bigger page (20) filtered client-side so a
/// single response covers typical use. If the filter yields zero rows,
/// the UI shows the right empty state and the user can clear the chip.
final expandedTransactionsProvider =
    FutureProvider<Result<Paginated<WalletTransactionResponse>>>((ref) async {
      return ref.read(paymentRepositoryProvider).transactions(limit: 50);
    });

/// The current wallet balance, listed on the Top-up screen's success path
/// (not shown on P-17 per the design). Refreshes after a successful top-up.
final walletBalanceProvider = FutureProvider<Result<WalletResponse>>((
  ref,
) async {
  return ref.read(paymentRepositoryProvider).wallet();
});
