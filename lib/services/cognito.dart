import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter/foundation.dart';

class CognitoService {
  static const String _userPoolId = 'ap-southeast-1_EOC1FP1QW';
  static const String _clientId = '3eos0b6l6p89r7r1524opl2kak';

  final CognitoUserPool _userPool;
  late CognitoUser _currentUser;

  CognitoService() : _userPool = CognitoUserPool(_userPoolId, _clientId);

  CognitoUser get currentUser => _currentUser;

  Future<CognitoUserSession?> signIn(String email, String password) async {
    print('🔐 [Cognito] Starting sign-in process for $email');

    if (email.isEmpty || password.isEmpty) {
      print('⚠️ [Cognito] Email or password missing');
      throw Exception('Email and password are required');
    }

    _currentUser = CognitoUser(email, _userPool);
    final authDetails = AuthenticationDetails(username: email, password: password);

    try {
      print('📧 [Cognito] Authenticating user...');
      final session = await _currentUser.authenticateUser(authDetails);

      if (session == null) {
        print('❌ [Cognito] Authentication returned null session');
        return null;
      }

      print('✅ [Cognito] Sign-in successful!');
      print('JWT Token: ${session.accessToken.jwtToken}');
      print('ID Token: ${session.idToken?.jwtToken}');

      final idToken = session.idToken;
      final userId = idToken?.payload['sub'];
      print('👤 User ID: $userId');

      return session;

    } on CognitoUserNewPasswordRequiredException catch (e, s) {
      print('🟡 [Cognito] New password required');
      print('Stack Trace: $s');
      rethrow;
    } on CognitoUserMfaRequiredException catch (e, s) {
      print('🟡 [Cognito] MFA Required');
      print('Stack Trace: $s');
      rethrow;
    } on CognitoClientException catch (e, s) {
      print('🔴 [Cognito] Client Exception: ${e.code} - ${e.message}');
      print('Stack Trace: $s');

      if (e.code == 'NotAuthorizedException') {
        throw Exception('Incorrect email or password');
      } else if (e.code == 'UserNotFoundException') {
        throw Exception('User not found');
      } else {
        throw Exception('Login failed: ${e.message}');
      }
    } catch (e, s) {
      print('💥 [Cognito] Unknown error during sign-in: $e');
      print('Stack Trace: $s');
      throw Exception('Login failed: $e');
    }
  }

  Future<CognitoUserSession?> completeNewPasswordChallenge(String newPassword) async {
    try {
      print('🔄 [Cognito] Completing new password challenge...');
      final session = await _currentUser.sendNewPasswordRequiredAnswer(newPassword);

      print('✅ [Cognito] Password changed successfully!');
      return session;
    } catch (e, s) {
      print('🔴 [Cognito] Error during password change: $e');
      print('Stack Trace: $s');
      rethrow;
    }
  }
}