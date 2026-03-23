import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).login(_emailCtrl.text, _passCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.isAuthenticated) context.go('/dashboard');
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // Logo / brand
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to The Ledger',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 40),

              // Error banner
              if (auth.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.spending.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.spending.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.spending, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(auth.error!, style: TextStyle(color: AppColors.spending, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _Field(
                      controller: _emailCtrl,
                      label: 'Email',
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 16),
                    _Field(
                      controller: _passCtrl,
                      label: 'Password',
                      hint: '••••••••',
                      obscure: _obscure,
                      suffix: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.textSecondary, size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Sign in button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryContainer],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                    ),
                    onPressed: auth.isLoading ? null : _submit,
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Sign In',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Register link
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/register'),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      children: [
                        const TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: 'Create one',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFADB5BD)),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00333F), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF64001E)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF64001E), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
