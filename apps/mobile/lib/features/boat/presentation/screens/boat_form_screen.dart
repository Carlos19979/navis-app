import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

class BoatFormScreen extends ConsumerStatefulWidget {
  const BoatFormScreen({super.key, required this.boatId});

  final String boatId;

  @override
  ConsumerState<BoatFormScreen> createState() => _BoatFormScreenState();
}

class _BoatFormScreenState extends ConsumerState<BoatFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _registrationController = TextEditingController();
  final _lengthController = TextEditingController();
  final _homePortController = TextEditingController();
  String _selectedType = 'sailboat';
  bool _isLoading = false;
  bool _isEdit = false;
  String? _photoPath;

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
    setState(() {
      _selectedType = boat.type;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _registrationController.dispose();
    _lengthController.dispose();
    _homePortController.dispose();
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
      final boat = Boat(
        id: _isEdit ? widget.boatId : '',
        name: _nameController.text.trim(),
        registration: _registrationController.text.trim(),
        type: _selectedType,
        lengthMeters: double.parse(_lengthController.text.trim()),
        homePort: _homePortController.text.trim().isEmpty
            ? null
            : _homePortController.text.trim(),
        photoUrl: _photoPath,
      );

      if (_isEdit) {
        await ref.read(boatsProvider.notifier).updateBoat(boat);
      } else {
        await ref.read(boatsProvider.notifier).createBoat(boat);
      }

      if (mounted) {
        NavisSnackbar.success(
          context,
          _isEdit ? 'Boat updated successfully' : 'Boat created successfully',
        );
        context.go('/boats');
      }
    } catch (e) {
      if (mounted) {
        NavisSnackbar.error(context, 'Failed to save boat');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit) {
      final boatAsync = ref.watch(boatProvider(widget.boatId));
      if (boatAsync.isLoading) {
        return const Scaffold(body: NavisLoading());
      }
    }

    return Scaffold(
      appBar: NavisAppBar(
        title: _isEdit ? 'Edit Boat' : 'New Boat',
        showBack: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.darkDivider),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add Photo',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Boat Name',
                  prefixIcon: Icon(Icons.sailing_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the boat name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _registrationController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Registration Number',
                  prefixIcon: Icon(Icons.tag),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the registration number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Boat Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _boatTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type[0].toUpperCase() + type.substring(1)),
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
                decoration: const InputDecoration(
                  labelText: 'Length (meters)',
                  prefixIcon: Icon(Icons.straighten),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the length';
                  }
                  if (double.tryParse(value.trim()) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _homePortController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Home Port (optional)',
                  prefixIcon: Icon(Icons.anchor),
                ),
              ),
              const SizedBox(height: 32),
              NavisButton(
                label: _isEdit ? 'Update Boat' : 'Create Boat',
                onPressed: _onSave,
                isLoading: _isLoading,
              ),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Boat'),
                        content: const Text(
                          'Are you sure you want to delete this boat? This action cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      try {
                        await ref
                            .read(boatsProvider.notifier)
                            .deleteBoat(widget.boatId);
                        if (!context.mounted) return;
                        NavisSnackbar.success(context, 'Boat deleted');
                        context.go('/boats');
                      } catch (e) {
                        if (context.mounted) {
                          NavisSnackbar.error(context, 'Failed to delete boat');
                        }
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red),
                  ),
                  child: const Text('Delete Boat'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
