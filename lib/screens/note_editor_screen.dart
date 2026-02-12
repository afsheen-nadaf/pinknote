import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart'; 
import 'package:flutter/services.dart'; 
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:audioplayers/audioplayers.dart';

import '../models/note.dart';
import '../models/category.dart';
import '../services/notes_service.dart';
import '../utils/app_constants.dart';
import '../services/services.dart'; 
import '../widgets/category_form_modal.dart'; 
import '../widgets/custom_keypad.dart'; 
import '../widgets/custom_quill_toolbar.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final FirestoreService firestoreService;
  final List<Category> availableCategories; 
  final bool isAuthenticated; 

  const NoteEditorScreen({
    super.key,
    this.note,
    required this.firestoreService,
    required this.availableCategories,
    this.isAuthenticated = false, 
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> with WidgetsBindingObserver {
  late final TextEditingController _titleController;
  late final quill.QuillController _quillController;
  late final ScrollController _editorScrollController;
  late final FocusNode _editorFocusNode;
  late final AudioPlayer _audioPlayer;
  
  bool _isPinned = false;
  bool _isFavorite = false;
  bool _isLocked = false;
  bool _isArchived = false;
  String? _passwordHash;
  String? _selectedCategoryId;
  int _selectedColorValue = 0xFFFFF8E1;
  late DateTime _createdAt;
  
  String? _currentNoteId;
  late bool _canViewContent; 
  
  Timer? _autoSaveTimer;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _editorScrollController = ScrollController();
    _editorFocusNode = FocusNode();
    _audioPlayer = AudioPlayer();
    _currentNoteId = widget.note?.id;
    
    _initializeQuillController();
    
    _isPinned = widget.note?.isPinned ?? false;
    _isFavorite = widget.note?.isFavorite ?? false;
    _isLocked = widget.note?.isLocked ?? false;
    _isArchived = widget.note?.isArchived ?? false;
    _passwordHash = widget.note?.passwordHash;
    _selectedCategoryId = widget.note?.categoryId;
    _selectedColorValue = widget.note?.colorValue ?? 0xFFFFF8E1;
    _createdAt = widget.note?.createdAt ?? DateTime.now();

    _canViewContent = !_isLocked || widget.isAuthenticated;

    _titleController.addListener(_onTextChanged);
    _quillController.document.changes.listen((event) {
      _onTextChanged();
    });
  }

  void _initializeQuillController() {
    try {
      if (widget.note?.content != null && widget.note!.content.isNotEmpty) {
        final json = jsonDecode(widget.note!.content);
        _quillController = quill.QuillController(
          document: quill.Document.fromJson(json),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        _quillController = quill.QuillController.basic();
      }
    } catch (e) {
      final plainText = widget.note?.content ?? '';
      final doc = quill.Document()..insert(0, plainText);
      _quillController = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    _saveNote();
    
    _titleController.dispose();
    _quillController.dispose();
    _editorScrollController.dispose();
    _editorFocusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _saveNote();
    }
  }

  void _onTextChanged() {
    _isDirty = true;
    if (_autoSaveTimer?.isActive ?? false) _autoSaveTimer!.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _saveNote);
  }

  Future<void> _saveNote() async {
    if (!_isDirty) return;
    
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final title = _titleController.text.trim();
    final contentJson = jsonEncode(_quillController.document.toDelta().toJson());
    final plainText = _quillController.document.toPlainText().trim();

    if (title.isEmpty && plainText.isEmpty && _currentNoteId == null) return;

    final idToUse = _currentNoteId ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    final note = Note(
      id: idToUse,
      userId: userId,
      title: title,
      content: contentJson, 
      isPinned: _isPinned,
      isFavorite: _isFavorite,
      isLocked: _isLocked,
      isArchived: _isArchived,
      passwordHash: _passwordHash,
      categoryId: _selectedCategoryId,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
      colorValue: _selectedColorValue,
    );

    if (_currentNoteId == null) {
      await notesService.addNote(note);
      if (mounted) {
        setState(() {
          _currentNoteId = idToUse;
        });
      } else {
        _currentNoteId = idToUse;
      }
    } else {
      await notesService.updateNote(note);
    }
    
    _isDirty = false;
  }

  void _shareNote() {
    final text = "${_titleController.text}\n\n${_quillController.document.toPlainText()}";
    Share.share(text);
  }

  Future<void> _playFavoriteSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/mark_as_important.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void _toggleLock() {
    if (_isLocked) {
      setState(() {
        _isLocked = false;
        _passwordHash = null;
        _isDirty = true;
        _canViewContent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("note unlocked"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        )
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return CustomKeypad(
            pinLength: 4,
            onCancel: () => Navigator.pop(context),
            onPinEntered: (pin) {
              if (pin.length >= 4) {
                setState(() {
                  _isLocked = true;
                  _passwordHash = pin.hashCode.toString(); 
                  _isDirty = true;
                  _canViewContent = true; 
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("note locked"),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  )
                );
              }
            },
          );
        },
      );
    }
  }

  void _showCategoryForm(BuildContext context, Category? existingCategory, List<Category> currentCategories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CategoryFormModal(
        category: existingCategory,
        firestoreService: widget.firestoreService,
        currentCategories: currentCategories,
        existingCategories: currentCategories,
        onSave: (category) {
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    final backgroundColor = isDarkMode ? AppColors.darkBackground : Color(_selectedColorValue);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDarkMode ? Colors.white : AppColors.textDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: _isPinned ? AppColors.primaryPink : (isDarkMode ? Colors.white : AppColors.textDark),
            ),
            onPressed: () {
              setState(() {
                _isPinned = !_isPinned;
                _isDirty = true;
              });
            },
          ),
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : (isDarkMode ? Colors.white : AppColors.textDark),
            ),
            onPressed: () {
              _playFavoriteSound();
              setState(() {
                _isFavorite = !_isFavorite;
                _isDirty = true;
              });
            },
          ),
          IconButton(
            icon: Icon(
              _isLocked ? Icons.lock : Icons.lock_open,
              color: _isLocked ? AppColors.primaryPink : (isDarkMode ? Colors.white : AppColors.textDark),
            ),
            onPressed: _toggleLock,
          ),
          IconButton(
            icon: Icon(Icons.share_outlined, color: isDarkMode ? Colors.white : AppColors.textDark),
            onPressed: _shareNote,
          ),
          IconButton(
            icon: Icon(
              Icons.inventory_2, 
              color: _isArchived ? AppColors.primaryPink : (isDarkMode ? Colors.white : AppColors.textDark)
            ),
            onPressed: () {
              setState(() {
                _isArchived = !_isArchived;
                _isDirty = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isArchived ? "note archived" : "note unarchived"),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                )
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildEditor(isDarkMode),
    );
  }

  Widget _buildEditor(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: TextField(
            controller: _titleController,
            style: GoogleFonts.quicksand(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppColors.textDark,
            ),
            decoration: InputDecoration(
              hintText: 'title',
              hintStyle: GoogleFonts.quicksand(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white38 : AppColors.textLight,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "${_createdAt.day} ${_createdAt.monthName()} ${_createdAt.year}  ${_createdAt.hour}:${_createdAt.minute.toString().padLeft(2, '0')}",
            style: GoogleFonts.quicksand(
              fontSize: 12,
              color: isDarkMode ? Colors.white70 : AppColors.textLight,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(),
        ),
        
        StreamBuilder<List<Category>>(
          stream: widget.firestoreService.getCategories(), 
          initialData: widget.availableCategories,
          builder: (context, snapshot) {
            final categories = snapshot.data ?? [];
            return _buildCategorySelector(categories);
          },
        ),

        const SizedBox(height: 10),

        CustomQuillToolbar(controller: _quillController),
        
        Expanded(
          child: _StableQuillEditor(
            controller: _quillController,
            focusNode: _editorFocusNode,
            scrollController: _editorScrollController,
            canViewContent: _canViewContent,
            isDarkMode: isDarkMode,
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector(List<Category> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length + 1,
            itemBuilder: (context, index) {
              if (index == categories.length) {
                return _buildAddCategoryChip(categories);
              }
              final category = categories[index];
              final isSelected = _selectedCategoryId == category.id;
              return _buildCategoryChip(category, isSelected, categories);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddCategoryChip(List<Category> currentCategories) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        avatar: const Icon(Icons.add, color: AppColors.primaryPink, size: 18),
        label: Text('new', style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primaryPink)),
        backgroundColor: isDarkMode ? AppColors.darkSurface : theme.colorScheme.surface,
        onPressed: () => _showCategoryForm(context, null, currentCategories),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDarkMode ? AppColors.darkBorder : theme.colorScheme.outline),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(Category category, bool isSelected, List<Category> currentCategories) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color getTextColor() {
      if (isSelected) {
        return ThemeData.estimateBrightnessForColor(category.color) == Brightness.dark ? Colors.white : Colors.black;
      }
      return isDark ? Colors.white70 : theme.colorScheme.onSurface;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onLongPress: () {
          if (category.name != 'general') {
            _showCategoryManagementOptions(category, currentCategories);
          }
        },
        child: ChoiceChip(
          avatar: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.circle,
            ),
          ),
          label: Text(category.name),
          selected: isSelected,
          onSelected: (selected) {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedCategoryId = isSelected ? null : category.id;
              _isDirty = true;
            });
          },
          selectedColor: category.color,
          backgroundColor: isSelected ? category.color : (isDark ? category.color.withOpacity(0.25) : category.color.withOpacity(0.1)),
          labelStyle: theme.textTheme.labelMedium?.copyWith(color: getTextColor()),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isSelected ? category.color : (isDark ? AppColors.darkBorder : theme.colorScheme.outline)),
          ),
        ),
      ),
    );
  }

  void _showCategoryManagementOptions(Category category, List<Category> currentCategories) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.softCream,
        title: Text('manage "${category.name}"', style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'Quicksand', color: isDark ? Colors.white : null)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showCategoryForm(context, category, currentCategories);
            },
            child: const Text('edit', style: TextStyle(color: AppColors.primaryPink)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteCategory(category);
            },
            child: Text('delete', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.errorRed)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.errorRed))),
        ],
      ),
    );
  }
  
  void _confirmDeleteCategory(Category category) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.softCream,
        title: Text('delete category?', style: theme.textTheme.titleMedium?.copyWith(color: isDark ? Colors.white : null)),
        content: Text('tasks in "${category.name}" will be moved to "general".', style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white70 : null)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('cancel', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.errorRed))),
          TextButton(
            onPressed: () {
              widget.firestoreService.deleteCategory(category.id);
              if (_selectedCategoryId == category.id) {
                setState(() => _selectedCategoryId = null);
              }
              Navigator.of(context).pop();
            },
            child: Text('delete', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
  }
}

class _StableQuillEditor extends StatefulWidget {
  final quill.QuillController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final bool canViewContent;
  final bool isDarkMode;

  const _StableQuillEditor({
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.canViewContent,
    required this.isDarkMode,
  });

  @override
  State<_StableQuillEditor> createState() => _StableQuillEditorState();
}

class _StableQuillEditorState extends State<_StableQuillEditor> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        children: [
          Opacity(
            opacity: widget.canViewContent ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !widget.canViewContent,
              child: quill.QuillEditor(
                controller: widget.controller,
                focusNode: widget.focusNode,
                scrollController: widget.scrollController,
                config: quill.QuillEditorConfig(
                  placeholder: 'what\'s on your mind?',
                ),
              ),
            ),
          ),
          if (!widget.canViewContent)
            Center(
              child: Text(
                "🔒 note is locked",
                style: GoogleFonts.quicksand(
                  fontSize: 18,
                  color: widget.isDarkMode ? Colors.white70 : AppColors.textLight,
                ),
              ),
            ),
        ],
      ),
    );
  }
}