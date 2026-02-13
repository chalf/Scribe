import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../services/database_service.dart';
import 'note_editor_screen.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    final notes = await _databaseService.readAllNotes();
    setState(() {
      _notes = notes;
      _filteredNotes = notes;
      _isLoading = false;
    });
  }

  void _searchNotes(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredNotes = _notes;
      });
    } else {
      final results = await _databaseService.searchNotes(query);
      setState(() {
        _filteredNotes = results;
      });
    }
  }

  Future<void> _createNewNote() async {
    final uuid = const Uuid();
    final now = DateTime.now();
    final newNote = Note(
      id: uuid.v4(),
      title: 'Ghi chú mới',
      content: '[{"insert":"\\n"}]', // Empty Quill document
      createdAt: now,
      updatedAt: now,
    );

    await _databaseService.createNote(newNote);
    
    if (!mounted) return;
    
    // Navigate to editor
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(note: newNote),
      ),
    );

    if (result == true) {
      _loadNotes();
    }
  }

  Future<void> _deleteNote(Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa ghi chú'),
        content: Text('Bạn có chắc muốn xóa "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _databaseService.deleteNote(note.id);
      _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: _searchNotes,
              )
            : const Text('Scribe Notes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filteredNotes = _notes;
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredNotes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.note_add,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _notes.isEmpty
                            ? 'Chưa có ghi chú nào'
                            : 'Không tìm thấy kết quả',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotes,
                  child: ListView.builder(
                    itemCount: _filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = _filteredNotes[index];
                      return _buildNoteCard(note);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewNote,
        tooltip: 'Tạo ghi chú mới',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(
          note.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _getPreviewText(note.content),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              dateFormat.format(note.updatedAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteNote(note),
        ),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoteEditorScreen(note: note),
            ),
          );

          if (result == true) {
            _loadNotes();
          }
        },
      ),
    );
  }

  String _getPreviewText(String content) {
    try {
      if (content.isEmpty) return 'Ghi chú trống';
      
      // Parse Quill Delta JSON to extract plain text
      final List<dynamic> delta = jsonDecode(content);
      final StringBuffer buffer = StringBuffer();
      
      for (var op in delta) {
        if (op is Map && op.containsKey('insert')) {
          final insert = op['insert'];
          
          // If insert is a string, add it to buffer
          if (insert is String) {
            buffer.write(insert);
          } 
          // If insert is a Map (like image embed), show a placeholder
          else if (insert is Map) {
            if (insert.containsKey('image')) {
              buffer.write('[Hình ảnh] ');
            }
          }
        }
      }
      
      String plainText = buffer.toString().trim();
      
      // Remove extra newlines and whitespace
      plainText = plainText.replaceAll(RegExp(r'\n+'), ' ');
      plainText = plainText.replaceAll(RegExp(r'\s+'), ' ');
      
      if (plainText.isEmpty) return 'Ghi chú trống';
      
      return plainText.length > 100 
          ? '${plainText.substring(0, 100)}...' 
          : plainText;
    } catch (e) {
      return 'Ghi chú trống';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
