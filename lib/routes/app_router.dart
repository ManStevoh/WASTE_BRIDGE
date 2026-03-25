import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/features/auth/auth.dart';
import 'package:waste_bridge/models/marketplace_listing.dart';
import 'package:waste_bridge/features/collector/collector.dart';
import 'package:waste_bridge/features/generator/generator.dart';
import 'package:waste_bridge/features/recycler/recycler.dart';
import 'package:waste_bridge/features/shared/shared.dart';
import 'package:waste_bridge/providers/app_providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/role',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      GoRoute(
        path: '/generator',
        builder: (context, state) => const GeneratorHomeScreen(),
        routes: [
          GoRoute(
            path: 'request-pickup',
            builder: (context, state) => const RequestPickupScreen(),
          ),
          GoRoute(
            path: 'requests',
            builder: (context, state) => const MyRequestsScreen(),
          ),
          GoRoute(
            path: 'impact',
            builder: (context, state) => const ImpactDashboardScreen(),
          ),
          GoRoute(
            path: 'create-listing',
            builder: (context, state) => const CreateListingScreen(),
          ),
          GoRoute(
            path: 'track/:id',
            builder: (context, state) =>
                RequestTrackingScreen(requestId: state.pathParameters['id']!),
          ),
        ],
      ),

      GoRoute(
        path: '/collector',
        builder: (context, state) => const CollectorDashboardScreen(),
        routes: [
          GoRoute(
            path: 'job/:id',
            builder: (context, state) =>
                JobDetailsScreen(jobId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'active/:id',
            builder: (context, state) =>
                ActiveJobScreen(jobId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'map/:id',
            builder: (context, state) =>
                PickupMapScreen(jobId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'earnings',
            builder: (context, state) => const EarningsScreen(),
          ),
          GoRoute(
            path: 'wallet',
            builder: (context, state) => const WalletLedgerScreen(),
          ),
        ],
      ),

      GoRoute(
        path: '/recycler',
        builder: (context, state) => const RecyclerDashboardScreen(),
        routes: [
          GoRoute(
            path: 'listing',
            builder: (context, state) {
              final listing = state.extra as MarketplaceListing?;
              if (listing == null) {
                return const Scaffold(
                  body: Center(child: Text('No listing selected.')),
                );
              }
              return RecyclerListingDetailScreen(listing: listing);
            },
          ),
          GoRoute(
            path: 'order/:orderId',
            builder: (context, state) => PurchaseDetailScreen(
              orderPublicId: state.pathParameters['orderId']!,
            ),
          ),
          GoRoute(
            path: 'transactions',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: 'wallet',
            builder: (context, state) => const WalletLedgerScreen(),
          ),
        ],
      ),

      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/kyc',
        builder: (context, state) => const KycScreen(),
      ),
      GoRoute(
        path: '/users/:userPublicId/ratings',
        builder: (context, state) => UserRatingsScreen(
          userPublicId: state.pathParameters['userPublicId']!,
        ),
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider).valueOrNull;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/role' ||
          state.matchedLocation == '/onboarding';
      if (auth == null && !isAuthRoute) return '/role';
      return null;
    },
  );
});
