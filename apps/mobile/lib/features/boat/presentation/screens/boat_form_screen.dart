import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:navis_mobile/core/network/storage_service.dart';
import 'package:navis_mobile/core/network/supabase_client.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/boat/presentation/screens/map_picker_screen.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/features/boat/presentation/boat_type_label.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

class BoatFormScreen extends ConsumerStatefulWidget {
  const BoatFormScreen({super.key, required this.boatId});

  final String boatId;

  @override
  ConsumerState<BoatFormScreen> createState() => _BoatFormScreenState();
}

class _BoatFormScreenState extends ConsumerState<BoatFormScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _registrationController = TextEditingController();
  final _lengthController = TextEditingController();
  final _homePortController = TextEditingController();
  final _engineHoursController = TextEditingController();
  String _selectedType = 'sailboat';
  bool _isLoading = false;
  bool _isEdit = false;
  String? _photoPath;
  String? _existingPhotoUrl;
  double? _homePortLat;
  double? _homePortLon;

  static const _boatTypes = ['sailboat', 'motorboat', 'catamaran', 'other'];

  @override
  void initState() {
    super.initState();
    _isEdit = widget.boatId != 'new';
    if (_isEdit) {
      _loadBoat();
    }
  }

  Future<void> _loadBoat() async {
    final boat = await ref.read(boatProvider(widget.boatId).future);
    _nameController.text = boat.name;
    _registrationController.text = boat.registration;
    _lengthController.text = boat.lengthMeters.toString();
    _homePortController.text = boat.homePort ?? '';
    if (boat.engineHours > 0) {
      _engineHoursController.text = boat.engineHours.toStringAsFixed(0);
    }
    setState(() {
      _selectedType = boat.type;
      _existingPhotoUrl = boat.photoUrl;
      _homePortLat = boat.homePortLat;
      _homePortLon = boat.homePortLon;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _registrationController.dispose();
    _lengthController.dispose();
    _homePortController.dispose();
    _engineHoursController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _photoPath = image.path;
      });
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = supabaseClient.auth.currentUser!.id;
      final storage = ref.read(storageServiceProvider);
      String? photoUrl;

      if (_isEdit) {
        final existing = await ref.read(boatProvider(widget.boatId).future);
        photoUrl = existing.photoUrl;
      }

      final boat = Boat(
        id: _isEdit ? widget.boatId : '',
        name: _nameController.text.trim(),
        registration: _registrationController.text.trim(),
        type: _selectedType,
        lengthMeters: double.parse(_lengthController.text.trim()),
        homePort: _homePortController.text.trim().isEmpty
            ? null
            : _homePortController.text.trim(),
        homePortLat: _homePortLat,
        homePortLon: _homePortLon,
        photoUrl: photoUrl,
        engineHours: double.tryParse(_engineHoursController.text.trim()) ?? 0,
      );

      if (_isEdit) {
        if (_photoPath != null) {
          photoUrl = await storage.uploadBoatPhoto(
            userId: userId,
            boatId: widget.boatId,
            file: File(_photoPath!),
          );
        }
        await ref.read(boatsProvider.notifier).updateBoat(
              boat.copyWith(photoUrl: photoUrl),
            );
      } else {
        final created = await ref.read(boatsProvider.notifier).createBoat(boat);
        if (_photoPath != null) {
          final url = await storage.uploadBoatPhoto(
            userId: userId,
            boatId: created.id,
            file: File(_photoPath!),
          );
          await ref
              .read(boatsProvider.notifier)
              .updateBoat(created.copyWith(photoUrl: url));
        }
      }

      if (mounted) {
        final l = AppLocalizations.of(context)!;
        NavisSnackbar.success(
          context,
          _isEdit ? l.boatUpdated : l.boatCreated,
        );
        if (_isEdit) {
          context.pop();
        } else {
          context.go('/boats');
        }
      }
    } catch (e) {
      if (mounted) {
        NavisSnackbar.error(
            context, AppLocalizations.of(context)!.failedToSaveBoat);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isEdit) {
      final boatAsync = ref.watch(boatProvider(widget.boatId));
      if (boatAsync.isLoading) {
        return const GradientBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: NavisLoading(),
          ),
        );
      }
    }

    final l = AppLocalizations.of(context)!;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: NavisAppBar(
          title: _isEdit ? l.editBoat : l.newBoat,
          showBack: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Photo picker section
                NavisCard(
                  padding: EdgeInsets.zero,
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: SizedBox(
                      height: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _photoPath != null || _existingPhotoUrl != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (_photoPath != null)
                                    Image.file(
                                      File(_photoPath!),
                                      fit: BoxFit.cover,
                                      semanticLabel: l.boatPhoto,
                                    )
                                  else
                                    Semantics(
                                      label: l.boatPhoto,
                                      child: CachedNetworkImage(
                                        imageUrl: _existingPhotoUrl!,
                                        memCacheWidth: 1200,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                          color: AppColors.darkCard,
                                        ),
                                        errorWidget: (_, __, ___) => Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            size: 48,
                                            color: context.txtSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Gradient overlay on photo
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.3),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: context.glassBg,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: context.glassBorderColor,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : CustomPaint(
                                painter: _DashedBorderPainter(
                                  color: context.glassBorderColor,
                                  borderRadius: 16,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        context.glassBg,
                                        AppColors.glassOverlay,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: context.glassBg,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: context.glassBorderColor,
                                            width: 0.5,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 28,
                                          color: AppColors.cyan,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        l.addPhoto,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: context.txtSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.05, end: 0, duration: 400.ms),
                const SizedBox(height: 20),
                // Form fields section
                NavisCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.boatDetailsSection,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l.boatName,
                          prefixIcon: const Icon(Icons.sailing_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l.pleaseEnterBoatName;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _registrationController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l.registration,
                          prefixIcon: const Icon(Icons.tag),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l.pleaseEnterRegistration;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedType,
                        decoration: InputDecoration(
                          labelText: l.boatType,
                          prefixIcon: const Icon(Icons.category_outlined),
                        ),
                        items: _boatTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(localizedBoatType(l, type)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _lengthController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l.length,
                          prefixIcon: const Icon(Icons.straighten),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l.pleaseEnterLength;
                          }
                          if (double.tryParse(value.trim()) == null) {
                            return l.validNumber;
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 50.ms).slideY(
                      begin: 0.05,
                      end: 0,
                      duration: 400.ms,
                      delay: 50.ms,
                    ),
                const SizedBox(height: 16),
                // Home port section
                NavisCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.homePort,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _homePortController,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: l.homePortOptional,
                          prefixIcon: const Icon(Icons.anchor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      NavisButton(
                        label: _homePortLat != null
                            ? 'Location set (${_homePortLat!.toStringAsFixed(3)}, ${_homePortLon!.toStringAsFixed(3)})'
                            : l.pickLocationOnMap,
                        icon: _homePortLat != null
                            ? Icons.check_circle
                            : Icons.map_outlined,
                        variant: NavisButtonVariant.secondary,
                        compact: true,
                        onPressed: () async {
                          final result =
                              await Navigator.of(context).push<MapPickerResult>(
                            MaterialPageRoute(
                              builder: (_) => MapPickerScreen(
                                initialLatitude: _homePortLat,
                                initialLongitude: _homePortLon,
                              ),
                            ),
                          );
                          if (result != null) {
                            setState(() {
                              _homePortLat = result.point.latitude;
                              _homePortLon = result.point.longitude;
                              _homePortController.text = result.name ?? '';
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(
                      begin: 0.05,
                      end: 0,
                      duration: 400.ms,
                      delay: 100.ms,
                    ),
                const SizedBox(height: 24),
                Text(
                  l.engineSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.engineSectionHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.txtSecondary,
                      ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _engineHoursController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.engineHoursCurrent,
                    prefixIcon: const Icon(Icons.speed),
                    suffixText: 'h',
                  ),
                ),
                const SizedBox(height: 24),
                NavisButton(
                  label: _isEdit ? l.updateBoat : l.createBoat,
                  onPressed: _onSave,
                  isLoading: _isLoading,
                ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideY(
                      begin: 0.05,
                      end: 0,
                      duration: 400.ms,
                      delay: 150.ms,
                    ),
                if (_isEdit) ...[
                  const SizedBox(height: 12),
                  NavisButton(
                    label: l.deleteBoat,
                    variant: NavisButtonVariant.danger,
                    onPressed: () async {
                      unawaited(HapticFeedback.mediumImpact());
                      final confirmed = await NavisConfirmDialog.show(
                        context,
                        title: l.deleteBoat,
                        message: l.deleteConfirm,
                        confirmLabel: l.delete,
                        destructive: true,
                      );
                      if (confirmed && context.mounted) {
                        try {
                          await ref
                              .read(boatsProvider.notifier)
                              .deleteBoat(widget.boatId);
                          if (!context.mounted) return;
                          NavisSnackbar.success(context, l.delete);
                          context.go('/boats');
                        } catch (e) {
                          if (context.mounted) {
                            NavisSnackbar.error(context, l.failedToDelete);
                          }
                        }
                      }
                    },
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
  });

  final Color color;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || borderRadius != oldDelegate.borderRadius;
}
