import 'package:flutter/material.dart';

import '../main.dart';
import '../services/api_service.dart';
import 'auth_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final ApiService _api = ApiService();
  bool _checking = true;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final loggedIn = await _api.isLoggedIn();

      if (!mounted) return;
      setState(() {
        _authenticated = loggedIn;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authenticated = false;
        _checking = false;
      });
    }
  }

  void _onAuthenticated() {
    setState(() => _authenticated = true);
  }

  Future<void> logout() async {
    await _api.logout();
    if (!mounted) return;
    setState(() => _authenticated = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_authenticated) {
      return AuthScreen(onAuthenticated: _onAuthenticated);
    }

    return WaveHomePage(onLogout: logout);
  }
}
