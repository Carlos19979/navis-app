import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

class GroupFormScreen extends ConsumerStatefulWidget {
  const GroupFormScreen({super.key});

  @override
  ConsumerState<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends ConsumerState<GroupFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _visibility = 'public';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final group = await ref.read(groupRepositoryProvider).createGroup(
            name: _nameController.text.trim(),
            visibility: _visibility,
            description: _descriptionController.text.trim(),
          );
      ref.invalidate(myGroupsProvider);
      if (!mounted) return;
      NavisSnackbar.success(context, 'Grupo creado');
      context.pushReplacement('/groups/${group.id}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      NavisSnackbar.error(context, 'No se pudo crear el grupo');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const NavisAppBar(title: 'Crear grupo', showBack: true),
      body: GradientBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _field(
                  controller: _nameController,
                  label: 'Nombre del grupo',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _descriptionController,
                  label: 'Descripción (opcional)',
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Visibilidad',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _visibilityOption(
                  value: 'public',
                  title: 'Público',
                  subtitle: 'Cualquiera puede solicitar unirse (tú apruebas).',
                  icon: Icons.public,
                ),
                const SizedBox(height: 8),
                _visibilityOption(
                  value: 'private',
                  title: 'Privado',
                  subtitle: 'Solo se unen con un código de invitación.',
                  icon: Icons.lock_outline,
                ),
                const SizedBox(height: 28),
                NavisButton(
                  label: 'Crear grupo',
                  isLoading: _saving,
                  isDisabled: _saving,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.glassWhite,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cyan),
        ),
      ),
    );
  }

  Widget _visibilityOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _visibility == value;
    return NavisCard(
      onTap: () => setState(() => _visibility = value),
      borderColor: selected ? AppColors.cyan : null,
      child: Row(
        children: [
          Icon(icon,
              color: selected ? AppColors.cyan : AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle, color: AppColors.cyan, size: 20),
        ],
      ),
    );
  }
}
