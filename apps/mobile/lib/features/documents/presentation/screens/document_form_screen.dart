import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
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
  final _customNameController = TextEditingController();
  final _renewalCostController = TextEditingController();
  final _renewalProviderController = TextEditingController();
  String _selectedType = 'itb';
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  bool _isLoading = false;
  bool _isEdit = false;
  String? _photoPath;
  String? _existingPhotoUrl;

  /// Selected expiry-alert thresholds (days before expiry). The API stores
  /// the full array (`alert_days`); default mirrors the server's [30, 7].
  final Set<int> _selectedAlertDays = {30, 7};

  /// Extra (non-preset) thresholds added via the custom chip or loaded from
  /// an existing document.
  final List<int> _extraAlertDays = [];

  static const _alertDayPresets = [30, 15, 7, 1];

  List<int> get _alertDayOptions =>
      {..._alertDayPresets, ..._extraAlertDays, ..._selectedAlertDays}.toList()
        ..sort((a, b) => b.compareTo(a));

  // Canonical API document types (see internal/dto/document_dto.go oneof).
  // The form used to offer display strings ('Registration', 'Insurance'…)
  // that the API rejects with 400 — document creation was broken. 'custom'
  // requires a custom_name (required_if in the API DTO): the form shows a
  // mandatory name field when it is selected.
  static final _documentTypes = [
    'itb',
    'insurance_rc',
    'insurance_full',
    'life_raft',
    'extinguisher',
    'flares',
    'first_aid',
    'medical_cert',
    'radio_cert',
    'navigation_license',
    'custom',
  ];

  static String _localizedDocType(AppLocalizations l, String type) =>
      switch (type) {
        'itb' => l.docTypeItb,
        'insurance_rc' => l.docTypeInsuranceRc,
        'insurance_full' => l.docTypeInsuranceFull,
        'life_raft' => l.docTypeLifeRaft,
        'extinguisher' => l.docTypeFireExtinguisher,
        'flares' => l.docTypeFlares,
        'first_aid' => l.docTypeFirstAidKit,
        'medical_cert' => l.docTypeMedicalCertificate,
        'radio_cert' => l.docTypeRadioLicense,
        'navigation_license' => l.docTypeNavigationLicense,
        // Legacy rows created before the canonical alignment keep rendering
        // through the old display names.
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
        'custom' => l.docTypeCustom,
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
    _customNameController.text = doc.customName ?? '';
    _renewalCostController.text = doc.lastRenewalCost?.toStringAsFixed(2) ?? '';
    _renewalProviderController.text = doc.lastRenewalProvider ?? '';
    final loadedAlerts = (doc.alertDays ??
            [if (doc.alertDaysBefore != null) doc.alertDaysBefore!])
        .where((d) => d > 0)
        .toSet();
    setState(() {
      if (loadedAlerts.isNotEmpty) {
        _selectedAlertDays
          ..clear()
          ..addAll(loadedAlerts);
        _extraAlertDays.addAll(
          loadedAlerts.where((d) => !_alertDayPresets.contains(d)),
        );
      }
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
    _customNameController.dispose();
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

      final alertDays = _selectedAlertDays.toList()
        ..sort((a, b) => b.compareTo(a));
      final customName = _customNameController.text.trim();

      final document = Document(
        id: widget.documentId ?? '',
        boatId: widget.boatId,
        type: _selectedType,
        customName: _selectedType == 'custom' && customName.isNotEmpty
            ? customName
            : null,
        expiryDate: _expiryDate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        alertDays: alertDays,
        alertDaysBefore: alertDays.isNotEmpty ? alertDays.first : null,
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

  /// Multi-select chips for the expiry-alert thresholds. A [FormField] so
  /// "at least one selected" validates alongside the rest of the form.
  Widget _buildAlertDaysField(BuildContext context, AppLocalizations l) {
    return FormField<Set<int>>(
      validator: (_) =>
          _selectedAlertDays.isEmpty ? l.selectAtLeastOneAlertDay : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_outlined,
                size: 20,
                color: context.txtSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.alertDaysBeforeExpiry,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.txtSecondary,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final days in _alertDayOptions)
                FilterChip(
                  label: Text(l.alertChipDays(days)),
                  selected: _selectedAlertDays.contains(days),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedAlertDays.add(days);
                      } else {
                        _selectedAlertDays.remove(days);
                      }
                    });
                    field.didChange(_selectedAlertDays);
                  },
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(l.customAlertDay),
                onPressed: () => _addCustomAlertDay(field),
              ),
            ],
          ),
          if (field.hasError) ...[
            const SizedBox(height: 6),
            Text(
              field.errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addCustomAlertDay(FormFieldState<Set<int>> field) async {
    final l = AppLocalizations.of(context)!;
    final text = await NavisInputDialog.show(
      context,
      title: l.alertDaysBeforeExpiry,
      hintText: l.customAlertDayHint,
    );
    if (text == null) return;
    final days = int.tryParse(text.trim());
    if (days == null || days <= 0) {
      if (mounted) {
        NavisSnackbar.error(context, l.validNumber);
      }
      return;
    }
    setState(() {
      if (!_alertDayPresets.contains(days)) {
        _extraAlertDays.add(days);
      }
      _selectedAlertDays.add(days);
    });
    field.didChange(_selectedAlertDays);
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
                        if (_selectedType == 'custom') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _customNameController,
                            maxLength: 100,
                            decoration: InputDecoration(
                              labelText: l.customDocumentName,
                              prefixIcon: const Icon(Icons.edit_outlined),
                              counterText: '',
                            ),
                            validator: (value) {
                              if (_selectedType == 'custom' &&
                                  (value == null || value.trim().isEmpty)) {
                                return l.customDocumentNameRequired;
                              }
                              return null;
                            },
                          ),
                        ],
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
                        _buildAlertDaysField(context, l),
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
                                      Semantics(
                                        label: 'Document scan',
                                        child: CachedNetworkImage(
                                          imageUrl: _existingPhotoUrl!,
                                          memCacheWidth: 1200,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(color: context.glassBg),
                                          errorWidget: (_, __, ___) => Center(
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                              size: 48,
                                              color: context.txtSecondary,
                                            ),
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
