import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

class DocumentFormScreen extends ConsumerStatefulWidget {
  const DocumentFormScreen({
    super.key,
    required this.boatId,
    this.documentId,
  });

  final String boatId;
  final String? documentId;

  @override
  ConsumerState<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends ConsumerState<DocumentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _alertDaysController = TextEditingController(text: '30');
  String _selectedType = 'Registration';
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  bool _isLoading = false;
  String? _photoPath;

  static const _documentTypes = [
    'Registration',
    'Insurance',
    'Inspection',
    'License',
    'Safety Certificate',
    'Radio License',
    'Pollution Certificate',
    'Other',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    _alertDaysController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.cyan,
                ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _expiryDate = date);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _photoPath = image.path);
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final document = Document(
        id: widget.documentId ?? '',
        boatId: widget.boatId,
        type: _selectedType,
        expiryDate: _expiryDate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        alertDaysBefore: int.tryParse(_alertDaysController.text.trim()),
        photoUrl: _photoPath,
      );

      final repository = ref.read(documentRepositoryProvider);
      await repository.createDocument(document);
      ref.invalidate(boatDocumentsProvider(widget.boatId));

      if (mounted) {
        NavisSnackbar.success(context, 'Document saved');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        NavisSnackbar.error(context, 'Failed to save document');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NavisAppBar(title: 'New Document', showBack: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Document Type',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                items: _documentTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Expiry Date',
                      prefixIcon: const Icon(Icons.calendar_today),
                      hintText: NavisDateUtils.formatDate(_expiryDate),
                    ),
                    controller: TextEditingController(
                      text: NavisDateUtils.formatDate(_expiryDate),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _alertDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Alert Days Before Expiry',
                  prefixIcon: Icon(Icons.notifications_outlined),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label:
                    Text(_photoPath != null ? 'Photo selected' : 'Add Photo'),
              ),
              const SizedBox(height: 32),
              NavisButton(
                label: 'Save Document',
                onPressed: _onSave,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
