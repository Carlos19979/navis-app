import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/supabase_client.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
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
          // Resolve who booked: current user -> "You", else member name.
          final members = ref.watch(boatMembersProvider(boatId)).valueOrNull ??
              const <BoatMember>[];
          final myId = supabaseClient.auth.currentUser?.id;
          String bookerName(String userId) {
            if (userId == myId) return l.bookingYou;
            for (final m in members) {
              if (m.userId == userId && m.name.isNotEmpty) return m.name;
            }
            return l.bookingCrew;
          }

          // Mark bookings whose range intersects another active one, so
          // conflicts stay visible after creation (forced or raced).
          bool clashes(Booking a) =>
              a.status != 'cancelled' &&
              bookings.any((b) =>
                  !identical(a, b) &&
                  b.status != 'cancelled' &&
                  a.startsAt.isBefore(b.endsAt) &&
                  a.endsAt.isAfter(b.startsAt));

          return ListView.separated(
            padding: const EdgeInsets.all(Dimens.spaceLg),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: Dimens.spaceSm),
            itemBuilder: (context, i) => _BookingCard(
              boatId: boatId,
              booking: bookings[i],
              bookerName: bookerName(bookings[i].userId),
              overlaps: clashes(bookings[i]),
            ),
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

    // Time slot: start and end time.
    final startT = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: l.bookingStartTime,
    );
    if (startT == null || !context.mounted) return;
    final endT = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (startT.hour + 4).clamp(0, 23), minute: 0),
      helpText: l.bookingEndTime,
    );
    if (endT == null || !context.mounted) return;

    final start =
        DateTime(day.year, day.month, day.day, startT.hour, startT.minute);
    var end = DateTime(day.year, day.month, day.day, endT.hour, endT.minute);
    if (!end.isAfter(start)) {
      // End not after start → treat as next-day end so the range is valid.
      end = end.add(const Duration(days: 1));
    }

    final purpose = await NavisInputDialog.show(
      context,
      title: l.bookingAdd,
      hintText: l.bookingPurposeHint,
      confirmLabel: l.save,
    );
    if (purpose == null || !context.mounted) return;

    // The API is the overlap authority (it sees bookings this client hasn't
    // loaded yet — two members booking at once). On 409 the user can still
    // confirm and force it: overlaps are advisory on a shared boat.
    final repo = ref.read(sharedRepositoryProvider);
    try {
      try {
        await repo.createBooking(
          boatId,
          startsAt: start,
          endsAt: end,
          purpose: purpose,
        );
      } on BookingOverlapException {
        if (!context.mounted) return;
        final proceed = await NavisConfirmDialog.show(
          context,
          title: l.bookingOverlapTitle,
          message: l.bookingOverlapMessage,
          confirmLabel: l.bookingBookAnyway,
        );
        if (!proceed) return;
        await repo.createBooking(
          boatId,
          startsAt: start,
          endsAt: end,
          purpose: purpose,
          force: true,
        );
      }
      ref.invalidate(boatBookingsProvider(boatId));
    } catch (_) {
      if (context.mounted) NavisSnackbar.error(context, l.somethingWentWrong);
    }
  }
}

class _BookingCard extends ConsumerWidget {
  const _BookingCard({
    required this.boatId,
    required this.booking,
    required this.bookerName,
    this.overlaps = false,
  });

  final String boatId;
  final Booking booking;
  final String bookerName;

  /// Whether this booking's range intersects another active booking.
  final bool overlaps;

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
                  '${NavisDateUtils.formatDate(booking.startsAt)}  '
                  '${NavisDateUtils.formatTime(booking.startsAt)}–'
                  '${NavisDateUtils.formatTime(booking.endsAt)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.txtPrimary,
                  ),
                ),
                Text(
                  booking.purpose != null && booking.purpose!.isNotEmpty
                      ? '$bookerName · ${booking.purpose!}'
                      : bookerName,
                  style: TextStyle(fontSize: 13, color: context.txtSecondary),
                ),
                if (overlaps)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 14, color: AppColors.amber),
                        const SizedBox(width: 4),
                        Text(
                          l.bookingOverlapsBadge,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.amber,
                          ),
                        ),
                      ],
                    ),
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
