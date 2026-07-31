import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../shared/models/store.dart';
import '../../shared/models/product.dart';
import '../../shared/models/sale.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/home/ui/home_screen.dart';
import '../../features/products/ui/add_product_screen.dart';
import '../../features/pos/ui/ticket_detail_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGate(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => _ShellWrapper(child: child),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
          routes: [
            GoRoute(
              path: 'products/add',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final params = state.extra as Map<String, dynamic>? ?? {};
                return AddProductScreen(
                  businessId: params['businessId'] as String? ?? '',
                  storeId: params['storeId'] as String? ?? '',
                );
              },
            ),
            GoRoute(
              path: 'products/edit',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final params = state.extra as Map<String, dynamic>? ?? {};
                return AddProductScreen(
                  businessId: params['businessId'] as String? ?? '',
                  storeId: params['storeId'] as String? ?? '',
                  product: params['product'] as Product?,
                );
              },
            ),
            GoRoute(
              path: 'tickets/:saleId',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final params = state.extra as Map<String, dynamic>? ?? {};
                return TicketDetailScreen(
                  businessName: params['businessName'] as String? ?? '',
                  store: params['store'] as Store,
                  sale: params['sale'] as Sale,
                );
              },
            ),
          ],
        ),
      ],
    ),
  ],
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final path = state.matchedLocation;

    if (user == null && path != '/') {
      return '/';
    }
    if (user != null && path == '/') {
      return '/home';
    }
    return null;
  },
);

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class _ShellWrapper extends StatelessWidget {
  const _ShellWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}
