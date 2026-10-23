// lib/providers/fee_provider.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/fee_model.dart';

class FeeProvider extends ChangeNotifier {
  List<FeeTypeModel> _feeTypes = [];
  Map<int, List<FeeRecordModel>> _feeRecords = {};
  bool _isLoading = false;

  List<FeeTypeModel> get feeTypes => _feeTypes;
  bool get isLoading => _isLoading;

  Future<void> loadFeeTypes() async {
    _feeTypes = await DatabaseHelper.instance.getAllFeeTypes();
    notifyListeners();
  }

  Future<List<FeeRecordModel>> getFeesForStudent(int studentId) async {
    final fees = await DatabaseHelper.instance.getFeesByStudent(studentId);
    _feeRecords[studentId] = fees;
    return fees;
  }

  Future<List<FeeRecordModel>> getFeesForMonth(int studentId, int month, int year) async {
    return await DatabaseHelper.instance.getFeesByStudentAndMonth(studentId, month, year);
  }

  Future<void> generateMonthlyFees(int studentId, int month, int year) async {
    final existing = await DatabaseHelper.instance.getFeesByStudentAndMonth(studentId, month, year);
    if (existing.isNotEmpty) return;
    for (final ft in _feeTypes) {
      await DatabaseHelper.instance.insertFeeRecord(FeeRecordModel(
        studentId: studentId,
        feeTypeId: ft.id!,
        feeTypeName: ft.name,
        month: month,
        year: year,
        amount: ft.defaultAmount,
      ));
    }
    notifyListeners();
  }

  Future<void> markAsPaid(FeeRecordModel fee) async {
    final updated = fee.copyWith(isPaid: true, paidDate: DateTime.now());
    await DatabaseHelper.instance.updateFeeRecord(updated);
    if (_feeRecords.containsKey(fee.studentId)) {
      final idx = _feeRecords[fee.studentId]!.indexWhere((f) => f.id == fee.id);
      if (idx >= 0) _feeRecords[fee.studentId]![idx] = updated;
    }
    notifyListeners();
  }

  Future<void> markAsUnpaid(FeeRecordModel fee) async {
    final updated = fee.copyWith(isPaid: false);
    await DatabaseHelper.instance.updateFeeRecord(updated);
    notifyListeners();
  }

  Future<void> addFeeType(FeeTypeModel feeType) async {
    final id = await DatabaseHelper.instance.insertFeeType(feeType);
    _feeTypes.add(FeeTypeModel(id: id, name: feeType.name, defaultAmount: feeType.defaultAmount));
    notifyListeners();
  }

  Future<void> updateFeeType(FeeTypeModel feeType) async {
    await DatabaseHelper.instance.updateFeeType(feeType);
    final idx = _feeTypes.indexWhere((e) => e.id == feeType.id);
    if (idx >= 0) {
      _feeTypes[idx] = feeType;
    }
    notifyListeners();
  }

  Future<void> deleteFeeType(int id) async {
    await DatabaseHelper.instance.deleteFeeType(id);
    _feeTypes.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<double> getTotalCollected(int year) =>
      DatabaseHelper.instance.getTotalFeeCollected(year);

  Future<double> getTotalPending(int year) =>
      DatabaseHelper.instance.getTotalFeePending(year);
}
