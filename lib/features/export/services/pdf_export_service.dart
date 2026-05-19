import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../notes/models/note.dart';

/// Service responsible for generating timeline-style PDF exports.
///
/// It creates a multi-page document where each note is rendered with:
/// - class/session timestamp
/// - image preview (if available)
/// - OCR text snippet/full text
class PdfExportService {
  /// Creates a PDF as raw bytes for a class timeline.
  ///
  /// [subjectName] is used in headers and the output filename.
  /// [notes] should be from a single subject/class timeline, ideally sorted by
  /// creation time descending or ascending based on the desired output order.
  Future<Uint8List> generateClassTimelinePdf({
    required String subjectName,
    required List<Note> notes,
    DateTime? generatedAt,
  }) async {
    final doc = pw.Document();
    final now = generatedAt ?? DateTime.now();
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final timeFmt = DateFormat('HH:mm');

    // Build note blocks sequentially so image decoding stays predictable.
    final noteWidgets = <pw.Widget>[];
    for (final note in notes) {
      final imageWidget = await _buildImageWidget(note.imagePath);
      final textLabel = note.isTextNote ? 'Note' : 'OCR Text';
      final textBody = note.isTextNote
          ? (note.textContent == null || note.textContent!.trim().isEmpty)
                ? 'No text available.'
                : note.textContent!
          : (note.ocrText == null || note.ocrText!.trim().isEmpty)
          ? 'No extracted text.'
          : note.ocrText!;
      noteWidgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 14),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Time: ${timeFmt.format(note.createdAt)}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              pw.SizedBox(height: 8),
              imageWidget,
              pw.SizedBox(height: 8),
              pw.Text(
                textLabel,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColors.blueGrey700,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(textBody, style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'Aulens - Class Timeline Export',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Subject: $subjectName',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.Text(
            'Generated at: ${dateFmt.format(now)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          if (notes.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Text('No notes available for export.'),
            )
          else
            ...noteWidgets,
        ],
      ),
    );

    return doc.save();
  }

  /// Generates and stores a class timeline PDF in the app's document directory.
  ///
  /// Returns the absolute file path of the generated PDF.
  Future<String> exportClassTimelineToFile({
    required String subjectName,
    required List<Note> notes,
    DateTime? generatedAt,
  }) async {
    final bytes = await generateClassTimelinePdf(
      subjectName: subjectName,
      notes: notes,
      generatedAt: generatedAt,
    );

    final dir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(p.join(dir.path, 'exports'));
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final sanitized = _sanitizeFileName(subjectName);
    final outPath = p.join(exportsDir.path, '${sanitized}_$timestamp.pdf');
    final outFile = File(outPath);
    await outFile.writeAsBytes(bytes, flush: true);
    return outFile.path;
  }

  Future<pw.Widget> _buildImageWidget(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return _placeholder('Text note');
    }

    if (!await _isManagedImagePath(imagePath)) {
      return _placeholder('Image path is outside managed storage');
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      return _placeholder('Image not found');
    }

    try {
      final bytes = await file.readAsBytes();
      final image = pw.MemoryImage(bytes);
      return pw.Container(
        constraints: const pw.BoxConstraints(maxHeight: 220),
        width: double.infinity,
        child: pw.Image(image, fit: pw.BoxFit.contain),
      );
    } catch (_) {
      return _placeholder('Failed to load image');
    }
  }

  Future<bool> _isManagedImagePath(String imagePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final imagesDir = p.normalize(p.join(docsDir.path, 'aulens_images'));
    final candidate = p.normalize(imagePath);
    return p.isWithin(imagesDir, candidate);
  }

  pw.Widget _placeholder(String text) {
    return pw.Container(
      height: 120,
      alignment: pw.Alignment.center,
      color: PdfColors.grey200,
      child: pw.Text(text, style: const pw.TextStyle(color: PdfColors.grey700)),
    );
  }

  String _sanitizeFileName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'class_timeline' : cleaned;
  }
}
