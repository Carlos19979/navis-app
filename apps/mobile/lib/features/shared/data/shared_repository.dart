import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/api_client.dart';

/// A reservation of boat time.
/// The API rejected an unforced booking that overlaps an existing one
/// (409 BOOKING_OVERLAP). Retry with `force: true` after user confirmation.
class BookingOverlapException implements Exception {
  const BookingOverlapException();
}

class Booking {
  const Booking({
    required this.id,
    required this.boatId,
    required this.userId,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.purpose,
  });

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as String,
        boatId: j['boat_id'] as String,
        userId: j['user_id'] as String,
        startsAt: DateTime.parse(j['starts_at'] as String),
        endsAt: DateTime.parse(j['ends_at'] as String),
        status: j['status'] as String? ?? 'confirmed',
        purpose: j['purpose'] as String?,
      );

  final String id;
  final String boatId;
  final String userId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final String? purpose;
}

/// One person's share of an expense.
class ExpenseSplit {
  const ExpenseSplit({
    required this.id,
    required this.userId,
    required this.shareAmount,
    required this.settled,
  });

  factory ExpenseSplit.fromJson(Map<String, dynamic> j) => ExpenseSplit(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        shareAmount: (j['share_amount'] as num).toDouble(),
        settled: j['settled'] as bool? ?? false,
      );

  final String id;
  final String userId;
  final double shareAmount;
  final bool settled;
}

/// Per-expense split rollup for the current user (their share + settled).
class ExpenseSplitSummary {
  const ExpenseSplitSummary({
    required this.count,
    required this.myShare,
    required this.mySettled,
  });

  factory ExpenseSplitSummary.fromJson(Map<String, dynamic> j) =>
      ExpenseSplitSummary(
        count: (j['count'] as num?)?.toInt() ?? 0,
        myShare: (j['my_share'] as num?)?.toDouble(),
        mySettled: j['my_settled'] as bool? ?? false,
      );

  final int count;
  final double? myShare;
  final bool mySettled;
}

class SharedRepository {
  SharedRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<List<Booking>> listBookings(String boatId) async {
    final res = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/boats/$boatId/bookings');
    final data = (res.data!['data'] as List?) ?? [];
    return data
        .map((e) => Booking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates a booking. The API is the overlap authority: without [force]
  /// it rejects clashes with 409 BOOKING_OVERLAP, surfaced here as
  /// [BookingOverlapException] so the UI can confirm and retry forced.
  Future<void> createBooking(
    String boatId, {
    required DateTime startsAt,
    required DateTime endsAt,
    String? purpose,
    bool force = false,
  }) async {
    try {
      await _apiClient.post<Map<String, dynamic>>(
        '/api/v1/boats/$boatId/bookings',
        data: {
          'starts_at': startsAt.toUtc().toIso8601String(),
          'ends_at': endsAt.toUtc().toIso8601String(),
          if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
          if (force) 'force': true,
        },
      );
    } on DioException catch (e) {
      final code =
          (e.response?.data as Map<String, dynamic>?)?['error']?['code'];
      if (e.response?.statusCode == 409 && code == 'BOOKING_OVERLAP') {
        throw const BookingOverlapException();
      }
      rethrow;
    }
  }

  Future<void> deleteBooking(String boatId, String bookingId) async {
    await _apiClient.delete<void>('/api/v1/boats/$boatId/bookings/$bookingId');
  }

  Future<List<ExpenseSplit>> listSplits(String boatId, String expenseId) async {
    final res = await _apiClient.get<Map<String, dynamic>>(
        '/api/v1/boats/$boatId/expenses/$expenseId/splits');
    final data = (res.data!['data'] as List?) ?? [];
    return data
        .map((e) => ExpenseSplit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ExpenseSplit>> setSplits(
    String boatId,
    String expenseId,
    Map<String, double> shares,
  ) async {
    final res = await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/boats/$boatId/expenses/$expenseId/splits',
      data: {
        'splits': [
          for (final e in shares.entries)
            {'user_id': e.key, 'share_amount': e.value},
        ],
      },
    );
    final data = (res.data!['data'] as List?) ?? [];
    return data
        .map((e) => ExpenseSplit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> settleSplit(
    String boatId,
    String expenseId,
    String splitId,
    bool settled,
  ) async {
    await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/boats/$boatId/expenses/$expenseId/splits/$splitId/settle',
      data: {'settled': settled},
    );
  }

  /// Map of expenseId -> split summary for the current user (only expenses
  /// that have splits are present).
  Future<Map<String, ExpenseSplitSummary>> splitSummary(String boatId) async {
    final res = await _apiClient.get<Map<String, dynamic>>(
        '/api/v1/boats/$boatId/expense-splits-summary');
    final data = (res.data!['data'] as List?) ?? [];
    return {
      for (final e in data)
        (e as Map<String, dynamic>)['expense_id'] as String:
            ExpenseSplitSummary.fromJson(e),
    };
  }
}

/// Splits for a given expense. Family key = "boatId|expenseId".
final expenseSplitsProvider = FutureProvider.autoDispose
    .family<List<ExpenseSplit>, ({String boatId, String expenseId})>(
        (ref, key) {
  return ref
      .watch(sharedRepositoryProvider)
      .listSplits(key.boatId, key.expenseId);
});

final sharedRepositoryProvider =
    Provider<SharedRepository>((ref) => SharedRepository());

final boatBookingsProvider =
    FutureProvider.autoDispose.family<List<Booking>, String>((ref, boatId) {
  return ref.watch(sharedRepositoryProvider).listBookings(boatId);
});

/// expenseId -> split summary for the current user. Empty on error (e.g. Free).
final boatSplitSummaryProvider = FutureProvider.autoDispose
    .family<Map<String, ExpenseSplitSummary>, String>((ref, boatId) async {
  try {
    return await ref.watch(sharedRepositoryProvider).splitSummary(boatId);
  } catch (_) {
    return const {};
  }
});
