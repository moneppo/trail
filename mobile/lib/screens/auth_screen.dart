import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../theme/trail_theme.dart';
import '../widgets/trail_widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _service = SupabaseService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await _service.signUp(_emailController.text.trim(), _passwordController.text);
      } else {
        await _service.signIn(_emailController.text.trim(), _passwordController.text);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = TrailColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: Compass()),
                const SizedBox(height: 32),
                Cartouche(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isSignUp ? 'Join Trail' : 'Trail',
                        style: TrailText.titleXl(c),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Walks, drawn in ink on paper',
                        style: TrailText.caption(c),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      const LabelText('Email'),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TrailText.body(c),
                        decoration:
                            const InputDecoration(hintText: 'you@example.com'),
                      ),
                      const SizedBox(height: 24),
                      const LabelText('Password'),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: TrailText.body(c),
                        decoration: const InputDecoration(
                            hintText: 'At least 8 characters'),
                      ),
                      const SizedBox(height: 24),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(_error!, style: TrailText.error(c)),
                        ),
                      PlateButton(
                        primary: true,
                        label: _loading
                            ? 'Please wait'
                            : (_isSignUp ? 'Sign up' : 'Sign in'),
                        onPressed: _loading ? null : _submit,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TrailLink(
                          text: _isSignUp
                              ? 'I already have an account'
                              : 'Create an account',
                          onPressed: _loading
                              ? null
                              : () => setState(() => _isSignUp = !_isSignUp),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
