import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/note.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('notes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const nullableTextType = 'TEXT';

    await db.execute('''
      CREATE TABLE notes (
        id $idType,
        title $textType,
        content $textType,
        createdAt $textType,
        updatedAt $textType,
        imagePath $nullableTextType
      )
    ''');
  }

  // Create a new note
  Future<Note> createNote(Note note) async {
    final db = await database;
    await db.insert('notes', note.toMap());
    return note;
  }

  // Read a single note
  Future<Note?> readNote(String id) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Note.fromMap(maps.first);
    }
    return null;
  }

  // Read all notes
  Future<List<Note>> readAllNotes() async {
    final db = await database;
    final result = await db.query(
      'notes',
      orderBy: 'updatedAt DESC',
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  // Update a note
  Future<int> updateNote(Note note) async {
    final db = await database;
    return db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  // Delete a note
  Future<int> deleteNote(String id) async {
    final db = await database;
    return db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Search notes by keyword
  Future<List<Note>> searchNotes(String query) async {
    final db = await database;
    final result = await db.query(
      'notes',
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'updatedAt DESC',
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  // Close database
  Future close() async {
    final db = await database;
    db.close();
  }
}
