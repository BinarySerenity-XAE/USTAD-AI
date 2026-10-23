import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfFonts {
  static pw.Font? _sans;
  static pw.Font? _sansBold;
  static pw.Font? _arabic;
  static pw.Font? _arabicBold;

  static Future<void> ensureLoaded() async {
    if (_sans != null && _arabic != null) return;
    try {
      final sansBytes = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final sansBoldBytes = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      final arabicBytes = await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
      final arabicBoldBytes = await rootBundle.load('assets/fonts/NotoNaskhArabic-Bold.ttf');

      _sans = pw.Font.ttf(sansBytes);
      _sansBold = pw.Font.ttf(sansBoldBytes);
      _arabic = pw.Font.ttf(arabicBytes);
      _arabicBold = pw.Font.ttf(arabicBoldBytes);
    } catch (e) {
      debugPrint('Error loading PDF fonts: $e');
    }
  }

  static pw.ThemeData get theme {
    if (_sans != null && _arabic != null) {
      return pw.ThemeData.withFont(
        base: _sans!,
        bold: _sansBold ?? _sans!,
        fontFallback: [_arabic!, if (_arabicBold != null) _arabicBold!],
      );
    }
    return pw.ThemeData.base();
  }

  static pw.Font get arabicFont => _arabic ?? pw.Font.courier();
  static pw.Font get arabicBoldFont => _arabicBold ?? _arabic ?? pw.Font.courierBold();
  static pw.Font get sansFont => _sans ?? pw.Font.helvetica();
  static pw.Font get sansBoldFont => _sansBold ?? pw.Font.helveticaBold();
}
