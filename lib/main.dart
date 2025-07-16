import 'package:flutter/material.dart';
import 'package:bmsapp/pages/home.dart';
import 'package:bmsapp/pages/login_page.dart';
import 'package:bmsapp/services/mongodb.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Add error handling
  try {
    await MongoService.init();
  } catch (e) {
    print('❌ MongoDB init failed: $e');
    // Handle DB failure gracefully
  }

  // Add this for Shared Preferences reliability
  try {
    final prefs = await SharedPreferences.getInstance();
    print('✅ SharedPreferences initialized');
  } catch (e) {
    print('⚠️ SharedPrefs failed: $e');
    // Fallback logic if needed
  }

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Building App',
      theme: AppTheme.lightTheme,  // Apply your custom theme here
      home: const AuthenticationWrapper(),
    );
  }
}

class AuthenticationWrapper extends StatefulWidget {
  const AuthenticationWrapper({super.key});

  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('userToken');
      final userId = prefs.getString('userId');

      if (token != null && userId != null) {
        setState(() {
          _isLoggedIn = true;
          _userId = userId;
        });
      }
    } catch (e) {
      print('⚠️ SharedPreferences error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isLoggedIn && _userId != null) {
      return HomePage(userId: _userId!);
    } else {
      return const LoginPage();
    }
  }
}
