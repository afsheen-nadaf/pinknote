import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter/services.dart';
import '../models/note.dart';
import '../models/category.dart';
import '../services/notes_service.dart';
import '../services/services.dart'; 
import '../services/firestore_service.dart';
import '../utils/app_constants.dart';
import '../widgets/note_card.dart';
import '../widgets/category_form_modal.dart';
import '../widgets/custom_keypad.dart'; 
import 'note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final List<Category> availableCategories;

  const NotesScreen({
    super.key,
    required this.firestoreService,
    required this.availableCategories,
  });

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _isGridView = true;
  String _searchQuery = "";
  String? _filterCategory;
  bool _showArchived = false;
  bool _showFavoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // 1. Search Bar (Scrollable now)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), // Reduced top padding to bring closer to app bar
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 45,
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppColors.darkSurface : AppColors.softCream,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                        style: GoogleFonts.quicksand(fontSize: 14, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'search notes...',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryPink),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          hintStyle: GoogleFonts.quicksand(fontSize: 14, color: isDarkMode ? Colors.white54 : Colors.black45),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: Icon(_isGridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded),
                    color: isDarkMode ? Colors.white : AppColors.textDark,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _isGridView = !_isGridView);
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // 2. Special Filters
          SliverToBoxAdapter(
            child: Center(
              child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSpecialFilterChip("all notes", !_showArchived && !_showFavoritesOnly, () {
                    setState(() { _showArchived = false; _showFavoritesOnly = false; _filterCategory = null; });
                  }),
                  const SizedBox(width: 8),
                  _buildSpecialFilterChip("favorites", _showFavoritesOnly, () {
                    setState(() { _showFavoritesOnly = !_showFavoritesOnly; _showArchived = false; });
                  }),
                  const SizedBox(width: 8),
                  _buildSpecialFilterChip("archived", _showArchived, () {
                    setState(() { _showArchived = !_showArchived; _showFavoritesOnly = false; });
                  }),
                ],
              ),
            ),
            ),
          ),

          // 3. Category Selector
          SliverToBoxAdapter(
            child: _buildCategorySelector(),
          ),

          // 4. Notes Grid/List
          StreamBuilder<List<Note>>(
            stream: notesService.getNotes(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverToBoxAdapter(child: _buildEmptyState(theme, 'oops! something went wrong.', icon: Icons.error_outline_rounded, iconColor: AppColors.errorRed));
              }
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                 return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primaryPink)));
              }
              
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                 return SliverToBoxAdapter(child: SizedBox(height: 300, child: _buildEmptyState(theme, 'no notes yet', icon: Icons.note_alt_outlined)));
              }

              // Filter Logic
              var notes = snapshot.data!.where((note) {
                if (_searchQuery.isNotEmpty) {
                  if (!note.title.toLowerCase().contains(_searchQuery) && 
                      !note.content.toLowerCase().contains(_searchQuery)) {
                    return false;
                  }
                }
                if (_filterCategory != null && note.categoryId != _filterCategory) return false;
                if (_showArchived) return note.isArchived;
                if (_showFavoritesOnly) return note.isFavorite && !note.isArchived;
                return !note.isArchived; 
              }).toList();

              // Sort Pinned notes to the top
              notes.sort((a, b) {
                if (a.isPinned != b.isPinned) {
                  return a.isPinned ? -1 : 1; 
                }
                return b.updatedAt.compareTo(a.updatedAt);
              });

              if (notes.isEmpty) {
                 return SliverToBoxAdapter(child: SizedBox(height: 300, child: _buildEmptyState(theme, 'no matches found', icon: Icons.search_off_rounded)));
              }

              if (_isGridView) {
                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childCount: notes.length,
                    itemBuilder: (context, index) {
                       final note = notes[index];
                       Category? category;
                       if (note.categoryId != null) {
                         try {
                           category = widget.availableCategories.firstWhere((c) => c.id == note.categoryId);
                         } catch (e) { }
                       }

                       return NoteCard(
                         note: note, 
                         categoryColor: category?.color,
                         categoryName: category?.name,
                         borderColor: note.isPinned ? AppColors.primaryPink : category?.color,
                         onTap: () => _openNote(context, note),
                         onLongPress: () => _showNoteOptions(context, note),
                       );
                    },
                  ),
                );
              } else {
                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final note = notes[index];
                         Category? category;
                         if (note.categoryId != null) {
                           try {
                             category = widget.availableCategories.firstWhere((c) => c.id == note.categoryId);
                           } catch (e) { }
                         }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: NoteCard(
                            note: note, 
                            isListMode: true,
                            categoryColor: category?.color,
                            categoryName: category?.name,
                            borderColor: note.isPinned ? AppColors.primaryPink : category?.color,
                            onTap: () => _openNote(context, note),
                            onLongPress: () => _showNoteOptions(context, note),
                          ),
                        );
                      },
                      childCount: notes.length,
                    ),
                  ),
                );
              }
            },
          ),
          
          // Bottom Spacer
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'notes_fab_main',
        onPressed: () {
          soundService.playAddTaskSound();
          // Adding new note: Not locked, so authenticated by default
          _openNote(context, null);
        },
        backgroundColor: AppColors.primaryPink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
        elevation: 10.0,
        label: Text(
          'add note',
          style: theme.textTheme.labelLarge?.copyWith(color: isDarkMode ? Colors.black : Colors.white),
        ),
        icon: Icon(Icons.add_rounded, color: isDarkMode ? Colors.black : Colors.white, size: 24),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --- LOGIC METHODS ---

  void _openNote(BuildContext context, Note? note) {
    HapticFeedback.lightImpact();
    
    if (note != null && note.isLocked) {
      // Locked Note: Must Authenticate First
      _showUnlockDialog(context, note);
    } else {
      // Unlocked or New Note: Authenticated by default
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NoteEditorScreen(
            note: note, 
            firestoreService: widget.firestoreService,
            availableCategories: widget.availableCategories,
            isAuthenticated: true, // Auto-auth for non-locked notes
          ),
        ),
      );
    }
  }

  void _showUnlockDialog(BuildContext context, Note note) {
    soundService.playModalOpeningSound();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String? errorMessage;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return CustomKeypad(
              pinLength: 4,
              errorMessage: errorMessage,
              onCancel: () => Navigator.pop(context),
              onPinEntered: (pin) {
                if (pin.hashCode.toString() == note.passwordHash) {
                  Navigator.pop(context); // Close keypad
                  // Success: Navigate with auth flag true
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteEditorScreen(
                        note: note, 
                        firestoreService: widget.firestoreService,
                        availableCategories: widget.availableCategories,
                        isAuthenticated: true, 
                      ),
                    ),
                  );
                } else {
                  HapticFeedback.heavyImpact(); 
                  setState(() {
                    errorMessage = "incorrect pin";
                  });
                }
              },
            );
          },
        );
      },
    );
  }

  // --- CATEGORY WIDGETS (Adapted for Sliver context usage within ToBoxAdapter) ---

  Widget _buildCategorySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: widget.availableCategories.length + 1,
          itemBuilder: (context, index) {
            if (index == widget.availableCategories.length) {
              return _buildAddCategoryChip();
            }
            final category = widget.availableCategories[index];
            final isSelected = _filterCategory == category.id;
            return _buildCategoryChip(category, isSelected);
          },
        ),
      ),
    );
  }

  Widget _buildAddCategoryChip() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        avatar: const Icon(Icons.add, color: AppColors.primaryPink, size: 18),
        label: Text('new', style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primaryPink)),
        backgroundColor: theme.colorScheme.surface,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => CategoryFormModal(
              firestoreService: widget.firestoreService,
              currentCategories: widget.availableCategories,
              existingCategories: widget.availableCategories,
              onSave: (newCategory) {
                widget.firestoreService.addCategory(newCategory);
              },
            ),
          );
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(Category category, bool isSelected) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color getTextColor() {
      if (isSelected) {
        return ThemeData.estimateBrightnessForColor(category.color) == Brightness.dark ? Colors.white : Colors.black;
      }
      return theme.colorScheme.onSurface;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onLongPress: () {
          if (category.name != 'general') {
            _showCategoryManagementOptions(category);
          }
        },
        child: ChoiceChip(
          avatar: category.name != 'general'
              ? Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: category.color,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          label: Text(category.name),
          selected: isSelected,
          onSelected: (selected) {
            HapticFeedback.selectionClick();
            setState(() {
              if (isSelected) {
                _filterCategory = null;
              } else {
                _filterCategory = category.id;
                _showArchived = false;
                _showFavoritesOnly = false;
              }
            });
          },
          selectedColor: category.color,
          backgroundColor: isSelected ? category.color : (isDark ? category.color.withOpacity(0.25) : category.color.withOpacity(0.1)),
          labelStyle: theme.textTheme.labelMedium?.copyWith(color: getTextColor()),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isSelected ? category.color : theme.colorScheme.outline),
          ),
        ),
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildSpecialFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPink : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryPink.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : AppColors.primaryPink,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message, {IconData icon = Icons.note_alt_outlined, Color? iconColor}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: iconColor ?? theme.disabledColor),
          const SizedBox(height: 10),
          Text(message, style: GoogleFonts.quicksand(color: theme.disabledColor)),
        ],
      ),
    );
  }

  void _showCategoryManagementOptions(Category category) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.softCream,
        title: Text('manage "${category.name}"', style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'Quicksand')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CategoryFormModal(
                  firestoreService: widget.firestoreService,
                  currentCategories: widget.availableCategories,
                  category: category,
                  existingCategories: widget.availableCategories,
                  onSave: (updatedCategory) {
                    widget.firestoreService.updateCategory(updatedCategory);
                  },
                ),
              );
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
        title: Text('delete category?', style: theme.textTheme.titleMedium),
        content: Text('tasks in "${category.name}" will be moved to "general".', style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('cancel', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.errorRed))),
          TextButton(
            onPressed: () {
              widget.firestoreService.deleteCategory(category.id);
              if (_filterCategory == category.id) {
                setState(() => _filterCategory = null);
              }
              Navigator.of(context).pop();
            },
            child: Text('delete', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
  }

  void _showNoteOptions(BuildContext context, Note note) {
    soundService.playModalOpeningSound();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final modalColor = isDarkMode ? Colors.black : AppColors.softCream;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: modalColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.5), width: 1.0),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin, color: AppColors.primaryPink),
              title: Text(note.isPinned ? 'unpin' : 'pin'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              onTap: () {
                notesService.togglePin(note.id, note.isPinned);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(note.isFavorite ? Icons.favorite_border : Icons.favorite, color: AppColors.errorRed),
              title: Text(note.isFavorite ? 'unfavorite' : 'favorite'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              onTap: () {
                notesService.toggleFavorite(note.id, note.isFavorite);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(note.isArchived ? Icons.unarchive : Icons.archive, color: AppColors.accentBlue),
              title: Text(note.isArchived ? 'unarchive' : 'archive'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              onTap: () {
                notesService.toggleArchive(note.id, note.isArchived);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.errorRed),
              title: const Text('delete'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              onTap: () {
                Navigator.pop(context);
                _deleteNoteWithUndo(context, note);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteNoteWithUndo(BuildContext context, Note note) {
    soundService.playSwipeDeleteSound();
    notesService.deleteNote(note.id);
    
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          'note deleted',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
        ),
        action: SnackBarAction(
          label: 'undo',
          textColor: AppColors.primaryPink,
          onPressed: () {
            notesService.addNote(note);
          },
        ),
        backgroundColor: theme.cardColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: BorderSide(color: AppColors.primaryPink.withOpacity(0.3)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        elevation: 6.0,
      ));
  }
}