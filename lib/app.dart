import 'package:expense_tracker/config/routes.dart';
import 'package:expense_tracker/shared/di/app_init_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(appInitProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: init.when(
        loading: () => _loadingRouter,
        error: (e, st) => _errorRouter(e),
        data: (_) => router,
      ),
    );
  }

  /// Router shown during initialization loading state
  GoRouter get _loadingRouter => GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    ],
  );

  /// Router shown when initialization fails
  GoRouter _errorRouter(Object error) => GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            Scaffold(body: Center(child: Text('Init failed: $error'))),
      ),
    ],
  );
}
