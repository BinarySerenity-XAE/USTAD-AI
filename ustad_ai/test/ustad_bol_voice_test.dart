import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ustad_ai/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8000\n');
  });

  group('Ustad Bol Voice Command Processing Tests', () {
    test('Offline fallback: Unrecognized speech returns none and does NOT default to homework', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'random background noise blah blah',
        currentRole: 'admin',
      );

      expect(res['target_route'], equals('none'));
      expect(res['action'], equals('none'));
      expect(res['spoken_reply_urdu'], contains('آپ کیا کھولنا چاہتے ہیں'));
    });

    test('Admin role: Timetable keyword routes to timetable', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'ماسٹر ٹائم ٹیبل دیکھو',
        currentRole: 'admin',
      );

      expect(res['target_route'], equals('timetable'));
      expect(res['action'], equals('navigate'));
    });

    test('Admin role: Marks keyword routes to marks', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'طلباء کے امتحانی نمبرات اور رزلٹ',
        currentRole: 'admin',
      );

      expect(res['target_route'], equals('marks'));
      expect(res['action'], equals('navigate'));
    });

    test('Admin role: Certificates keyword routes to certificate', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'طلباء کے اعزازی سرٹیفکیٹ',
        currentRole: 'admin',
      );

      expect(res['target_route'], equals('certificate'));
      expect(res['action'], equals('navigate'));
    });

    test('Admin role: Fee management routes to fee', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'فیس مینجمنٹ اور بقایا جات',
        currentRole: 'admin',
      );

      expect(res['target_route'], equals('fee'));
      expect(res['action'], equals('navigate'));
    });

    test('Admin role: Staff attendance routes to staff_attendance', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'عملہ اور اساتذہ کی حاضری',
        currentRole: 'admin',
      );

      expect(res['target_route'], equals('staff_attendance'));
      expect(res['action'], equals('navigate'));
    });

    test('Teacher role: Homework keyword routes to homework', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'پانچویں جماعت کا ہوم ورک',
        currentRole: 'teacher',
      );

      expect(res['target_route'], equals('homework'));
      expect(res['action'], equals('navigate'));
    });

    test('Teacher role: Class marks routes to marks', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'امتحانی نمبر درج کرو',
        currentRole: 'teacher',
      );

      expect(res['target_route'], equals('marks'));
      expect(res['action'], equals('navigate'));
    });

    test('Teacher role: Paper grader routes to paper_grader', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'پیپر اور ریاضی چیک کرو',
        currentRole: 'teacher',
      );

      expect(res['target_route'], equals('paper_grader'));
      expect(res['action'], equals('navigate'));
    });

    test('Teacher role: Lesson plan routes to lesson_plan', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'یکساں نصاب کا لیسن پلان',
        currentRole: 'teacher',
      );

      expect(res['target_route'], equals('lesson_plan'));
      expect(res['action'], equals('navigate'));
    });

    test('Teacher role: Oral exam routes to oral_exam', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'زبانی امتحان شروع کرو',
        currentRole: 'teacher',
      );

      expect(res['target_route'], equals('oral_exam'));
      expect(res['action'], equals('navigate'));
    });

    test('Teacher role: Roleplay routes to roleplay', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'قائد اعظم سے مکالمہ',
        currentRole: 'teacher',
      );

      expect(res['target_route'], equals('roleplay'));
      expect(res['action'], equals('navigate'));
    });

    test('Admin role: Asking for homework is strictly blocked and does NOT route to homework', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'پانچویں جماعت کا ہوم ورک',
        currentRole: 'admin',
      );

      expect(res['target_route'], equals('none'));
      expect(res['action'], equals('none'));
      expect(res['spoken_reply_urdu'], contains('صرف اساتذہ کے لیے'));
    });

    test('Admin role: English homework query is blocked', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'Open class 5 homework and diary',
        currentRole: 'admin',
      );

      expect(res['target_route'], equals('none'));
      expect(res['action'], equals('none'));
    });

    test('Teacher role: "ہوم ورک چیک کرو" routes to homework and NOT paper_grader', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'ہوم ورک چیک کرو',
        currentRole: 'teacher',
      );

      expect(res['target_route'], equals('homework'));
      expect(res['action'], equals('navigate'));
    });

    test('Teacher role: "ٹیسٹ کے نمبر" routes to marks and NOT paper_grader', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'ٹیسٹ کے نمبر',
        currentRole: 'teacher',
      );

      expect(res['target_route'], equals('marks'));
      expect(res['action'], equals('navigate'));
    });

    test('Teacher role: Unrecognized speech returns none and does NOT default to homework', () async {
      final res = await ApiService.instance.processVoiceCommand(
        transcript: 'hello some noise unknown command',
        currentRole: 'teacher',
      );

      expect(res['target_route'], equals('none'));
      expect(res['action'], equals('none'));
    });
  });
}
