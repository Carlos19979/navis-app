import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

/// A chip-based crew editor: existing names show as removable chips, a text
/// field adds arbitrary names (type + Enter/comma), and optional suggestions
/// (e.g. group members who RSVP'd "going") can be tapped to add quickly.
class CrewChipsField extends StatefulWidget {
  const CrewChipsField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.suggestions = const [],
    this.label,
  });

  final List<String> initial;
  final ValueChanged<List<String>> onChanged;
  final List<String> suggestions;
  final String? label;

  @override
  State<CrewChipsField> createState() => _CrewChipsFieldState();
}

class _CrewChipsFieldState extends State<CrewChipsField> {
  late List<String> _crew = List.of(widget.initial);
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return;
    final exists = _crew.any((c) => c.toLowerCase() == name.toLowerCase());
    if (!exists) {
      setState(() => _crew = [..._crew, name]);
      widget.onChanged(_crew);
    }
    _ctrl.clear();
  }

  void _remove(String name) {
    setState(() => _crew = _crew.where((c) => c != name).toList());
    widget.onChanged(_crew);
  }

  void _onChangedText(String value) {
    // Adding on comma lets users paste/type "a, b, c".
    if (value.endsWith(',')) {
      _add(value.substring(0, value.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final available = widget.suggestions
        .where((s) =>
            s.trim().isNotEmpty &&
            !_crew.any((c) => c.toLowerCase() == s.toLowerCase()))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              color: context.txtSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (_crew.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in _crew)
                Chip(
                  label: Text(name),
                  labelStyle:
                      TextStyle(color: context.txtPrimary, fontSize: 13),
                  backgroundColor: AppColors.cyan.withValues(alpha: 0.12),
                  side: BorderSide(
                    color: AppColors.cyan.withValues(alpha: 0.35),
                    width: 0.5,
                  ),
                  deleteIconColor: context.txtSecondary,
                  onDeleted: () => _remove(name),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        if (_crew.isNotEmpty) const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'\n')),
          ],
          style: TextStyle(color: context.txtPrimary),
          decoration: InputDecoration(
            hintText: l.addCrewMemberHint,
            prefixIcon: const Icon(Icons.person_add_alt_1, size: 20),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add, size: 20),
              tooltip: l.add,
              onPressed: () => _add(_ctrl.text),
            ),
          ),
          onChanged: _onChangedText,
          onSubmitted: _add,
        ),
        if (available.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in available)
                ActionChip(
                  avatar:
                      Icon(Icons.add, size: 16, color: context.txtSecondary),
                  label: Text(name),
                  labelStyle:
                      TextStyle(color: context.txtSecondary, fontSize: 12),
                  backgroundColor: context.glassBg,
                  side: BorderSide(color: context.glassBorderColor, width: 0.5),
                  onPressed: () => _add(name),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
