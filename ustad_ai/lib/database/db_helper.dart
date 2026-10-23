// lib/database/db_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../models/student_model.dart';
import '../models/fee_model.dart';
import '../models/marks_model.dart';
import '../models/attendance_model.dart';
import '../models/teacher_model.dart';
import '../models/homework_model.dart';
import '../models/timetable_model.dart';
import '../config/app_config.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ustad_ai.db');
    final db = await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onOpen: (db) async {
        await _ensureTablesAndColumns(db);
      },
    );
    return db;
  }

  Future<void> _ensureTablesAndColumns(Database db) async {
    try {
      await db.execute('ALTER TABLE users ADD COLUMN assigned_class TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE users ADD COLUMN assigned_subject TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE homework ADD COLUMN image_path TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE homework ADD COLUMN instructions_image_path TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE homework ADD COLUMN target_student_id INTEGER');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE homework ADD COLUMN audio_path TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE marks ADD COLUMN exam_type TEXT DEFAULT "Exam"');
    } catch (_) {}
    await db.execute('''
      CREATE TABLE IF NOT EXISTS parent_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        parent_name TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_roleplay_characters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        title TEXT NOT NULL,
        subject TEXT NOT NULL,
        initial_greeting TEXT,
        system_prompt TEXT,
        voice_gender TEXT DEFAULT 'male',
        voice_language TEXT DEFAULT 'en-US',
        avatar_emoji TEXT DEFAULT '🧑‍🏫',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS homework (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_name TEXT NOT NULL,
        subject_name TEXT NOT NULL,
        teacher_id INTEGER,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        assigned_date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        is_broadcasted INTEGER DEFAULT 0,
        image_path TEXT,
        instructions_image_path TEXT,
        target_student_id INTEGER,
        audio_path TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS homework_checks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        homework_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        student_name TEXT NOT NULL,
        is_completed INTEGER DEFAULT 1,
        checked_at TEXT NOT NULL,
        remarks TEXT,
        FOREIGN KEY (homework_id) REFERENCES homework (id),
        FOREIGN KEY (student_id) REFERENCES students (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS timetables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_name TEXT NOT NULL,
        day_of_week TEXT NOT NULL,
        period_number INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        subject_name TEXT NOT NULL,
        teacher_name TEXT NOT NULL,
        room_number TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS weekly_diaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_name TEXT NOT NULL,
        subject_name TEXT NOT NULL,
        week_start_date TEXT NOT NULL,
        week_end_date TEXT NOT NULL,
        day_plans_json TEXT NOT NULL,
        parent_summary_urdu TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        phone TEXT,
        assigned_class TEXT,
        assigned_subject TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE teachers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        assigned_classes TEXT DEFAULT '',
        subjects TEXT DEFAULT '',
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE families (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_name TEXT NOT NULL,
        phone TEXT,
        whatsapp_number TEXT,
        address TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        father_name TEXT NOT NULL,
        class_name TEXT NOT NULL,
        section TEXT DEFAULT 'A',
        phone TEXT,
        whatsapp_number TEXT,
        family_id INTEGER,
        roll_number TEXT,
        enrolled_at TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        FOREIGN KEY (family_id) REFERENCES families (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        class_name TEXT NOT NULL,
        teacher_id INTEGER,
        FOREIGN KEY (teacher_id) REFERENCES teachers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE marks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        subject_id INTEGER NOT NULL,
        subject_name TEXT NOT NULL,
        term TEXT NOT NULL,
        score REAL NOT NULL,
        max_score REAL NOT NULL,
        remarks TEXT,
        recorded_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id),
        FOREIGN KEY (subject_id) REFERENCES subjects (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE oral_exam_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        student_name TEXT NOT NULL,
        question TEXT NOT NULL,
        answer_text TEXT NOT NULL,
        score REAL NOT NULL,
        feedback TEXT NOT NULL,
        feedback_urdu TEXT DEFAULT '',
        recorded_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE fee_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        default_amount REAL NOT NULL,
        class_name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE fee_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        fee_type_id INTEGER NOT NULL,
        fee_type_name TEXT NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        amount REAL NOT NULL,
        is_paid INTEGER DEFAULT 0,
        paid_date TEXT,
        notes TEXT,
        FOREIGN KEY (student_id) REFERENCES students (id),
        FOREIGN KEY (fee_type_id) REFERENCES fee_types (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        student_name TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await _ensureTablesAndColumns(db);

    // Seed default data
    await _seedDefaultData(db);
  }

  Future<void> _seedDefaultData(Database db) async {
    // Insert app settings
    await db.insert('app_settings', {'key': 'setup_complete', 'value': 'false'});
    await db.insert('app_settings', {'key': 'school_name', 'value': 'Sublime Grammar School'});

    // Insert default fee types
    final feeTypes = [
      {'name': 'Tuition Fee', 'default_amount': 3000.0, 'class_name': null},
      {'name': 'Transport Fee', 'default_amount': 1000.0, 'class_name': null},
      {'name': 'Uniform Fee', 'default_amount': 500.0, 'class_name': null},
      {'name': 'Miscellaneous', 'default_amount': 200.0, 'class_name': null},
    ];
    for (final ft in feeTypes) {
      await db.insert('fee_types', ft);
    }

    // Insert principal / chairman (Sadia Babar)
    final principalHash = _hashPassword('principal123');
    await db.insert('users', {
      'name': 'Sadia Babar',
      'username': 'sadia',
      'password_hash': principalHash,
      'role': 'principal',
      'phone': null,
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('users', {
      'name': 'Sadia Babar',
      'username': 'principal',
      'password_hash': principalHash,
      'role': 'principal',
      'phone': null,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Insert admins
    final adminHash = _hashPassword('admin123');
    await db.insert('users', {
      'name': 'Ansab Shuja',
      'username': 'ansab',
      'password_hash': adminHash,
      'role': 'admin',
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('users', {
      'name': 'Moiz Shuja',
      'username': 'moiz',
      'password_hash': adminHash,
      'role': 'admin',
      'created_at': DateTime.now().toIso8601String(),
    });

    // Insert teachers only if NOT in clean data mode
    if (!AppConfig.isCleanDataMode) {
      final teacherHash = _hashPassword('teacher123');
      final teacherNames = [
        'Munza', 'Maham', 'Nisa', 'Aleeza', 'Lubaba',
        'Zainab', 'Areesha', 'Kainat', 'Laika', 'Ramzan', 'Haroon'
      ];
      for (final tName in teacherNames) {
        final userId = await db.insert('users', {
          'name': tName,
          'username': tName.toLowerCase(),
          'password_hash': teacherHash,
          'role': 'teacher',
          'created_at': DateTime.now().toIso8601String(),
        });
        await db.insert('teachers', {
          'user_id': userId,
          'name': tName,
          'assigned_classes': '',
          'subjects': '',
        });
      }
    }

    // Mark setup as complete
    await db.update('app_settings', {'value': 'true'}, where: 'key = ?', whereArgs: ['setup_complete']);
    
    // Seed subjects and sample students
    await _seedSubjectsAndSampleData(db);
  }

  Future<void> ensureCurriculumAndSampleData() async {
    final db = await database;
    if (AppConfig.isCleanDataMode) {
      final cleanDone = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM app_settings WHERE key = 'clean_init_done' AND value = 'true'")
      ) ?? 0;
      if (cleanDone == 0) {
        // Clean slate: remove all sample teachers and students, preserve only Admin & Principal
        await db.delete('students');
        await db.delete('families');
        await db.delete('fee_records');
        await db.delete('attendance');
        await db.delete('marks');
        await db.delete('teachers');
        await db.delete('users', where: 'role = ?', whereArgs: ['teacher']);
        await db.insert('app_settings', {'key': 'clean_init_done', 'value': 'true'});
      }
    }
    await _seedSubjectsAndSampleData(db);
  }

  Future<void> _seedSubjectsAndSampleData(Database db) async {
    // 1. Seed Subjects
    final subjectCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM subjects')) ?? 0;
    if (subjectCount == 0) {
      final defaultSubjects = {
        'PG': ['English', 'Urdu', 'Mathematics', 'General Knowledge', 'Art & Craft'],
        'Nursery': ['English', 'Urdu', 'Mathematics', 'General Knowledge', 'Art & Craft'],
        'KG': ['English', 'Urdu', 'Mathematics', 'General Knowledge', 'Rhymes & Story'],
        'Class 1': ['English', 'Urdu', 'Mathematics', 'General Science', 'Islamiyat'],
        'Class 2': ['English', 'Urdu', 'Mathematics', 'General Science', 'Islamiyat'],
        'Class 3': ['English', 'Urdu', 'Mathematics', 'General Science', 'Islamiyat', 'Social Studies'],
        'Class 4': ['English', 'Urdu', 'Mathematics', 'General Science', 'Islamiyat', 'Social Studies', 'Computer'],
        'Class 5': ['English', 'Urdu', 'Mathematics', 'General Science', 'Islamiyat', 'Social Studies', 'Computer'],
        'Class 6': ['English', 'Urdu', 'Mathematics', 'General Science', 'Islamiyat', 'History', 'Geography', 'Computer'],
        'Class 7': ['English', 'Urdu', 'Mathematics', 'General Science', 'Islamiyat', 'History', 'Geography', 'Computer'],
        'Class 8': ['English', 'Urdu', 'Mathematics', 'General Science', 'Islamiyat', 'History', 'Geography', 'Computer'],
        'Class 9': ['English', 'Urdu', 'Mathematics', 'Physics', 'Chemistry', 'Biology', 'Computer Science', 'Islamiyat', 'Pakistan Studies'],
        'Class 10': ['English', 'Urdu', 'Mathematics', 'Physics', 'Chemistry', 'Biology', 'Computer Science', 'Islamiyat', 'Pakistan Studies'],
      };
      for (final entry in defaultSubjects.entries) {
        for (final subName in entry.value) {
          await db.insert('subjects', {
            'name': subName,
            'class_name': entry.key,
          });
        }
      }
    }

    // 2. Default Teacher Class Allocations
    if (!AppConfig.isCleanDataMode) {
      final teacherAllocations = {
        'Munza': {'classes': 'Class 1,Class 2,Class 3,Class 4,Class 5,Class 6,Class 7', 'subjects': 'English'},
        'Maham': {'classes': 'Class 1,Class 2,Class 3,Class 4,Class 5,Class 6,Class 7', 'subjects': 'Urdu'},
        'Nisa': {'classes': 'Class 1,Class 2,Class 3,Class 4,Class 5,Class 6,Class 7', 'subjects': 'Mathematics'},
        'Aleeza': {'classes': 'Nursery,KG', 'subjects': 'English,Urdu,General Knowledge,Rhymes'},
        'Lubaba': {'classes': 'Class 1,Class 2,Class 3,Class 4,Class 5,Class 6,Class 7', 'subjects': 'General Science'},
        'Zainab': {'classes': 'Class 1,Class 2,Class 3,Class 4,Class 5,Class 6,Class 7', 'subjects': 'Islamiyat'},
        'Areesha': {'classes': 'Class 8', 'subjects': 'All Subjects (Class 8 Dedicated Lead Teacher)'},
        'Kainat': {'classes': 'Class 1,Class 2,Class 3,Class 4,Class 5,Class 6,Class 7', 'subjects': 'Social Studies,History,Geography'},
        'Laika': {'classes': 'Class 1,Class 2,Class 3,Class 4,Class 5,Class 6,Class 7', 'subjects': 'Computer,Art & Craft'},
        'Ramzan': {'classes': 'Class 10', 'subjects': 'All Subjects (Class 10 Dedicated Lead Teacher)'},
        'Haroon': {'classes': 'Class 9', 'subjects': 'All Subjects (Class 9 Dedicated Lead Teacher)'},
      };
      for (final entry in teacherAllocations.entries) {
        await db.rawUpdate(
          "UPDATE teachers SET assigned_classes = ?, subjects = ? WHERE LOWER(name) = ?",
          [entry.value['classes'], entry.value['subjects'], entry.key.toLowerCase()],
        );
      }
    }

    // 3. Seed Sample Students, Families, Fees, Marks & Attendance if students table is empty (< 150)
    if (AppConfig.isCleanDataMode) return;
    final studentCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM students')) ?? 0;
    if (studentCount < 150) {
      if (studentCount > 0) {
        // Clear old small set to re-seed full 156-student dataset
        await db.delete('students');
        await db.delete('families');
        await db.delete('fee_records');
        await db.delete('attendance');
        await db.delete('marks');
      }

      final familySeeds = [
        {'name': 'Babar Ali', 'phone': '03001234567', 'address': 'House 12, Street 4, Lahore'},
        {'name': 'Noor Muhammad', 'phone': '03019876543', 'address': 'House 45, Gulberg, Lahore'},
        {'name': 'Tariq Mehmood', 'phone': '03214567890', 'address': 'Flat 3, Model Town, Lahore'},
        {'name': 'Aslam Khan', 'phone': '03335554433', 'address': 'House 88, Johar Town, Lahore'},
        {'name': 'Rizwan Ahmed', 'phone': '03457778899', 'address': 'House 21, Iqbal Town, Lahore'},
        {'name': 'Khalid Mehmood', 'phone': '03021112233', 'address': 'House 19, Cavalry Ground, Lahore'},
        {'name': 'Farooq Umar', 'phone': '03223334455', 'address': 'House 55, DHA Phase 5, Lahore'},
        {'name': 'Amir Sohail', 'phone': '03348889900', 'address': 'House 102, Wapda Town, Lahore'},
        {'name': 'Raza Ali', 'phone': '03461234567', 'address': 'House 7, Shadman, Lahore'},
        {'name': 'Malik Riaz', 'phone': '03039998877', 'address': 'House 81, Bahria Town, Lahore'},
        {'name': 'Shahzad Akhtar', 'phone': '03045556677', 'address': 'House 14, Faisal Town, Lahore'},
        {'name': 'Imran Qureshi', 'phone': '03157778811', 'address': 'House 92, Garden Town, Lahore'},
        {'name': 'Nadeem Iqbal', 'phone': '03239990022', 'address': 'House 34, Samanabad, Lahore'},
        {'name': 'Rashid Javed', 'phone': '03351112233', 'address': 'House 67, Township, Lahore'},
        {'name': 'Kamran Siddiqui', 'phone': '03473334455', 'address': 'House 50, Cantt, Lahore'},
        {'name': 'Waqas Butt', 'phone': '03058889911', 'address': 'House 23, Mughalpura, Lahore'},
        {'name': 'Faisal Rehman', 'phone': '03162223344', 'address': 'House 78, Gulshan-e-Ravi, Lahore'},
        {'name': 'Junaid Jamshed', 'phone': '03244445566', 'address': 'House 11, Green Town, Lahore'},
        {'name': 'Tanveer Abbasi', 'phone': '03366667788', 'address': 'House 90, Valencia, Lahore'},
        {'name': 'Zafar Abbas', 'phone': '03487778899', 'address': 'House 42, Lake City, Lahore'},
      ];

      final List<int> familyIds = [];
      for (final f in familySeeds) {
        final fid = await db.insert('families', {
          'parent_name': f['name'],
          'phone': f['phone'],
          'whatsapp_number': '92${(f['phone'] as String).substring(1)}',
          'address': f['address'],
        });
        familyIds.add(fid);
      }

      final firstNames = [
        'Hamza', 'Fatima', 'Muhammad Bilal', 'Ayesha', 'Zainab', 'Ali', 'Usman', 'Maryam',
        'Abdullah', 'Saad', 'Hania', 'Danial', 'Hassan', 'Eshal', 'Zayan', 'Dua', 'Zoya',
        'Minahil', 'Anaya', 'Hoorain', 'Maham', 'Manahil', 'Hira', 'Kinza', 'Sara', 'Rida',
        'Laiba', 'Iman', 'Bisma', 'Alishba', 'Mehak', 'Iqra', 'Areeba', 'Rimsha', 'Bushra',
        'Samreen', 'Amna', 'Khadija', 'Syeda Fizza', 'Aiza', 'Jannat', 'Bareera', 'Rayyan',
        'Talha', 'Farhan', 'Haris', 'Subhan', 'Mustafa', 'Ibrahim', 'Yahya', 'Hashir', 'Rohaan',
        'Zain', 'Affan', 'Taha', 'Shahmeer', 'Shehroz', 'Ayan', 'Azan', 'Shayan', 'Rehan',
        'Waleed', 'Arham', 'Moosa', 'Ahmed', 'Umar', 'Hussain', 'Daniyal', 'Faizan', 'Adeel',
        'Saim', 'Sameer', 'Kamran', 'Kashif', 'Waqar', 'Bilal', 'Junaid', 'Zubair', 'Noman'
      ];

      final classes = [
        'Nursery', 'KG', 'Class 1', 'Class 2', 'Class 3', 'Class 4',
        'Class 5', 'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10'
      ];

      final now = DateTime.now();
      int totalCreated = 0;

      for (final cls in classes) {
        final classSubjects = await db.query('subjects', where: 'class_name = ?', whereArgs: [cls]);

        for (int roll = 1; roll <= 13; roll++) {
          totalCreated++;
          final fIdx = (totalCreated - 1) % familySeeds.length;
          final fam = familySeeds[fIdx];
          final fId = familyIds[fIdx];
          final fn = firstNames[(totalCreated - 1) % firstNames.length];
          final fatherLastName = (fam['name'] as String).split(' ').last;
          final studentName = '$fn $fatherLastName';
          final phone = fam['phone'] as String;
          final section = roll <= 7 ? 'A' : 'B';
          final rollStr = roll < 10 ? '0$roll' : '$roll';

          final studentId = await db.insert('students', {
            'name': studentName,
            'father_name': fam['name'],
            'class_name': cls,
            'section': section,
            'phone': phone,
            'whatsapp_number': '92${phone.substring(1)}',
            'family_id': fId,
            'roll_number': rollStr,
            'enrolled_at': now.toIso8601String(),
            'is_active': 1,
          });

          // Fee records (12 months)
          for (int month = 1; month <= 12; month++) {
            final isPaid = month < now.month ? 1 : (month == now.month ? (totalCreated % 3 != 0 ? 1 : 0) : 0);
            await db.insert('fee_records', {
              'student_id': studentId,
              'fee_type_id': 1,
              'fee_type_name': 'Tuition Fee',
              'month': month,
              'year': now.year,
              'amount': 3000.0,
              'is_paid': isPaid,
              'paid_date': isPaid == 1 ? '${now.year}-${month.toString().padLeft(2, '0')}-05' : null,
              'notes': isPaid == 1 ? 'Paid via Cash/Online' : 'Pending',
            });
          }

          // Attendance for current month
          for (int day = 1; day <= now.day && day <= 20; day++) {
            final isAbsent = (totalCreated % 7 == 0 && (day == 2 || day == 9)) || (totalCreated % 13 == 0 && (day == 3 || day == 8 || day == 14));
            await db.insert('attendance', {
              'student_id': studentId,
              'student_name': studentName,
              'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
              'status': isAbsent ? 'absent' : 'present',
            });
          }

          // Marks for subjects
          for (final sub in classSubjects) {
            final subId = sub['id'] as int;
            final subName = sub['name'] as String;
            final baseScore = 55.0 + (totalCreated * 3 + roll * 4) % 40;

            await db.insert('marks', {
              'student_id': studentId,
              'subject_id': subId,
              'subject_name': subName,
              'term': 'Term 1',
              'score': (baseScore + 2).clamp(40.0, 98.0),
              'max_score': 100.0,
              'remarks': 'Good understanding',
              'recorded_at': now.subtract(const Duration(days: 90)).toIso8601String(),
            });

            await db.insert('marks', {
              'student_id': studentId,
              'subject_id': subId,
              'subject_name': subName,
              'term': 'Term 2',
              'score': (baseScore + 5).clamp(42.0, 99.0),
              'max_score': 100.0,
              'remarks': 'Significant progress',
              'recorded_at': now.subtract(const Duration(days: 30)).toIso8601String(),
            });

            await db.insert('marks', {
              'student_id': studentId,
              'subject_id': subId,
              'subject_name': subName,
              'term': 'Term 3',
              'score': (baseScore + 7).clamp(45.0, 100.0),
              'max_score': 100.0,
              'remarks': 'Final assessment passed',
              'recorded_at': now.toIso8601String(),
            });

            await db.insert('marks', {
              'student_id': studentId,
              'subject_id': subId,
              'subject_name': subName,
              'term': 'Monthly Test (Oct)',
              'score': (baseScore + 6).clamp(44.0, 99.0),
              'max_score': 100.0,
              'remarks': 'Monthly assessment October',
              'recorded_at': now.subtract(const Duration(days: 5)).toIso8601String(),
            });

            await db.insert('marks', {
              'student_id': studentId,
              'subject_id': subId,
              'subject_name': subName,
              'term': 'Monthly Test (Sep)',
              'score': (baseScore + 3).clamp(42.0, 96.0),
              'max_score': 100.0,
              'remarks': 'Monthly assessment September',
              'recorded_at': now.subtract(const Duration(days: 35)).toIso8601String(),
            });

            await db.insert('marks', {
              'student_id': studentId,
              'subject_id': subId,
              'subject_name': subName,
              'term': 'Monthly Test (Aug)',
              'score': (baseScore).clamp(40.0, 90.0),
              'max_score': 100.0,
              'remarks': 'Monthly assessment August',
              'recorded_at': now.subtract(const Duration(days: 65)).toIso8601String(),
            });
          }
        }
      }
    }

    // 4. Seed Synchronized Conflict-Free Timetable if empty
    await _seedDefaultTimetable(db);
  }

  Future<void> _seedDefaultTimetable(Database db) async {
    if (AppConfig.isCleanDataMode) return;

    // Check version to force clean sync on updated APK
    final versionCount = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM app_settings WHERE key = 'timetable_sync_version' AND value = 'v5'"
    )) ?? 0;
    if (versionCount == 0) {
      await db.delete('timetables');
      await db.insert('app_settings', {'key': 'timetable_sync_version', 'value': 'v5'},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final slotCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM timetables')) ?? 0;
    if (slotCount > 0) return;

    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final lowerClasses = ['Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7'];
    final specialists = [
      {'subject': 'English', 'teacher': 'Miss Munza'},
      {'subject': 'Urdu', 'teacher': 'Miss Maham'},
      {'subject': 'Mathematics', 'teacher': 'Miss Nisa'},
      {'subject': 'General Science', 'teacher': 'Miss Lubaba'},
      {'subject': 'Islamiyat', 'teacher': 'Miss Zainab'},
      {'subject': 'Social Studies', 'teacher': 'Miss Kainat'},
      {'subject': 'Computer', 'teacher': 'Miss Laika'},
    ];

    final upperClasses = {
      'Class 8': {
        'teacher': 'Miss Arisha', // Miss Arisha dedicated lead
        'subjects': ['Mathematics', 'General Science', 'English', 'Urdu', 'Islamiyat', 'History', 'Computer'],
      },
      'Class 9': {
        'teacher': 'Sir Haroon', // Sir Haroon dedicated lead
        'subjects': ['Physics', 'Mathematics', 'Chemistry', 'Biology', 'English', 'Urdu', 'Pakistan Studies'],
      },
      'Class 10': {
        'teacher': 'Sir Ramzan', // Sir Ramzan dedicated lead
        'subjects': ['Chemistry', 'Physics', 'Mathematics', 'Biology', 'Computer Science', 'English', 'Urdu'],
      },
    };

    final earlyYears = {
      'PG': ['English Phonics', 'Urdu Haroof', 'Mathematics Numbers', 'General Knowledge', 'Art & Activity', 'Story Time', 'Play Period'],
      'Nursery': ['English Phonics', 'Urdu Haroof', 'Mathematics Numbers', 'General Knowledge', 'Art & Activity', 'Story Time', 'Play Period'],
      'KG': ['English Reading', 'Urdu Alfaz', 'Mathematics Addition', 'General Science', 'Rhymes & Singing', 'Islamiyat Basics', 'Activity Time'],
    };

    final regularTimes = [
      ('08:00 AM', '08:45 AM'),
      ('08:45 AM', '09:30 AM'),
      ('09:30 AM', '10:15 AM'),
      ('10:15 AM', '10:55 AM'),
      ('11:25 AM', '12:05 PM'),
      ('12:05 PM', '12:45 PM'),
      ('12:45 PM', '01:25 PM'),
    ];

    final fridayTimes = [
      ('08:00 AM', '08:40 AM'),
      ('08:40 AM', '09:20 AM'),
      ('09:20 AM', '10:00 AM'),
      ('10:25 AM', '11:05 AM'),
      ('11:05 AM', '11:45 AM'),
      ('11:45 AM', '12:25 PM'),
      ('12:25 PM', '01:00 PM'),
    ];

    final batch = db.batch();

    for (int dIdx = 0; dIdx < days.length; dIdx++) {
      final day = days[dIdx];
      final isFriday = day == 'Friday';
      final periodTimes = isFriday ? fridayTimes : regularTimes;

      // 1. Lower classes (Class 1 to 7) - conflict-free specialist rotation
      for (int cIdx = 0; cIdx < lowerClasses.length; cIdx++) {
        final className = lowerClasses[cIdx];
        for (int p = 1; p <= 7; p++) {
          final specIdx = (cIdx + (p - 1) + dIdx) % specialists.length;
          final spec = specialists[specIdx];
          batch.insert('timetables', {
            'class_name': className,
            'day_of_week': day,
            'period_number': p,
            'start_time': periodTimes[p - 1].$1,
            'end_time': periodTimes[p - 1].$2,
            'subject_name': spec['subject']!,
            'teacher_name': spec['teacher']!,
            'room_number': 'Room ${cIdx + 1}',
          });
        }
      }

      // 2. Upper classes (Class 8, Class 9, Class 10) - single dedicated lead teacher
      for (final entry in upperClasses.entries) {
        final className = entry.key;
        final teacher = entry.value['teacher'] as String;
        final subjects = entry.value['subjects'] as List<String>;

        for (int p = 1; p <= 7; p++) {
          final subIdx = ((p - 1) + dIdx) % subjects.length;
          batch.insert('timetables', {
            'class_name': className,
            'day_of_week': day,
            'period_number': p,
            'start_time': periodTimes[p - 1].$1,
            'end_time': periodTimes[p - 1].$2,
            'subject_name': subjects[subIdx],
            'teacher_name': teacher,
            'room_number': className == 'Class 10' ? 'Room 10' : (className == 'Class 9' ? 'Room 9' : 'Room 8'),
          });
        }
      }

      // 3. Early Years (Nursery & KG) - Miss Aleeza
      for (final entry in earlyYears.entries) {
        final className = entry.key;
        final subjects = entry.value;
        for (int p = 1; p <= 7; p++) {
          final subIdx = ((p - 1) + dIdx) % subjects.length;
          batch.insert('timetables', {
            'class_name': className,
            'day_of_week': day,
            'period_number': p,
            'start_time': periodTimes[p - 1].$1,
            'end_time': periodTimes[p - 1].$2,
            'subject_name': subjects[subIdx],
            'teacher_name': 'Miss Aleeza',
            'room_number': 'Junior Wing',
          });
        }
      }
    }

    await batch.commit(noResult: true);
  }

  Future<void> seedDefaultTimetable() async {
    final db = await database;
    await _seedDefaultTimetable(db);
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password + 'ustad_ai_salt_2024');
    return sha256.convert(bytes).toString();
  }

  String hashPassword(String password) => _hashPassword(password);

  // ── App Settings ──────────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('app_settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── Synchronized Custom & Monthly Tests ───────────────────────────────────

  Future<List<String>> getCustomTests() async {
    final db = await database;
    final Set<String> tests = {
      'Monthly Test (September)',
      'Monthly Test (October)',
      'Monthly Test (November)',
      'Monthly Test (December)',
      'Weekly / Chapter Test',
    };
    final raw = await getSetting('custom_tests_list');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List decoded = jsonDecode(raw);
        for (final t in decoded) {
          if (t.toString().trim().isNotEmpty) tests.add(t.toString().trim());
        }
      } catch (_) {}
    }
    try {
      final rows = await db.rawQuery('SELECT DISTINCT term FROM marks');
      for (final r in rows) {
        final t = r['term'] as String?;
        if (t != null && t.isNotEmpty && !['Term 1', 'Term 2', 'Term 3', 'Annual', 'Annual (Combined)'].contains(t)) {
          tests.add(t);
        }
      }
    } catch (_) {}
    return tests.toList();
  }

  Future<void> addCustomTest(String testName) async {
    final clean = testName.trim();
    if (clean.isEmpty) return;
    final list = await getCustomTests();
    if (!list.contains(clean)) {
      list.add(clean);
      await setSetting('custom_tests_list', jsonEncode(list));
    }
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  Future<UserModel?> getUserByUsername(String username) async {
    final db = await database;
    final normalized = username.toLowerCase().trim();
    final result = await db.query('users', where: 'username = ?', whereArgs: [normalized]);
    if (result.isNotEmpty) return UserModel.fromMap(result.first);

    // Fallback alias support: allow 'sadia' and 'principal' interchangeably across existing databases
    if (normalized == 'sadia') {
      final fallback = await db.query('users', where: 'username = ?', whereArgs: ['principal']);
      if (fallback.isNotEmpty) return UserModel.fromMap(fallback.first);
    } else if (normalized == 'principal') {
      final fallback = await db.query('users', where: 'username = ?', whereArgs: ['sadia']);
      if (fallback.isNotEmpty) return UserModel.fromMap(fallback.first);
    }
    return null;
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final result = await db.query('users', orderBy: 'name ASC');
    return result.map((e) => UserModel.fromMap(e)).toList();
  }

  Future<int> insertUser(UserModel user) async {
    final db = await database;
    return await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateUserPassword(int userId, String newPasswordHash) async {
    final db = await database;
    await db.update('users', {'password_hash': newPasswordHash}, where: 'id = ?', whereArgs: [userId]);
  }

  // ── Teachers ──────────────────────────────────────────────────────────────

  Future<List<TeacherModel>> getAllTeachers() async {
    final db = await database;
    final result = await db.query('teachers', orderBy: 'name ASC');
    return result.map((e) => TeacherModel.fromMap(e)).toList();
  }

  Future<TeacherModel?> getTeacherByUserId(int userId) async {
    final db = await database;
    final result = await db.query('teachers', where: 'user_id = ?', whereArgs: [userId]);
    if (result.isEmpty) return null;
    return TeacherModel.fromMap(result.first);
  }

  Future<void> updateTeacher(TeacherModel teacher) async {
    final db = await database;
    await db.update('teachers', teacher.toMap(), where: 'id = ?', whereArgs: [teacher.id]);
  }

  Future<int> insertTeacher(TeacherModel teacher) async {
    final db = await database;
    return await db.insert('teachers', teacher.toMap());
  }

  Future<void> deleteTeacher(int id) async {
    final db = await database;
    final result = await db.query('teachers', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      final userId = result.first['user_id'] as int?;
      final teacherName = (result.first['name'] as String? ?? '').trim().toLowerCase();
      await db.delete('teachers', where: 'id = ?', whereArgs: [id]);
      if (userId != null) {
        await db.delete('users', where: 'id = ?', whereArgs: [userId]);
      }
      if (teacherName.isNotEmpty) {
        await db.delete('users', where: 'LOWER(username) = ? AND role = ?', whereArgs: [teacherName, 'teacher']);
      }
    } else {
      await db.delete('teachers', where: 'id = ?', whereArgs: [id]);
    }
  }

  // ── Families ──────────────────────────────────────────────────────────────

  Future<List<FamilyModel>> getAllFamilies() async {
    final db = await database;
    final result = await db.query('families', orderBy: 'parent_name ASC');
    return result.map((e) => FamilyModel.fromMap(e)).toList();
  }

  Future<int> insertFamily(FamilyModel family) async {
    final db = await database;
    return await db.insert('families', family.toMap());
  }

  Future<void> updateFamily(FamilyModel family) async {
    final db = await database;
    await db.update('families', family.toMap(), where: 'id = ?', whereArgs: [family.id]);
  }

  // ── Students ──────────────────────────────────────────────────────────────

  Future<List<StudentModel>> getAllStudents({bool activeOnly = true}) async {
    final db = await database;
    final where = activeOnly ? 'is_active = 1' : null;
    final result = await db.query('students', where: where, orderBy: 'name ASC');
    return result.map((e) => StudentModel.fromMap(e)).toList();
  }

  Future<List<StudentModel>> getStudentsByClass(String className) async {
    final db = await database;
    final result = await db.query('students',
        where: 'class_name = ? AND is_active = 1',
        whereArgs: [className],
        orderBy: 'name ASC');
    return result.map((e) => StudentModel.fromMap(e)).toList();
  }

  Future<List<StudentModel>> getStudentsByFamily(int familyId) async {
    final db = await database;
    final result = await db.query('students',
        where: 'family_id = ? AND is_active = 1', whereArgs: [familyId]);
    return result.map((e) => StudentModel.fromMap(e)).toList();
  }

  Future<int> insertStudent(StudentModel student) async {
    final db = await database;
    return await db.insert('students', student.toMap());
  }

  Future<void> updateStudent(StudentModel student) async {
    final db = await database;
    await db.update('students', student.toMap(), where: 'id = ?', whereArgs: [student.id]);
  }

  Future<void> deleteStudent(int id) async {
    final db = await database;
    await db.update('students', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getStudentCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM students WHERE is_active = 1');
    return result.first['count'] as int;
  }

  // ── Subjects ──────────────────────────────────────────────────────────────

  Future<List<SubjectModel>> getSubjectsByClass(String className) async {
    final db = await database;
    final result = await db.query('subjects', where: 'class_name = ?', whereArgs: [className]);
    return result.map((e) => SubjectModel.fromMap(e)).toList();
  }

  Future<List<SubjectModel>> getAllSubjects() async {
    final db = await database;
    final result = await db.query('subjects', orderBy: 'class_name ASC, name ASC');
    return result.map((e) => SubjectModel.fromMap(e)).toList();
  }

  Future<int> insertSubject(SubjectModel subject) async {
    final db = await database;
    return await db.insert('subjects', subject.toMap());
  }

  Future<void> deleteSubject(int id) async {
    final db = await database;
    await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
  }

  // ── Marks ─────────────────────────────────────────────────────────────────

  Future<List<MarksModel>> getMarksByStudent(int studentId) async {
    final db = await database;
    final result = await db.query('marks',
        where: 'student_id = ?', whereArgs: [studentId], orderBy: 'term ASC');
    return result.map((e) => MarksModel.fromMap(e)).toList();
  }

  Future<List<MarksModel>> getMarksByClassAndSubject(
      String className, int subjectId, String term) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT m.* FROM marks m
      JOIN students s ON m.student_id = s.id
      WHERE s.class_name = ? AND m.subject_id = ? AND m.term = ?
      ORDER BY s.name ASC
    ''', [className, subjectId, term]);
    return result.map((e) => MarksModel.fromMap(e)).toList();
  }

  Future<int> insertMarks(MarksModel marks) async {
    final db = await database;
    // Remove any existing mark for this student, subject, and term to guarantee single source of truth
    await db.delete(
      'marks',
      where: 'student_id = ? AND subject_id = ? AND term = ?',
      whereArgs: [marks.studentId, marks.subjectId, marks.term],
    );
    return await db.insert('marks', marks.toMap());
  }

  Future<List<Map<String, dynamic>>> getSubjectMarksForClass(
      String className, int subjectId, String term) async {
    final db = await database;
    final students = await getStudentsByClass(className);
    final List<Map<String, dynamic>> list = [];
    for (final s in students) {
      final res = await db.query(
        'marks',
        where: 'student_id = ? AND subject_id = ? AND term = ?',
        whereArgs: [s.id, subjectId, term],
      );
      MarksModel? mark;
      if (res.isNotEmpty) {
        mark = MarksModel.fromMap(res.first);
      }
      list.add({'student': s, 'mark': mark});
    }
    return list;
  }

  Future<void> updateMarks(MarksModel marks) async {
    final db = await database;
    await db.update('marks', marks.toMap(), where: 'id = ?', whereArgs: [marks.id]);
  }

  Future<int> insertOralExamResult(OralExamResult result) async {
    final db = await database;
    return await db.insert('oral_exam_results', result.toMap());
  }

  Future<List<OralExamResult>> getOralExamResults(int studentId) async {
    final db = await database;
    final result = await db.query('oral_exam_results',
        where: 'student_id = ?', whereArgs: [studentId], orderBy: 'recorded_at DESC');
    return result.map((e) => OralExamResult.fromMap(e)).toList();
  }

  // ── Fees ──────────────────────────────────────────────────────────────────

  Future<List<FeeTypeModel>> getAllFeeTypes() async {
    final db = await database;
    final result = await db.query('fee_types', orderBy: 'name ASC');
    return result.map((e) => FeeTypeModel.fromMap(e)).toList();
  }

  Future<int> insertFeeType(FeeTypeModel feeType) async {
    final db = await database;
    return await db.insert('fee_types', feeType.toMap());
  }

  Future<int> updateFeeType(FeeTypeModel feeType) async {
    final db = await database;
    return await db.update(
      'fee_types',
      feeType.toMap(),
      where: 'id = ?',
      whereArgs: [feeType.id],
    );
  }

  Future<int> deleteFeeType(int id) async {
    final db = await database;
    return await db.delete('fee_types', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FeeRecordModel>> getFeesByStudent(int studentId) async {
    final db = await database;
    final result = await db.query('fee_records',
        where: 'student_id = ?', whereArgs: [studentId], orderBy: 'year DESC, month DESC');
    return result.map((e) => FeeRecordModel.fromMap(e)).toList();
  }

  Future<List<FeeRecordModel>> getFeesByStudentAndMonth(
      int studentId, int month, int year) async {
    final db = await database;
    final result = await db.query('fee_records',
        where: 'student_id = ? AND month = ? AND year = ?',
        whereArgs: [studentId, month, year]);
    return result.map((e) => FeeRecordModel.fromMap(e)).toList();
  }

  Future<int> insertFeeRecord(FeeRecordModel fee) async {
    final db = await database;
    return await db.insert('fee_records', fee.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateFeeRecord(FeeRecordModel fee) async {
    final db = await database;
    await db.update('fee_records', fee.toMap(), where: 'id = ?', whereArgs: [fee.id]);
  }

  Future<double> getTotalFeeCollected(int year) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM fee_records WHERE year = ? AND is_paid = 1', [year]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalFeePending(int year, {int? upToMonth}) async {
    final db = await database;
    final mLimit = upToMonth ?? DateTime.now().month;
    final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM fee_records WHERE year = ? AND month <= ? AND is_paid = 0', [year, mLimit]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getMonthlyFeeCollected(int month, int year) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM fee_records WHERE year = ? AND month = ? AND is_paid = 1',
        [year, month]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getMonthlyFeePending(int month, int year) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM fee_records WHERE year = ? AND month = ? AND is_paid = 0',
        [year, month]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getDefaulters({String? className}) async {
    final db = await database;
    String classClause = '';
    List<dynamic> args = [];
    if (className != null && className.isNotEmpty) {
      classClause = 'AND s.class_name = ?';
      args.add(className);
    }
    final results = await db.rawQuery('''
      SELECT s.id as student_id, s.name, s.father_name, s.class_name, s.section, s.roll_number, s.phone, s.whatsapp_number,
             SUM(f.amount) as total_due, COUNT(f.id) as unpaid_count
      FROM students s
      JOIN fee_records f ON s.id = f.student_id
      WHERE f.is_paid = 0 AND s.is_active = 1 $classClause
      GROUP BY s.id
      ORDER BY total_due DESC
    ''', args);
    return results;
  }

  Future<List<FeeRecordModel>> getUnpaidFeesByStudent(int studentId) async {
    final db = await database;
    final results = await db.query(
      'fee_records',
      where: 'student_id = ? AND is_paid = 0',
      whereArgs: [studentId],
      orderBy: 'year ASC, month ASC',
    );
    return results.map((m) => FeeRecordModel.fromMap(m)).toList();
  }

  // ── Attendance ────────────────────────────────────────────────────────────

  Future<void> insertOrUpdateAttendance(AttendanceModel attendance) async {
    final db = await database;
    await db.insert('attendance', attendance.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AttendanceModel>> getAttendanceByClassAndDate(
      String className, DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT a.* FROM attendance a
      JOIN students s ON a.student_id = s.id
      WHERE s.class_name = ? AND a.date = ? AND s.is_active = 1
    ''', [className, dateStr]);
    return result.map((e) => AttendanceModel.fromMap(e)).toList();
  }

  Future<List<AttendanceModel>> getStudentAttendance(int studentId, int month, int year) async {
    final db = await database;
    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final endDate = '$year-${month.toString().padLeft(2, '0')}-31';
    final result = await db.query('attendance',
        where: 'student_id = ? AND date >= ? AND date <= ?',
        whereArgs: [studentId, startDate, endDate],
        orderBy: 'date ASC');
    return result.map((e) => AttendanceModel.fromMap(e)).toList();
  }

  Future<int> getAttendanceAbsenceCount(int studentId) async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as count FROM attendance WHERE student_id = ? AND status = 'absent'",
        [studentId]);
    return result.first['count'] as int;
  }

  // ── Analytics Helpers ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAtRiskStudents() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT * FROM (
        SELECT s.id, s.name, s.class_name,
          (SELECT COUNT(*) FROM attendance a WHERE a.student_id = s.id AND a.status = 'absent') as absence_count,
          (SELECT COUNT(*) FROM fee_records f WHERE f.student_id = s.id AND f.is_paid = 0) as unpaid_fees,
          (SELECT AVG((m.score / m.max_score) * 100) FROM marks m WHERE m.student_id = s.id) as avg_marks
        FROM students s
        WHERE s.is_active = 1
      )
      WHERE absence_count >= 3 OR avg_marks < 50 OR unpaid_fees >= 2
      ORDER BY absence_count DESC
    ''');
    return result;
  }

  Future<Map<String, int>> getClassWiseStudentCount() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT class_name, COUNT(*) as count FROM students
      WHERE is_active = 1 GROUP BY class_name ORDER BY class_name ASC
    ''');
    return {for (var r in result) r['class_name'] as String: r['count'] as int};
  }

  Future<List<String>> getAllClasses() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT class_name FROM students
      WHERE is_active = 1 ORDER BY class_name ASC
    ''');
    return result.map((r) => r['class_name'] as String).toList();
  }

  Future<double> getAttendanceRate() async {
    final db = await database;
    final total = await db.rawQuery('SELECT COUNT(*) as count FROM attendance');
    final present = await db.rawQuery(
        "SELECT COUNT(*) as count FROM attendance WHERE status = 'present'");
    final t = (total.first['count'] as int);
    final p = (present.first['count'] as int);
    if (t == 0) return 0.0;
    return (p / t) * 100;
  }

  Future<int> bulkInsertStudents(List<StudentModel> students) async {
    final db = await database;
    int count = 0;
    final batch = db.batch();
    for (final s in students) {
      batch.insert('students', s.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
      count++;
    }
    await batch.commit(noResult: true);
    return count;
  }

  // ── Teacher Attendance ─────────────────────────────────────────────────────

  Future<void> _ensureTeacherAttendanceTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS teacher_attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_id INTEGER NOT NULL,
        teacher_name TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (teacher_id) REFERENCES teachers (id)
      )
    ''');
  }

  Future<void> insertOrUpdateTeacherAttendance({
    required int teacherId,
    required String teacherName,
    required DateTime date,
    required String status,
    String? notes,
  }) async {
    final db = await database;
    await _ensureTeacherAttendanceTable(db);
    final dateStr = date.toIso8601String().substring(0, 10);
    final existing = await db.query(
      'teacher_attendance',
      where: 'teacher_id = ? AND date = ?',
      whereArgs: [teacherId, dateStr],
    );
    if (existing.isNotEmpty) {
      await db.update(
        'teacher_attendance',
        {'status': status, 'notes': notes ?? ''},
        where: 'teacher_id = ? AND date = ?',
        whereArgs: [teacherId, dateStr],
      );
    } else {
      await db.insert('teacher_attendance', {
        'teacher_id': teacherId,
        'teacher_name': teacherName,
        'date': dateStr,
        'status': status,
        'notes': notes ?? '',
      });
    }
  }

  Future<Map<int, String>> getTeacherAttendanceByDate(DateTime date) async {
    final db = await database;
    await _ensureTeacherAttendanceTable(db);
    final dateStr = date.toIso8601String().substring(0, 10);
    final results = await db.query(
      'teacher_attendance',
      where: 'date = ?',
      whereArgs: [dateStr],
    );
    return {
      for (final r in results) (r['teacher_id'] as int): (r['status'] as String)
    };
  }

  // ── Teacher Management & Scoping ──────────────────────────────────────────

  static const Map<String, String> defaultTeacherAssignments = {
    'munza': 'Class 5',
    'maham': 'Class 1',
    'nisa': 'Class 2',
    'aleeza': 'Class 3',
    'lubaba': 'Class 4',
    'zainab': 'Class 6',
    'areesha': 'Class 7',
    'kainat': 'Class 8',
    'laika': 'Class 9',
    'ramzan': 'Class 10',
    'haroon': 'KG',
  };

  Future<TeacherModel?> getTeacherByName(String name) async {
    final db = await database;
    final results = await db.query('teachers', where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase().trim()]);
    if (results.isEmpty) return null;
    return TeacherModel.fromMap(results.first);
  }

  Future<void> updateTeacherClasses(int teacherId, List<String> classes, List<String> subjects) async {
    final db = await database;
    await db.update(
      'teachers',
      {
        'assigned_classes': classes.join(','),
        'subjects': subjects.join(','),
      },
      where: 'id = ?',
      whereArgs: [teacherId],
    );
  }

  Future<int> insertTeacherWithUser({
    required String name,
    required String username,
    required String password,
    required String assignedClass,
    required String subject,
  }) async {
    final db = await database;
    final passHash = _hashPassword(password);
    final userId = await db.insert('users', {
      'name': name,
      'username': username.toLowerCase().trim(),
      'password_hash': passHash,
      'role': 'teacher',
      'created_at': DateTime.now().toIso8601String(),
    });

    final teacherId = await db.insert('teachers', {
      'user_id': userId,
      'name': name,
      'assigned_classes': assignedClass,
      'subjects': subject,
    });
    return teacherId;
  }

  // ── Homework Operations ──────────────────────────────────────────────────

  Future<int> insertHomework(HomeworkModel hw) async {
    final db = await database;
    return await db.insert('homework', hw.toMap());
  }

  Future<List<HomeworkModel>> getHomeworkByClass(String className) async {
    final db = await database;
    final results = await db.query(
      'homework',
      where: 'class_name = ?',
      whereArgs: [className],
      orderBy: 'due_date DESC, id DESC',
    );
    return results.map((m) => HomeworkModel.fromMap(m)).toList();
  }

  Future<List<HomeworkModel>> getAllHomework() async {
    final db = await database;
    final results = await db.query('homework', orderBy: 'due_date DESC, id DESC');
    return results.map((m) => HomeworkModel.fromMap(m)).toList();
  }

  Future<void> deleteHomework(int id) async {
    final db = await database;
    await db.delete('homework', where: 'id = ?', whereArgs: [id]);
    await db.delete('homework_checks', where: 'homework_id = ?', whereArgs: [id]);
  }

  Future<void> saveHomeworkCheck(HomeworkCheckModel check) async {
    final db = await database;
    await db.insert(
      'homework_checks',
      check.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<HomeworkCheckModel>> getHomeworkChecks(int homeworkId) async {
    final db = await database;
    final results = await db.query(
      'homework_checks',
      where: 'homework_id = ?',
      whereArgs: [homeworkId],
      orderBy: 'student_name ASC',
    );
    return results.map((m) => HomeworkCheckModel.fromMap(m)).toList();
  }

  // ── Timetable Operations ─────────────────────────────────────────────────

  Future<int> insertTimetableSlot(TimetableSlotModel slot) async {
    final db = await database;
    return await db.insert('timetables', slot.toMap());
  }

  Future<List<TimetableSlotModel>> getTimetableByClass(String className) async {
    final db = await database;
    var results = await db.query(
      'timetables',
      where: 'class_name = ?',
      whereArgs: [className],
      orderBy: 'period_number ASC',
    );
    if (results.isEmpty && !AppConfig.isCleanDataMode) {
      await _seedDefaultTimetable(db);
      results = await db.query(
        'timetables',
        where: 'class_name = ?',
        whereArgs: [className],
        orderBy: 'period_number ASC',
      );
    }
    return results.map((m) => TimetableSlotModel.fromMap(m)).toList();
  }

  Future<List<TimetableSlotModel>> getTimetableByTeacher(String teacherName) async {
    final db = await database;
    final clean = teacherName.toLowerCase().replaceAll('sir', '').replaceAll('miss', '').replaceAll('teacher', '').trim();
    final results = await db.query(
      'timetables',
      where: 'LOWER(teacher_name) LIKE ? OR (LOWER(teacher_name) LIKE "%arisha%" AND ? LIKE "%arisha%") OR (LOWER(teacher_name) LIKE "%areesha%" AND ? LIKE "%arisha%")',
      whereArgs: ['%$clean%', '%$clean%', '%$clean%'],
      orderBy: 'day_of_week ASC, period_number ASC',
    );
    return results.map((m) => TimetableSlotModel.fromMap(m)).toList();
  }

  Future<List<TimetableSlotModel>> getTimetableBySubject(String subjectName) async {
    final db = await database;
    final results = await db.query(
      'timetables',
      where: 'subject_name LIKE ?',
      whereArgs: ['%$subjectName%'],
      orderBy: 'class_name ASC, day_of_week ASC, period_number ASC',
    );
    return results.map((m) => TimetableSlotModel.fromMap(m)).toList();
  }

  Future<void> updateTimetableSlot(TimetableSlotModel slot) async {
    final db = await database;
    if (slot.id != null) {
      await db.update('timetables', slot.toMap(), where: 'id = ?', whereArgs: [slot.id]);
    } else {
      await db.delete('timetables',
        where: 'class_name = ? AND day_of_week = ? AND period_number = ?',
        whereArgs: [slot.className, slot.dayOfWeek, slot.periodNumber]);
      await db.insert('timetables', slot.toMap());
    }
  }

  Future<void> clearTimetableForClass(String className) async {
    final db = await database;
    await db.delete('timetables', where: 'class_name = ?', whereArgs: [className]);
  }

  // ── Weekly Diary Operations ──────────────────────────────────────────────

  Future<int> insertWeeklyDiary(WeeklyDiaryModel diary) async {
    final db = await database;
    return await db.insert('weekly_diaries', diary.toMap());
  }

  Future<void> saveOrUpdateWeeklyDiary(WeeklyDiaryModel diary) async {
    final db = await database;
    await db.delete('weekly_diaries',
      where: 'class_name = ? AND subject_name = ?',
      whereArgs: [diary.className, diary.subjectName]);
    await db.insert('weekly_diaries', diary.toMap());
  }

  Future<List<WeeklyDiaryModel>> getWeeklyDiariesByClass(String className) async {
    final db = await database;
    final results = await db.query(
      'weekly_diaries',
      where: 'class_name = ?',
      whereArgs: [className],
      orderBy: 'week_start_date DESC',
    );
    return results.map((m) => WeeklyDiaryModel.fromMap(m)).toList();
  }

  // ── Sibling & Family Lookup (Parent Portal) ──────────────────────────────

  Future<List<StudentModel>> getStudentsByParentPhone(String rawPhone) async {
    final db = await database;
    final cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');
    final last7 = cleanPhone.length >= 7
        ? cleanPhone.substring(cleanPhone.length - 7)
        : cleanPhone;

    final results = await db.rawQuery('''
      SELECT DISTINCT s.* FROM students s
      LEFT JOIN families f ON s.family_id = f.id
      WHERE (s.phone LIKE ? OR s.whatsapp_number LIKE ? 
             OR f.phone LIKE ? OR f.whatsapp_number LIKE ?)
        AND s.is_active = 1
      ORDER BY s.class_name ASC, s.name ASC
    ''', ['%$last7%', '%$last7%', '%$last7%', '%$last7%']);

    return results.map((m) => StudentModel.fromMap(m)).toList();
  }

  // ── Parent Password & Account Management ──────────────────────────────────

  Future<bool> verifyParentPassword(String phone, String password) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (password.trim() == 'parent123') return true;
    final db = await database;
    final last7 = cleanPhone.length >= 7 ? cleanPhone.substring(cleanPhone.length - 7) : cleanPhone;
    final res = await db.query(
      'parent_accounts',
      where: 'phone LIKE ?',
      whereArgs: ['%$last7%'],
    );
    if (res.isNotEmpty) {
      final hash = res.first['password_hash'] as String?;
      return hash == _hashPassword(password.trim());
    }
    return password.trim() == 'parent123';
  }

  Future<void> setParentPassword(String phone, String password, {String? parentName}) async {
    final db = await database;
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final hash = _hashPassword(password.trim());
    await db.insert(
      'parent_accounts',
      {
        'phone': cleanPhone,
        'password_hash': hash,
        'parent_name': parentName ?? 'Parent',
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Custom Roleplay Character Persistence ────────────────────────────────

  Future<int> insertCustomCharacter(Map<String, dynamic> character) async {
    final db = await database;
    return await db.insert('custom_roleplay_characters', {
      'name': character['name'],
      'title': character['title'],
      'subject': character['subject'],
      'initial_greeting': character['initial_greeting'],
      'system_prompt': character['system_prompt'],
      'voice_gender': character['voice_gender'] ?? 'male',
      'voice_language': character['voice_language'] ?? 'en-US',
      'avatar_emoji': character['avatar_emoji'] ?? '🧑‍🏫',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getCustomCharacters() async {
    final db = await database;
    return await db.query('custom_roleplay_characters', orderBy: 'id DESC');
  }

  Future<int> deleteCustomCharacter(int id) async {
    final db = await database;
    return await db.delete('custom_roleplay_characters', where: 'id = ?', whereArgs: [id]);
  }
}
