import 'package:flutter/material.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:bmsapp/services/cognito.dart';
import 'package:bmsapp/pages/home.dart';
import 'package:bmsapp/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  CognitoUserNewPasswordRequiredException? _newPwdChallenge;
  CognitoUser? _cognitoUser;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _cognitoService = CognitoService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('🔵 [LoginPage] Initialized');
  }


  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await _cognitoService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );


      if (session != null) {
        final idToken = session.idToken;
        final userId = idToken?.payload['sub'];
        final jwtToken = idToken?.jwtToken;

        if (userId == null || jwtToken == null) {
          throw Exception("User ID or JWT Token is missing");
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userToken', jwtToken);
        await prefs.setString('userId', userId);


        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage(userId: userId)),
        );
      }
    } on CognitoUserNewPasswordRequiredException catch (e) {
      // Store the exception (which holds the "Session" token)…
      _newPwdChallenge = e;
      // …then show the dialog
      _showNewPasswordPrompt();
    }on CognitoClientException catch (e) {
      print('🔴 [Cognito] Client Exception: ${e.code} - ${e.message}');
      if (e.code == 'NotAuthorizedException') {
        setState(() {
          _errorMessage = 'Incorrect email or password.';
        });
      } else {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    print('🧹 [LoginPage] Disposing controllers');
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 [LoginPage] Building UI');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Snowflake Icon
                  const Icon(
                    Icons.ac_unit,
                    color: Color(0xFF1A73E8),
                    size: 64.0,
                  ),
                  const SizedBox(height: 24.0),
                  // Log In Text
                  const Text(
                    'Log In',
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32.0),
                  // Email Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email:',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Enter email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 14.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  // Password Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Password:',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Enter Password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 14.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  // Forgot Password Link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        print('🔘 [LoginPage] Forgot password clicked');
                      },
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '', //put your forgetpassword here if u wanna implement this funciton
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  // Error Message (if any)
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 50.0,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(

                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25.0),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 24.0,
                        height: 24.0,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.0,
                        ),
                      )
                          : const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32.0),
                  // Copyright text
                  Text(
                    '© ${DateTime.now().year} Singapore Polytechnic',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  void _showNewPasswordPrompt() {
    final newPasswordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('You must change your password to continue.'),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  hintText: 'Enter your new password',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final session = await _cognitoService.completeNewPasswordChallenge(
                    newPasswordController.text.trim(),
                  );

                  // Handle successful password change
                  final idToken = session!.idToken!;
                  final userId = idToken.payload['sub'] as String;

                  // Save tokens and navigate to home
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('userToken', idToken.jwtToken!);
                  await prefs.setString('userId', userId);

                  if (!mounted) return;
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HomePage(userId: userId),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }
}