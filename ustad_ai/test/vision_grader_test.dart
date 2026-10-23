import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ustad_ai/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Load local test env with empty API key to test deterministic fallback & parameter verification
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8000\nDASHSCOPE_API_KEY=\n');
  });

  group('Vision Grader Verification Methods Tests', () {
    // Minimal valid base64 payload
    final sampleStudentImageBase64 = base64Encode(List<int>.generate(100, (i) => i));
    final sampleAnswerKeyImageBase64 = base64Encode(List<int>.generate(100, (i) => 255 - i));

    test('Paper Grader: Fallback gracefully handles AI direct verification when offline', () async {
      final res = await ApiService.instance.gradeHandwrittenPaper(
        imageBase64: sampleStudentImageBase64,
        className: 'Class 5',
        subject: 'General Science',
        questionOrTopic: 'What is photosynthesis?',
        directAi: true,
      );

      expect(res, isNotNull);
      expect(res.containsKey('score'), isTrue);
      expect(res.containsKey('max_score'), isTrue);
      expect(res.containsKey('extracted_handwriting'), isTrue);
      expect(res.containsKey('feedback_english'), isTrue);
      expect(res.containsKey('feedback_urdu'), isTrue);
    });

    test('Paper Grader: Fallback gracefully handles Provided Picture Answer Key when offline', () async {
      final res = await ApiService.instance.gradeHandwrittenPaper(
        imageBase64: sampleStudentImageBase64,
        className: 'Class 8',
        subject: 'Computer Science',
        questionOrTopic: 'Define RAM and ROM',
        expectedAnswerKey: 'RAM is temporary, ROM is permanent storage.',
        answerKeyImageBase64: sampleAnswerKeyImageBase64,
        directAi: false,
      );

      expect(res, isNotNull);
      expect(res['score'], isNotNull);
      expect(res['max_score'], equals(10.0));
      expect(res['is_correct'], isTrue);
    });

    test('Math Grader: Fallback gracefully handles AI direct math verification when offline', () async {
      final res = await ApiService.instance.gradeMathProblem(
        imageBase64: sampleStudentImageBase64,
        className: 'Class 7',
        mathProblem: '3x + 12 = 27',
        directAi: true,
      );

      expect(res, isNotNull);
      expect(res.containsKey('extracted_math'), isTrue);
      expect(res.containsKey('is_correct'), isTrue);
      expect(res.containsKey('step_by_step_check'), isTrue);
      expect(res['step_by_step_check'], isA<List>());
    });

    test('Math Grader: Fallback gracefully handles Provided Solution Picture when offline', () async {
      final res = await ApiService.instance.gradeMathProblem(
        imageBase64: sampleStudentImageBase64,
        className: 'Class 9',
        mathProblem: 'x^2 - 5x + 6 = 0',
        expectedSolution: '(x - 2)(x - 3) = 0, x = 2, 3',
        solutionImageBase64: sampleAnswerKeyImageBase64,
        directAi: false,
      );

      expect(res, isNotNull);
      expect(res['is_correct'], isTrue);
      expect(res['extracted_math'], contains('x^2 - 5x + 6 = 0'));
    });
  });
}
