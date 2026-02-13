import 'dart:io';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note.dart';

class ExportService {
  // Export note as TXT file
  Future<void> exportAsTxt(Note note) async {
    try {
      // Parse Quill Delta to plain text
      final doc = quill.Document.fromJson(jsonDecode(note.content));
      final plainText = doc.toPlainText();

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/${note.title}.txt';

      // Write to file
      final file = File(filePath);
      await file.writeAsString(plainText);

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: note.title,
      );
    } catch (e) {
      print('Error exporting as TXT: $e');
      rethrow;
    }
  }

  // Export note as DOCX (Word) file - simplified version
  Future<void> exportAsDocx(Note note) async {
    try {
      // Parse Quill Delta to plain text
      final doc = quill.Document.fromJson(jsonDecode(note.content));
      final plainText = doc.toPlainText();

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/${note.title}.txt';

      // Write to file (simplified - for full DOCX we'd need docx_template with template)
      // For now, export as TXT with .docx extension for basic compatibility
      final file = File(filePath.replaceAll('.txt', '.docx'));
      
      // Create basic RTF content (which Word can open)
      final rtfContent = _createRtfContent(note.title, plainText);
      await file.writeAsString(rtfContent);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: note.title,
      );
    } catch (e) {
      print('Error exporting as DOCX: $e');
      rethrow;
    }
  }

  // Create basic RTF content that Word can open
  String _createRtfContent(String title, String content) {
    return '''{\\rtf1\\ansi\\deff0
{\\fonttbl{\\f0 Times New Roman;}}
\\f0\\fs24
{\\b\\fs32 $title}\\par
\\par
$content
}''';
  }

  // Export note with HTML formatting (alternative format)
  Future<void> exportAsHtml(Note note) async {
    try {
      final doc = quill.Document.fromJson(jsonDecode(note.content));
      final plainText = doc.toPlainText();

      final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>${note.title}</title>
    <style>
        body { font-family: Arial, sans-serif; padding: 20px; }
        h1 { color: #333; }
        .content { line-height: 1.6; }
    </style>
</head>
<body>
    <h1>${note.title}</h1>
    <div class="content">
        ${plainText.replaceAll('\n', '<br>')}
    </div>
</body>
</html>
''';

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/${note.title}.html';

      final file = File(filePath);
      await file.writeAsString(htmlContent);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: note.title,
      );
    } catch (e) {
      print('Error exporting as HTML: $e');
      rethrow;
    }
  }
}
