import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/boat_join_link.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/boat_members_sheet.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/utils/native_share.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Opens the invite-code sheet for [boat].
///
/// Extracted from the boat-detail hub when that screen was retired: sharing is
/// reached from Today now, and the sheet is the same one either way.
Future<void> showShareBoatSheet(BuildContext context, Boat boat) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _ShareBoatSheet(boat: boat),
  );
}

/// The invite-code sheet: the code, copy, and the OS share sheet.
///
/// A widget rather than an inline builder so the code can load *inside* it.
/// The old version awaited the request first, which meant a tap that did
/// nothing for a moment and then a sheet that snapped in fully formed.
class _ShareBoatSheet extends ConsumerWidget {
  const _ShareBoatSheet({required this.boat});

  final Boat boat;

  /// Height of the code panel, fixed so the sheet does not resize when the
  /// code arrives — a sheet that grows mid-animation is the "flash" users see.
  static const _codePanelHeight = 62.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final codeAsync = ref.watch(boatShareCodeProvider(boat.id));
    final code = codeAsync.valueOrNull;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.shareBoat,
                style: TextStyle(
                    color: context.txtPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              l.shareBoatExplainer,
              style: TextStyle(color: context.txtSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: _codePanelHeight,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: context.accent.withValues(alpha: 0.4), width: 0.5),
                ),
                child: Center(
                  child: switch (codeAsync) {
                    AsyncData(:final value) => Text(
                        value,
                        style: TextStyle(
                          color: context.accent,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
                      ),
                    AsyncError() => TextButton.icon(
                        onPressed: () =>
                            ref.invalidate(boatShareCodeProvider(boat.id)),
                        icon: const Icon(Icons.refresh, size: Dimens.iconSm),
                        label: Text(l.couldNotGetCode),
                      ),
                    _ => SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.accent,
                        ),
                      ),
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: code == null
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: code));
                            NavisSnackbar.success(context, l.codeCopied);
                          },
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(l.copy),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Builder(
                    // Its own context so the share popover is anchored to the
                    // button, which is what iOS wants as the source rect.
                    builder: (buttonCtx) => FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: context.accent),
                      onPressed: code == null
                          ? null
                          : () => shareNavisText(
                                buttonCtx,
                                text: l.shareBoatMessageWithLink(
                                  boat.name,
                                  code,
                                  boatJoinLink(code),
                                ),
                                subject: l.shareBoat,
                              ),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text(l.share),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  showBoatMembersSheet(navigator.context, boatId: boat.id);
                },
                icon: const Icon(Icons.groups_outlined, size: 18),
                label: Text(l.boatCrewTitle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
