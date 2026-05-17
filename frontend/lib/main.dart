import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/app_config.dart';
import 'utils/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/post_job_screen.dart';
import 'screens/job_feed_screen.dart';
import 'screens/bids_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/review_screen.dart';
import 'screens/active_job_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appConfig.initialize();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ApkaHunarApp());
}

class ApkaHunarApp extends StatelessWidget {
  const ApkaHunarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apka Hunar',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      initialRoute: '/',
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/':
            return _fade(const SplashScreen());
          case '/login':
            return _fade(const LoginScreen());
          case '/signup':
            return _fade(const SignupScreen());
          case '/dashboard':
            return _fade(const DashboardScreen());
          case '/onboarding':
            return _fade(const OnboardingScreen());
          case '/post-job':
            return _slide(const PostJobScreen());
          case '/job-feed':
            return _slide(const JobFeedScreen());
          case '/posted-jobs':
            return _slide(const PostJobScreen());
          case '/bids':
            final jobId = settings.arguments as int;
            return _slide(BidsScreen(jobId: jobId));
          case '/chat':
            final args = settings.arguments as Map<String, dynamic>;
            return _slide(ChatScreen(
              jobId: args['jobId'],
              otherUserId: args['otherUserId'],
              otherName: args['otherName'],
            ));
          case '/review':
            final args = settings.arguments as Map<String, dynamic>;
            return _slide(ReviewScreen(
              jobId: args['jobId'],
              revieweeId: args['revieweeId'],
              revieweeName: args['revieweeName'],
            ));
          case '/active-job':
            return _slide(const ActiveJobScreen());
          case '/profile':
            final userId = settings.arguments as int?;
            return _slide(ProfileScreen(userId: userId));
          case '/settings':
            final args = settings.arguments as Map<String, dynamic>?;
            return _slide(SettingsScreen(
              user: args?['user'],
              onLogout: args?['onLogout'] ?? () {},
              onRefresh: args?['onRefresh'] ?? () {},
            ));
          default:
            return _fade(const LoginScreen());
        }
      },
    );
  }

  PageRoute _fade(Widget w) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => w,
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 300),
      );

  PageRoute _slide(Widget w) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => w,
        transitionsBuilder: (_, a, __, c) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
            CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
          ),
          child: c,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      );
}
