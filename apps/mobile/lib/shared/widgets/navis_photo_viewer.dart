import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/storage_service.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

/// Opens a fullscreen, swipeable (PageView) photo viewer over [urls].
///
/// [signed] resolves private-bucket URLs through [signedDocumentUrlProvider]
/// before display (documents bucket); public URLs render directly.
Future<void> showNavisPhotoViewer(
  BuildContext context, {
  required List<String> urls,
  int initialIndex = 0,
  bool signed = false,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => NavisPhotoViewer(
        urls: urls,
        initialIndex: initialIndex,
        signed: signed,
      ),
    ),
  );
}

/// Fullscreen photo viewer: swipe between photos, pinch to zoom.
class NavisPhotoViewer extends StatefulWidget {
  const NavisPhotoViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
    this.signed = false,
  });

  final List<String> urls;
  final int initialIndex;
  final bool signed;

  @override
  State<NavisPhotoViewer> createState() => _NavisPhotoViewerState();
}

class _NavisPhotoViewerState extends State<NavisPhotoViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: widget.urls.length > 1
            ? Text(
                '${_index + 1} / ${widget.urls.length}',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              )
            : null,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: NavisViewerImage(
              url: widget.urls[i],
              signed: widget.signed,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single viewer page image, resolving signed URLs when needed.
class NavisViewerImage extends ConsumerWidget {
  const NavisViewerImage({
    super.key,
    required this.url,
    this.signed = false,
  });

  final String url;
  final bool signed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final resolved =
        signed ? ref.watch(signedDocumentUrlProvider(url)).valueOrNull : url;
    if (resolved == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      );
    }
    return Semantics(
      label: l.photoLabel,
      child: CachedNetworkImage(
        imageUrl: resolved,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => const Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 48,
        ),
      ),
    );
  }
}
