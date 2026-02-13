# Scribe - Note Taking App

A feature-rich note-taking app similar to Samsung Notes, built with Flutter.

## Features

### ✨ Rich Text Editing
- **Text Formatting**: Bold, Italic, Underline, Strikethrough
- **Font Sizes**: Small, Normal, Large, Huge
- **Headers**: H1, H2, H3
- **Text Colors**: Change text color and highlight (background) color
- **Lists**: Bulleted and numbered lists
- **Alignment**: Left, Center, Right alignment
- **Clear Formatting**: Remove all formatting

### 📝 Note Management
- Create multiple notes
- Edit existing notes
- Delete notes with confirmation
- Auto-save functionality
- Search notes by title or content
- Notes sorted by last update time

### 🖼️ Image Support
- Add images from gallery
- Images embedded in notes
- Images stored with notes

### 💾 Export Options
- Export notes as TXT files
- Export notes as Word documents (RTF format)
- Share exported files

### 🔍 Search Functionality
- Real-time search
- Search in note title and content
- Clear search with one tap

## Technical Stack

- **Framework**: Flutter
- **Rich Text Editor**: flutter_quill
- **Database**: SQLite (sqflite)
- **Image Picker**: image_picker
- **File Sharing**: share_plus
- **Local Storage**: path_provider

## Installation

1. Make sure you have Flutter installed on your system
2. Clone this repository
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   └── note.dart               # Note data model
├── screens/
│   ├── notes_list_screen.dart  # Main screen with notes list
│   └── note_editor_screen.dart # Note editing screen
├── services/
│   ├── database_service.dart   # SQLite database operations
│   └── export_service.dart     # Export to TXT/Word
└── widgets/
    └── toolbar_widget.dart     # Rich text formatting toolbar
```

## How to Use

### Creating a Note
1. Tap the **+** button at the bottom right
2. Enter a title for your note
3. Use the formatting toolbar to style your text
4. Tap the **Save** icon to save

### Formatting Text
- Use the toolbar at the top of the editor
- Select text and apply formatting:
  - **B**: Bold
  - **I**: Italic
  - **U**: Underline
  - **S**: Strikethrough
  - **Size**: Change font size
  - **Colors**: Text and highlight colors
  - **Align**: Text alignment
  - **Lists**: Bullet or numbered
  - **Image**: Add images
  - **Clear**: Remove formatting

### Searching Notes
1. Use the search bar at the top of the main screen
2. Type keywords to filter notes
3. Tap **X** to clear search

### Exporting Notes
1. Open a note
2. Tap the **⋮** menu icon
3. Choose "Export as TXT" or "Export as Word"
4. Share the exported file

### Deleting Notes
1. On the main screen, tap the **Delete** icon on any note
2. Confirm deletion

## Features in Detail

### Database
- Notes stored locally using SQLite
- Persistent storage across app restarts
- Fast queries for search

### Rich Text Format
- Content stored as Quill Delta JSON
- Preserves all formatting
- Supports complex text structures

### Export Format
- **TXT**: Plain text without formatting
- **Word**: RTF format (compatible with Microsoft Word)

## Platform Support

- ✅ Android
- ✅ iOS
- ✅ macOS
- ✅ Windows
- ✅ Linux

## Dependencies

```yaml
dependencies:
  flutter_quill: ^11.5.0      # Rich text editor
  sqflite: ^2.4.1              # Local database
  path_provider: ^2.1.5        # File paths
  image_picker: ^1.1.2         # Image selection
  file_picker: ^10.3.10        # File operations
  share_plus: ^12.0.1          # File sharing
  uuid: ^4.5.2                 # Unique IDs
```

## Future Enhancements

Possible features to add:
- [ ] Cloud sync
- [ ] Categories/Tags
- [ ] Note locking with PIN
- [ ] Voice notes
- [ ] Drawing/Sketching
- [ ] PDF export
- [ ] Markdown support
- [ ] Dark mode
- [ ] Note templates
- [ ] Reminders

## License

This project is for educational purposes.

## Contributing

Feel free to contribute by:
- Reporting bugs
- Suggesting features
- Submitting pull requests

---

Built with ❤️ using Flutter

