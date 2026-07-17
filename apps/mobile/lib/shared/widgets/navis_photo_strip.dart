import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:navis_mobile/core/network/storage_service.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_photo_viewer.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Test seam: picks a photo from [source]. Defaults to [ImagePicker].
typedef NavisPhotoPickFn = Future<File?> Function(ImageSource source);

/// An editable strip of photos: thumbnails with remove buttons plus an
/// add tile (camera / gallery) that uploads through [upload].
///
/// [maxPhotos] is the plan-resolved cap; adding beyond it invokes
/// [onLimitReached] (typically a paywall) and only continues when it
/// resolves to true (e.g. the user upgraded).
class NavisPhotoStrip extends ConsumerStatefulWidget {
  const NavisPhotoStrip({
    super.key,
    required this.urls,
    required this.onChanged,
    required this.upload,
    required this.maxPhotos,
    this.onLimitReached,
    this.signed = false,
    this.label,
    this.pickOverride,
  });

  final List<String> urls;
  final ValueChanged<List<String>> onChanged;
  final Future<String> Function(File file) upload;
  final int maxPhotos;
  final Future<bool> Function()? onLimitReached;

  /// Resolve display URLs via signed URLs (private documents bucket).
  final bool signed;
  final String? label;

  /// Replaces the ImagePicker flow in widget tests.
  @visibleForTesting
  final NavisPhotoPickFn? pickOverride;

  @override
  ConsumerState<NavisPhotoStrip> createState() => _NavisPhotoStripState();
}

class _NavisPhotoStripState extends ConsumerState<NavisPhotoStrip> {
  bool _uploading = false;

  Future<File?> _pickWithImagePicker(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    return picked == null ? null : File(picked.path);
  }

  Future<void> _add() async {
    final l = AppLocalizations.of(context)!;
    if (widget.urls.length >= widget.maxPhotos) {
      final proceed = await widget.onLimitReached?.call() ?? false;
      if (!proceed || !mounted) return;
    }
    if (!mounted) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.dialogSurface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l.takePhoto),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.chooseFromGallery),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final pick = widget.pickOverride ?? _pickWithImagePicker;
    final file = await pick(source);
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final url = await widget.upload(file);
      widget.onChanged([...widget.urls, url]);
    } catch (_) {
      if (mounted) NavisSnackbar.error(context, l.couldNotUploadPhoto);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _remove(int index) {
    final next = [...widget.urls]..removeAt(index);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(color: context.txtSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, url) in widget.urls.indexed)
              _RemovableThumb(
                url: url,
                signed: widget.signed,
                onTap: () => showNavisPhotoViewer(
                  context,
                  urls: widget.urls,
                  initialIndex: i,
                  signed: widget.signed,
                ),
                onRemove: () => _remove(i),
              ),
            _AddTile(uploading: _uploading, onTap: _add, tooltip: l.addPhoto),
          ],
        ),
      ],
    );
  }
}

const double _thumbSize = 56;

class _RemovableThumb extends StatelessWidget {
  const _RemovableThumb({
    required this.url,
    required this.signed,
    required this.onTap,
    required this.onRemove,
  });

  final String url;
  final bool signed;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        NavisPhotoThumb(
          url: url,
          signed: signed,
          onTap: onTap,
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Tooltip(
            message: l.remove,
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                ),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.uploading,
    required this.onTap,
    required this.tooltip,
  });

  final bool uploading;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: uploading ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: _thumbSize,
          height: _thumbSize,
          decoration: BoxDecoration(
            color: context.glassBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.glassBorderColor, width: 0.5),
          ),
          child: uploading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.add_a_photo_outlined,
                  size: 20,
                  color: AppColors.cyan,
                ),
        ),
      ),
    );
  }
}

/// A compact, read-only row of photo thumbnails (e.g. on a log card). Shows
/// at most [maxVisible] thumbs plus a "+N" chip; taps open the fullscreen
/// viewer over the whole list.
class NavisPhotoThumbRow extends StatelessWidget {
  const NavisPhotoThumbRow({
    super.key,
    required this.urls,
    this.signed = false,
    this.size = 40,
    this.maxVisible = 4,
  });

  final List<String> urls;
  final bool signed;
  final double size;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final visible = urls.take(maxVisible).toList();
    final extra = urls.length - visible.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, url) in visible.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          NavisPhotoThumb(
            url: url,
            signed: signed,
            size: size,
            onTap: () => showNavisPhotoViewer(
              context,
              urls: urls,
              initialIndex: i,
              signed: signed,
            ),
          ),
        ],
        if (extra > 0) ...[
          const SizedBox(width: 6),
          Text(
            '+$extra',
            style: TextStyle(color: context.txtSecondary, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// A rounded square photo thumbnail, resolving signed URLs when needed.
class NavisPhotoThumb extends ConsumerWidget {
  const NavisPhotoThumb({
    super.key,
    required this.url,
    this.signed = false,
    this.size = _thumbSize,
    this.onTap,
  });

  final String url;
  final bool signed;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final resolved =
        signed ? ref.watch(signedDocumentUrlProvider(url)).valueOrNull : url;
    final placeholder = Container(
      width: size,
      height: size,
      color: context.glassBg,
      child: Icon(
        Icons.image_outlined,
        size: size * 0.4,
        color: context.txtSecondary,
      ),
    );
    return Semantics(
      label: l.photoLabel,
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: resolved == null
              ? placeholder
              : CachedNetworkImage(
                  imageUrl: resolved,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  memCacheWidth: 300,
                  placeholder: (context, url) => placeholder,
                  errorWidget: (context, url, error) => placeholder,
                ),
        ),
      ),
    );
  }
}
