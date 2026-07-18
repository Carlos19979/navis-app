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

/// Shows the Navis paywall as a modal sheet comparing Plus and Pro. Returns true
/// if the user ended up on a paid tier.
///
/// [reason] is an optional one-line context shown at the top. [requiredTier] is
/// the tier the gated action needs — its section is shown first and preselected.
Future<bool> showPaywall(
  BuildContext context,
  WidgetRef ref, {
  String? reason,
  PlanTier requiredTier = PlanTier.pro,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaywallSheet(reason: reason, requiredTier: requiredTier),
  );
  return result ?? false;
}

List<(IconData, String)> _plusBenefits(AppLocalizations l) => [
      (Icons.notifications_active_rounded, l.proBenefitReminders),
      (Icons.build_rounded, l.proBenefitMaintenance),
      (Icons.health_and_safety_rounded, l.proBenefitReadiness),
      (Icons.anchor_rounded, l.proBenefitAnchor),
      (Icons.directions_boat_rounded, l.plusBenefitBoats),
    ];

List<(IconData, String)> _proBenefits(AppLocalizations l) => [
      (Icons.insights_rounded, l.proBenefitCostAnalytics),
      (Icons.calendar_month_rounded, l.proBenefitShared),
      (Icons.workspace_premium_rounded, l.proBenefitPassport),
      (Icons.groups_rounded, l.proBenefitGroups),
      (Icons.directions_boat_rounded, l.proBenefitBoats),
    ];

/// Which tier a package belongs to, by product identifier convention
/// (navis_plus_* vs navis_pro_*). Defaults to Pro.
PlanTier _tierOf(Package p) =>
    p.storeProduct.identifier.toLowerCase().contains('plus')
        ? PlanTier.plus
        : PlanTier.pro;

class _PaywallSheet extends ConsumerStatefulWidget {
  const _PaywallSheet({this.reason, required this.requiredTier});

  final String? reason;
  final PlanTier requiredTier;

  @override
  ConsumerState<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<_PaywallSheet> {
  List<Package> _plus = const [];
  List<Package> _pro = const [];
  Package? _selected;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    final packages = await ref.read(billingServiceProvider).allPackages();
    if (!mounted) return;
    final plus = packages.where((p) => _tierOf(p) == PlanTier.plus).toList();
    final pro = packages.where((p) => _tierOf(p) == PlanTier.pro).toList();
    setState(() {
      _plus = plus;
      _pro = pro;
      // Preselect the required tier's yearly (or first) package.
      final preferred = widget.requiredTier == PlanTier.plus ? plus : pro;
      _selected = (preferred.isNotEmpty ? preferred : (pro + plus)).isEmpty
          ? null
          : (preferred.isNotEmpty ? preferred : pro + plus).first;
      _loading = false;
    });
  }

  Future<void> _subscribe() async {
    final package = _selected;
    if (package == null) return;
    setState(() => _busy = true);
    try {
      final tier = await ref.read(billingServiceProvider).purchase(package);
      if (!mounted) return;
      if (tier != PlanTier.free) {
        _onTierUnlocked(tier);
      } else {
        setState(() => _busy = false); // user cancelled
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      NavisSnackbar.error(
          context, AppLocalizations.of(context)!.purchaseFailed);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final tier = await ref.read(billingServiceProvider).restore();
    if (!mounted) return;
    if (tier != PlanTier.free) {
      _onTierUnlocked(tier);
    } else {
      setState(() => _busy = false);
      NavisSnackbar.info(
          context, AppLocalizations.of(context)!.nothingToRestore);
    }
  }

  void _onTierUnlocked(PlanTier tier) {
    // Unlock instantly; the server catches up via the RevenueCat webhook.
    ref.read(liveTierProvider.notifier).state = tier;
    ref.invalidate(accountProvider);
    NavisSnackbar.success(context, AppLocalizations.of(context)!.welcomeToPro);
    Navigator.of(context).pop(true);
  }

  String _packageLabel(Package p, AppLocalizations l) =>
      switch (p.packageType) {
        PackageType.annual => l.paywallYearly,
        PackageType.monthly => l.paywallMonthly,
        PackageType.weekly => l.paywallWeekly,
        PackageType.lifetime => l.paywallLifetime,
        _ => p.storeProduct.title,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Show the required tier's section first.
    final proFirst = widget.requiredTier == PlanTier.pro;
    return Container(
      decoration: BoxDecoration(
        color: context.dialogSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
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
              l.paywallTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: context.txtPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.reason ?? l.paywallDefaultReason,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.txtSecondary),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_plus.isEmpty && _pro.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l.subscriptionsUnavailable,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.txtSecondary),
                ),
              )
            else ...[
              for (final tier in proFirst
                  ? [PlanTier.pro, PlanTier.plus]
                  : [PlanTier.plus, PlanTier.pro])
                if ((tier == PlanTier.plus ? _plus : _pro).isNotEmpty)
                  _TierSection(
                    tier: tier,
                    packages: tier == PlanTier.plus ? _plus : _pro,
                    benefits: tier == PlanTier.plus
                        ? _plusBenefits(l)
                        : _proBenefits(l),
                    includesPlusNote: tier == PlanTier.pro && _plus.isNotEmpty,
                    selected: _selected,
                    busy: _busy,
                    onSelect: (p) => setState(() => _selected = p),
                    labelOf: (p) => _packageLabel(p, l),
                  ),
              const SizedBox(height: 8),
              NavisButton(
                label: l.subscribe,
                isLoading: _busy,
                onPressed: _subscribe,
              ),
              TextButton(
                onPressed: _busy ? null : _restore,
                child: Text(
                  l.restorePurchases,
                  style: TextStyle(color: context.txtSecondary),
                ),
              ),
            ],
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
                    style: TextStyle(fontSize: 12, color: context.txtSecondary),
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
                    style: TextStyle(fontSize: 12, color: context.txtSecondary),
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

/// One tier's card: name, benefit bullets, and its monthly/yearly package tiles.
class _TierSection extends StatelessWidget {
  const _TierSection({
    required this.tier,
    required this.packages,
    required this.benefits,
    required this.includesPlusNote,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.labelOf,
  });

  final PlanTier tier;
  final List<Package> packages;
  final List<(IconData, String)> benefits;
  final bool includesPlusNote;
  final Package? selected;
  final bool busy;
  final ValueChanged<Package> onSelect;
  final String Function(Package) labelOf;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final name = tier == PlanTier.plus ? l.paywallPlusName : l.paywallProName;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.glassBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.glassBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.txtPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if (includesPlusNote) ...[
            Text(
              l.paywallProIncludesPlus,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: context.txtSecondary,
              ),
            ),
            const SizedBox(height: 6),
          ],
          for (final (icon, label) in benefits)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.cyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 14, color: context.txtPrimary),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (packages.isEmpty)
            Text(
              l.subscriptionsUnavailable,
              style: TextStyle(fontSize: 12, color: context.txtSecondary),
            )
          else
            for (final package in packages)
              _PackageTile(
                label: labelOf(package),
                price: package.storeProduct.priceString,
                selected: identical(package, selected),
                onTap: busy ? null : () => onSelect(package),
              ),
        ],
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.dialogSurface,
          borderRadius: BorderRadius.circular(12),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.txtPrimary,
                ),
              ),
            ),
            Text(
              price,
              style: TextStyle(
                fontSize: 15,
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
