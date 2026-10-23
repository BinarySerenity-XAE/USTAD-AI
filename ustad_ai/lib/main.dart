import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/student_provider.dart';
import 'providers/fee_provider.dart';
import 'providers/marks_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/settings_provider.dart';
import 'database/db_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await DatabaseHelper.instance.database;
  await DatabaseHelper.instance.ensureCurriculumAndSampleData();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => StudentProvider()),
        ChangeNotifierProvider(create: (_) => FeeProvider()),
        ChangeNotifierProvider(create: (_) => MarksProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
      ],
      child: const UstadAiApp(),
    ),
  );
}
