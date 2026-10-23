// lib/screens/admin/fee_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/student_provider.dart';
import '../../providers/fee_provider.dart';
import '../../models/student_model.dart';
import '../../models/fee_model.dart';
import '../../database/db_helper.dart';
import '../../services/fee_pdf_service.dart';
import '../../services/whatsapp_service.dart';

class FeeManagementScreen extends StatefulWidget {
  const FeeManagementScreen({super.key});

  @override
  State<FeeManagementScreen> createState() => _FeeManagementScreenState();
}

class _FeeManagementScreenState extends State<FeeManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _selectedClass = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Fee Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Batch Print Class Challans (PDF)',
            onPressed: () => _showBatchPrintDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Manage Fee Types',
            onPressed: () => _showManageFeeTypesSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Fee Category',
            onPressed: () => _showEditFeeTypeDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.white,
          labelColor: AppTheme.white,
          unselectedLabelColor: AppTheme.white.withOpacity(0.6),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Monthly Fees'),
            Tab(icon: Icon(Icons.warning_amber_rounded, size: 18), text: 'Arrears & Defaulters'),
            Tab(icon: Icon(Icons.pie_chart_rounded, size: 18), text: 'Summary'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _MonthlyFeesTab(
            selectedMonth: _selectedMonth,
            selectedYear: _selectedYear,
            selectedClass: _selectedClass,
            onMonthChanged: (m, y) => setState(() { _selectedMonth = m; _selectedYear = y; }),
            onClassChanged: (c) => setState(() => _selectedClass = c),
          ),
          _ArrearsDefaultersTab(
            selectedMonth: _selectedMonth,
            selectedYear: _selectedYear,
            selectedClass: _selectedClass,
            onClassChanged: (c) => setState(() => _selectedClass = c),
          ),
          _FeeSummaryTab(year: _selectedYear),
        ],
      ),
    );
  }

  void _showBatchPrintDialog(BuildContext context) {
    String selectedClass = _selectedClass.isNotEmpty ? _selectedClass : 'Class 5';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.print_rounded, color: AppTheme.navyBlue),
              SizedBox(width: 8),
              Text('Batch Print Challans', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Generate a combined PDF of 3-Copy Fee Challans for all students in the selected class.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedClass,
                decoration: const InputDecoration(labelText: 'Select Class', border: OutlineInputBorder()),
                items: StudentModel.classes
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedClass = val);
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Month: ${FeeTypeModel.months[_selectedMonth - 1]} $_selectedYear',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyBlue),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Generate & Print'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navyBlue),
              onPressed: () async {
                Navigator.pop(ctx);
                final students = context.read<StudentProvider>().students
                    .where((s) => s.className == selectedClass)
                    .toList();
                if (students.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No students found in $selectedClass')),
                  );
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('⏳ Generating ${students.length} challans for $selectedClass...')),
                );
                await FeePdfService.printBatchClassChallans(
                  context: context,
                  className: selectedClass,
                  month: _selectedMonth,
                  year: _selectedYear,
                  students: students,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showManageFeeTypesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<FeeProvider>(
          builder: (context, feeProv, _) {
            final feeTypes = feeProv.feeTypes;
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fee Categories & Tuition', style: AppTheme.headingSmall),
                          const SizedBox(height: 2),
                          const Text(
                            'Edit, replace name & update default fee amounts',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.navyBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showEditFeeTypeDialog(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (feeTypes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('No fee categories defined.')),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: feeTypes.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final ft = feeTypes[idx];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.lightBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.payments_rounded, color: AppTheme.navyBlue, size: 22),
                            ),
                            title: Text(ft.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('Default: Rs. ${ft.defaultAmount.toStringAsFixed(0)}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: AppTheme.navyBlue, size: 20),
                                  tooltip: 'Edit / Replace',
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showEditFeeTypeDialog(context, existing: ft);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 20),
                                  tooltip: 'Delete',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text('Delete Fee Type?'),
                                        content: Text('Are you sure you want to delete "${ft.name}"?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                                            onPressed: () => Navigator.pop(c, true),
                                            child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true && ft.id != null) {
                                      feeProv.deleteFeeType(ft.id!);
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditFeeTypeDialog(BuildContext context, {FeeTypeModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl = TextEditingController(
      text: existing != null ? existing.defaultAmount.toStringAsFixed(0) : '',
    );
    final isEditing = existing != null;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEditing ? 'Edit Fee Category' : 'Add Fee Category', style: AppTheme.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Fee Name',
                hintText: 'e.g. Monthly Tuition Fee',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Default Amount (Rs.)',
                hintText: 'e.g. 3500',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navyBlue),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (name.isNotEmpty) {
                if (isEditing) {
                  context.read<FeeProvider>().updateFeeType(FeeTypeModel(
                    id: existing.id,
                    name: name,
                    defaultAmount: amt,
                  ));
                } else {
                  context.read<FeeProvider>().addFeeType(FeeTypeModel(
                    name: name,
                    defaultAmount: amt,
                  ));
                }
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Fee category ${isEditing ? "updated" : "added"} successfully!')),
                );
              }
            },
            child: Text(isEditing ? 'Save Changes' : 'Add', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _MonthlyFeesTab extends StatefulWidget {
  final int selectedMonth;
  final int selectedYear;
  final String selectedClass;
  final void Function(int, int) onMonthChanged;
  final void Function(String) onClassChanged;

  const _MonthlyFeesTab({
    required this.selectedMonth,
    required this.selectedYear,
    required this.selectedClass,
    required this.onMonthChanged,
    required this.onClassChanged,
  });

  @override
  State<_MonthlyFeesTab> createState() => _MonthlyFeesTabState();
}

class _MonthlyFeesTabState extends State<_MonthlyFeesTab> {
  @override
  Widget build(BuildContext context) {
    final students = context.watch<StudentProvider>().students;
    final filtered = widget.selectedClass.isEmpty
        ? students
        : students.where((s) => s.className == widget.selectedClass).toList();

    return Column(
      children: [
        // Month/Year selector
        Container(
          color: AppTheme.white,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: DropdownButtonFormField<int>(
                  value: widget.selectedMonth,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: List.generate(12, (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(
                      FeeTypeModel.months[i],
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
                  onChanged: (m) => widget.onMonthChanged(m!, widget.selectedYear),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  value: widget.selectedYear,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: [2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(
                    value: y,
                    child: Text(
                      y.toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  )).toList(),
                  onChanged: (y) => widget.onMonthChanged(widget.selectedMonth, y!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: widget.selectedClass.isEmpty ? '' : widget.selectedClass,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All', style: TextStyle(fontSize: 12))),
                    ...StudentModel.classes.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c.replaceAll('Class ', 'C'),
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                  ],
                  onChanged: (c) => widget.onClassChanged(c ?? ''),
                ),
              ),
            ],
          ),
        ),

        // Student fee list
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No students found', style: TextStyle(color: AppTheme.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _StudentFeeCard(
                    student: filtered[i],
                    month: widget.selectedMonth,
                    year: widget.selectedYear,
                  ),
                ),
        ),
      ],
    );
  }
}

class _StudentFeeCard extends StatefulWidget {
  final StudentModel student;
  final int month;
  final int year;
  const _StudentFeeCard({required this.student, required this.month, required this.year});

  @override
  State<_StudentFeeCard> createState() => _StudentFeeCardState();
}

class _StudentFeeCardState extends State<_StudentFeeCard> {
  List<FeeRecordModel> _fees = [];
  bool _isExpanded = false;
  bool _isLoading = false;

  Future<void> _loadFees() async {
    if (_fees.isEmpty) {
      setState(() => _isLoading = true);
      final fp = context.read<FeeProvider>();
      // Auto-generate if not exists
      await fp.generateMonthlyFees(widget.student.id!, widget.month, widget.year);
      _fees = await fp.getFeesForMonth(widget.student.id!, widget.month, widget.year);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDue = _fees.where((f) => !f.isPaid).fold(0.0, (s, f) => s + f.amount);
    final allPaid = _fees.isNotEmpty && _fees.every((f) => f.isPaid);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadowList,
        border: allPaid
            ? Border.all(color: AppTheme.successGreen.withOpacity(0.4))
            : null,
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: allPaid ? AppTheme.successGreen.withOpacity(0.15) : AppTheme.lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                allPaid ? Icons.check_circle_rounded : Icons.account_balance_wallet_rounded,
                color: allPaid ? AppTheme.successGreen : AppTheme.navyBlue,
                size: 22,
              ),
            ),
            title: Text(widget.student.name, style: AppTheme.labelMedium),
            subtitle: Text('${widget.student.className} • ${FeeTypeModel.months[widget.month - 1]}',
                style: AppTheme.bodySmall),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (totalDue > 0) ...[
                  IconButton(
                    icon: const Icon(Icons.print_rounded, size: 20, color: AppTheme.navyBlue),
                    tooltip: 'Print 3-Part Fee Challan (PDF)',
                    onPressed: () async {
                      if (_fees.isEmpty) await _loadFees();
                      await FeePdfService.print3CopyChallan(
                        context: context,
                        student: widget.student,
                        month: widget.month,
                        year: widget.year,
                        fees: _fees,
                      );
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Due: Rs.${totalDue.toInt()}',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.errorRed, fontWeight: FontWeight.w700)),
                  ),
                ] else if (allPaid) ...[
                  IconButton(
                    icon: const Icon(Icons.receipt_rounded, size: 20, color: AppTheme.successGreen),
                    tooltip: 'Print Payment Receipt (PDF)',
                    onPressed: () async {
                      if (_fees.isEmpty) await _loadFees();
                      final paidFee = _fees.firstWhere((f) => f.isPaid, orElse: () => _fees.first);
                      await FeePdfService.printPaymentReceipt(
                        context: context,
                        student: widget.student,
                        fee: paidFee,
                      );
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Paid ✓',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.successGreen, fontWeight: FontWeight.w700)),
                  ),
                ],
                IconButton(
                  icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () async {
                    if (!_isExpanded) await _loadFees();
                    setState(() => _isExpanded = !_isExpanded);
                  },
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            if (_isLoading)
              const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
            else ...[
              ..._fees.map((fee) => _FeeRow(
                fee: fee,
                onToggle: () async {
                  final fp = context.read<FeeProvider>();
                  if (fee.isPaid) {
                    await fp.markAsUnpaid(fee);
                  } else {
                    await fp.markAsPaid(fee);
                  }
                  _fees = await fp.getFeesForMonth(widget.student.id!, widget.month, widget.year);
                  setState(() {});
                },
                onEdit: () => _showEditAmountDialog(context, fee),
                onPrintReceipt: () async {
                  await FeePdfService.printPaymentReceipt(
                    context: context,
                    student: widget.student,
                    fee: fee,
                  );
                },
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextButton.icon(
                  onPressed: () => _showAddExtraFeeDialog(context),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: const Text('Add Fee Item for this Month', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.navyBlue),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showEditAmountDialog(BuildContext context, FeeRecordModel fee) {
    final ctrl = TextEditingController(text: fee.amount.toInt().toString());
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit ${fee.feeTypeName}', style: AppTheme.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${widget.student.name} • ${FeeTypeModel.months[widget.month - 1]} ${widget.year}',
                style: AppTheme.bodySmall),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Fee Amount (Rs.)',
                prefixText: 'Rs. ',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newAmt = double.tryParse(ctrl.text.trim());
              if (newAmt != null && newAmt >= 0) {
                final updated = fee.copyWith(amount: newAmt);
                await DatabaseHelper.instance.updateFeeRecord(updated);
                final fp = context.read<FeeProvider>();
                _fees = await fp.getFeesForMonth(widget.student.id!, widget.month, widget.year);
                setState(() {});
                if (mounted) Navigator.of(dlgCtx).pop();
              }
            },
            child: const Text('Save Amount'),
          ),
        ],
      ),
    );
  }

  void _showAddExtraFeeDialog(BuildContext context) {
    final amountCtrl = TextEditingController(text: '1000');
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Month Fee Item', style: AppTheme.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Fee Description',
                hintText: 'e.g. Exam Fee, Fine, Trip',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (Rs.)',
                prefixText: 'Rs. ',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final desc = nameCtrl.text.trim();
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (desc.isNotEmpty && amt > 0) {
                final allTypes = await DatabaseHelper.instance.getAllFeeTypes();
                int typeId = 4; // default misc
                if (allTypes.isNotEmpty) typeId = allTypes.first.id ?? 1;

                await DatabaseHelper.instance.insertFeeRecord(FeeRecordModel(
                  studentId: widget.student.id!,
                  feeTypeId: typeId,
                  feeTypeName: desc,
                  month: widget.month,
                  year: widget.year,
                  amount: amt,
                  isPaid: false,
                ));
                final fp = context.read<FeeProvider>();
                _fees = await fp.getFeesForMonth(widget.student.id!, widget.month, widget.year);
                setState(() {});
                if (mounted) Navigator.of(dlgCtx).pop();
              }
            },
            child: const Text('Add Fee'),
          ),
        ],
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  final FeeRecordModel fee;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onPrintReceipt;
  const _FeeRow({
    required this.fee,
    required this.onToggle,
    required this.onEdit,
    required this.onPrintReceipt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(fee.isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
              color: fee.isPaid ? AppTheme.successGreen : AppTheme.textLight, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(fee.feeTypeName, style: AppTheme.bodyMedium)),
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Text('Rs. ${fee.amount.toInt()}',
                      style: AppTheme.labelMedium.copyWith(
                          color: fee.isPaid ? AppTheme.successGreen : AppTheme.textPrimary)),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_outlined, size: 14, color: AppTheme.navyBlue),
                ],
              ),
            ),
          ),
          if (fee.isPaid) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.receipt_long_rounded, size: 18, color: AppTheme.successGreen),
              tooltip: 'Print Official Receipt (PDF)',
              onPressed: onPrintReceipt,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: fee.isPaid ? AppTheme.errorRed.withOpacity(0.1) : AppTheme.navyBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                fee.isPaid ? 'Unpay' : 'Pay',
                style: AppTheme.bodySmall.copyWith(
                    color: fee.isPaid ? AppTheme.errorRed : AppTheme.white,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrearsDefaultersTab extends StatefulWidget {
  final int selectedMonth;
  final int selectedYear;
  final String selectedClass;
  final void Function(String) onClassChanged;

  const _ArrearsDefaultersTab({
    required this.selectedMonth,
    required this.selectedYear,
    required this.selectedClass,
    required this.onClassChanged,
  });

  @override
  State<_ArrearsDefaultersTab> createState() => _ArrearsDefaultersTabState();
}

class _ArrearsDefaultersTabState extends State<_ArrearsDefaultersTab> {
  List<Map<String, dynamic>> _defaulters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDefaulters();
  }

  @override
  void didUpdateWidget(covariant _ArrearsDefaultersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedClass != widget.selectedClass ||
        oldWidget.selectedMonth != widget.selectedMonth ||
        oldWidget.selectedYear != widget.selectedYear) {
      _loadDefaulters();
    }
  }

  Future<void> _loadDefaulters() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.getDefaulters(
      className: widget.selectedClass.isNotEmpty ? widget.selectedClass : null,
    );
    if (mounted) {
      setState(() {
        _defaulters = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendWhatsAppReminder(Map<String, dynamic> item) async {
    final sName = item['name'] ?? 'Student';
    final cls = item['class_name'] ?? 'Class';
    final due = (item['total_due'] as num?)?.toDouble() ?? 0.0;
    final phone = item['whatsapp_number'] ?? item['phone'];
    final monthName = FeeTypeModel.months[widget.selectedMonth - 1];

    final message =
        'محترم والدین، السلام علیکم!\n'
        'سبلائم گرامر اسکول (Sublime Grammar School) کی جانب سے مطلع کیا جاتا ہے کہ آپ کے بچے $sName (جماعت $cls) کے اسکول فیس واجبات بقایا ہیں:\n\n'
        '💰 کل واجب الادا رقم: Rs. ${due.toInt()} PKR\n'
        '📅 فیس کا مہینہ: $monthName ${widget.selectedYear}\n\n'
        'برائے مہربانی اسکول اکاؤنٹ یا کیش کاؤنٹر پر فیس جمع کروا کر چالان اسکول دفتر جمع کروائیں۔\n\n'
        'شکریہ، انتظامیہ سبلائم گرامر اسکول';

    await WhatsAppService.showShareDialog(
      context: context,
      title: 'Fee Reminder - $sName',
      subtitle: 'Class: $cls • Due: Rs. ${due.toInt()} PKR ($monthName)',
      message: message,
      initialPhone: phone?.toString(),
    );
  }

  Future<void> _printChallan(Map<String, dynamic> item) async {
    final sId = item['student_id'] as int;
    final students = context.read<StudentProvider>().students;
    final student = students.firstWhere(
      (s) => s.id == sId,
      orElse: () => StudentModel(
        id: sId,
        name: item['name'] ?? 'Student',
        fatherName: item['father_name'] ?? '',
        className: item['class_name'] ?? 'Class 5',
        section: item['section'] ?? 'A',
        rollNumber: item['roll_number'] ?? '01',
      ),
    );

    final unpaidFees = await DatabaseHelper.instance.getUnpaidFeesByStudent(sId);
    await FeePdfService.print3CopyChallan(
      context: context,
      student: student,
      month: widget.selectedMonth,
      year: widget.selectedYear,
      fees: unpaidFees,
    );
  }

  Future<void> _markPaid(Map<String, dynamic> item) async {
    final sId = item['student_id'] as int;
    final unpaidFees = await DatabaseHelper.instance.getUnpaidFeesByStudent(sId);
    for (final f in unpaidFees) {
      await context.read<FeeProvider>().markAsPaid(f);
    }
    await _loadDefaulters();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Cleared dues of Rs. ${(item['total_due'] as num?)?.toInt() ?? 0} for ${item['name']}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDefaulters = _defaulters.length;
    final totalOutstanding = _defaulters.fold<double>(
      0.0,
      (sum, item) => sum + ((item['total_due'] as num?)?.toDouble() ?? 0.0),
    );

    return Column(
      children: [
        // Class Filter & Summary Bar
        Container(
          color: AppTheme.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: widget.selectedClass.isEmpty ? '' : widget.selectedClass,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Filter by Class',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('All Classes')),
                        ...StudentModel.classes.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                      ],
                      onChanged: (c) {
                        widget.onClassChanged(c ?? '');
                        _loadDefaulters();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppTheme.navyBlue),
                    tooltip: 'Refresh List',
                    onPressed: _loadDefaulters,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Defaulters Count', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          Text(
                            '$totalDefaulters Students',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.errorRed),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.navyBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Overdue Dues', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          Text(
                            'Rs. ${totalOutstanding.toInt()} PKR',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _defaulters.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 48, color: AppTheme.successGreen),
                          const SizedBox(height: 10),
                          Text('No Unpaid Arrears / Defaulters!', style: AppTheme.headingSmall),
                          const SizedBox(height: 4),
                          const Text('All students in this selection have cleared their fees.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _defaulters.length,
                      itemBuilder: (ctx, i) {
                        final item = _defaulters[i];
                        final name = item['name'] ?? 'Student';
                        final father = item['father_name'] ?? '';
                        final cls = item['class_name'] ?? '';
                        final roll = item['roll_number'] ?? '';
                        final due = (item['total_due'] as num?)?.toDouble() ?? 0.0;
                        final count = (item['unpaid_count'] as num?)?.toInt() ?? 1;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: AppTheme.cardShadowList,
                            border: const Border(
                              left: BorderSide(color: AppTheme.errorRed, width: 4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppTheme.errorRed.withValues(alpha: 0.12),
                                    child: Text(
                                      name.isNotEmpty ? name[0] : 'S',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorRed),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: AppTheme.labelMedium),
                                        Text('Father: $father • $cls (Roll $roll)', style: AppTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Rs. ${due.toInt()}',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.errorRed),
                                      ),
                                      Text('$count pending item(s)', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.print_rounded, size: 15),
                                    label: const Text('Challan', style: TextStyle(fontSize: 11)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.navyBlue,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: const Size(0, 32),
                                    ),
                                    onPressed: () => _printChallan(item),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.message_rounded, size: 15),
                                    label: const Text('WhatsApp', style: TextStyle(fontSize: 11)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.successGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: const Size(0, 32),
                                    ),
                                    onPressed: () => _sendWhatsAppReminder(item),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.check_rounded, size: 15),
                                    label: const Text('Collect', style: TextStyle(fontSize: 11)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.navyBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: const Size(0, 32),
                                    ),
                                    onPressed: () => _markPaid(item),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _FeeSummaryTab extends StatefulWidget {
  final int year;
  const _FeeSummaryTab({required this.year});

  @override
  State<_FeeSummaryTab> createState() => _FeeSummaryTabState();
}

class _FeeSummaryTabState extends State<_FeeSummaryTab> {
  double _collected = 0;
  double _pending = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _collected = await DatabaseHelper.instance.getTotalFeeCollected(widget.year);
    _pending = await DatabaseHelper.instance.getTotalFeePending(widget.year);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final total = _collected + _pending;
    final pct = total > 0 ? (_collected / total * 100) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Fee collection progress
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.navyGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text('Fee Collection ${widget.year}',
                    style: AppTheme.bodyLarge.copyWith(color: AppTheme.white.withOpacity(0.85))),
                const SizedBox(height: 20),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 14,
                        backgroundColor: AppTheme.white.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGold),
                      ),
                    ),
                    Column(
                      children: [
                        Text('${pct.toStringAsFixed(1)}%',
                            style: AppTheme.headingLarge.copyWith(color: AppTheme.white, fontSize: 28)),
                        Text('collected', style: AppTheme.bodySmall.copyWith(color: AppTheme.white.withOpacity(0.7))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryItem('Collected', 'Rs. ${NumberFormat("#,##0").format(_collected.toInt())}', AppTheme.successGreen),
                    _SummaryItem('Pending Dues', 'Rs. ${NumberFormat("#,##0").format(_pending.toInt())}', AppTheme.errorRed),
                    _SummaryItem('Billed Dues', 'Rs. ${NumberFormat("#,##0").format(total.toInt())}', AppTheme.accentGold),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Fee types breakdown
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadowList,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fee Types', style: AppTheme.headingSmall),
                const SizedBox(height: 14),
                ...context.watch<FeeProvider>().feeTypes.map((ft) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: AppTheme.navyBlue),
                      const SizedBox(width: 10),
                      Expanded(child: Text(ft.name, style: AppTheme.bodyMedium)),
                      Text('Rs. ${ft.defaultAmount.toInt()}/month',
                          style: AppTheme.labelMedium.copyWith(color: AppTheme.navyBlue)),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryItem(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
        Text(label, style: AppTheme.bodySmall.copyWith(color: AppTheme.white.withOpacity(0.7))),
      ],
    );
  }
}
