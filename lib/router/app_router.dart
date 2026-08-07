
import 'package:go_router/go_router.dart';

// Screens will be imported here
import '../ui/dashboard/dashboard_screen.dart';
import '../ui/scanner/scanner_screen.dart';
import '../ui/settings/settings_screen.dart';
import '../ui/transactions/add_transaction_screen.dart';
import '../ui/transactions/transactions_screen.dart';
import '../data/database/database.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/transactions',
      builder: (context, state) => const TransactionsScreen(),
    ),
    GoRoute(
      path: '/scanner',
      builder: (context, state) => const ScannerScreen(),
    ),
    GoRoute(
      path: '/add_transaction',
      builder: (context, state) {
        final transaction = state.extra as TransactionEntity?;
        return AddTransactionScreen(transaction: transaction);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
