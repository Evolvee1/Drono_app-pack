import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/config.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/devices/presentation/devices_screen.dart';
import 'features/commands/presentation/commands_screen.dart';
import 'features/monitoring/presentation/monitoring_screen.dart';
import 'features/network/presentation/network_screen.dart';
import 'utils/logger.dart';
import 'utils/web_logger.dart';
import 'shared/widgets/debug_menu.dart';
import 'utils/error_overlay.dart';

void main() async {
  try {
    // Initialize Flutter binding and app in same zone
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize error logging system
    WebLogger.initialize();
    
    // Load environment variables
    await dotenv.load(fileName: ".env");
    
    // Log startup info
    log.info('Starting Drono Dashboard application');
    log.info('Environment loaded - API_BASE_URL: ${Config.baseUrl}, WS_URL: ${Config.wsUrl}');
    
    // Set up error handlers for mouse tracker errors
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('_debugDuringDeviceUpdate') || 
          details.exception.toString().contains('RangeError') ||
          details.exception.toString().contains('Navigator operation requested with a context') ||
          details.exception.toString().contains('build scope') ||
          details.exception.toString().contains('_dependents.isEmpty')) {
        // Silently handle mouse tracker and range errors and navigation errors
        log.warning('Non-critical Flutter framework error: ${details.exception}');
        return; // Don't propagate these errors further
      } else {
        // Report other errors
        WebLogger.logError('Flutter Error', details.exception.toString(), details.stack.toString());
        FlutterError.presentError(details);
      }
    };
    
    // Run the app directly
    runApp(
      const ProviderScope(
        child: DronoDashboard(),
      ),
    );
  } catch (e, stackTrace) {
    print('Error during app initialization: $e');
    print(stackTrace);
  }
}

class DronoDashboard extends StatelessWidget {
  const DronoDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Drono Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: _router,
      builder: (context, child) {
        // Add error overlay and debug menu
        if (child == null) return const SizedBox.shrink();
        return ErrorOverlay(
          key: ErrorOverlayManager().overlayKey,
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) => Stack(
                  children: [
                    child,
                    const Positioned(
                      bottom: 10,
                      right: 10,
                      child: DebugMenu(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

final _router = GoRouter(
  initialLocation: '/monitoring',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => DashboardShell(child: child),
      routes: [
        GoRoute(
          path: '/devices',
          builder: (context, state) => const DevicesScreen(),
        ),
        GoRoute(
          path: '/commands',
          builder: (context, state) => const CommandsScreen(),
        ),
        GoRoute(
          path: '/monitoring',
          builder: (context, state) => const MonitoringScreen(),
        ),
        GoRoute(
          path: '/network',
          builder: (context, state) => const NetworkScreen(),
        ),
      ],
    ),
  ],
  // Log navigation errors
  errorBuilder: (context, state) {
    log.error('Navigation error: ${state.error}');
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Route not found: ${state.uri.path}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/monitoring'),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    );
  },
);

class DashboardShell extends StatefulWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _selectedIndex = 2; // Default to monitoring

  @override
  Widget build(BuildContext context) {
    try {
      // Safely determine the current index when possible
      final String location = GoRouterState.of(context).uri.path;
      _selectedIndex = _calculateSelectedIndex(location);
      
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.of(context).size.width >= 800,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.devices),
                  label: Text('Devices'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.terminal),
                  label: Text('Commands'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.monitor_heart),
                  label: Text('Monitoring'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.network_check),
                  label: Text('Network'),
                ),
              ],
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    } catch (error, stackTrace) {
      log.error('Error in DashboardShell', error, stackTrace);
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Error loading dashboard layout'),
              Text(
                error.toString().length > 100
                    ? '${error.toString().substring(0, 100)}...'
                    : error.toString(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  try {
                    GoRouter.of(context).go('/login');
                  } catch (e) {
                    // If navigation fails, try to restart the app
                    log.error('Failed to navigate: $e');
                  }
                },
                child: const Text('Return to Login'),
              ),
            ],
          ),
        ),
      );
    }
  }

  int _calculateSelectedIndex(String location) {
    try {
      if (location.startsWith('/devices')) return 0;
      if (location.startsWith('/commands')) return 1;
      if (location.startsWith('/monitoring')) return 2;
      if (location.startsWith('/network')) return 3;
      return 2; // Default to monitoring
    } catch (e, stackTrace) {
      log.error('Error calculating selected index', e, stackTrace);
      return 2; // Default to monitoring if there's an error
    }
  }

  void _onItemTapped(int index) {
    try {
      // Update state first to avoid UI jumps
      setState(() {
        _selectedIndex = index;
      });
      
      // Then navigate
      switch (index) {
        case 0:
          GoRouter.of(context).go('/devices');
          break;
        case 1:
          GoRouter.of(context).go('/commands');
          break;
        case 2:
          GoRouter.of(context).go('/monitoring');
          break;
        case 3:
          GoRouter.of(context).go('/network');
          break;
        default:
          log.warning('Unknown navigation index: $index');
          GoRouter.of(context).go('/monitoring');
      }
    } catch (e, stackTrace) {
      log.error('Error during navigation', e, stackTrace);
    }
  }
}

      if (location.startsWith('/devices')) return 0;
      if (location.startsWith('/commands')) return 1;
      if (location.startsWith('/monitoring')) return 2;
      if (location.startsWith('/network')) return 3;
      return 2; // Default to monitoring
    } catch (e, stackTrace) {
      log.error('Error calculating selected index', e, stackTrace);
      return 2; // Default to monitoring if there's an error
    }
  }

  void _onItemTapped(int index) {
    try {
      // Update state first to avoid UI jumps
      setState(() {
        _selectedIndex = index;
      });
      
      // Then navigate
      switch (index) {
        case 0:
          GoRouter.of(context).go('/devices');
          break;
        case 1:
          GoRouter.of(context).go('/commands');
          break;
        case 2:
          GoRouter.of(context).go('/monitoring');
          break;
        case 3:
          GoRouter.of(context).go('/network');
          break;
        default:
          log.warning('Unknown navigation index: $index');
          GoRouter.of(context).go('/monitoring');
      }
    } catch (e, stackTrace) {
      log.error('Error during navigation', e, stackTrace);
    }
  }
}