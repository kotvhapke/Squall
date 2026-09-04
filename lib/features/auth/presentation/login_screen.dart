import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squall/core/theme/app_colors.dart';
import 'package:squall/core/theme/effects.dart';
import 'package:squall/shared/widgets/squall_button.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;

  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _error;

  void _signIn(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required');
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (mounted) widget.onLogin();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Connection error. Check your internet.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToRegister() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RegisterScreen(onLogin: widget.onLogin),
    ));
  }

  void _signInAnonymously() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInAnonymously();
      if (mounted) widget.onLogin();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Connection error.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(top: -60, right: -60, child: AppEffects.ambientGlow(color: AppColors.electricBlue, width: 300, height: 300, blur: 120)),
          Positioned(bottom: -40, left: -40, child: AppEffects.ambientGlow(color: AppColors.blue, width: 250, height: 250, blur: 100)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _LoginForm(
                  onSignIn: _signIn,
                  onNavigateRegister: _navigateToRegister,
                  onGuestLogin: _signInAnonymously,
                  isLoading: _isLoading,
                  error: _error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  final VoidCallback onLogin;

  const RegisterScreen({super.key, required this.onLogin});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isLoading = false;
  String? _error;

  void _register(
    String username,
    String email,
    String password,
    String confirm,
  ) async {
    if (username.trim().length < 2) {
      setState(() => _error = 'Username must be at least 2 characters');
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'username': username.trim(),
          'display_name': username.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check your email to confirm registration')),
        );
        Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Connection error. Check your internet.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(top: -60, right: -60, child: AppEffects.ambientGlow(color: AppColors.coldNeon, width: 300, height: 300, blur: 120)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _RegisterForm(
                  onRegister: _register,
                  isLoading: _isLoading,
                  error: _error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Shared form widgets ----

class _LoginForm extends StatefulWidget {
  final void Function(String email, String password) onSignIn;
  final VoidCallback onNavigateRegister;
  final VoidCallback? onGuestLogin;
  final bool isLoading;
  final String? error;

  const _LoginForm({
    required this.onSignIn,
    required this.onNavigateRegister,
    this.onGuestLogin,
    required this.isLoading,
    this.error,
  });

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppEffects.squallLogo(size: 64),
        const SizedBox(height: 16),
        const Text('Squall', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        const Text('Connect. Play. Dominate.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 40),
        _field(controller: _emailCtrl, hint: 'Email', icon: Icons.person_outline),
        const SizedBox(height: 12),
        _field(
          controller: _passCtrl,
          hint: 'Password', icon: Icons.lock_outline,
          obscure: _obscure,
          suffix: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textMuted),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 10),
          Text(widget.error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
        ],
        const SizedBox(height: 20),
        widget.isLoading
            ? const SizedBox(width: 44, height: 44, child: Center(child: CircularProgressIndicator(color: AppColors.electricBlue, strokeWidth: 2.5)))
            : SquallButton(label: 'Sign In', onPressed: () => widget.onSignIn(_emailCtrl.text, _passCtrl.text)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.border.withValues(alpha: 0.3))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('OR', style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
            Expanded(child: Divider(color: AppColors.border.withValues(alpha: 0.3))),
          ],
        ),
        const SizedBox(height: 16),
        SquallButton(label: 'Create Account', onPressed: widget.onNavigateRegister, primary: false),
        const SizedBox(height: 10),
        if (widget.onGuestLogin != null)
          SquallButton(label: 'Continue as Guest', onPressed: widget.onGuestLogin, primary: false),
      ],
    );
  }

  Widget _field({required TextEditingController controller, required String hint, required IconData icon, bool obscure = false, Widget? suffix}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _RegisterForm extends StatefulWidget {
  final void Function(String username, String email, String password, String confirm) onRegister;
  final bool isLoading;
  final String? error;

  const _RegisterForm({required this.onRegister, required this.isLoading, this.error});

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppEffects.squallLogo(size: 48),
        const SizedBox(height: 12),
        const Text('Create Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 32),
        _field(controller: _usernameCtrl, hint: 'Username', icon: Icons.person_outline),
        const SizedBox(height: 10),
        _field(controller: _emailCtrl, hint: 'Email', icon: Icons.email_outlined),
        const SizedBox(height: 10),
        _field(controller: _passCtrl, hint: 'Password', icon: Icons.lock_outline, obscure: _obscurePass,
          suffix: IconButton(
            icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textMuted),
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
          ),
        ),
        const SizedBox(height: 10),
        _field(controller: _confirmCtrl, hint: 'Confirm Password', icon: Icons.lock_outline, obscure: _obscureConfirm,
          suffix: IconButton(
            icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textMuted),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 10),
          Text(widget.error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
        ],
        const SizedBox(height: 20),
        widget.isLoading
            ? const SizedBox(width: 44, height: 44, child: Center(child: CircularProgressIndicator(color: AppColors.electricBlue, strokeWidth: 2.5)))
            : SquallButton(label: 'Create Account', onPressed: () => widget.onRegister(
                _usernameCtrl.text, _emailCtrl.text, _passCtrl.text, _confirmCtrl.text,
              )),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Already have an account? Sign In', style: TextStyle(fontSize: 12, color: AppColors.electricBlue)),
        ),
      ],
    );
  }

  Widget _field({required TextEditingController controller, required String hint, required IconData icon, bool obscure = false, Widget? suffix}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: TextField(
        controller: controller, obscureText: obscure,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}