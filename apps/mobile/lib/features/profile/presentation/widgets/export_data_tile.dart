import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Writes the export JSON to a temp file and opens the platform share sheet.
/// Injectable so widget tests can stub the platform channels away.
final exportShareProvider =
    Provider<Future<void> Function(String json, Rect? origin)>(
  (ref) => shareExportFile,
);

Future<void> shareExportFile(String json, Rect? origin) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/navis-export.json');
  await file.writeAsString(json);
  // iOS presents the share sheet as a popover and requires a non-zero
  // sharePositionOrigin (required on iPad; also enforced on iOS 26 iPhone).
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/json')],
    sharePositionOrigin: origin,
  );
}

/// Settings entry that downloads the user's data (GDPR export) and hands the
/// resulting JSON file to the platform share sheet.
class ExportDataTile extends ConsumerStatefulWidget {
  const ExportDataTile({super.key});

  @override
  ConsumerState<ExportDataTile> createState() => _ExportDataTileState();
}

class _ExportDataTileState extends ConsumerState<ExportDataTile> {
  bool _exporting = false;

  Future<void> _export() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _exporting = true);
    try {
      final data = await ref.read(accountRepositoryProvider).exportData();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final origin =
          mounted ? (Offset.zero & MediaQuery.of(context).size) : null;
      await ref.read(exportShareProvider)(json, origin);
      if (mounted) {
        NavisSnackbar.success(context, l.exportDataReady);
      }
    } catch (_) {
      if (mounted) {
        NavisSnackbar.error(context, l.exportDataFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListTile(
      leading: _exporting
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.ios_share, color: context.txtSecondary),
      title: Text(l.exportMyData),
      subtitle: Text(l.exportMyDataSubtitle),
      onTap: _exporting ? null : _export,
    );
  }
}
