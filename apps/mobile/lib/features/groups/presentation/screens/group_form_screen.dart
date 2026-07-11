import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_scaffold.dart';
import 'package:navis_mobile/shared/widgets/navis_section.dart';
import 'package:navis_mobile/shared/widgets/navis_selectable_card.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';

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
    final l = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      final group = await ref.read(groupRepositoryProvider).createGroup(
            name: _nameController.text.trim(),
            visibility: _visibility,
            description: _descriptionController.text.trim(),
          );
      ref.invalidate(myGroupsProvider);
      if (!mounted) return;
      NavisSnackbar.success(context, l.groupCreated);
      context.pushReplacement('/groups/${group.id}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      NavisSnackbar.error(context, l.couldNotCreateGroup);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return NavisScaffold(
      title: l.createGroup,
      showBack: true,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            NavisTextField(
              controller: _nameController,
              label: l.groupName,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.requiredField : null,
            ),
            const SizedBox(height: 16),
            NavisTextField(
              controller: _descriptionController,
              label: l.descriptionOptional,
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            NavisSectionHeader(label: l.visibilityLabel),
            NavisSelectableCard(
              title: l.publicLabel,
              subtitle: l.groupPublicSubtitle,
              icon: Icons.public,
              selected: _visibility == 'public',
              onTap: () => setState(() => _visibility = 'public'),
            ),
            NavisSelectableCard(
              title: l.privateLabel,
              subtitle: l.groupPrivateSubtitle,
              icon: Icons.lock_outline,
              selected: _visibility == 'private',
              onTap: () => setState(() => _visibility = 'private'),
            ),
            const SizedBox(height: 28),
            NavisButton(
              label: l.createGroup,
              isLoading: _saving,
              isDisabled: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
