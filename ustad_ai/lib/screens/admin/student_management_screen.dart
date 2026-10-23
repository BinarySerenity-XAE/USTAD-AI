// lib/screens/admin/student_management_screen.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';
import '../../providers/student_provider.dart';
import '../../models/student_model.dart';
import '../../models/fee_model.dart';
import '../../database/db_helper.dart';
import '../../providers/fee_provider.dart';
import '../../widgets/custom_text_field.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _selectedClass = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Student Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import Excel / CSV',
            onPressed: () => _showImportInstructionsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Add Single Student',
            onPressed: () => _showAddStudentDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.white,
          labelColor: AppTheme.white,
          unselectedLabelColor: AppTheme.white.withOpacity(0.6),
          tabs: const [
            Tab(text: 'All Students'),
            Tab(text: 'Families'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _StudentsTab(searchCtrl: _searchCtrl, selectedClass: _selectedClass,
              onClassChanged: (c) => setState(() => _selectedClass = c)),
          _FamiliesTab(),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddStudentDialog(context),
          icon: const Icon(Icons.person_add_rounded),
          label: const Text('Add Student'),
        ),
      ),
    );
  }

  void _showImportInstructionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.navyBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.file_upload_outlined, color: AppTheme.navyBlue),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Bulk Import Students',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload an Excel (.xlsx) or CSV (.csv) file with your school roster to instantly import all students into the database.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.offWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Supported Columns (any order):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyBlue),
                  ),
                  SizedBox(height: 6),
                  Text('• Student Name / Full Name', style: TextStyle(fontSize: 12)),
                  Text('• Father Name', style: TextStyle(fontSize: 12)),
                  Text('• Current Class (e.g. PG, Nursery, KG, Class 1-10)', style: TextStyle(fontSize: 12)),
                  Text('• Section (e.g. A, B)', style: TextStyle(fontSize: 12)),
                  Text('• Phone / Mobile / WhatsApp', style: TextStyle(fontSize: 12)),
                  Text('• Roll Number (optional)', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Fully compatible with Sublime Grammar School master files & custom sheets.',
                    style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.navyBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: const Text('Select Spreadsheet File'),
            onPressed: () {
              Navigator.pop(ctx);
              _importStudents(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _importStudents(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final path = file.path;
    if (path == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Reading and importing student spreadsheet...'),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );

    try {
      final ext = path.split('.').last.toLowerCase();
      final students = <StudentModel>[];

      if (ext == 'xlsx' || ext == 'xls') {
        Uint8List bytes = await File(path).readAsBytes();

        // Sanitize styles.xml in zip to prevent custom numFmtId < 164 parser exceptions
        try {
          final archive = ZipDecoder().decodeBytes(bytes);
          final newArchive = Archive();
          bool modified = false;
          for (final f in archive) {
            if (f.name == 'xl/styles.xml') {
              var content = utf8.decode(f.content as List<int>, allowMalformed: true);
              if (content.contains('numFmts')) {
                content = content.replaceAll(RegExp(r'<numFmts[^>]*>.*?</numFmts>'), '<numFmts count="0"/>');
                final newContent = utf8.encode(content);
                newArchive.addFile(ArchiveFile(f.name, newContent.length, newContent));
                modified = true;
                continue;
              }
            }
            newArchive.addFile(f);
          }
          if (modified) {
            final encoded = ZipEncoder().encode(newArchive);
            if (encoded != null) bytes = Uint8List.fromList(encoded);
          }
        } catch (_) {}

        final excel = Excel.decodeBytes(bytes);

        // Pick the best sheet (prefers sheet containing 'student' or 'master', else sheet with most rows)
        Sheet? targetSheet;
        for (final key in excel.tables.keys) {
          final lk = key.toLowerCase();
          if (lk.contains('student') || lk.contains('master')) {
            targetSheet = excel.tables[key];
            break;
          }
        }
        if (targetSheet == null) {
          int maxRows = -1;
          for (final table in excel.tables.values) {
            if (table.maxRows > maxRows) {
              maxRows = table.maxRows;
              targetSheet = table;
            }
          }
        }

        if (targetSheet != null && targetSheet.maxRows > 0) {
          // Identify headers
          int nameIdx = 0;
          int fatherIdx = 1;
          int classIdx = 2;
          int sectionIdx = -1;
          int phoneIdx = 3;
          int whatsappIdx = -1;
          int rollIdx = -1;
          int startRow = 0;

          // Search first 5 rows for header keywords
          for (int r = 0; r < targetSheet.maxRows && r < 5; r++) {
            final row = targetSheet.rows[r];
            final rowTexts = row.map((c) => c?.value?.toString().trim().toLowerCase() ?? '').toList();
            final hasName = rowTexts.any((t) => t.contains('name'));
            final hasClass = rowTexts.any((t) => t.contains('class') || t.contains('grade'));
            if (hasName && (hasClass || rowTexts.any((t) => t.contains('father')))) {
              startRow = r + 1;
              for (int c = 0; c < rowTexts.length; c++) {
                final h = rowTexts[c];
                if ((h.contains('student') && h.contains('name')) || h == 'name' || h == 'student full name' || h == 'full name') {
                  nameIdx = c;
                } else if (h.contains('father') || h.contains('guardian')) {
                  fatherIdx = c;
                } else if (h.contains('class') || h.contains('grade')) {
                  classIdx = c;
                } else if (h.contains('section')) {
                  sectionIdx = c;
                } else if (h.contains('whatsapp')) {
                  whatsappIdx = c;
                } else if (h.contains('mobile') || h.contains('phone') || h.contains('contact')) {
                  if (phoneIdx == 3) phoneIdx = c;
                } else if (h.contains('roll') || h.contains('admission')) {
                  rollIdx = c;
                }
              }
              break;
            }
          }

          for (int r = startRow; r < targetSheet.maxRows; r++) {
            final row = targetSheet.rows[r];
            if (row.isEmpty) continue;
            String getCell(int idx) {
              if (idx < 0 || idx >= row.length) return '';
              return row[idx]?.value?.toString().trim() ?? '';
            }

            final name = getCell(nameIdx);
            if (name.isEmpty || name.toLowerCase() == 'student name' || name.toLowerCase() == 'name') continue;

            final father = getCell(fatherIdx);
            final rawClass = getCell(classIdx);
            final rawSection = sectionIdx >= 0 ? getCell(sectionIdx) : 'A';
            final phone = getCell(phoneIdx);
            final whatsapp = whatsappIdx >= 0 ? getCell(whatsappIdx) : phone;
            final roll = rollIdx >= 0 ? getCell(rollIdx) : null;

            students.add(StudentModel(
              name: name,
              fatherName: father.isNotEmpty ? father : 'N/A',
              className: _cleanClassName(rawClass),
              section: _cleanSection(rawSection),
              phone: phone.isNotEmpty ? phone : null,
              whatsappNumber: whatsapp.isNotEmpty ? whatsapp : (phone.isNotEmpty ? phone : null),
              rollNumber: roll != null && roll.isNotEmpty ? roll : null,
            ));
          }
        }
      } else {
        // CSV / Plain text file
        final content = await File(path).readAsString();
        final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
        final startIdx = lines.first.toLowerCase().contains('name') ? 1 : 0;

        for (int i = startIdx; i < lines.length; i++) {
          final cols = lines[i].split(',').map((c) => c.trim().replaceAll('"', '')).toList();
          if (cols.length < 2) continue;
          final name = cols[0];
          if (name.isEmpty) continue;
          final father = cols.length > 1 ? cols[1] : 'N/A';
          final rawClass = cols.length > 2 ? cols[2] : 'Class 1';
          final phone = cols.length > 3 ? cols[3] : null;

          students.add(StudentModel(
            name: name,
            fatherName: father,
            className: _cleanClassName(rawClass),
            section: 'A',
            phone: phone,
            whatsappNumber: phone,
          ));
        }
      }

      if (students.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No student rows found in the selected file.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        return;
      }

      if (!mounted) return;
      final count = await context.read<StudentProvider>().bulkImport(students);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Successfully imported $count students into the database!'),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  String _cleanClassName(String raw) {
    final clean = raw.trim();
    final lower = clean.toLowerCase();
    if (lower.contains('play') || lower == 'pg') return 'PG';
    if (lower.contains('nursery')) return 'Nursery';
    if (lower.contains('kg') || lower.contains('kindergarten')) return 'KG';
    for (int i = 1; i <= 10; i++) {
      if (lower == '$i' || lower == 'class $i' || lower == 'grade $i') {
        return 'Class $i';
      }
    }
    return clean.isNotEmpty ? clean : 'Class 1';
  }

  String _cleanSection(String raw) {
    final s = raw.trim().toUpperCase();
    if (s.isEmpty) return 'A';
    if (s.length == 1 && RegExp(r'[A-Z]').hasMatch(s)) return s;
    return 'A';
  }

  void _showAddStudentDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddStudentSheet(),
    );
  }
}

class _StudentsTab extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String selectedClass;
  final void Function(String) onClassChanged;

  const _StudentsTab({
    required this.searchCtrl,
    required this.selectedClass,
    required this.onClassChanged,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentProvider>();

    return Column(
      children: [
        // Search + Filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search students...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: AppTheme.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.navyBlue, width: 2),
                    ),
                  ),
                  onChanged: provider.setSearchQuery,
                ),
              ),
              const SizedBox(width: 10),
              _ClassFilterButton(
                selectedClass: selectedClass,
                onChanged: (c) {
                  onClassChanged(c);
                  provider.setClassFilter(c);
                },
              ),
            ],
          ),
        ),

        // Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${provider.students.length} students',
                style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600),
              ),
              if (selectedClass.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    onClassChanged('');
                    provider.clearFilters();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.navyBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(selectedClass, style: AppTheme.bodySmall.copyWith(color: AppTheme.navyBlue)),
                        const SizedBox(width: 4),
                        const Icon(Icons.close, size: 12, color: AppTheme.navyBlue),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // List
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.students.isEmpty
                  ? _EmptyState(
                      icon: Icons.people_outline,
                      title: 'No students found',
                      subtitle: 'Add students using the + button or import a CSV file',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: provider.students.length,
                      itemBuilder: (_, i) => _StudentCard(student: provider.students[i]),
                    ),
        ),
      ],
    );
  }
}

class _ClassFilterButton extends StatelessWidget {
  final String selectedClass;
  final void Function(String) onChanged;

  const _ClassFilterButton({required this.selectedClass, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final selected = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Filter by Class', style: AppTheme.headingSmall),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SizedBox(
              width: double.maxFinite,
              height: 350,
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('All Classes'),
                    onTap: () => Navigator.pop(context, ''),
                    trailing: selectedClass.isEmpty
                        ? const Icon(Icons.check, color: AppTheme.navyBlue)
                        : null,
                  ),
                  const Divider(),
                  ...StudentModel.classes.map((c) => ListTile(
                        title: Text(c),
                        onTap: () => Navigator.pop(context, c),
                        trailing: selectedClass == c
                            ? const Icon(Icons.check, color: AppTheme.navyBlue)
                            : null,
                      )),
                ],
              ),
            ),
          ),
        );
        if (selected != null) onChanged(selected);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selectedClass.isNotEmpty ? AppTheme.navyBlue : AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Icon(
          Icons.filter_list_rounded,
          color: selectedClass.isNotEmpty ? AppTheme.white : AppTheme.textSecondary,
          size: 20,
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final StudentModel student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadowList,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppTheme.navyGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              student.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        ),
        title: Text(student.name, style: AppTheme.labelMedium),
        subtitle: Text(
          '${student.className} • ${student.fatherName}',
          style: AppTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.lightBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(student.className,
                  style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.navyBlue, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
              onSelected: (v) {
                if (v == 'edit') _showEditDialog(context, student);
                if (v == 'delete') _confirmDelete(context, student);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: AppTheme.errorRed), const SizedBox(width: 8), Text('Remove', style: TextStyle(color: AppTheme.errorRed))])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, StudentModel student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddStudentSheet(student: student),
    );
  }

  void _confirmDelete(BuildContext context, StudentModel student) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${student.name}?', style: AppTheme.headingSmall),
        content: const Text('This will archive the student. Their records will be preserved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<StudentProvider>().deleteStudent(student.id!);
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
  }
}

class _FamiliesTab extends StatelessWidget {
  const _FamiliesTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentProvider>();
    final families = provider.families;

    return families.isEmpty
        ? _EmptyState(
            icon: Icons.family_restroom,
            title: 'No families linked',
            subtitle: 'Link siblings when adding students',
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: families.length,
            itemBuilder: (_, i) {
              final fam = families[i];
              final children = provider.getStudentsInFamily(fam.id!);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.cardShadowList,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.family_restroom, color: AppTheme.navyBlue),
                        const SizedBox(width: 10),
                        Expanded(child: Text(fam.parentName, style: AppTheme.labelMedium)),
                        if (fam.phone != null)
                          Text(fam.phone!, style: AppTheme.bodySmall),
                      ],
                    ),
                    if (children.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 6),
                      ...children.map((s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                const Icon(Icons.person, size: 16, color: AppTheme.textSecondary),
                                const SizedBox(width: 8),
                                Text(s.name, style: AppTheme.bodyMedium),
                                const Spacer(),
                                Text(s.className,
                                    style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.navyBlue, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              );
            },
          );
  }
}

class _AddStudentSheet extends StatefulWidget {
  final StudentModel? student;
  const _AddStudentSheet({this.student});

  @override
  State<_AddStudentSheet> createState() => _AddStudentSheetState();
}

class _AddStudentSheetState extends State<_AddStudentSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _fatherCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _whatsappCtrl;
  String _selectedClass = 'Class 1';
  String _section = 'A';
  bool _linkFamily = false;
  late TextEditingController _familyParentCtrl;
  late TextEditingController _familyPhoneCtrl;

  // Fee setup fields (for new student)
  late TextEditingController _tuitionCtrl;
  bool _includeUniform = false;
  late TextEditingController _uniformCtrl;
  String _uniformFreq = 'once'; // 'once' or 'monthly'

  bool _includeAccessories = false;
  late TextEditingController _accessoriesCtrl;
  String _accessoriesFreq = 'once'; // 'once' or 'monthly'

  bool _includeAdmission = true;
  late TextEditingController _admissionCtrl;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _fatherCtrl = TextEditingController(text: s?.fatherName ?? '');
    _phoneCtrl = TextEditingController(text: s?.phone ?? '');
    _whatsappCtrl = TextEditingController(text: s?.whatsappNumber ?? '');
    _selectedClass = s?.className ?? 'Class 1';
    _section = s?.section ?? 'A';
    _familyParentCtrl = TextEditingController();
    _familyPhoneCtrl = TextEditingController();

    _tuitionCtrl = TextEditingController(text: '3500');
    _uniformCtrl = TextEditingController(text: '1500');
    _accessoriesCtrl = TextEditingController(text: '1200');
    _admissionCtrl = TextEditingController(text: '2000');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fatherCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _familyParentCtrl.dispose();
    _familyPhoneCtrl.dispose();

    _tuitionCtrl.dispose();
    _uniformCtrl.dispose();
    _accessoriesCtrl.dispose();
    _admissionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<StudentProvider>();

    int? familyId = widget.student?.familyId;
    if (_linkFamily && _familyParentCtrl.text.isNotEmpty) {
      familyId = await provider.addFamily(FamilyModel(
        parentName: _familyParentCtrl.text.trim(),
        phone: _familyPhoneCtrl.text.trim().isNotEmpty ? _familyPhoneCtrl.text.trim() : null,
        whatsappNumber: _familyPhoneCtrl.text.trim().isNotEmpty ? _familyPhoneCtrl.text.trim() : null,
      ));
    }

    final student = StudentModel(
      id: widget.student?.id,
      name: _nameCtrl.text.trim(),
      fatherName: _fatherCtrl.text.trim(),
      className: _selectedClass,
      section: _section,
      phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
      whatsappNumber: _whatsappCtrl.text.trim().isNotEmpty ? _whatsappCtrl.text.trim() : null,
      familyId: familyId,
    );

    if (widget.student == null) {
      final studentId = await provider.addStudent(student);

      // Auto-configure initial fees
      final now = DateTime.now();
      final curMonth = now.month;
      final curYear = now.year;

      final existingTypes = await DatabaseHelper.instance.getAllFeeTypes();

      Future<FeeTypeModel> ensureType(String name, double defaultAmt) async {
        final match = existingTypes.where((t) => t.name.toLowerCase() == name.toLowerCase()).firstOrNull;
        if (match != null) return match;
        final id = await DatabaseHelper.instance.insertFeeType(FeeTypeModel(name: name, defaultAmount: defaultAmt));
        return FeeTypeModel(id: id, name: name, defaultAmount: defaultAmt);
      }

      final tuitionType = await ensureType('Tuition Fee', 3500.0);
      final uniformType = await ensureType('Uniform Fee', 1500.0);
      final accType = await ensureType('Accessories & Books', 1200.0);
      final admType = await ensureType('Admission Fee', 2000.0);

      // 1. Tuition Fee (Monthly from curMonth to 12)
      final tuitionAmount = double.tryParse(_tuitionCtrl.text.trim()) ?? 3500.0;
      if (tuitionAmount > 0) {
        for (int m = curMonth; m <= 12; m++) {
          await DatabaseHelper.instance.insertFeeRecord(FeeRecordModel(
            studentId: studentId,
            feeTypeId: tuitionType.id!,
            feeTypeName: tuitionType.name,
            month: m,
            year: curYear,
            amount: tuitionAmount,
            isPaid: false,
          ));
        }
      }

      // 2. Uniform Fee
      if (_includeUniform) {
        final uniformAmt = double.tryParse(_uniformCtrl.text.trim()) ?? 1500.0;
        if (uniformAmt > 0) {
          if (_uniformFreq == 'once') {
            await DatabaseHelper.instance.insertFeeRecord(FeeRecordModel(
              studentId: studentId,
              feeTypeId: uniformType.id!,
              feeTypeName: uniformType.name,
              month: curMonth,
              year: curYear,
              amount: uniformAmt,
              isPaid: false,
              notes: 'One-time Uniform Charge',
            ));
          } else {
            for (int m = curMonth; m <= 12; m++) {
              await DatabaseHelper.instance.insertFeeRecord(FeeRecordModel(
                studentId: studentId,
                feeTypeId: uniformType.id!,
                feeTypeName: uniformType.name,
                month: m,
                year: curYear,
                amount: uniformAmt,
                isPaid: false,
                notes: 'Monthly Uniform Fee',
              ));
            }
          }
        }
      }

      // 3. Accessories & Books Fee
      if (_includeAccessories) {
        final accAmt = double.tryParse(_accessoriesCtrl.text.trim()) ?? 1200.0;
        if (accAmt > 0) {
          if (_accessoriesFreq == 'once') {
            await DatabaseHelper.instance.insertFeeRecord(FeeRecordModel(
              studentId: studentId,
              feeTypeId: accType.id!,
              feeTypeName: accType.name,
              month: curMonth,
              year: curYear,
              amount: accAmt,
              isPaid: false,
              notes: 'One-time Accessories Charge',
            ));
          } else {
            for (int m = curMonth; m <= 12; m++) {
              await DatabaseHelper.instance.insertFeeRecord(FeeRecordModel(
                studentId: studentId,
                feeTypeId: accType.id!,
                feeTypeName: accType.name,
                month: m,
                year: curYear,
                amount: accAmt,
                isPaid: false,
                notes: 'Monthly Accessories Fee',
              ));
            }
          }
        }
      }

      // 4. Admission Fee (One-time)
      if (_includeAdmission) {
        final admAmt = double.tryParse(_admissionCtrl.text.trim()) ?? 2000.0;
        if (admAmt > 0) {
          await DatabaseHelper.instance.insertFeeRecord(FeeRecordModel(
            studentId: studentId,
            feeTypeId: admType.id!,
            feeTypeName: admType.name,
            month: curMonth,
            year: curYear,
            amount: admAmt,
            isPaid: false,
            notes: 'One-time Admission Fee',
          ));
        }
      }

      try {
        await context.read<FeeProvider>().loadFeeTypes();
      } catch (_) {}
    } else {
      await provider.updateStudent(student);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.borderColor, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(widget.student == null ? 'Add New Student' : 'Edit Student',
                  style: AppTheme.headingSmall),
              const SizedBox(height: 20),
              CustomTextField(controller: _nameCtrl, label: 'Student Name', prefixIcon: Icons.person,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 14),
              CustomTextField(controller: _fatherCtrl, label: 'Father\'s Name', prefixIcon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _buildDropdown('Class', StudentModel.classes, _selectedClass, (v) => setState(() => _selectedClass = v!))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDropdown('Section', StudentModel.sections, _section, (v) => setState(() => _section = v!))),
                ],
              ),
              const SizedBox(height: 14),
              CustomTextField(controller: _phoneCtrl, label: 'Phone (optional)', prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              CustomTextField(controller: _whatsappCtrl, label: 'WhatsApp Number (optional)', prefixIcon: Icons.message,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _linkFamily,
                    onChanged: (v) => setState(() => _linkFamily = v ?? false),
                    activeColor: AppTheme.navyBlue,
                  ),
                  Text('Link to a Family / Sibling Group', style: AppTheme.bodyMedium),
                ],
              ),
              if (_linkFamily) ...[
                const SizedBox(height: 10),
                CustomTextField(controller: _familyParentCtrl, label: 'Parent Name', prefixIcon: Icons.family_restroom,
                    textCapitalization: TextCapitalization.words),
                const SizedBox(height: 10),
                CustomTextField(controller: _familyPhoneCtrl, label: 'Parent WhatsApp', prefixIcon: Icons.phone,
                    keyboardType: TextInputType.phone),
              ],

              // Initial Fee Setup (When adding new student)
              if (widget.student == null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.lightBlue.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.navyBlue.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.navyBlue, size: 20),
                          const SizedBox(width: 8),
                          Text('Fee Setup & Custom Charges', style: AppTheme.labelMedium),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Tuition Fee
                      CustomTextField(
                        controller: _tuitionCtrl,
                        label: 'Monthly Tuition Fee (Rs.)',
                        prefixIcon: Icons.payments_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 14),
                      // Uniform Fee
                      _buildFeeOptionRow(
                        title: 'Uniform Fee',
                        enabled: _includeUniform,
                        onToggle: (v) => setState(() => _includeUniform = v),
                        amountCtrl: _uniformCtrl,
                        freq: _uniformFreq,
                        onFreqChanged: (f) => setState(() => _uniformFreq = f),
                      ),
                      const SizedBox(height: 12),
                      // Accessories Fee
                      _buildFeeOptionRow(
                        title: 'Accessories & Books',
                        enabled: _includeAccessories,
                        onToggle: (v) => setState(() => _includeAccessories = v),
                        amountCtrl: _accessoriesCtrl,
                        freq: _accessoriesFreq,
                        onFreqChanged: (f) => setState(() => _accessoriesFreq = f),
                      ),
                      const SizedBox(height: 12),
                      // Admission Fee
                      Row(
                        children: [
                          Checkbox(
                            value: _includeAdmission,
                            onChanged: (v) => setState(() => _includeAdmission = v ?? false),
                            activeColor: AppTheme.navyBlue,
                          ),
                          const Expanded(
                            child: Text('Admission Fee (One-Time)',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          if (_includeAdmission)
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _admissionCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  prefixText: 'Rs. ',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                child: Text(widget.student == null ? 'Add Student' : 'Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeeOptionRow({
    required String title,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required TextEditingController amountCtrl,
    required String freq,
    required ValueChanged<String> onFreqChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: enabled,
                onChanged: (v) => onToggle(v ?? false),
                activeColor: AppTheme.navyBlue,
              ),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              if (enabled)
                SizedBox(
                  width: 95,
                  child: TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      prefixText: 'Rs. ',
                    ),
                  ),
                ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Row(
                children: [
                  const Text('Billing: ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ChoiceChip(
                    label: const Text('Charge Once', style: TextStyle(fontSize: 11)),
                    selected: freq == 'once',
                    selectedColor: AppTheme.navyBlue,
                    labelStyle: TextStyle(color: freq == 'once' ? AppTheme.white : AppTheme.textPrimary),
                    onSelected: (_) => onFreqChanged('once'),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Monthly Recurring', style: TextStyle(fontSize: 11)),
                    selected: freq == 'monthly',
                    selectedColor: AppTheme.navyBlue,
                    labelStyle: TextStyle(color: freq == 'monthly' ? AppTheme.white : AppTheme.textPrimary),
                    onSelected: (_) => onFreqChanged('monthly'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.navyBlue, width: 2)),
      ),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: AppTheme.bodyMedium))).toList(),
      onChanged: onChanged,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: AppTheme.textLight),
            const SizedBox(height: 16),
            Text(title, style: AppTheme.headingSmall.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text(subtitle, style: AppTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
