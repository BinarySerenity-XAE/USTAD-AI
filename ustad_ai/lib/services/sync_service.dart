// lib/services/sync_service.dart
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import 'api_service.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Push local changes to cloud
  Future<Map<String, dynamic>> syncToCloud() async {
    if (_isSyncing) return {'status': 'in_progress'};
    _isSyncing = true;

    try {
      final db = await DatabaseHelper.instance.database;

      // Pull local tables
      final students = await db.query('students');
      final attendance = await db.query('attendance');
      final marks = await db.query('marks');
      final homework = await db.query('homework');
      final homeworkChecks = await db.query('homework_checks');
      final fees = await db.query('fee_records');
      final timetables = await db.query('timetables');
      final weeklyDiaries = await db.query('weekly_diaries');

      final payload = {
        'device_id': 'Teacher_App_Android',
        'school_name': 'Sublime Grammar School',
        'students': students,
        'attendance': attendance,
        'marks': marks,
        'homework': homework,
        'homework_checks': homeworkChecks,
        'fees': fees,
        'timetables': timetables,
        'weekly_diaries': weeklyDiaries,
      };

      final res = await ApiService.instance.pushCloudSync(payload);
      _lastSyncTime = DateTime.now();
      debugPrint('Cloud Sync Success: $res');
      return res;
    } catch (e) {
      debugPrint('Cloud Sync Failed: $e');
      return {'status': 'error', 'message': e.toString()};
    } finally {
      _isSyncing = false;
    }
  }

  /// Pull latest cloud changes down to local SQLite
  Future<Map<String, dynamic>> pullFromCloud() async {
    try {
      final res = await ApiService.instance.pullCloudSync();
      if (res['status'] != 'success' || res['data'] == null) {
        return {'status': 'error', 'message': 'Failed to pull cloud data'};
      }

      final data = res['data'] as Map<String, dynamic>;
      final db = await DatabaseHelper.instance.database;

      // Upsert into local SQLite with ConflictAlgorithm.replace
      final tables = [
        'students',
        'attendance',
        'marks',
        'homework',
        'homework_checks',
        'fee_records',
        'timetables',
        'weekly_diaries'
      ];

      for (final table in tables) {
        final list = data[table] as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          final batch = db.batch();
          for (final row in list) {
            if (row is Map<String, dynamic>) {
              batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
          await batch.commit(noResult: true);
        }
      }

      _lastSyncTime = DateTime.now();
      return {'status': 'success', 'synced_at': _lastSyncTime!.toIso8601String()};
    } catch (e) {
      debugPrint('Cloud Pull Failed: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Full bi-directional sync: pushes local updates to cloud, then pulls any changes made by other teachers/admin!
  Future<Map<String, dynamic>> syncBiDirectional() async {
    final pushRes = await syncToCloud();
    final pullRes = await pullFromCloud();
    final isSuccess = pushRes['status'] == 'success' || pullRes['status'] == 'success';
    return {
      'status': isSuccess ? 'success' : 'offline_cached',
      'synced_at': DateTime.now().toIso8601String(),
      'push': pushRes,
      'pull': pullRes,
    };
  }
}
