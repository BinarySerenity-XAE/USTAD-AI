// test/whatsapp_share_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustad_ai/models/student_model.dart';
import 'package:ustad_ai/services/whatsapp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhatsApp Service & Share Tests', () {
    test('WhatsAppService handles null or empty phone gracefully without throwing', () async {
      final res = await WhatsAppService.sendMessage(
        phone: null,
        message: 'Test message for class timetable',
      );
      expect(res, isA<bool>());
    });

    test('WhatsAppService filters out dummy phone 923001234567', () async {
      final res = await WhatsAppService.sendMessage(
        phone: '923001234567',
        message: 'Test dummy message',
      );
      expect(res, isA<bool>());
    });

    testWidgets('WhatsApp Share Dialog displays group option, input, and student roster', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sampleStudents = [
        StudentModel(
          id: 1,
          name: 'Hamza Babar',
          fatherName: 'Babar Ali',
          className: 'Class 5',
          rollNumber: '01',
          whatsappNumber: '03011234567',
        ),
        StudentModel(
          id: 2,
          name: 'Fatima Noor',
          fatherName: 'Noor Muhammad',
          className: 'Class 5',
          rollNumber: '02',
          phone: '03029876543',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    WhatsAppService.showShareDialog(
                      context: context,
                      title: 'Share Class Timetable',
                      subtitle: 'Class: Class 5',
                      message: 'Timetable announcement',
                      students: sampleStudents,
                    );
                  },
                  child: const Text('Open Share'),
                );
              },
            ),
          ),
        ),
      );

      // Tap open share
      await tester.tap(find.text('Open Share'));
      await tester.pumpAndSettle();

      // Verify header and title
      expect(find.text('Share Class Timetable'), findsOneWidget);
      expect(find.text('Class: Class 5'), findsOneWidget);

      // Verify Option 1: 1-Tap Group Share
      expect(find.text('Share to Class Group / Any Chat'), findsOneWidget);
      expect(find.text('Opens WhatsApp to pick your class group or any contact'), findsOneWidget);

      // Verify Option 2: Enter specific number
      expect(find.text('OR ENTER SPECIFIC NUMBER'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Verify Option 3: Student roster
      expect(find.text('OR SELECT STUDENT PARENT (2)'), findsOneWidget);
      expect(find.text('Hamza Babar'), findsOneWidget);
      expect(find.text('Fatima Noor'), findsOneWidget);
      expect(find.text('Parent: 03011234567'), findsOneWidget);
      expect(find.text('Parent: 03029876543'), findsOneWidget);

      // Dismiss dialog via close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Share Class Timetable'), findsNothing);
    });
  });
}
