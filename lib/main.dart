import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/storage/local_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_toast.dart';
import 'features/auth/presentation/auth_state.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/coach_welcome_wizard_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/student/presentation/student_dashboard_screen.dart';
import 'features/parent/presentation/parent_dashboard_screen.dart';

import 'package:flutter/services.dart';

import 'core/services/network_service.dart';
import 'core/presentation/network_error_screen.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enforce solid white system navigation bar for phone 3-button / gesture bars
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Hive storage helper
  await LocalStorage.init();

  // Initialize Notification Service
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('[Notification init error] $e');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        navigatorKey: AppToast.navigatorKey,
        title: 'AcademyPro Athlete Command',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreenBody(),
      );
    }

    final isOnline = ref.watch(networkStatusProvider);

    final authState = ref.watch(authProvider);
    final token = LocalStorage.getToken();
    final profile = authState.userProfile ?? LocalStorage.getUserProfile();
    final isAuthenticated = authState.status == AuthStatus.authenticated || 
        (token != null && profile != null && authState.status != AuthStatus.unauthenticated);

    Widget homeScreen = const LoginScreen();
    if (isAuthenticated && profile != null) {
      final role = (profile['role'] ?? '').toString().trim();
      final firstName = (profile['first_name'] ?? '').toString().trim();
      final lastName = (profile['last_name'] ?? profile['surname'] ?? '').toString().trim();
      final isFirstTime = profile['is_first_time'] == true || profile['is_first_time'] == 1 || (firstName.isEmpty && lastName.isEmpty);

      if (role == 'Headmaster' || role == 'Coach') {
        if (isFirstTime) {
          homeScreen = const CoachWelcomeWizardScreen();
        } else {
          homeScreen = const DashboardScreen();
        }
      } else if (role == 'Parent') {
        homeScreen = const ParentDashboardScreen();
      } else if (role == 'Student') {
        homeScreen = const StudentDashboardScreen();
      } else {
        homeScreen = Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Invalid Role: "$role"',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your account role is not recognized. Valid roles are Headmaster, Coach, Student, or Parent.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                    child: const Text('Log Out'),
                  )
                ],
              ),
            ),
          ),
        );
      }
    }

    return MaterialApp(
      navigatorKey: AppToast.navigatorKey,
      title: 'AcademyPro Athlete Command',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? homeScreen,
            // Full-screen overlay when offline — keeps the app tree alive underneath
            if (!isOnline)
              const Positioned.fill(
                child: NetworkErrorScreen(),
              ),
          ],
        );
      },
      home: homeScreen,
    );
  }
}

class SplashScreenBody extends StatelessWidget {
  const SplashScreenBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120.0,
              height: 120.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28.0),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF003EC7).withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28.0),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF003EC7),
                    child: const Icon(Icons.shield, color: Colors.white, size: 64.0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24.0),
            const Text(
              'AcademyPro',
              style: TextStyle(
                fontSize: 28.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6.0),
            const Text(
              'ATHLETE COMMAND & PERFORMANCE',
              style: TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 48.0),
            const SizedBox(
              width: 24.0,
              height: 24.0,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF003EC7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
