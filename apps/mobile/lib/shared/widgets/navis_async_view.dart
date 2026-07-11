import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

/// Unifies the `AsyncValue.when(loading/error/data)` + shimmer + retry + empty
/// + pull-to-refresh pattern copied across ~10 list screens. Empty states
/// take a CTA so no listing dead-ends (several previously showed only an
/// icon + message).
class NavisAsyncListView<T> extends StatelessWidget {
  const NavisAsyncListView({
    super.key,
    required this.value,
    required this.itemBuilder,
    required this.onRefresh,
    this.itemCount,
    this.emptyIcon = Icons.inbox_outlined,
    required this.emptyMessage,
    this.emptyDescription,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.header,
    this.padding = Insets.screenWithNav,
    this.shimmerItemHeight = 120,
  });

  final AsyncValue<List<T>> value;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Future<void> Function() onRefresh;
  final int? itemCount;

  final IconData emptyIcon;
  final String emptyMessage;
  final String? emptyDescription;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  /// Optional pinned-first widget (e.g. a stats summary) above the list.
  final Widget? header;
  final EdgeInsetsGeometry padding;
  final double shimmerItemHeight;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => NavisShimmer(itemHeight: shimmerItemHeight),
      error: (e, _) => NavisErrorWidget(
        message: e.toString(),
        onRetry: onRefresh,
      ),
      data: (items) {
        if (items.isEmpty) {
          return NavisEmptyState(
            icon: emptyIcon,
            message: emptyMessage,
            description: emptyDescription,
            actionLabel: emptyActionLabel,
            onAction: onEmptyAction,
          );
        }
        final headerCount = header != null ? 1 : 0;
        return RefreshIndicator(
          color: AppColors.cyan,
          backgroundColor: AppColors.darkSurface,
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: padding,
            itemCount: (itemCount ?? items.length) + headerCount,
            itemBuilder: (context, index) {
              if (header != null && index == 0) return header!;
              final i = index - headerCount;
              return itemBuilder(context, items[i], i);
            },
          ),
        );
      },
    );
  }
}
