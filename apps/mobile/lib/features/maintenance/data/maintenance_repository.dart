import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/session_provider.dart';

import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_models.dart';

class MaintenanceRepository {
  MaintenanceRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<List<MaintenanceLog>> listLogs(String boatId) async {
    final res = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/boats/$boatId/maintenance');
    final data = (res.data!['data'] as List).cast<Map<String, dynamic>>();
    return data.map(MaintenanceLog.fromJson).toList();
  }

  Future<void> updateLog(
      String boatId, String id, Map<String, dynamic> body) async {
    await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/boats/$boatId/maintenance/$id',
      data: body,
    );
  }

  Future<void> deleteLog(String boatId, String id) async {
    await _apiClient.delete<void>('/api/v1/boats/$boatId/maintenance/$id');
  }

  Future<List<MaintenanceTask>> listTasks(String boatId) async {
    final res = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/boats/$boatId/maintenance/tasks');
    final data = (res.data!['data'] as List).cast<Map<String, dynamic>>();
    return data.map(MaintenanceTask.fromJson).toList();
  }

  Future<MaintenanceTask> addTask(
    String boatId,
    Map<String, dynamic> body,
  ) async {
    final res = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/boats/$boatId/maintenance/tasks',
      data: body,
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return MaintenanceTask.fromJson(data);
  }

  /// Marks a task as carried out. The API writes the history entry and rolls a
  /// periodic task's due date past it in one transaction, and answers with the
  /// task's new state — so the client never stitches those two together (and
  /// can never leave one done without the other).
  Future<MaintenanceTask> completeTask(
    String boatId,
    String taskId,
    Map<String, dynamic> body,
  ) async {
    final res = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/boats/$boatId/maintenance/tasks/$taskId/complete',
      data: body,
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return MaintenanceTask.fromJson(data);
  }

  Future<void> updateTask(
      String boatId, String id, Map<String, dynamic> body) async {
    await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/boats/$boatId/maintenance/tasks/$id',
      data: body,
    );
  }

  Future<void> deleteTask(String boatId, String id) async {
    await _apiClient
        .delete<void>('/api/v1/boats/$boatId/maintenance/tasks/$id');
  }

  Future<List<Expense>> listExpenses(String boatId) async {
    final res = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/boats/$boatId/expenses');
    final data = (res.data!['data'] as List).cast<Map<String, dynamic>>();
    return data.map(Expense.fromJson).toList();
  }

  Future<void> addExpense(String boatId, Map<String, dynamic> body) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/boats/$boatId/expenses',
      data: body,
    );
  }

  Future<void> updateExpense(
      String boatId, String id, Map<String, dynamic> body) async {
    await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/boats/$boatId/expenses/$id',
      data: body,
    );
  }

  Future<void> deleteExpense(String boatId, String id) async {
    await _apiClient.delete<void>('/api/v1/boats/$boatId/expenses/$id');
  }

  Future<ExpenseSummary> expenseSummary(String boatId) async {
    final res = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/boats/$boatId/expenses/summary');
    return ExpenseSummary.fromJson(res.data!['data'] as Map<String, dynamic>);
  }
}

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>(
  (ref) => MaintenanceRepository(),
);

final maintenanceLogsProvider =
    FutureProvider.family<List<MaintenanceLog>, String>((ref, boatId) {
  ref.watch(sessionUserIdProvider);
  return ref.read(maintenanceRepositoryProvider).listLogs(boatId);
});

final maintenanceTasksProvider =
    FutureProvider.family<List<MaintenanceTask>, String>((ref, boatId) {
  ref.watch(sessionUserIdProvider);
  return ref.read(maintenanceRepositoryProvider).listTasks(boatId);
});

final expensesProvider =
    FutureProvider.family<List<Expense>, String>((ref, boatId) {
  ref.watch(sessionUserIdProvider);
  return ref.read(maintenanceRepositoryProvider).listExpenses(boatId);
});

final expenseSummaryProvider =
    FutureProvider.family<ExpenseSummary, String>((ref, boatId) {
  ref.watch(sessionUserIdProvider);
  return ref.read(maintenanceRepositoryProvider).expenseSummary(boatId);
});
