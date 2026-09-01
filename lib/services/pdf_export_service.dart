import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExportService {
  /// Sanitizes string for safe filename across OS/browsers.
  static String sanitizeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_').trim();
    return sanitized.isEmpty ? 'konusma' : sanitized;
  }

  /// Exports speech script details and full text to a styled PDF document.
  static Future<void> exportTalkPdf({
    required String title,
    required String text,
    String? language,
    String? speechType,
    String? duration,
    String? place,
    String? createdAt,
  }) async {
    final regularFont = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final isArabic =
        language != null &&
        (language.toLowerCase().contains('arap') ||
            language.toLowerCase().contains('arab') ||
            language.toLowerCase() == 'ar');

    pw.Font? arabicFont;
    if (isArabic) {
      try {
        arabicFont = await PdfGoogleFonts.notoSansArabicRegular();
      } catch (_) {
        arabicFont = null;
      }
    }

    final doc = pw.Document();
    final baseFont = (isArabic && arabicFont != null)
        ? arabicFont
        : regularFont;
    final titleFont = boldFont;

    final metaList = <MapEntry<String, String>>[];
    if (speechType != null && speechType.trim().isNotEmpty) {
      metaList.add(MapEntry('Konuşma Türü', speechType.trim()));
    }
    if (language != null && language.trim().isNotEmpty) {
      metaList.add(MapEntry('Dil', language.trim()));
    }
    if (duration != null && duration.trim().isNotEmpty) {
      metaList.add(MapEntry('Süre', duration.trim()));
    }
    if (place != null && place.trim().isNotEmpty) {
      metaList.add(MapEntry('Yer', place.trim()));
    }
    if (createdAt != null && createdAt.trim().isNotEmpty) {
      metaList.add(MapEntry('Tarih', createdAt.trim()));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Text(
            'TalkForge',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(
              font: baseFont,
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ),
        build: (context) => [
          pw.Text(
            title.trim().isNotEmpty ? title.trim() : 'Konuşma Metni',
            style: pw.TextStyle(
              font: titleFont,
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 12),
          if (metaList.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 10,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Wrap(
                spacing: 16,
                runSpacing: 6,
                children: metaList.map((entry) {
                  return pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(
                          text: '${entry.key}: ',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.TextSpan(
                          text: entry.value,
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 9.5,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            pw.SizedBox(height: 14),
          ],
          pw.Divider(color: PdfColors.grey300, thickness: 0.8),
          pw.SizedBox(height: 14),
          pw.Paragraph(
            text: text,
            style: pw.TextStyle(
              font: baseFont,
              fontSize: 11,
              lineSpacing: 2,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final filename = '${sanitizeFileName(title)}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
