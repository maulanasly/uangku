import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/dashboard/dashboard_screen.dart';
import '../ui/scanner/scanner_screen.dart';
import '../ui/settings/settings_screen.dart';
import '../ui/settings/categories_screen.dart';
import '../ui/settings/budgets_screen.dart';
import '../ui/analytics/analytics_screen.dart';
import '../ui/transactions/add_transaction_screen.dart';
import '../ui/transactions/transactions_screen.dart';
import '../ui/receipts/receipt_collection_screen.dart';
import '../ui/list/shopping_lists_screen.dart';
import '../ui/list/shopping_list_detail_screen.dart';
import '../ui/shell/bottom_nav_shell.dart';
import '../data/database/database.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          BottomNavShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/transactions',
              builder: (context, state) => const TransactionsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/analytics',
              builder: (context, state) => const AnalyticsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/lists',
              builder: (context, state) => const ShoppingListsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/scanner',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const ScannerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: '/add_transaction',
      builder: (context, state) {
        final transaction = state.extra as TransactionEntity?;
        return AddTransactionScreen(transaction: transaction);
      },
    ),
    GoRoute(
      path: '/categories',
      builder: (context, state) => const CategoriesScreen(),
    ),
    GoRoute(
      path: '/budgets',
      builder: (context, state) => const BudgetsScreen(),
    ),
    GoRoute(
      path: '/receipts',
      builder: (context, state) => const ReceiptCollectionScreen(),
    ),
    GoRoute(
      path: '/shopping_list/:id',
      builder: (context, state) =>
          ShoppingListDetailScreen(listId: state.pathParameters['id']!),
    ),
  ],
);
