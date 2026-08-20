import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/network/notification_service.dart';
import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/motion.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/auth/domain/auth_state.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';
import 'package:navis_mobile/shared/widgets/navis_alert.dart';
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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.socialLoginFailed),
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
              backgroundColor: context.accent,
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
        // Deliberately non-committal: Supabase answers 200 whether or not the
        // address belongs to an account, so it will not tell us — and must not,
        // or the form becomes a way to test which emails are registered. The
        // old copy ("email sent, check your inbox") therefore promised a mail
        // that, for a typo'd or never-registered address, was never sent.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.passwordResetSent),
            duration: const Duration(seconds: 6),
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
        context.go(Routes.today);
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
                    // The mark, then the wordmark. It used to be a 120 px
                    // circle with a glass fill, a border and a 40-blur glow
                    // around the app icon — three treatments on an asset that
                    // is already a logo.
                    // On dark the mark needs a ground to sit on: the asset is
                    // a navy disc with a compass in it, so on the navy canvas
                    // the disc's edge vanishes and only the compass floats.
                    // A hairline ring gives it back its shape without adding a
                    // glow or a second asset.
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: context.isDarkMode
                              ? Border.all(color: context.onMediaBorder)
                              : null,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/icon/navis_icon.png',
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ).entrance(),
                    const SizedBox(height: Dimens.spaceLg),
                    Text(
                      'Navis',
                      textAlign: TextAlign.center,
                      style: NavisType.display.copyWith(color: context.ink),
                    ).entrance(index: 1),
                    Text(
                      l.boatManagement,
                      textAlign: TextAlign.center,
                      style: NavisType.overline.copyWith(
                        color: context.inkMuted,
                      ),
                    ).entrance(index: 2),
                    const SizedBox(height: Dimens.spaceXxl),

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
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _onLogin(),
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
                    const SizedBox(height: 28),

                    // -- Login Button --
                    NavisButton(
                      label: l.login,
                      onPressed: _onLogin,
                      isLoading: authState.status == AuthStatus.loading,
                    ).entrance(index: 6),
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
                            l.orDivider,
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
                      label: l.continueWithApple,
                      onPressed: () => _onOAuth(
                          ref.read(authRepositoryProvider).signInWithApple),
                    ),
                    // Google sign-in is deferred until the Supabase Google
                    // provider is configured; v1.0 ships email + Apple only.
                    const SizedBox(height: 20),

                    // -- Forgot Password --
                    GestureDetector(
                      onTap: _onForgotPassword,
                      child: Text(
                        l.forgotPassword,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: context.accent,
                        ),
                      ),
                    ).entrance(index: 7),
                    const SizedBox(height: 16),

                    // -- Register Link --
                    GestureDetector(
                      onTap: () => context.go(Routes.register),
                      child: Text.rich(
                        TextSpan(
                          text: '${l.noAccount} ',
                          style: textTheme.bodyMedium?.copyWith(
                            color: context.txtSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: l.register,
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
