import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:navis_mobile/core/network/storage_service.dart';
import 'package:navis_mobile/core/network/supabase_client.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
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

  static final _documentTypes = [
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

  static String _localizedDocType(AppLocalizations l, String type) =>
      switch (type) {
        'Registration' => l.docTypeRegistration,
        'Insurance' => l.docTypeInsurance,
        'Inspection' => l.docTypeInspection,
        'License' => l.docTypeLicense,
        'Safety Certificate' => l.docTypeSafetyCertificate,
        'Radio License' => l.docTypeRadioLicense,
        'Pollution Certificate' => l.docTypePollutionCertificate,
        'Medical Certificate' => l.docTypeMedicalCertificate,
        'Life Raft' => l.docTypeLifeRaft,
        'Fire Extinguisher' => l.docTypeFireExtinguisher,
        'Flares' => l.docTypeFlares,
        'First Aid Kit' => l.docTypeFirstAidKit,
        'Fishing Permit' => l.docTypeFishingPermit,
        'Other' => l.other,
        _ => type,
      };

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
    _renewalCostController.text = doc.lastRenewalCost?.toStringAsFixed(2) ?? '';
    _renewalProviderController.text = doc.lastRenewalProvider ?? '';
    setState(() {
      _selectedType = doc.type;
      if (!_documentTypes.contains(doc.type)) {
        _documentTypes.add(doc.type);
      }
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
              title: Text(AppLocalizations.of(context)!.takePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(AppLocalizations.of(context)!.chooseFromGallery),
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
        // Renewing stamps a new renewal date; editing keeps the existing one.
        lastRenewalDate: widget.isRenew ? DateTime.now() : null,
        lastRenewalCost: double.tryParse(
            _renewalCostController.text.trim().replaceAll(',', '.')),
        lastRenewalProvider: _renewalProviderController.text.trim().isEmpty
            ? null
            : _renewalProviderController.text.trim(),
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
      if (_isEdit && widget.documentId != null) {
        ref.invalidate(documentProvider(widget.documentId!));
      }

      if (mounted) {
        final l = AppLocalizations.of(context)!;
        NavisSnackbar.success(
          context,
          widget.isRenew
              ? l.documentRenewed
              : _isEdit
                  ? l.documentUpdated
                  : l.documentSaved,
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        NavisSnackbar.error(
            context, AppLocalizations.of(context)!.failedToSave);
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
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NavisAppBar(
        title: widget.isRenew
            ? l.renewDocument
            : _isEdit
                ? l.editDocument
                : l.newDocument,
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
                          l.documentType,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppColors.cyan,
                                    letterSpacing: 0.8,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedType,
                          decoration: InputDecoration(
                            labelText: l.documentType,
                            prefixIcon: const Icon(Icons.description_outlined),
                          ),
                          items: _documentTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(
                                _localizedDocType(l, type),
                              ),
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
                                labelText: l.expiryDate,
                                prefixIcon: const Icon(Icons.calendar_today),
                                hintText:
                                    NavisDateUtils.formatDate(_expiryDate),
                              ),
                              controller: TextEditingController(
                                text: NavisDateUtils.formatDate(_expiryDate),
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
                          l.notes,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppColors.cyan,
                                    letterSpacing: 0.8,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _alertDaysController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l.alertDaysBeforeExpiry,
                            prefixIcon:
                                const Icon(Icons.notifications_outlined),
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (int.tryParse(value) == null) {
                                return l.validNumber;
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: l.notesOptional,
                            prefixIcon: const Icon(Icons.notes_outlined),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Renewal section — shown for existing documents so edit and
                  // renew expose the same fields; hidden when creating a new one.
                  if (_isEdit) ...[
                    const SizedBox(height: 16),
                    NavisCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.lastRenewal,
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
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: l.renewalCost,
                              prefixIcon: const Icon(Icons.euro),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _renewalProviderController,
                            decoration: InputDecoration(
                              labelText: l.renewalProvider,
                              prefixIcon: const Icon(Icons.business_outlined),
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
                          decoration: BoxDecoration(
                            color: context.glassBg,
                          ),
                          child: _photoPath != null || _existingPhotoUrl != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (_photoPath != null)
                                      Image.file(
                                        File(_photoPath!),
                                        fit: BoxFit.cover,
                                        semanticLabel: 'Document scan',
                                      )
                                    else
                                      Image.network(
                                        _existingPhotoUrl!,
                                        fit: BoxFit.cover,
                                        semanticLabel: 'Document scan',
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            size: 48,
                                            color: context.txtSecondary,
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
                                              .withValues(alpha: 0.7),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: context.glassBorderColor,
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.document_scanner_outlined,
                                      size: 48,
                                      color: context.txtSecondary
                                          .withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l.addScan,
                                      style: TextStyle(
                                        color: context.txtSecondary
                                            .withValues(alpha: 0.8),
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
                    label: widget.isRenew ? l.renewDocument : l.save,
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
