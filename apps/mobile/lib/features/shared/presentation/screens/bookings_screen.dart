import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/shared/data/shared_repository.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_gradient_fab.dart';
import 'package:navis_mobile/shared/widgets/navis_scaffold.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key, required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final async = ref.watch(boatBookingsProvider(boatId));

    return NavisScaffold(
      title: l.bookingsTitle,
      showBack: true,
      floatingActionButton: NavisGradientFab(
        onPressed: () => _addBooking(context, ref),
        icon: Icons.add,
        tooltip: l.bookingAdd,
        label: l.bookingAdd,
      ),
      body: async.when(
        loading: () => const NavisShimmer(itemHeight: 80),
        error: (e, _) => NavisErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(boatBookingsProvider(boatId)),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return NavisEmptyState(
              icon: Icons.event_available_outlined,
              message: l.bookingsEmpty,
              description: l.bookingsEmptyDescription,
              actionLabel: l.bookingAdd,
              onAction: () => _addBooking(context, ref),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(Dimens.spaceLg),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: Dimens.spaceSm),
            itemBuilder: (context, i) =>
                _BookingCard(boatId: boatId, booking: bookings[i]),
          );
        },
      ),
    );
  }

  Future<void> _addBooking(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !context.mounted) return;

    final purpose = await NavisInputDialog.show(
      context,
      title: l.bookingAdd,
      hintText: l.bookingPurposeHint,
      confirmLabel: l.save,
    );
    if (purpose == null || !context.mounted) return;

    try {
      // A day booking: whole day from the picked date.
      final start = DateTime(day.year, day.month, day.day, 8);
      final end = DateTime(day.year, day.month, day.day, 20);
      await ref.read(sharedRepositoryProvider).createBooking(
            boatId,
            startsAt: start,
            endsAt: end,
            purpose: purpose,
          );
      ref.invalidate(boatBookingsProvider(boatId));
    } catch (_) {
      if (context.mounted) NavisSnackbar.error(context, l.somethingWentWrong);
    }
  }
}

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.boatId, required this.booking});

  final String boatId;
  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return NavisCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event, color: AppColors.cyan, size: 22),
          ),
          const SizedBox(width: Dimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  NavisDateUtils.formatDate(booking.startsAt),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.txtPrimary,
                  ),
                ),
                if (booking.purpose != null && booking.purpose!.isNotEmpty)
                  Text(
                    booking.purpose!,
                    style: TextStyle(fontSize: 13, color: context.txtSecondary),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: context.txtSecondary),
            tooltip: l.delete,
            onPressed: () async {
              final ok = await NavisConfirmDialog.show(
                context,
                title: l.bookingDelete,
                message: l.bookingDeleteConfirm,
                confirmLabel: l.delete,
                destructive: true,
              );
              if (!ok) return;
              try {
                await ref
                    .read(sharedRepositoryProvider)
                    .deleteBooking(boatId, booking.id);
                ref.invalidate(boatBookingsProvider(boatId));
              } catch (_) {
                if (context.mounted) {
                  NavisSnackbar.error(context, l.somethingWentWrong);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
