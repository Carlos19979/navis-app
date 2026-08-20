import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/motion.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/auth/domain/auth_state.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';
import 'package:navis_mobile/shared/widgets/navis_alert.dart';
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
        context.go(Routes.today);
      } else if (next.status == AuthStatus.pendingEmailConfirmation) {
        context.go(Routes.checkEmail);
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
                              color: context.accent.withValues(alpha: 0.2),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        // No BackdropFilter: it was blurring an icon glyph,
                        // which has nothing behind it to reveal.
                        child: Center(
                          child: Icon(
                            Icons.sailing,
                            size: 64,
                            color: context.accent,
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
                    ).entrance(index: 2),
                    const SizedBox(height: 4),
                    Text(
                      l.joinNavisSubtitle,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: context.txtSecondary,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ).entrance(index: 3),
                    const SizedBox(height: 48),

                    // -- Error Display --
                    if (authState.errorMessage != null)
                      NavisAlert(
                        message: authState.errorMessage!,
                        margin: const EdgeInsets.only(bottom: Dimens.spaceXl),
                      ).animate().fadeIn(duration: 300.ms).shakeX(
                            hz: 3,
                            amount: 4,
                            duration: 400.ms,
                          ),

                    // -- Email Field --
                    NavisTextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      label: l.email,
                      prefixIcon: Icons.email_outlined,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l.pleaseEnterEmail;
                        }
                        if (!value.contains('@')) {
                          return l.invalidEmail;
                        }
                        return null;
                      },
                    ).entrance(index: 4),
                    const SizedBox(height: 16),

                    // -- Password Field --
                    NavisTextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      label: l.password,
                      prefixIcon: Icons.lock_outlined,
                      suffix: IconButton(
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
                    ).entrance(index: 5),
                    const SizedBox(height: 16),

                    // -- Confirm Password Field --
                    NavisTextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _onRegister(),
                      label: l.confirmPassword,
                      prefixIcon: Icons.lock_outlined,
                      suffix: IconButton(
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
                    ).entrance(index: 6),
                    const SizedBox(height: 28),

                    // -- Register Button --
                    NavisButton(
                      label: l.register,
                      onPressed: _onRegister,
                      isLoading: authState.status == AuthStatus.loading,
                    ).entrance(index: 7),
                    const SizedBox(height: 24),

                    // -- Login Link --
                    GestureDetector(
                      onTap: () => context.go(Routes.login),
                      child: Text.rich(
                        TextSpan(
                          text: '${l.hasAccount} ',
                          style: textTheme.bodyMedium?.copyWith(
                            color: context.txtSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: l.login,
                              style: TextStyle(
                                color: context.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ).entrance(index: 8),
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
