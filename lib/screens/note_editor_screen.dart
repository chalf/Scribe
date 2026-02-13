import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/note.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note note;

  const NoteEditorScreen({super.key, required this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  final ExportService _exportService = ExportService();
  final TextEditingController _titleController = TextEditingController();
  late quill.QuillController _quillController;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isModified = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<int> _searchResults = [];
  int _currentSearchIndex = -1;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.note.title;
    
    // Initialize Quill controller with note content
    try {
      final doc = quill.Document.fromJson(jsonDecode(widget.note.content));
      _quillController = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (e) {
      // If parsing fails, create empty document
      _quillController = quill.QuillController.basic();
    }

    // Listen to content changes
    _quillController.addListener(() {
      if (!_isModified) {
        setState(() => _isModified = true);
      }
      _scheduleAutoSave();
    });

    _titleController.addListener(() {
      if (!_isModified) {
        setState(() => _isModified = true);
      }
      _scheduleAutoSave();
    });
  }

  void _scheduleAutoSave() {
    // Cancel previous timer
    _autoSaveTimer?.cancel();
    
    // Schedule new auto-save after 2 seconds of inactivity
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (_isModified) {
        _saveNote(autoSave: true);
      }
    });
  }

  Future<void> _saveNote({bool autoSave = false}) async {
    final content = jsonEncode(_quillController.document.toDelta().toJson());
    final updatedNote = widget.note.copyWith(
      title: _titleController.text.isEmpty ? 'Ghi chú không tiêu đề' : _titleController.text,
      content: content,
      updatedAt: DateTime.now(),
    );

    await _databaseService.updateNote(updatedNote);
    setState(() => _isModified = false);
    
    if (!mounted) return;
    
    // Only show snackbar for manual saves, not auto-saves
    if (!autoSave) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu ghi chú')),
      );
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      try {
        // Save image to app's document directory
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${appDir.path}/note_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        
        // Generate unique filename
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
        final savedImage = File('${imagesDir.path}/$fileName');
        await File(image.path).copy(savedImage.path);
        
        // Insert image embed into document
        final index = _quillController.selection.baseOffset;
        _quillController.document.insert(
          index,
          quill.BlockEmbed.image(savedImage.path),
        );
        
        // Move cursor after image
        _quillController.updateSelection(
          TextSelection.collapsed(offset: index + 1),
          quill.ChangeSource.local,
        );
        
        setState(() => _isModified = true);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm hình ảnh')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi thêm hình: $e')),
        );
      }
    }
  }

  void _applyFormat(quill.Attribute attribute) {
    final selection = _quillController.selection;
    if (!selection.isCollapsed) {
      // Apply to selection
      _quillController.formatSelection(attribute);
    } else {
      // Toggle style for next input
      _quillController.formatSelection(attribute);
    }
  }

  void _searchInNote(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _currentSearchIndex = -1;
      });
      return;
    }

    final text = _quillController.document.toPlainText().toLowerCase();
    final searchQuery = query.toLowerCase();
    final results = <int>[];

    int index = text.indexOf(searchQuery);
    while (index != -1) {
      results.add(index);
      index = text.indexOf(searchQuery, index + 1);
    }

    setState(() {
      _searchResults = results;
      _currentSearchIndex = results.isNotEmpty ? 0 : -1;
    });

    if (results.isNotEmpty) {
      _highlightSearchResult(0);
    }
  }

  void _highlightSearchResult(int resultIndex) {
    if (resultIndex < 0 || resultIndex >= _searchResults.length) return;

    final position = _searchResults[resultIndex];
    final length = _searchController.text.length;

    // Simply select the current result to highlight it
    _quillController.updateSelection(
      TextSelection(baseOffset: position, extentOffset: position + length),
      quill.ChangeSource.local,
    );
    
    // Request focus to ensure the selection is visible
    if (!_editorFocusNode.hasFocus) {
      _editorFocusNode.requestFocus();
    }
  }

  void _nextSearchResult() {
    if (_searchResults.isEmpty) return;
    
    setState(() {
      _currentSearchIndex = (_currentSearchIndex + 1) % _searchResults.length;
    });
    _highlightSearchResult(_currentSearchIndex);
  }

  void _previousSearchResult() {
    if (_searchResults.isEmpty) return;
    
    setState(() {
      _currentSearchIndex = (_currentSearchIndex - 1 + _searchResults.length) % _searchResults.length;
    });
    _highlightSearchResult(_currentSearchIndex);
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchResults.clear();
        _currentSearchIndex = -1;
      }
    });
  }

  Future<void> _showExportDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xuất ghi chú'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('Xuất file TXT'),
              onTap: () {
                Navigator.pop(context);
                _exportAsTxt();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Xuất file Word (RTF)'),
              onTap: () {
                Navigator.pop(context);
                _exportAsDocx();
              },
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Xuất file HTML'),
              onTap: () {
                Navigator.pop(context);
                _exportAsHtml();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAsTxt() async {
    await _saveNote();
    final updatedNote = await _databaseService.readNote(widget.note.id);
    if (updatedNote != null) {
      await _exportService.exportAsTxt(updatedNote);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xuất file TXT')),
      );
    }
  }

  Future<void> _exportAsDocx() async {
    await _saveNote();
    final updatedNote = await _databaseService.readNote(widget.note.id);
    if (updatedNote != null) {
      await _exportService.exportAsDocx(updatedNote);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xuất file Word')),
      );
    }
  }

  Future<void> _exportAsHtml() async {
    await _saveNote();
    final updatedNote = await _databaseService.readNote(widget.note.id);
    if (updatedNote != null) {
      await _exportService.exportAsHtml(updatedNote);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xuất file HTML')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Tìm kiếm trong note...',
                        hintStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                      ),
                      onChanged: _searchInNote,
                    ),
                  ),
                  if (_searchResults.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '${_currentSearchIndex + 1}/${_searchResults.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                ],
              )
            : const Text('Chỉnh sửa ghi chú'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (_isSearching) {
              _toggleSearch();
            } else {
              if (_isModified) {
                await _saveNote();
              }
              if (!mounted) return;
              Navigator.pop(context, true);
            }
          },
        ),
        actions: [
          if (_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              tooltip: 'Kết quả trước',
              onPressed: _searchResults.isNotEmpty ? _previousSearchResult : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward),
              tooltip: 'Kết quả sau',
              onPressed: _searchResults.isNotEmpty ? _nextSearchResult : null,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Đóng tìm kiếm',
              onPressed: _toggleSearch,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Tìm kiếm',
              onPressed: _toggleSearch,
            ),
            IconButton(
              icon: const Icon(Icons.image),
              tooltip: 'Thêm hình ảnh',
              onPressed: _pickImage,
            ),
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Lưu',
              onPressed: _saveNote,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Xuất file',
              onPressed: _showExportDialog,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Title field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _titleController,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: 'Tiêu đề',
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(height: 1),
          
          // Custom formatting toolbar
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.format_bold),
                    onPressed: () => _applyFormat(quill.Attribute.bold),
                    tooltip: 'In đậm',
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_italic),
                    onPressed: () => _applyFormat(quill.Attribute.italic),
                    tooltip: 'In nghiêng',
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_underline),
                    onPressed: () => _applyFormat(quill.Attribute.underline),
                    tooltip: 'Gạch chân',
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_strikethrough),
                    onPressed: () => _applyFormat(quill.Attribute.strikeThrough),
                    tooltip: 'Gạch ngang',
                  ),
                  const VerticalDivider(),
                  IconButton(
                    icon: const Icon(Icons.format_size),
                    onPressed: () {
                      // Show font size picker
                      _showFontSizePicker();
                    },
                    tooltip: 'Kích thước chữ',
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_list_bulleted),
                    onPressed: () => _applyFormat(quill.Attribute.ul),
                    tooltip: 'Danh sách',
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_list_numbered),
                    onPressed: () => _applyFormat(quill.Attribute.ol),
                    tooltip: 'Danh sách số',
                  ),
                  const VerticalDivider(),
                  IconButton(
                    icon: const Icon(Icons.format_color_text),
                    onPressed: () {
                      // Show color picker
                      _showColorPicker(false);
                    },
                    tooltip: 'Màu chữ',
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_color_fill),
                    onPressed: () {
                      // Show background color picker
                      _showColorPicker(true);
                    },
                    tooltip: 'Màu nền',
                  ),
                ],
              ),
            ),
          ),
          
          const Divider(height: 1),
          
          // Editor
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: quill.QuillEditor.basic(
                configurations: quill.QuillEditorConfigurations(
                  controller: _quillController,
                  placeholder: 'Bắt đầu viết...',
                  padding: EdgeInsets.zero,
                  scrollable: true,
                  autoFocus: false,
                  expands: false,
                  embedBuilders: [
                    ResizableImageEmbedBuilder(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(bool isBackground) {
    final colors = [
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.orange,
      Colors.purple,
      Colors.pink,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isBackground ? 'Chọn màu nền' : 'Chọn màu chữ'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((color) {
            return InkWell(
              onTap: () {
                final colorHex = '#${color.value.toRadixString(16).substring(2)}';
                if (isBackground) {
                  final attr = quill.Attribute.fromKeyValue('bg', colorHex);
                  if (attr != null) _applyFormat(attr);
                } else {
                  final attr = quill.Attribute.fromKeyValue('color', colorHex);
                  if (attr != null) _applyFormat(attr);
                }
                Navigator.pop(context);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showFontSizePicker() {
    final sizes = [
      {'label': 'Rất nhỏ', 'value': '8'},
      {'label': 'Nhỏ', 'value': '12'},
      {'label': 'Bình thường', 'value': '15'}, // Clear size attribute
      {'label': 'Lớn', 'value': '18'},
      {'label': 'Rất lớn', 'value': '22'},
      {'label': 'Khổng lồ', 'value': '28'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn kích thước chữ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: sizes.map((size) {
            return ListTile(
              title: Text(
                size['label'].toString(),
                style: TextStyle(
                  fontSize: _getSizePreview(size['value']?.toString()),
                ),
              ),
              onTap: () {
                final sizeValue = size['value']?.toString();
                if (sizeValue == null) {
                  // Clear size formatting
                  _quillController.formatSelection(quill.Attribute.clone(quill.Attribute.size, null));
                } else {
                  final attr = quill.Attribute.fromKeyValue('size', sizeValue);
                  if (attr != null) _applyFormat(attr);
                }
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  double _getSizePreview(String? size) {
    switch (size) {
      case 'small':
        return 12.0;
      case '12':
        return 12.0;
      case '18':
        return 18.0;
      case 'large':
        return 20.0;
      case 'huge':
        return 24.0;
      default:
        return 16.0;
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

// Custom embed builder for resizable images
class ResizableImageEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'image';

  @override
  Widget build(
    BuildContext context,
    quill.QuillController controller,
    quill.Embed node,
    bool readOnly,
    bool inline,
    TextStyle textStyle,
  ) {
    final imageUrl = node.value.data;
    return ResizableImageWidget(
      imageUrl: imageUrl,
      readOnly: readOnly,
    );
  }
}

// Stateful widget for resizable image
class ResizableImageWidget extends StatefulWidget {
  final String imageUrl;
  final bool readOnly;

  const ResizableImageWidget({
    Key? key,
    required this.imageUrl,
    this.readOnly = false,
  }) : super(key: key);

  @override
  State<ResizableImageWidget> createState() => _ResizableImageWidgetState();
}

class _ResizableImageWidgetState extends State<ResizableImageWidget> {
  double _width = 300.0;
  double _initialWidth = 300.0;

  @override
  Widget build(BuildContext context) {
    final file = File(widget.imageUrl);
    
    if (!file.existsSync()) {
      return Container(
        padding: const EdgeInsets.all(8),
        child: const Row(
          children: [
            Icon(Icons.broken_image, color: Colors.grey),
            SizedBox(width: 8),
            Text('Hình ảnh không tồn tại'),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onScaleStart: (details) {
              _initialWidth = _width;
            },
            onScaleUpdate: (details) {
              setState(() {
                _width = (_initialWidth * details.scale).clamp(100.0, 600.0);
              });
            },
            child: Container(
              width: _width,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  file,
                  width: _width,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          if (!widget.readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Pinch để thay đổi kích thước',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          // Alternative: Slider for precise control
          if (!widget.readOnly)
            Slider(
              value: _width,
              min: 100,
              max: 600,
              divisions: 50,
              label: '${_width.toInt()}px',
              onChanged: (value) {
                setState(() {
                  _width = value;
                });
              },
            ),
        ],
      ),
    );
  }
}
