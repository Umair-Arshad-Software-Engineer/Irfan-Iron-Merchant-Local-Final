import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/custom_text_field.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../components/custom_button.dart';
import '../components/custom_dialog.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final TextEditingController _categoryNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedCategoryId;
  String _viewMode = 'categories'; // 'categories' or 'subcategories'
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final provider = Provider.of<CategoryProvider>(context, listen: false);
    await provider.loadCategories();
  }

  void _showCategoryDialog({String? categoryId, String? categoryName}) {
    _categoryNameController.text = categoryName ?? '';
    _selectedCategoryId = categoryId;

    showDialog(
      context: context,
      builder: (context) => CustomDialog(
        title: categoryId == null ? 'Add Category' : 'Edit Category',
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _categoryNameController,
                labelText: 'Category Name',
                hintText: 'Enter category name',
                prefixIcon: Icons.category,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter category name';
                  }
                  if (value.length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                await _saveCategory();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            child: Text(categoryId == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCategory() async {
    final provider = Provider.of<CategoryProvider>(context, listen: false);
    final name = _categoryNameController.text.trim();

    if (_selectedCategoryId == null) {
      await provider.createCategory(name);
    } else {
      await provider.updateCategory(_selectedCategoryId!, name);
    }

    _categoryNameController.clear();
    _selectedCategoryId = null;
  }

  Future<void> _deleteCategory(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: const Text('Are you sure you want to delete this category? All subcategories will also be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = Provider.of<CategoryProvider>(context, listen: false);
      await provider.deleteCategory(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFC),
          body: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Categories',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your product categories and subcategories',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // View Mode Toggle
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              _buildViewModeButton('Categories', Icons.category),
                              _buildViewModeButton('Subcategories', Icons.category_outlined),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        CustomButton(
                          text: 'Add Category',
                          icon: Icons.add,
                          onPressed: () => _showCategoryDialog(),
                          width: 160,
                          height: 48,
                          useGradient: true,
                          gradientColors: const [Color(0xFF7C3AED), Color(0xFF6366F1)],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Search and Filter Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFF0F0F5))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search categories...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: (value) {
                            provider.searchCategories(value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.filter_list, color: Colors.grey[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Filter',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _viewMode == 'categories'
                    ? _buildCategoriesList(provider)
                    : _buildSubcategoriesScreen(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildViewModeButton(String label, IconData icon) {
    final isSelected = _viewMode == label.toLowerCase();

    return InkWell(
      onTap: () {
        setState(() {
          _viewMode = label.toLowerCase();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: isSelected ? const Color(0xFF7C3AED) : Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? const Color(0xFF7C3AED) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesList(CategoryProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined,
                size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No categories found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first category to get started',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: provider.categories.length,
      itemBuilder: (context, index) {
        final category = provider.categories[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0F0F5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ExpansionTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.category, color: Colors.white, size: 20),
            ),
            title: Text(
              category.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
              ),
            ),
            subtitle: Text(
              '${category.subcategories?.length ?? 0} subcategories',
              style: TextStyle(color: Colors.grey[600]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _showCategoryDialog(
                    categoryId: category.id,
                    categoryName: category.name,
                  ),
                  icon: Icon(Icons.edit, color: Colors.grey[600], size: 20),
                  tooltip: 'Edit',
                ),
                IconButton(
                  onPressed: () => _deleteCategory(category.id),
                  icon: Icon(Icons.delete, color: Colors.red[400], size: 20),
                  tooltip: 'Delete',
                ),
              ],
            ),
            children: [
              _buildSubcategoriesList(category),
              Padding(
                padding: const EdgeInsets.all(16),
                child: CustomButton(
                  text: 'Add Subcategory',
                  icon: Icons.add,
                  onPressed: () => _showSubcategoryDialog(category),
                  // isSmall: true,
                  backgroundColor: Colors.transparent,
                  // borderColor: const Color(0xFF7C3AED),
                  textColor: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubcategoriesList(Category category) {
    final subcategories = category.subcategories ?? [];

    if (subcategories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No subcategories yet',
          style: TextStyle(color: Colors.grey[500]),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: subcategories.map((subcategory) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.category_outlined,
                      size: 18, color: const Color(0xFF7C3AED)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    subcategory.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _showSubcategoryDialog(category, subcategory: subcategory),
                  icon: Icon(Icons.edit, size: 18, color: Colors.grey[600]),
                ),
                IconButton(
                  onPressed: () => _deleteSubcategory(subcategory.id),
                  icon: Icon(Icons.delete, size: 18, color: Colors.red[400]),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubcategoriesScreen() {
    // Similar structure but showing all subcategories across categories
    return Consumer<CategoryProvider>(
      builder: (context, provider, child) {
        final allSubcategories = provider.categories
            .expand((category) => category.subcategories ?? [])
            .toList();

        if (allSubcategories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category_outlined,
                    size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No subcategories found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: allSubcategories.length,
          itemBuilder: (context, index) {
            final subcategory = allSubcategories[index];
            final category = provider.categories.firstWhere(
                  (cat) => cat.subcategories?.contains(subcategory) ?? false,
              orElse: () => provider.categories[0],
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF0F0F5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF34D399)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.category_outlined,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subcategory.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Category: ${category.name}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _showSubcategoryDialog(category, subcategory: subcategory),
                        icon: Icon(Icons.edit, color: Colors.grey[600], size: 20),
                      ),
                      IconButton(
                        onPressed: () => _deleteSubcategory(subcategory.id),
                        icon: Icon(Icons.delete, color: Colors.red[400], size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSubcategoryDialog(Category category, {Subcategory? subcategory}) {
    final subcategoryNameController = TextEditingController(
      text: subcategory?.name ?? '',
    );
    final _subcategoryFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => CustomDialog(
        title: subcategory == null ? 'Add Subcategory' : 'Edit Subcategory',
        content: Form(
          key: _subcategoryFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Category: ${category.name}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: subcategoryNameController,
                labelText: 'Subcategory Name',
                hintText: 'Enter subcategory name',
                prefixIcon: Icons.category_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter subcategory name';
                  }
                  if (value.length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_subcategoryFormKey.currentState!.validate()) {
                await _saveSubcategory(
                  category.id,
                  subcategoryNameController.text.trim(),
                  subcategory?.id,
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            child: Text(subcategory == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSubcategory(String categoryId, String name, String? subcategoryId) async {
    final provider = Provider.of<CategoryProvider>(context, listen: false);

    if (subcategoryId == null) {
      await provider.createSubcategory(categoryId, name);
    } else {
      await provider.updateSubcategory(subcategoryId, name, categoryId);
    }
  }

  Future<void> _deleteSubcategory(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subcategory'),
        content: const Text('Are you sure you want to delete this subcategory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = Provider.of<CategoryProvider>(context, listen: false);
      await provider.deleteSubcategory(id);
    }
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}