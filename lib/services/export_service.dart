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

  // Export note as DOCX (Word) file - Using HTML with embedded images that Word can open
  Future<void> exportAsDocx(Note note) async {
    try {
      // Parse Quill Delta
      final delta = jsonDecode(note.content) as List;

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      // Use .doc extension - Word will open HTML content
      final filePath = '${directory.path}/${note.title}.doc';

      // Create HTML with embedded images (Word-compatible format)
      final htmlContent = await _createWordCompatibleHtml(note.title, delta);
      
      final file = File(filePath);
      await file.writeAsString(htmlContent, encoding: utf8);

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

  // Create Word-compatible HTML with embedded images
  Future<String> _createWordCompatibleHtml(String title, List delta) async {
    final buffer = StringBuffer();
    
    // Simple HTML header compatible with Word
    buffer.write('''<html xmlns:v="urn:schemas-microsoft-com:vml"
xmlns:o="urn:schemas-microsoft-com:office:office"
xmlns:w="urn:schemas-microsoft-com:office:word"
xmlns:m="http://schemas.microsoft.com/office/2004/12/omml"
xmlns="http://www.w3.org/TR/REC-html40">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta name="ProgId" content="Word.Document">
<meta name="Generator" content="Scribe Notes">
<meta name="Originator" content="Scribe Notes">
<title>$title</title>
<!--[if gte mso 9]><xml>
 <w:WordDocument>
  <w:View>Print</w:View>
  <w:Zoom>100</w:Zoom>
  <w:HyphenationZone>21</w:HyphenationZone>
  <w:ValidateAgainstSchemas/>
  <w:SaveIfXMLInvalid>false</w:SaveIfXMLInvalid>
  <w:IgnoreMixedContent>false</w:IgnoreMixedContent>
  <w:AlwaysShowPlaceholderText>false</w:AlwaysShowPlaceholderText>
  <w:Compatibility>
   <w:BreakWrappedTables/>
   <w:SnapToGridInCell/>
   <w:WrapTextWithPunct/>
   <w:UseAsianBreakRules/>
  </w:Compatibility>
 </w:WordDocument>
</xml><![endif]-->
<style>
<!--
body {
  font-family: Arial, sans-serif;
  font-size: 12pt;
  line-height: 1.5;
  margin: 1in;
}
h1 {
  font-size: 18pt;
  font-weight: bold;
  margin-bottom: 12pt;
  color: #000000;
}
p {
  margin: 0 0 6pt 0;
}
strong {
  font-weight: bold;
}
em {
  font-style: italic;
}
u {
  text-decoration: underline;
}
s {
  text-decoration: line-through;
}
img {
  display: block;
  margin: 6pt 0;
  max-width: 6in;
}
-->
</style>
</head>
<body lang=VI style='tab-interval:36.0pt'>
<div class=WordSection1>
<h1>$title</h1>
''');
    
    // Process delta operations
    buffer.write('<p>');
    for (var op in delta) {
      if (op is Map && op.containsKey('insert')) {
        final insert = op['insert'];
        final attributes = op['attributes'] as Map?;
        
        if (insert is String) {
          buffer.write(_formatHtmlText(insert, attributes));
        } else if (insert is Map && insert.containsKey('image')) {
          buffer.write('</p>'); // Close current paragraph
          final imagePath = insert['image'] as String;
          final imageWidth = insert['width'] as num?;
          await _addWordEmbeddedImage(buffer, imagePath, imageWidth?.toDouble());
          buffer.write('<p>'); // Start new paragraph
        }
      }
    }
    buffer.write('</p>');
    
    buffer.write('''
</div>
</body>
</html>''');
    
    return buffer.toString();
  }

  Future<void> _addWordEmbeddedImage(StringBuffer buffer, String imagePath, double? width) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        buffer.write('<p><i>[Hình ảnh không tìm thấy]</i></p>\n');
        return;
      }
      
      // Read image and convert to base64
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Determine image type
      String mimeType = 'image/jpeg';
      if (imagePath.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      } else if (imagePath.toLowerCase().endsWith('.gif')) {
        mimeType = 'image/gif';
      } else if (imagePath.toLowerCase().endsWith('.webp')) {
        mimeType = 'image/webp';
      }
      
      // Use a reasonable default width that fits in a Word document
      // Word page width is typically ~6.5 inches = ~468px at 96 DPI
      final imageWidth = width ?? 400.0;
      
      buffer.write('<p><img src="data:$mimeType;base64,$base64Image" style="width: ${imageWidth}px; max-width: 100%; height: auto;" /></p>\n');
    } catch (e) {
      buffer.write('<p><i>[Lỗi hình ảnh]</i></p>\n');
    }
  }

  // Export note with HTML formatting (alternative format)
  Future<void> exportAsHtml(Note note) async {
    try {
      final delta = jsonDecode(note.content) as List;
      
      final htmlContent = await _createRichHtmlContent(note.title, delta);

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/${note.title}.html';

      final file = File(filePath);
      await file.writeAsString(htmlContent, encoding: utf8);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: note.title,
      );
    } catch (e) {
      print('Error exporting as HTML: $e');
      rethrow;
    }
  }

  Future<String> _createRichHtmlContent(String title, List delta) async {
    final buffer = StringBuffer();
    
    buffer.write('''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>$title</title>
    <style>
        body { 
          font-family: Arial, sans-serif; 
          padding: 20px; 
          background: #f5f5f5;
        }
        .container {
          max-width: 800px;
          margin: 0 auto;
          background: white;
          padding: 30px;
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 { 
          color: #333; 
          border-bottom: 2px solid #007bff;
          padding-bottom: 10px;
        }
        .content { 
          line-height: 1.6; 
          color: #333;
        }
        img {
          max-width: 100%;
          height: auto;
          margin: 10px 0;
          border-radius: 4px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>$title</h1>
        <div class="content">
''');
    
    // Process delta operations
    for (var op in delta) {
      if (op is Map && op.containsKey('insert')) {
        final insert = op['insert'];
        final attributes = op['attributes'] as Map?;
        
        if (insert is String) {
          buffer.write(_formatHtmlText(insert, attributes));
        } else if (insert is Map && insert.containsKey('image')) {
          final imagePath = insert['image'] as String;
          await _addImageToHtml(buffer, imagePath);
        }
      }
    }
    
    buffer.write('''
        </div>
    </div>
</body>
</html>
''');
    
    return buffer.toString();
  }

  String _formatHtmlText(String text, Map? attributes) {
    var formatted = _escapeHtml(text);
    
    if (attributes != null) {
      final styles = <String>[];
      String tags = '';
      String closeTags = '';
      
      // Apply HTML tags and styles
      if (attributes['bold'] == true) {
        tags += '<strong>';
        closeTags = '</strong>' + closeTags;
      }
      
      if (attributes['italic'] == true) {
        tags += '<em>';
        closeTags = '</em>' + closeTags;
      }
      
      if (attributes['underline'] == true) {
        styles.add('text-decoration: underline');
      }
      
      if (attributes['strike'] == true) {
        tags += '<s>';
        closeTags = '</s>' + closeTags;
      }
      
      if (attributes['size'] != null) {
        styles.add('font-size: ${attributes['size']}px');
      }
      
      if (attributes['color'] != null) {
        styles.add('color: ${attributes['color']}');
      }
      
      if (attributes['background'] != null) {
        styles.add('background-color: ${attributes['background']}');
      }
      
      if (styles.isNotEmpty) {
        formatted = '<span style="${styles.join('; ')}">$formatted</span>';
      }
      
      formatted = tags + formatted + closeTags;
    }
    
    // Convert newlines to <br>
    formatted = formatted.replaceAll('\n', '<br>\n');
    
    return formatted;
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  Future<void> _addImageToHtml(StringBuffer buffer, String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        buffer.write('<p><em>[Image not found]</em></p>\n');
        return;
      }
      
      // Read image and convert to base64 for embedding
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Determine image type
      String mimeType = 'image/jpeg';
      if (imagePath.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      } else if (imagePath.toLowerCase().endsWith('.gif')) {
        mimeType = 'image/gif';
      }
      
      buffer.write('<img src="data:$mimeType;base64,$base64Image" alt="Note image" />\n');
    } catch (e) {
      buffer.write('<p><em>[Image error]</em></p>\n');
    }
  }
}
