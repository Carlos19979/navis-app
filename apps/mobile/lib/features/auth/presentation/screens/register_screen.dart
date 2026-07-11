import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/auth/domain/auth_state.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final textTheme = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context)!;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/boats');
      } else if (next.status == AuthStatus.pendingEmailConfirmation) {
        context.go('/check-email');
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
                      l.createAccount,
                      textAlign: TextAlign.center,
                      style: textTheme.displayMedium?.copyWith(
                        color: context.txtPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                    const SizedBox(height: 4),
                    Text(
                      l.joinNavisSubtitle,
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
                      textInputAction: TextInputAction.next,
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
                    const SizedBox(height: 16),

                    // -- Confirm Password Field --
                    _GlassTextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _onRegister(),
                      labelText: l.confirmPassword,
                      prefixIconData: Icons.lock_outlined,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: context.txtSecondary,
                          size: 20,
                        ),
                        tooltip: _obscureConfirmPassword
                            ? l.showPassword
                            : l.hidePassword,
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l.pleaseConfirmPassword;
                        }
                        if (value != _passwordController.text) {
                          return l.passwordsDoNotMatch;
                        }
                        return null;
                      },
                    ).animate().fadeIn(delay: 600.ms, duration: 500.ms).slideY(
                          begin: 0.3,
                          end: 0,
                          delay: 600.ms,
                          duration: 500.ms,
                          curve: Curves.easeOut,
                        ),
                    const SizedBox(height: 28),

                    // -- Register Button --
                    NavisButton(
                      label: l.register,
                      onPressed: _onRegister,
                      isLoading: authState.status == AuthStatus.loading,
                    ).animate().fadeIn(delay: 700.ms, duration: 500.ms).slideY(
                          begin: 0.3,
                          end: 0,
                          delay: 700.ms,
                          duration: 500.ms,
                          curve: Curves.easeOut,
                        ),
                    const SizedBox(height: 24),

                    // -- Login Link --
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Text.rich(
                        TextSpan(
                          text: '${l.hasAccount} ',
                          style: textTheme.bodyMedium?.copyWith(
                            color: context.txtSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: l.login,
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
