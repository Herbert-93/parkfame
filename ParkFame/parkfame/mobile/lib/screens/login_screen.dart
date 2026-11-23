import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false, _hide = true;
  String? _err;

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _err = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _pass.text);
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'network-request-failed' => 'No internet connection.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        'user-disabled' => 'This account has been disabled.',
        _ => 'Wrong email or password.',
      };
      if (mounted) setState(() => _err = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF16305A), Brand.navy, Brand.navy], stops: [0, .55, 1]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Brand.accent,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [BoxShadow(color: Brand.accent.withValues(alpha: .4), blurRadius: 40, offset: const Offset(0, 14))],
                      ),
                      child: const Icon(Icons.local_parking_rounded, size: 52, color: Brand.navy),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'Park', style: TextStyle(fontWeight: FontWeight.w500)),
                      TextSpan(text: 'Fame', style: TextStyle(fontWeight: FontWeight.w900, color: Brand.accent)),
                    ]),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 38, letterSpacing: -1),
                  ),
                  const SizedBox(height: 6),
                  const Text('Smart parking, simplified', textAlign: TextAlign.center, style: TextStyle(color: Brand.muted)),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pass,
                    obscureText: _hide,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _hide = !_hide)),
                    ),
                  ),
                  if (_err != null) ...[
                    const SizedBox(height: 14),
                    Text(_err!, style: const TextStyle(color: Brand.danger), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _login,
                    child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('Sign in'),
                  ),
                  const SizedBox(height: 18),
                  const Text('Accounts are created by your administrator.', textAlign: TextAlign.center, style: TextStyle(color: Brand.muted, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
