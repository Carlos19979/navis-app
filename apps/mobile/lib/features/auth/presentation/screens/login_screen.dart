import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/network/notification_service.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/auth/domain/auth_state.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  Future<void> _onOAuth(Future<bool> Function() start) async {
    try {
      await start();
      // Session arrives via the redirect deep link → onAuthStateChange → router.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo iniciar sesión con ese proveedor'),
          ),
        );
      }
    }
  }

  Future<void> _onForgotPassword() async {
    final emailCtrl = TextEditingController(
      text: _emailController.text.trim(),
    );
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.dialogSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.glassBorderColor),
        ),
        title: Text(
          AppLocalizations.of(context)!.resetPassword,
          style: TextStyle(color: context.txtPrimary),
        ),
        content: TextField(
          controller: emailCtrl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: context.txtPrimary),
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.email,
            prefixIcon: const Icon(Icons.email_outlined),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: TextStyle(
                color: context.txtSecondary.withValues(alpha: 0.8),
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cyan,
            ),
            onPressed: () => Navigator.of(ctx).pop(emailCtrl.text.trim()),
            child: Text(AppLocalizations.of(context)!.sendResetLink),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;

    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.passwordResetSent),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.failedToSendResetEmail)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final textTheme = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context)!;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        final notificationService = ref.read(notificationServiceProvider);
        notificationService.requestPermission().then((_) {
          notificationService.registerDevice();
        });
        context.go('/boats');
      }
    });

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // -- Logo Section --
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.glassBg,
                          border: Border.all(
                            color: context.glassBorderColor,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.cyan.withValues(alpha: 0.2),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 12,
                              sigmaY: 12,
                            ),
                            child: const Icon(
                              Icons.sailing,
                              size: 100,
                              color: AppColors.cyan,
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 600.ms).scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1.0, 1.0),
                          duration: 600.ms,
                          curve: Curves.easeOut,
                        ),
                    const SizedBox(height: 20),
                    Text(
                      'Navis',
                      textAlign: TextAlign.center,
                      style: textTheme.displayMedium?.copyWith(
                        color: context.txtPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                    const SizedBox(height: 4),
                    Text(
                      l.boatManagement,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: context.txtSecondary,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                    const SizedBox(height: 48),

                    // -- Error Display --
                    if (authState.errorMessage != null)
                      GlassContainer(
                        borderRadius: 12,
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 20),
                        borderColor: AppColors.red.withValues(alpha: 0.4),
                        opacity: 0.06,
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: AppColors.red.withValues(
                                alpha: 0.9,
                              ),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                authState.errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.red,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms).shakeX(
                            hz: 3,
                            amount: 4,
                            duration: 400.ms,
                          ),

                    // -- Email Field --
                    _GlassTextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      labelText: l.email,
                      prefixIconData: Icons.email_outlined,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l.pleaseEnterEmail;
                        }
                        if (!value.contains('@')) {
                          return l.invalidEmail;
                        }
                        return null;
                      },
                    ).animate().fadeIn(delay: 400.ms, duration: 500.ms).slideY(
                          begin: 0.3,
                          end: 0,
                          delay: 400.ms,
                          duration: 500.ms,
                          curve: Curves.easeOut,
                        ),
                    const SizedBox(height: 16),

                    // -- Password Field --
                    _GlassTextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _onLogin(),
                      labelText: l.password,
                      prefixIconData: Icons.lock_outlined,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: context.txtSecondary,
                          size: 20,
                        ),
                        tooltip:
                            _obscurePassword ? l.showPassword : l.hidePassword,
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l.pleaseEnterPassword;
                        }
                        if (value.length < 6) {
                          return l.passwordTooShort;
                        }
                        return null;
                      },
                    ).animate().fadeIn(delay: 500.ms, duration: 500.ms).slideY(
                          begin: 0.3,
                          end: 0,
                          delay: 500.ms,
                          duration: 500.ms,
                          curve: Curves.easeOut,
                        ),
                    const SizedBox(height: 28),

                    // -- Login Button --
                    NavisButton(
                      label: l.login,
                      onPressed: _onLogin,
                      isLoading: authState.status == AuthStatus.loading,
                    ).animate().fadeIn(delay: 600.ms, duration: 500.ms).slideY(
                          begin: 0.3,
                          end: 0,
                          delay: 600.ms,
                          duration: 500.ms,
                          curve: Curves.easeOut,
                        ),
                    const SizedBox(height: 16),

                    // -- Divider --
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: context.glassBorderColor),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'o',
                            style: TextStyle(color: context.txtSecondary),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: context.glassBorderColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // -- Social sign-in --
                    _SocialButton(
                      icon: Icons.apple,
                      label: 'Continuar con Apple',
                      onPressed: () => _onOAuth(
                          ref.read(authRepositoryProvider).signInWithApple),
                    ),
                    const SizedBox(height: 10),
                    _SocialButton(
                      icon: Icons.g_mobiledata,
                      label: 'Continuar con Google',
                      onPressed: () => _onOAuth(
                          ref.read(authRepositoryProvider).signInWithGoogle),
                    ),
                    const SizedBox(height: 20),

                    // -- Forgot Password --
                    GestureDetector(
                      onTap: _onForgotPassword,
                      child: Text(
                        l.forgotPassword,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.cyan,
                        ),
                      ),
                    ).animate().fadeIn(delay: 700.ms, duration: 500.ms),
                    const SizedBox(height: 16),

                    // -- Register Link --
                    GestureDetector(
                      onTap: () => context.go('/register'),
                      child: Text.rich(
                        TextSpan(
                          text: '${l.noAccount} ',
                          style: textTheme.bodyMedium?.copyWith(
                            color: context.txtSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: l.register,
                              style: const TextStyle(
                                color: AppColors.cyan,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ).animate().fadeIn(delay: 800.ms, duration: 500.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass-style text field with an icon inside a small glass circle.
class _GlassTextField extends StatelessWidget {
  const _GlassTextField({
    required this.controller,
    required this.labelText,
    required this.prefixIconData,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String labelText;
  final IconData prefixIconData;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onFieldSubmitted: onFieldSubmitted,
      style: TextStyle(color: context.txtPrimary),
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(left: 8, right: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.glassBg,
            border: Border.all(color: context.glassBorderColor),
          ),
          child: Icon(
            prefixIconData,
            color: AppColors.cyan,
            size: 20,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 52,
          minHeight: 40,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: context.txtPrimary),
        label: Text(
          label,
          style: TextStyle(
            color: context.txtPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: context.glassBorderColor),
          backgroundColor: context.glassBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
