import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:navis_mobile/core/network/storage_service.dart';
import 'package:navis_mobile/core/network/supabase_client.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

class DocumentFormScreen extends ConsumerStatefulWidget {
  const DocumentFormScreen({
    super.key,
    required this.boatId,
    this.documentId,
    this.isRenew = false,
  });

  final String boatId;
  final String? documentId;
  final bool isRenew;

  @override
  ConsumerState<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends ConsumerState<DocumentFormScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _alertDaysController = TextEditingController(text: '30');
  final _renewalCostController = TextEditingController();
  final _renewalProviderController = TextEditingController();
  String _selectedType = 'Registration';
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  bool _isLoading = false;
  bool _isEdit = false;
  String? _photoPath;
  String? _existingPhotoUrl;

  static const _documentTypes = [
    'Registration',
    'Insurance',
    'Inspection',
    'License',
    'Safety Certificate',
    'Radio License',
    'Pollution Certificate',
    'Medical Certificate',
    'Life Raft',
    'Fire Extinguisher',
    'Flares',
    'First Aid Kit',
    'Fishing Permit',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _isEdit = widget.documentId != null;
    if (widget.isRenew) {
      _expiryDate = DateTime.now().add(const Duration(days: 365));
    }
    if (_isEdit) {
      _loadDocument();
    }
  }

  Future<void> _loadDocument() async {
    final doc = await ref.read(documentProvider(widget.documentId!).future);
    _notesController.text = doc.notes ?? '';
    _alertDaysController.text = (doc.alertDaysBefore ?? 30).toString();
    if (widget.isRenew) {
      _renewalCostController.text =
          doc.lastRenewalCost?.toStringAsFixed(2) ?? '';
      _renewalProviderController.text = doc.lastRenewalProvider ?? '';
    }
    setState(() {
      _selectedType = doc.type;
      _expiryDate = widget.isRenew
          ? DateTime.now().add(const Duration(days: 365))
          : doc.expiryDate;
      _existingPhotoUrl = doc.photoUrl;
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _alertDaysController.dispose();
    _renewalCostController.dispose();
    _renewalProviderController.dispose();
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

  Future<void> _pickScan() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    if (image != null) {
      setState(() => _photoPath = image.path);
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = supabaseClient.auth.currentUser!.id;
      final storage = ref.read(storageServiceProvider);
      final repository = ref.read(documentRepositoryProvider);

      final document = Document(
        id: widget.documentId ?? '',
        boatId: widget.boatId,
        type: _selectedType,
        expiryDate: _expiryDate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        alertDaysBefore: int.tryParse(_alertDaysController.text.trim()),
        photoUrl: _existingPhotoUrl,
        lastRenewalDate: widget.isRenew ? DateTime.now() : null,
        lastRenewalCost: widget.isRenew
            ? double.tryParse(_renewalCostController.text.trim())
            : null,
        lastRenewalProvider:
            widget.isRenew && _renewalProviderController.text.trim().isNotEmpty
                ? _renewalProviderController.text.trim()
                : null,
      );

      if (_isEdit) {
        String? photoUrl = _existingPhotoUrl;
        if (_photoPath != null) {
          photoUrl = await storage.uploadDocumentScan(
            userId: userId,
            documentId: widget.documentId!,
            file: File(_photoPath!),
          );
        }
        await repository.updateDocument(
          document.copyWith(photoUrl: photoUrl),
        );
      } else {
        final created = await repository.createDocument(document);
        if (_photoPath != null) {
          final url = await storage.uploadDocumentScan(
            userId: userId,
            documentId: created.id,
            file: File(_photoPath!),
          );
          await repository.updateDocument(
            created.copyWith(photoUrl: url),
          );
        }
      }

      ref.invalidate(boatDocumentsProvider(widget.boatId));

      if (mounted) {
        NavisSnackbar.success(
          context,
          widget.isRenew
              ? 'Document renewed'
              : _isEdit
                  ? 'Document updated'
                  : 'Document saved',
        );
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
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NavisAppBar(
        title: widget.isRenew
            ? 'Renew Document'
            : _isEdit
                ? 'Edit Document'
                : 'New Document',
        showBack: true,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Document type & expiry section
                  NavisCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Document Info',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: AppColors.cyan,
                                letterSpacing: 0.8,
                              ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Document Type',
                            prefixIcon:
                                Icon(Icons.description_outlined),
                          ),
                          items: _documentTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: widget.isRenew
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(
                                        () => _selectedType = value);
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
                                prefixIcon:
                                    const Icon(Icons.calendar_today),
                                hintText: NavisDateUtils.formatDate(
                                    _expiryDate),
                              ),
                              controller: TextEditingController(
                                text: NavisDateUtils.formatDate(
                                    _expiryDate),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Alert & notes section
                  NavisCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alerts & Notes',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: AppColors.cyan,
                                letterSpacing: 0.8,
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _alertDaysController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Alert Days Before Expiry',
                            prefixIcon:
                                Icon(Icons.notifications_outlined),
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
                      ],
                    ),
                  ),

                  // Renewal section
                  if (widget.isRenew) ...[
                    const SizedBox(height: 16),
                    NavisCard(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Renewal Details',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AppColors.cyan,
                                  letterSpacing: 0.8,
                                ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _renewalCostController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Renewal Cost',
                              prefixIcon: Icon(Icons.euro),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller:
                                _renewalProviderController,
                            decoration: const InputDecoration(
                              labelText: 'Provider / Company',
                              prefixIcon:
                                  Icon(Icons.business_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Scan section
                  NavisCard(
                    padding: EdgeInsets.zero,
                    child: GestureDetector(
                      onTap: _pickScan,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 160,
                          decoration: const BoxDecoration(
                            color: AppColors.glassWhite,
                          ),
                          child: _photoPath != null ||
                                  _existingPhotoUrl != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (_photoPath != null)
                                      Image.file(
                                        File(_photoPath!),
                                        fit: BoxFit.cover,
                                        semanticLabel:
                                            'Document scan',
                                      )
                                    else
                                      Image.network(
                                        _existingPhotoUrl!,
                                        fit: BoxFit.cover,
                                        semanticLabel:
                                            'Document scan',
                                        errorBuilder:
                                            (_, __, ___) =>
                                                const Center(
                                          child: Icon(
                                            Icons
                                                .broken_image_outlined,
                                            size: 48,
                                            color: AppColors
                                                .textSecondary,
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
                                          color: AppColors.navy
                                              .withValues(
                                                  alpha: 0.7),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors
                                                .glassBorder,
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
                              : Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons
                                          .document_scanner_outlined,
                                      size: 48,
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add Scan',
                                      style: TextStyle(
                                        color: AppColors
                                            .textSecondary
                                            .withValues(
                                                alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  NavisButton(
                    label: widget.isRenew
                        ? 'Renew Document'
                        : _isEdit
                            ? 'Update Document'
                            : 'Save Document',
                    onPressed: _onSave,
                    isLoading: _isLoading,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
