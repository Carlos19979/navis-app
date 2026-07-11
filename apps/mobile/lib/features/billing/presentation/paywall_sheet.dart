import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:navis_mobile/core/config/env.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Shows the Navis Pro paywall as a modal sheet. Returns true if the user ended
/// up with Pro (purchased or restored), false otherwise.
///
/// [reason] is an optional one-line context shown at the top (e.g. why the
/// action was gated).
Future<bool> showPaywall(
  BuildContext context,
  WidgetRef ref, {
  String? reason,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaywallSheet(reason: reason),
  );
  return result ?? false;
}

const _proBenefits = <(IconData, String)>[
  (
    Icons.notifications_active_rounded,
    'Recordatorios ilimitados de caducidad de documentos'
  ),
  (Icons.build_rounded, 'Recordatorios de mantenimiento programado'),
  (Icons.directions_boat_rounded, 'Hasta 3 barcos'),
  (Icons.groups_rounded, 'Crea clubes y eventos'),
  (Icons.attach_file_rounded, 'Adjuntos ilimitados en documentos'),
];

class _PaywallSheet extends ConsumerStatefulWidget {
  const _PaywallSheet({this.reason});

  final String? reason;

  @override
  ConsumerState<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<_PaywallSheet> {
  List<Package> _packages = const [];
  Package? _selected;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    final packages = await ref.read(billingServiceProvider).proPackages();
    if (!mounted) return;
    setState(() {
      _packages = packages;
      _selected = packages.isNotEmpty ? packages.first : null;
      _loading = false;
    });
  }

  Future<void> _subscribe() async {
    final package = _selected;
    if (package == null) return;
    setState(() => _busy = true);
    try {
      final ok = await ref.read(billingServiceProvider).purchase(package);
      if (!mounted) return;
      if (ok) {
        _onProUnlocked();
      } else {
        setState(() => _busy = false); // user cancelled
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      NavisSnackbar.error(context, 'No se pudo completar la compra.');
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final ok = await ref.read(billingServiceProvider).restore();
    if (!mounted) return;
    if (ok) {
      _onProUnlocked();
    } else {
      setState(() => _busy = false);
      NavisSnackbar.info(context, 'No hay compras que restaurar.');
    }
  }

  void _onProUnlocked() {
    // Unlock instantly; the server catches up via the RevenueCat webhook.
    ref.read(proEntitlementProvider.notifier).state = true;
    ref.invalidate(accountProvider);
    NavisSnackbar.success(context, '¡Bienvenido a Navis Pro!');
    Navigator.of(context).pop(true);
  }

  String _packageLabel(Package p) => switch (p.packageType) {
        PackageType.annual => 'Anual',
        PackageType.monthly => 'Mensual',
        PackageType.weekly => 'Semanal',
        PackageType.lifetime => 'De por vida',
        _ => p.storeProduct.title,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: context.dialogSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: context.glassBorderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Navis Pro',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: context.txtPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.reason ??
                  'Mantén tu barco legal, mantenido y seguro. Por menos que '
                      'una sola multa por documentación caducada.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.txtSecondary),
            ),
            const SizedBox(height: 20),
            for (final (icon, label) in _proBenefits)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: AppColors.cyan),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          color: context.txtPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_packages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Las suscripciones no están disponibles en este momento. '
                  'Inténtalo de nuevo más tarde.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.txtSecondary),
                ),
              )
            else ...[
              for (final package in _packages)
                _PackageTile(
                  label: _packageLabel(package),
                  price: package.storeProduct.priceString,
                  selected: identical(package, _selected),
                  onTap:
                      _busy ? null : () => setState(() => _selected = package),
                ),
              const SizedBox(height: 16),
              NavisButton(
                label: 'Suscribirse',
                isLoading: _busy,
                onPressed: _subscribe,
              ),
              TextButton(
                onPressed: _busy ? null : _restore,
                child: Text(
                  'Restaurar compras',
                  style: TextStyle(color: context.txtSecondary),
                ),
              ),
            ],
            // App Store 3.1.2: auto-renewal disclosure + legal links must be
            // visible on the purchase surface.
            const SizedBox(height: 8),
            Text(
              l.paywallAutoRenewNotice,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: context.txtSecondary.withValues(alpha: 0.8),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(Env.privacyUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(
                    l.privacyPolicy,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.txtSecondary,
                    ),
                  ),
                ),
                Text('·', style: TextStyle(color: context.txtSecondary)),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(Env.termsUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(
                    l.termsOfService,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.txtSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.label,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String price;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.glassBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.cyan : context.glassBorderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.cyan : context.txtSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.txtPrimary,
                ),
              ),
            ),
            Text(
              price,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.txtPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
