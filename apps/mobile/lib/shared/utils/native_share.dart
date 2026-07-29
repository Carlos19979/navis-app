import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// The one way the app opens the OS share sheet for text.
///
/// It exists because of a single mandatory argument: **`sharePositionOrigin`**.
/// On iPad the sheet is a popover anchored to the widget that opened it, and
/// since iOS 26 UIKit also enforces a non-nil source rect on iPhone —
/// `Share.share()` without it throws, the sheet never opens, and nothing at all
/// happens on screen. That is exactly how trip sharing was broken while boat
/// sharing (the one call site that happened to pass the origin) worked.
/// share_plus only stopped throwing in 12.0.1, which needs an Android toolchain
/// bump, so passing the origin is the fix — and having one helper is what keeps
/// a future call site from forgetting it again.
///
/// Returns true when the sheet was handed over to the OS. On failure the user
/// gets a message and the text on the clipboard, so the share is never a
/// dead end.
Future<bool> shareNavisText(
  BuildContext context, {
  required String text,
  String? subject,
}) async {
  final l = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Share.share(
      text,
      subject: subject,
      sharePositionOrigin: shareOriginOf(context),
    );
    return true;
  } on Exception catch (error) {
    debugPrint('share sheet unavailable: $error');
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      NavisSnackbar.warning(context, l.shareFailedCopied);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(l.shareFailedCopied)));
    }
    return false;
  }
}

/// The rect the share popover points at: the widget behind [context] when it
/// has been laid out, falling back to the whole screen.
///
/// Never null — a null origin is what iOS rejects.
Rect shareOriginOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box != null && box.hasSize) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  return Offset.zero & MediaQuery.of(context).size;
}
