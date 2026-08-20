import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/theme/motion.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Shown after a password-recovery deep link is opened. The user has a valid
/// (recovery) session; setting a new password completes the flow and lands
/// them in the app.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context)!;
    setState(() => _submitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(_passwordController.text);
      ref.read(passwordRecoveryProvider.notifier).complete();
      if (!mounted) return;
      NavisSnackbar.success(context, l.resetPwSuccess);
      context.go(Routes.today);
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        NavisSnackbar.error(context, l.resetPwFailed);
      }
    }
  }

  /// Leaves the recovery without setting a password. Signs out on the way:
  /// the link handed us a live session, and abandoning the flow must not leave
  /// the account open to whoever opened the email.
  Future<void> _onCancel() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

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
                    Icon(
                      Icons.lock_reset_outlined,
                      size: 72,
                      color: context.accent,
                    ).animate().fadeIn(duration: 500.ms),
                    const SizedBox(height: 24),
                    Text(
                      l.newPasswordTitle,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(
                        color: context.txtPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ).entrance(index: 1),
                    const SizedBox(height: 8),
                    Text(
                      l.newPasswordSubtitle,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: context.txtSecondary,
                      ),
                    ).entrance(index: 2),
                    const SizedBox(height: 36),

                    // -- New Password Field --
                    _GlassTextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      labelText: l.newPasswordLabel,
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
                    ).entrance(index: 3),
                    const SizedBox(height: 16),

                    // -- Confirm Password Field --
                    _GlassTextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _onSubmit(),
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
                    ).entrance(index: 4),
                    const SizedBox(height: 28),

                    // -- Submit Button --
                    NavisButton(
                      label: l.resetPwSubmit,
                      onPressed: _onSubmit,
                      isLoading: _submitting,
                    ).entrance(index: 5),
                    const SizedBox(height: 12),

                    // The way out. Mandatory now that the flag survives a
                    // restart: without it, opening a recovery link and
                    // changing your mind locks you on this screen for good.
                    TextButton(
                      onPressed: _submitting ? null : _onCancel,
                      child: Text(
                        l.cancel,
                        style: textTheme.bodyMedium?.copyWith(
                          color: context.txtSecondary,
                        ),
                      ),
                    ).entrance(index: 6),
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
    this.textInputAction,
    this.obscureText = false,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String labelText;
  final IconData prefixIconData;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
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
          child: Icon(prefixIconData, color: context.accent, size: 20),
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
