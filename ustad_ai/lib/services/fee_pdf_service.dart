// lib/services/fee_pdf_service.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/student_model.dart';
import '../models/fee_model.dart';
import '../utils/pdf_fonts.dart';
import '../database/db_helper.dart';

class FeePdfService {
  static const String schoolName = 'SUBLIME GRAMMAR SCHOOL';
  static const String schoolCampus = 'Main Campus, Gujranwala • Ph: 0322-7486000';
  static const double lateSurcharge = 200.0;

  /// Print a standard 3-Copy Bank/School Fee Challan on A4 Landscape
  static Future<void> print3CopyChallan({
    required BuildContext context,
    required StudentModel student,
    required int month,
    required int year,
    required List<FeeRecordModel> fees,
    double arrears = 0.0,
  }) async {
    await PdfFonts.ensureLoaded();
    final pdf = pw.Document();
    final monthName = FeeTypeModel.months[month - 1];
    final totalTuition = fees.fold<double>(0.0, (s, f) => s + f.amount);
    final grandTotal = totalTuition + arrears;
    final afterDueTotal = grandTotal + lateSurcharge;

    final challanNo = 'CHL-$year-${(student.id ?? 1).toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final issueDate = '01 $monthName $year';
    final dueDate = '10 $monthName $year';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(16),
        theme: PdfFonts.theme,
        build: (pw.Context ctx) {
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(
                child: _buildChallanCopy(
                  copyTitle: 'BANK / ACCOUNTS COPY',
                  badgeColor: PdfColors.blue800,
                  student: student,
                  challanNo: challanNo,
                  issueDate: issueDate,
                  dueDate: dueDate,
                  monthName: monthName,
                  year: year,
                  fees: fees,
                  arrears: arrears,
                  grandTotal: grandTotal,
                  afterDueTotal: afterDueTotal,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.VerticalDivider(borderStyle: pw.BorderStyle.dashed, color: PdfColors.grey500),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildChallanCopy(
                  copyTitle: 'SCHOOL OFFICE COPY',
                  badgeColor: PdfColors.purple800,
                  student: student,
                  challanNo: challanNo,
                  issueDate: issueDate,
                  dueDate: dueDate,
                  monthName: monthName,
                  year: year,
                  fees: fees,
                  arrears: arrears,
                  grandTotal: grandTotal,
                  afterDueTotal: afterDueTotal,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.VerticalDivider(borderStyle: pw.BorderStyle.dashed, color: PdfColors.grey500),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildChallanCopy(
                  copyTitle: 'STUDENT / PARENT COPY',
                  badgeColor: PdfColors.green800,
                  student: student,
                  challanNo: challanNo,
                  issueDate: issueDate,
                  dueDate: dueDate,
                  monthName: monthName,
                  year: year,
                  fees: fees,
                  arrears: arrears,
                  grandTotal: grandTotal,
                  afterDueTotal: afterDueTotal,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Fee_Challan_${student.name.replaceAll(' ', '_')}_$monthName.pdf',
    );
  }

  /// Print an Official Payment Receipt on A5
  static Future<void> printPaymentReceipt({
    required BuildContext context,
    required StudentModel student,
    required FeeRecordModel fee,
  }) async {
    await PdfFonts.ensureLoaded();
    final pdf = pw.Document();
    final monthName = FeeTypeModel.months[fee.month - 1];
    final receiptNo = 'REC-${fee.year}-${(fee.id ?? 1).toString().padLeft(4, '0')}';
    final dateStr = DateFormat('dd MMMM yyyy').format(fee.paidDate ?? DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(20),
        theme: PdfFonts.theme,
        build: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey800, width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        schoolName,
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(schoolCampus, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green700,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'OFFICIAL FEE PAYMENT RECEIPT',
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Meta Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Receipt No: $receiptNo', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Divider(color: PdfColors.grey400, thickness: 1),
                pw.SizedBox(height: 6),

                // Details
                _buildReceiptRow('Student Full Name:', student.name),
                _buildReceiptRow('Father / Guardian:', student.fatherName),
                _buildReceiptRow('Class & Section:', '${student.className} (Sec ${student.section})'),
                _buildReceiptRow('Roll Number:', student.rollNumber ?? ''),
                _buildReceiptRow('Fee Description:', '${fee.feeTypeName} ($monthName ${fee.year})'),
                _buildReceiptRow('Payment Method:', 'Cash / School Accounts Counter'),
                _buildReceiptRow('Status:', 'PAID IN FULL ✓'),

                pw.SizedBox(height: 12),

                // Amount Callout
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total Amount Received:',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                      pw.Text(
                        'Rs. ${fee.amount.toInt()}/- PKR',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                // Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.green700, width: 1.5),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'OFFICIAL STAMP\nRECEIVED WITH THANKS',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                      ),
                    ),
                    pw.Column(
                      children: [
                        pw.Text('________________________', style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 3),
                        pw.Text('Authorized Accounts Officer', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Fee_Receipt_${student.name.replaceAll(' ', '_')}_$monthName.pdf',
    );
  }

  /// Batch Print All Fee Challans for an Entire Class on A4 Landscape
  static Future<void> printBatchClassChallans({
    required BuildContext context,
    required String className,
    required int month,
    required int year,
    required List<StudentModel> students,
  }) async {
    await PdfFonts.ensureLoaded();
    final pdf = pw.Document();
    final monthName = FeeTypeModel.months[month - 1];
    final allFeeTypes = await DatabaseHelper.instance.getAllFeeTypes();

    for (final student in students) {
      // Fetch or generate fees for this student
      final fees = await DatabaseHelper.instance.getFeesByStudentAndMonth(student.id!, month, year);
      List<FeeRecordModel> studentFees = fees;
      if (studentFees.isEmpty) {
        studentFees = allFeeTypes.map((ft) => FeeRecordModel(
          studentId: student.id!,
          feeTypeId: ft.id!,
          feeTypeName: ft.name,
          month: month,
          year: year,
          amount: ft.defaultAmount,
        )).toList();
      }

      final totalTuition = studentFees.fold<double>(0.0, (s, f) => s + f.amount);
      final grandTotal = totalTuition;
      final afterDueTotal = grandTotal + lateSurcharge;
      final challanNo = 'CHL-$year-${(student.id ?? 1).toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
      final issueDate = '01 $monthName $year';
      final dueDate = '10 $monthName $year';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          theme: PdfFonts.theme,
          build: (pw.Context ctx) {
            return pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  child: _buildChallanCopy(
                    copyTitle: 'BANK / ACCOUNTS COPY',
                    badgeColor: PdfColors.blue800,
                    student: student,
                    challanNo: challanNo,
                    issueDate: issueDate,
                    dueDate: dueDate,
                    monthName: monthName,
                    year: year,
                    fees: studentFees,
                    arrears: 0,
                    grandTotal: grandTotal,
                    afterDueTotal: afterDueTotal,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.VerticalDivider(borderStyle: pw.BorderStyle.dashed, color: PdfColors.grey500),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildChallanCopy(
                    copyTitle: 'SCHOOL OFFICE COPY',
                    badgeColor: PdfColors.purple800,
                    student: student,
                    challanNo: challanNo,
                    issueDate: issueDate,
                    dueDate: dueDate,
                    monthName: monthName,
                    year: year,
                    fees: studentFees,
                    arrears: 0,
                    grandTotal: grandTotal,
                    afterDueTotal: afterDueTotal,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.VerticalDivider(borderStyle: pw.BorderStyle.dashed, color: PdfColors.grey500),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildChallanCopy(
                    copyTitle: 'STUDENT / PARENT COPY',
                    badgeColor: PdfColors.green800,
                    student: student,
                    challanNo: challanNo,
                    issueDate: issueDate,
                    dueDate: dueDate,
                    monthName: monthName,
                    year: year,
                    fees: studentFees,
                    arrears: 0,
                    grandTotal: grandTotal,
                    afterDueTotal: afterDueTotal,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Class_${className.replaceAll(' ', '_')}_Challans_$monthName.pdf',
    );
  }

  static pw.Widget _buildChallanCopy({
    required String copyTitle,
    required PdfColor badgeColor,
    required StudentModel student,
    required String challanNo,
    required String issueDate,
    required String dueDate,
    required String monthName,
    required int year,
    required List<FeeRecordModel> fees,
    required double arrears,
    required double grandTotal,
    required double afterDueTotal,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  schoolName,
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  schoolCampus,
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: badgeColor,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    copyTitle,
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          // Challan Meta
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Challan: $challanNo', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
              pw.Text('Due: $dueDate', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
            ],
          ),
          pw.Text('Fee Month: $monthName $year', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),

          // Student Details Table
          _buildInfoRow('Student:', student.name),
          _buildInfoRow('Father:', student.fatherName),
          _buildInfoRow('Class / Sec:', '${student.className} - ${student.section}'),
          _buildInfoRow('Roll Number:', student.rollNumber ?? ''),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),

          // Particulars Header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            color: PdfColors.grey200,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Particulars', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                pw.Text('Amount (Rs.)', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 4),

          // Particular items
          ...fees.take(4).map((f) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(f.feeTypeName, style: const pw.TextStyle(fontSize: 7.5)),
                pw.Text('${f.amount.toInt()}', style: const pw.TextStyle(fontSize: 7.5)),
              ],
            ),
          )),
          if (arrears > 0)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 4),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Previous Arrears:', style: pw.TextStyle(fontSize: 7.5, color: PdfColors.red800)),
                  pw.Text('${arrears.toInt()}', style: pw.TextStyle(fontSize: 7.5, color: PdfColors.red800)),
                ],
              ),
            ),

          pw.Divider(color: PdfColors.grey300, thickness: 0.5),

          // Totals
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total by Due Date:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text('Rs. ${grandTotal.toInt()}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('After Due Date (+Rs.200):', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                pw.Text('Rs. ${afterDueTotal.toInt()}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.red800)),
              ],
            ),
          ),

          pw.Spacer(),

          // Instructions
          pw.Text(
            '• Deposit at school counter on or before 10th of every month.\n• Fee once paid is non-refundable.',
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 10),

          // Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  pw.Text('________________', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text('Cashier / Officer', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('________________', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text('Depositor Signature', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 52,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReceiptRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
          ),
        ],
      ),
    );
  }
}
