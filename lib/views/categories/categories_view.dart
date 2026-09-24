import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/app_provider.dart';
import '../../services/adaptive_image_service.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../utils/quantity_utils.dart';
import '../../widgets/adaptive_image_preview.dart';
import '../../widgets/cart_checkout.dart';
import '../../widgets/workspace_ui.dart';

/// A two-pane catalogue browser.  The category rail is intentionally retained
/// on phones; only its width changes, so selecting a category never forces the
/// user through a separate screen or obscures the checkout action.
class CategoriesView extends StatefulWidget {
  const CategoriesView({super.key});

  @override
  State<CategoriesView> createState() => _CategoriesViewState();
}

enum _CategoryLayout { sidebar, dropdown, gallery }

class _CategoriesViewState extends State<CategoriesView> {
  static const _pageSize = 30;

  final _productsController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _isLoading = true;
  bool _isLoadingProducts = false;
  bool _isLoadingMore = false;
  bool _hasMoreProducts = true;
  int _page = 1;
  int? _selectedCategoryId;
  String _search = '';
  List<dynamic> _categories = [];
  List<dynamic> _products = [];
  _CategoryLayout _layout = _CategoryLayout.sidebar;

  @override
  void initState() {
    super.initState();
    _productsController.addListener(_loadMoreWhenNeeded);
    _fetchCategories();
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    final saved = await StorageService.getCategoryLayout();
    if (!mounted || saved == null) return;
    setState(() {
      _layout = _CategoryLayout.values.firstWhere(
        (layout) => layout.name == saved,
        orElse: () => _CategoryLayout.sidebar,
      );
    });
  }

  void _setLayout(_CategoryLayout layout) {
    if (_layout == layout) return;
    // A search field from the previous layout can retain focus in the
    // workspace. Clear it so switching views cannot summon the keyboard.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _layout = layout);
    StorageService.saveCategoryLayout(layout.name);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _productsController
      ..removeListener(_loadMoreWhenNeeded)
      ..dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get(ApiConfig.categories);
      final items = res['success'] == true ? (res['data'] as List? ?? []) : [];
      if (!mounted) return;
      final hasCurrent = items.any((item) => item['id'] == _selectedCategoryId);
      setState(() {
        _categories = items;
        _selectedCategoryId = hasCurrent
            ? _selectedCategoryId
            : (items.isEmpty ? null : items.first['id'] as int?);
        _isLoading = false;
        if (_selectedCategoryId == null) _products = [];
      });
      if (_selectedCategoryId != null) await _fetchProducts(reset: true);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProducts({bool reset = false}) async {
    if (_selectedCategoryId == null ||
        _isLoadingMore ||
        (!reset && (!_hasMoreProducts || _isLoadingProducts))) {
      return;
    }
    final nextPage = reset ? 1 : _page + 1;
    setState(() {
      if (reset) {
        _isLoadingProducts = true;
        _hasMoreProducts = true;
      } else {
        _isLoadingMore = true;
      }
    });
    try {
      final res = await ApiService.get(ApiConfig.products, queryParameters: {
        'categoryId': _selectedCategoryId.toString(),
        'pageNumber': nextPage.toString(),
        'pageSize': _pageSize.toString(),
        if (_search.isNotEmpty) 'searchTerm': _search,
      });
      if (!mounted) return;
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final items = data['items'] as List? ?? [];
      setState(() {
        _products = reset ? items : [..._products, ...items];
        _page = nextPage;
        _hasMoreProducts = items.length >= _pageSize;
        _isLoadingProducts = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _loadMoreWhenNeeded() {
    if (_productsController.hasClients &&
        _productsController.position.extentAfter < 280) {
      _fetchProducts();
    }
  }

  void _selectCategory(int categoryId) {
    if (_selectedCategoryId == categoryId) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedCategoryId = categoryId;
      _search = '';
      _searchController.clear();
    });
    _fetchProducts(reset: true);
  }

  void _setSearch(String value) {
    _search = value.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      _fetchProducts(reset: true);
    });
  }

  Map<String, dynamic>? get _currentCategory {
    for (final item in _categories) {
      final category = Map<String, dynamic>.from(item as Map);
      if (category['id'] == _selectedCategoryId) return category;
    }
    return null;
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final name = (category['name'] ?? 'this category').toString();
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (remove != true) return;
    try {
      await ApiService.delete('${ApiConfig.categories}/${category['id']}');
      await _fetchCategories();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _openCategoryEditor({Map<String, dynamic>? category}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CategoryEditorView(category: category),
      ),
    );
    if (saved == true && mounted) await _fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_categories.isEmpty) {
      return WorkspacePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _openCategoryEditor,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add category'),
              ),
            ),
            const SizedBox(height: 20),
            const Expanded(
              child: EmptyCanvas(
                icon: Icons.account_tree_outlined,
                title: 'No categories yet',
                detail: 'Create your first category to organise products.',
              ),
            ),
          ],
        ),
      );
    }

    final selected = _currentCategory;
    return WorkspacePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  onPressed: _fetchCategories,
                  tooltip: 'Refresh categories',
                  icon: const Icon(Icons.refresh_rounded),
                ),
                PopupMenuButton<_CategoryLayout>(
                  tooltip: 'Change category layout',
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  onSelected: _setLayout,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _CategoryLayout.sidebar,
                      child: _LayoutOption(
                        icon: Icons.view_sidebar_outlined,
                        label: 'Sidebar',
                        selected: _layout == _CategoryLayout.sidebar,
                      ),
                    ),
                    PopupMenuItem(
                      value: _CategoryLayout.dropdown,
                      child: _LayoutOption(
                        icon: Icons.view_agenda_outlined,
                        label: 'Full width',
                        selected: _layout == _CategoryLayout.dropdown,
                      ),
                    ),
                    PopupMenuItem(
                      value: _CategoryLayout.gallery,
                      child: _LayoutOption(
                        icon: Icons.grid_view_rounded,
                        label: 'Gallery',
                        selected: _layout == _CategoryLayout.gallery,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final railWidth = constraints.maxWidth < 390
                    ? 82.0
                    : constraints.maxWidth < 620
                        ? 112.0
                        : 236.0;
                if (_layout == _CategoryLayout.dropdown) {
                  return _FullWidthCategoryProducts(
                    categories: _categories,
                    selectedId: _selectedCategoryId,
                    onSelect: _selectCategory,
                    onAdd: _openCategoryEditor,
                    products: _products,
                    isLoading: _isLoadingProducts,
                    isLoadingMore: _isLoadingMore,
                    controller: _productsController,
                    searchController: _searchController,
                    onSearchChanged: _setSearch,
                    onEdit: selected == null
                        ? null
                        : () => _openCategoryEditor(category: selected),
                    onDelete: selected == null
                        ? null
                        : () => _deleteCategory(selected),
                  );
                }
                if (_layout == _CategoryLayout.gallery) {
                  return _GalleryCategoryProducts(
                    categories: _categories,
                    selectedId: _selectedCategoryId,
                    onSelect: _selectCategory,
                    onAdd: _openCategoryEditor,
                    products: _products,
                    isLoading: _isLoadingProducts,
                    isLoadingMore: _isLoadingMore,
                    controller: _productsController,
                    searchController: _searchController,
                    onSearchChanged: _setSearch,
                    onEdit: selected == null
                        ? null
                        : () => _openCategoryEditor(category: selected),
                    onDelete: selected == null
                        ? null
                        : () => _deleteCategory(selected),
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: railWidth,
                      child: _CategoryRail(
                        categories: _categories,
                        selectedId: _selectedCategoryId,
                        compact: railWidth < 140,
                        onSelect: _selectCategory,
                        onAdd: _openCategoryEditor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CategoryProducts(
                        category: selected,
                        products: _products,
                        isLoading: _isLoadingProducts,
                        isLoadingMore: _isLoadingMore,
                        controller: _productsController,
                        searchController: _searchController,
                        onSearchChanged: _setSearch,
                        onEdit: selected == null
                            ? null
                            : () => _openCategoryEditor(category: selected),
                        onDelete: selected == null
                            ? null
                            : () => _deleteCategory(selected),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const CartSummaryBar(),
        ],
      ),
    );
  }
}

/// A dedicated, scrollable route avoids the short-screen overflow caused by
/// placing a focused text field in an alert dialog. The controller belongs to
/// this route for its whole lifetime, including the exit animation.
class _CategoryEditorView extends StatefulWidget {
  const _CategoryEditorView({this.category});

  final Map<String, dynamic>? category;

  @override
  State<_CategoryEditorView> createState() => _CategoryEditorViewState();
}

class _CategoryEditorViewState extends State<_CategoryEditorView> {
  late final TextEditingController _nameController;
  String _imageUrl = '';
  XFile? _pickedImage;
  bool _isUploading = false;
  bool _isSaving = false;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.category?['name']?.toString() ?? '',
    );
    _imageUrl = widget.category?['imageUrl']?.toString() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await AdaptiveImageService.pickForUser(
        context,
        sheetTitle: 'Category image',
        galleryLabel: 'Choose category image',
      );
      if (image == null || !mounted) return;
      setState(() {
        _pickedImage = image;
        _isUploading = true;
      });
      final uploaded = await ApiService.uploadImage(image);
      if (!mounted) return;
      setState(() {
        _imageUrl = uploaded ?? _imageUrl;
        _isUploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload image: $error')),
      );
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a category name.')),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);
    try {
      final body = <String, dynamic>{'name': name, 'imageUrl': _imageUrl};
      final response = _isEditing
          ? await ApiService.put(
              '${ApiConfig.categories}/${widget.category!['id']}',
              body,
            )
          : await ApiService.post(ApiConfig.categories, body);
      if (response is Map && response['success'] == false) {
        throw Exception(response['message'] ?? 'Could not save category.');
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _isSaving || _isUploading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit category' : 'Add category'),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth >= 640 ? 560 : double.infinity,
                ),
                child: SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isEditing ? 'Category details' : 'New category',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Use a short, recognisable name to keep browsing tidy.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: .66),
                            ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Semantics(
                          button: true,
                          label: 'Choose category image',
                          child: InkWell(
                            onTap: busy ? null : _pickImage,
                            borderRadius: BorderRadius.circular(20),
                            child: Ink(
                              width: 136,
                              height: 104,
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: scheme.outlineVariant),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AdaptiveImagePreview(
                                    pickedImage: _pickedImage,
                                    imageUrl: _imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: Icon(
                                      Icons.add_photo_alternate_outlined,
                                      color: scheme.primary,
                                    ),
                                  ),
                                  if (_isUploading)
                                    const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: busy ? null : _pickImage,
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: const Text('Choose image'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _save(),
                        decoration: const InputDecoration(
                          labelText: 'Category name',
                          prefixIcon: Icon(Icons.account_tree_outlined),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: busy ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(
                            _isEditing ? 'Save changes' : 'Create category'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LayoutOption extends StatelessWidget {
  const _LayoutOption({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(label),
          const Spacer(),
          if (selected) const Icon(Icons.check_rounded, size: 18),
        ],
      );
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.selectedId,
    required this.compact,
    required this.onSelect,
    required this.onAdd,
  });

  final List<dynamic> categories;
  final int? selectedId;
  final bool compact;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SurfacePanel(
      padding: EdgeInsets.all(compact ? 6 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            Text('Categories', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: ListView.separated(
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final category =
                    Map<String, dynamic>.from(categories[index] as Map);
                final selected = category['id'] == selectedId;
                return Material(
                  color: selected
                      ? scheme.primary.withValues(alpha: .14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => onSelect(category['id'] as int),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 6 : 10,
                        vertical: 11,
                      ),
                      child: Text(
                        (category['name'] ?? 'Untitled').toString(),
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: compact ? TextAlign.center : TextAlign.start,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color:
                                  selected ? scheme.primary : scheme.onSurface,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          compact
              ? IconButton.filledTonal(
                  onPressed: onAdd,
                  tooltip: 'Add category',
                  icon: const Icon(Icons.add_rounded),
                )
              : FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                ),
        ],
      ),
    );
  }
}

/// The alternate layout keeps the exact same product and cart behaviour, but
/// releases the rail's space for shops that prefer a wider product browser.
class _FullWidthCategoryProducts extends StatelessWidget {
  const _FullWidthCategoryProducts({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.onAdd,
    required this.products,
    required this.isLoading,
    required this.isLoadingMore,
    required this.controller,
    required this.searchController,
    required this.onSearchChanged,
    this.onEdit,
    this.onDelete,
  });

  final List<dynamic> categories;
  final int? selectedId;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final List<dynamic> products;
  final bool isLoading;
  final bool isLoadingMore;
  final ScrollController controller;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? selectedCategory;
    for (final item in categories) {
      final category = Map<String, dynamic>.from(item as Map);
      if (category['id'] == selectedId) {
        selectedCategory = category;
        break;
      }
    }
    return Column(
      children: [
        SurfacePanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories.map((item) {
                    final category = Map<String, dynamic>.from(item as Map);
                    return DropdownMenuItem<int>(
                      value: category['id'] as int,
                      child: Text(
                        (category['name'] ?? 'Untitled').toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(growable: false),
                  onChanged: (id) {
                    if (id != null) onSelect(id);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onAdd,
                tooltip: 'Add category',
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _CategoryProducts(
            category: selectedCategory,
            products: products,
            isLoading: isLoading,
            isLoadingMore: isLoadingMore,
            controller: controller,
            searchController: searchController,
            onSearchChanged: onSearchChanged,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ),
      ],
    );
  }
}

/// A visual third option for shops that browse from product photos first.
/// It remains a one-column list on narrow phones and only becomes a grid once
/// a card can comfortably show image, name, price and the add button.
class _GalleryCategoryProducts extends StatelessWidget {
  const _GalleryCategoryProducts({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.onAdd,
    required this.products,
    required this.isLoading,
    required this.isLoadingMore,
    required this.controller,
    required this.searchController,
    required this.onSearchChanged,
    this.onEdit,
    this.onDelete,
  });

  final List<dynamic> categories;
  final int? selectedId;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final List<dynamic> products;
  final bool isLoading;
  final bool isLoadingMore;
  final ScrollController controller;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? selectedCategory;
    for (final item in categories) {
      final category = Map<String, dynamic>.from(item as Map);
      if (category['id'] == selectedId) {
        selectedCategory = category;
        break;
      }
    }
    return Column(
      children: [
        SurfacePanel(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == categories.length) {
                  return IconButton.filledTonal(
                    onPressed: onAdd,
                    tooltip: 'Add category',
                    icon: const Icon(Icons.add_rounded),
                  );
                }
                final category =
                    Map<String, dynamic>.from(categories[index] as Map);
                return FilterChip(
                  label: Text((category['name'] ?? 'Untitled').toString()),
                  selected: category['id'] == selectedId,
                  showCheckmark: false,
                  onSelected: (_) => onSelect(category['id'] as int),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _GalleryProductPanel(
            category: selectedCategory,
            products: products,
            isLoading: isLoading,
            isLoadingMore: isLoadingMore,
            controller: controller,
            searchController: searchController,
            onSearchChanged: onSearchChanged,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ),
      ],
    );
  }
}

class _GalleryProductPanel extends StatelessWidget {
  const _GalleryProductPanel({
    required this.category,
    required this.products,
    required this.isLoading,
    required this.isLoadingMore,
    required this.controller,
    required this.searchController,
    required this.onSearchChanged,
    this.onEdit,
    this.onDelete,
  });

  final Map<String, dynamic>? category;
  final List<dynamic> products;
  final bool isLoading;
  final bool isLoadingMore;
  final ScrollController controller;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    if (category == null) return const SizedBox.shrink();
    return SurfacePanel(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 440 ? 1 : 2;
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (category!['name'] ?? 'Category').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'edit', child: Text('Edit category')),
                      PopupMenuItem(
                          value: 'delete', child: Text('Delete category')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search products',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : products.isEmpty
                        ? const EmptyCanvas(
                            icon: Icons.inventory_2_outlined,
                            title: 'No products here',
                            detail: 'Try another search or add a product.',
                          )
                        : GridView.builder(
                            controller: controller,
                            itemCount:
                                products.length + (isLoadingMore ? 1 : 0),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              mainAxisExtent: columns == 1 ? 96 : 210,
                            ),
                            itemBuilder: (context, index) {
                              if (index == products.length) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              return _GalleryProductCard(
                                product: Map<String, dynamic>.from(
                                    products[index] as Map),
                                compact: columns == 1,
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GalleryProductCard extends StatelessWidget {
  const _GalleryProductCard({required this.product, required this.compact});

  final Map<String, dynamic> product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = (product['imageUrl'] ?? '').toString();
    final stock = quantityValue(product['stockQuantity']);
    final add = IconButton.filled(
      onPressed: stock > 0 ? () => provider.addToCart(product) : null,
      tooltip: 'Add to sale',
      icon: const Icon(Icons.add_rounded),
    );
    final image = Container(
      width: compact ? 74 : double.infinity,
      height: compact ? 74 : 116,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: imageUrl.isEmpty
          ? Icon(Icons.inventory_2_outlined,
              color: scheme.onSurface.withValues(alpha: .38))
          : Image.network(imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(Icons.inventory_2_outlined,
                  color: scheme.onSurface.withValues(alpha: .38))),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text((product['name'] ?? 'Untitled product').toString(),
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text('₹${product['sellingPrice'] ?? '—'}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 14,
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                )),
      ],
    );
    return SurfacePanel(
      padding: const EdgeInsets.all(8),
      child: compact
          ? Row(children: [
              image,
              const SizedBox(width: 10),
              Expanded(child: details),
              add
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                image,
                const SizedBox(height: 8),
                Expanded(child: details),
                Align(alignment: Alignment.centerRight, child: add),
              ],
            ),
    );
  }
}

class _CategoryProducts extends StatelessWidget {
  const _CategoryProducts({
    required this.category,
    required this.products,
    required this.isLoading,
    required this.isLoadingMore,
    required this.controller,
    required this.searchController,
    required this.onSearchChanged,
    this.onEdit,
    this.onDelete,
  });

  final Map<String, dynamic>? category;
  final List<dynamic> products;
  final bool isLoading;
  final bool isLoadingMore;
  final ScrollController controller;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    if (category == null) {
      return const EmptyCanvas(
        icon: Icons.inventory_2_outlined,
        title: 'Choose a category',
        detail: 'Its products will appear here.',
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return SurfacePanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (category!['name'] ?? 'Category').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Category actions',
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit category')),
                  PopupMenuItem(
                      value: 'delete', child: Text('Delete category')),
                ],
                icon: Icon(Icons.more_horiz_rounded, color: scheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search products',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                    ? const EmptyCanvas(
                        icon: Icons.inventory_2_outlined,
                        title: 'No products here',
                        detail: 'Try a different search or add products.',
                      )
                    : ListView.separated(
                        controller: controller,
                        itemCount: products.length + (isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index == products.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _CategoryProductRow(
                            product: Map<String, dynamic>.from(
                                products[index] as Map),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _CategoryProductRow extends StatelessWidget {
  const _CategoryProductRow({required this.product});

  final Map<String, dynamic> product;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final scheme = Theme.of(context).colorScheme;
    final stock = quantityValue(product['stockQuantity']);
    final imageUrl = (product['imageUrl'] ?? '').toString();
    final inCart = provider.cartItems.containsKey(product['id']);

    return SurfacePanel(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 250;
          final image = Container(
            width: narrow ? 52 : 64,
            height: narrow ? 52 : 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: imageUrl.isEmpty
                ? Icon(Icons.inventory_2_outlined,
                    color: scheme.onSurface.withValues(alpha: .38))
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.inventory_2_outlined,
                      color: scheme.onSurface.withValues(alpha: .38),
                    ),
                  ),
          );
          final name = Text(
            (product['name'] ?? 'Untitled product').toString(),
            maxLines: narrow ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          );
          final price = Text(
            '₹${product['sellingPrice'] ?? '—'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
          );
          final add = IconButton.filled(
            onPressed: stock > 0 ? () => provider.addToCart(product) : null,
            tooltip: inCart ? 'Add another' : 'Add to sale',
            icon: Icon(
                inCart ? Icons.add_rounded : Icons.add_shopping_cart_rounded),
          );

          if (narrow) {
            return Column(
              children: [
                Row(children: [
                  image,
                  const SizedBox(width: 8),
                  Expanded(child: name)
                ]),
                const SizedBox(height: 8),
                Row(children: [Expanded(child: price), add]),
              ],
            );
          }
          return Row(
            children: [
              image,
              const SizedBox(width: 10),
              Expanded(child: name),
              const SizedBox(width: 8),
              price,
              const SizedBox(width: 4),
              add,
            ],
          );
        },
      ),
    );
  }
}
