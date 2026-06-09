import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/custom_text_field.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../components/custom_button.dart';
import '../components/custom_dialog.dart';
import '../providers/lanprovider.dart';

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
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    _categoryNameController.text = categoryName ?? '';
    _selectedCategoryId = categoryId;

    showDialog(
      context: context,
      builder: (context) => CustomDialog(
        title: categoryId == null
            ? (languageProvider.isEnglish ? 'Add Category' : 'کیٹگری شامل کریں')
            : (languageProvider.isEnglish ? 'Edit Category' : 'کیٹگری میں ترمیم کریں'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _categoryNameController,
                labelText: languageProvider.isEnglish ? 'Category Name' : 'کیٹگری کا نام',
                hintText: languageProvider.isEnglish ? 'Enter category name' : 'کیٹگری کا نام درج کریں',
                prefixIcon: Icons.category,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return languageProvider.isEnglish
                        ? 'Please enter category name'
                        : 'براہ کرم کیٹگری کا نام درج کریں';
                  }
                  if (value.length < 2) {
                    return languageProvider.isEnglish
                        ? 'Name must be at least 2 characters'
                        : 'نام کم از کم 2 حروف کا ہونا چاہیے';
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
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
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
            child: Text(categoryId == null
                ? (languageProvider.isEnglish ? 'Add' : 'شامل کریں')
                : (languageProvider.isEnglish ? 'Update' : 'اپ ڈیٹ کریں')),
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
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Delete Category' : 'کیٹگری حذف کریں'),
        content: Text(
          languageProvider.isEnglish
              ? 'Are you sure you want to delete this category? All subcategories will also be deleted.'
              : 'کیا آپ واقعی اس کیٹگری کو حذف کرنا چاہتے ہیں؟ تمام ذیلی کیٹگریز بھی حذف ہو جائیں گی۔',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: Text(languageProvider.isEnglish ? 'Delete' : 'حذف کریں'),
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
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
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
                            Text(
                              languageProvider.isEnglish ? 'Categories' : 'کیٹگریز',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3142),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              languageProvider.isEnglish
                                  ? 'Manage your product categories and subcategories'
                                  : 'اپنی پروڈکٹ کی کیٹگریز اور ذیلی کیٹگریز کا انتظام کریں',
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
                                  _buildViewModeButton(
                                    languageProvider.isEnglish ? 'Categories' : 'کیٹگریز',
                                    Icons.category,
                                    languageProvider,
                                  ),
                                  _buildViewModeButton(
                                    languageProvider.isEnglish ? 'Subcategories' : 'ذیلی کیٹگریز',
                                    Icons.category_outlined,
                                    languageProvider,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            CustomButton(
                              text: languageProvider.isEnglish ? 'Add Category' : 'کیٹگری شامل کریں',
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
                              style: TextStyle(fontFamily: languageProvider.fontFamily),
                              decoration: InputDecoration(
                                hintText: languageProvider.isEnglish
                                    ? 'Search categories...'
                                    : 'کیٹگریز تلاش کریں...',
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
                                languageProvider.isEnglish ? 'Filter' : 'فلٹر',
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
                        ? _buildCategoriesList(provider, languageProvider)
                        : _buildSubcategoriesScreen(languageProvider),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildViewModeButton(String label, IconData icon, LanguageProvider languageProvider) {
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
                fontFamily: languageProvider.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesList(CategoryProvider provider, LanguageProvider languageProvider) {
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
              languageProvider.isEnglish ? 'No categories found' : 'کوئی کیٹگری نہیں ملی',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[500],
                fontFamily: languageProvider.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              languageProvider.isEnglish
                  ? 'Add your first category to get started'
                  : 'شروع کرنے کے لیے اپنی پہلی کیٹگری شامل کریں',
              style: TextStyle(color: Colors.grey[400], fontFamily: languageProvider.fontFamily),
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2D3142),
                fontFamily: languageProvider.fontFamily,
              ),
            ),
            subtitle: Text(
              languageProvider.isEnglish
                  ? '${category.subcategories?.length ?? 0} subcategories'
                  : 'ذیلی کیٹگریز: ${category.subcategories?.length ?? 0}',
              style: TextStyle(color: Colors.grey[600], fontFamily: languageProvider.fontFamily),
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
                  tooltip: languageProvider.isEnglish ? 'Edit' : 'ترمیم کریں',
                ),
                IconButton(
                  onPressed: () => _deleteCategory(category.id),
                  icon: Icon(Icons.delete, color: Colors.red[400], size: 20),
                  tooltip: languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
                ),
              ],
            ),
            children: [
              _buildSubcategoriesList(category, languageProvider),
              Padding(
                padding: const EdgeInsets.all(16),
                child: CustomButton(
                  text: languageProvider.isEnglish ? 'Add Subcategory' : 'ذیلی کیٹگری شامل کریں',
                  icon: Icons.add,
                  onPressed: () => _showSubcategoryDialog(category, languageProvider: languageProvider),
                  backgroundColor: Colors.transparent,
                  textColor: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubcategoriesList(Category category, LanguageProvider languageProvider) {
    final subcategories = category.subcategories ?? [];

    if (subcategories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          languageProvider.isEnglish ? 'No subcategories yet' : 'ابھی تک کوئی ذیلی کیٹگری نہیں',
          style: TextStyle(color: Colors.grey[500], fontFamily: languageProvider.fontFamily),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF2D3142),
                      fontFamily: languageProvider.fontFamily,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _showSubcategoryDialog(category, subcategory: subcategory, languageProvider: languageProvider),
                  icon: Icon(Icons.edit, size: 18, color: Colors.grey[600]),
                  tooltip: languageProvider.isEnglish ? 'Edit' : 'ترمیم کریں',
                ),
                IconButton(
                  onPressed: () => _deleteSubcategory(subcategory.id),
                  icon: Icon(Icons.delete, size: 18, color: Colors.red[400]),
                  tooltip: languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubcategoriesScreen(LanguageProvider languageProvider) {
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
                  languageProvider.isEnglish ? 'No subcategories found' : 'کوئی ذیلی کیٹگری نہیں ملی',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[500],
                    fontFamily: languageProvider.fontFamily,
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2D3142),
                            fontFamily: languageProvider.fontFamily,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          languageProvider.isEnglish
                              ? 'Category: ${category.name}'
                              : 'کیٹگری: ${category.name}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: languageProvider.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _showSubcategoryDialog(category, subcategory: subcategory, languageProvider: languageProvider),
                        icon: Icon(Icons.edit, color: Colors.grey[600], size: 20),
                        tooltip: languageProvider.isEnglish ? 'Edit' : 'ترمیم کریں',
                      ),
                      IconButton(
                        onPressed: () => _deleteSubcategory(subcategory.id),
                        icon: Icon(Icons.delete, color: Colors.red[400], size: 20),
                        tooltip: languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
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

  void _showSubcategoryDialog(Category category, {Subcategory? subcategory, required LanguageProvider languageProvider}) {
    final subcategoryNameController = TextEditingController(
      text: subcategory?.name ?? '',
    );
    final _subcategoryFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => CustomDialog(
        title: subcategory == null
            ? (languageProvider.isEnglish ? 'Add Subcategory' : 'ذیلی کیٹگری شامل کریں')
            : (languageProvider.isEnglish ? 'Edit Subcategory' : 'ذیلی کیٹگری میں ترمیم کریں'),
        content: Form(
          key: _subcategoryFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                languageProvider.isEnglish
                    ? 'Category: ${category.name}'
                    : 'کیٹگری: ${category.name}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: subcategoryNameController,
                labelText: languageProvider.isEnglish ? 'Subcategory Name' : 'ذیلی کیٹگری کا نام',
                hintText: languageProvider.isEnglish ? 'Enter subcategory name' : 'ذیلی کیٹگری کا نام درج کریں',
                prefixIcon: Icons.category_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return languageProvider.isEnglish
                        ? 'Please enter subcategory name'
                        : 'براہ کرم ذیلی کیٹگری کا نام درج کریں';
                  }
                  if (value.length < 2) {
                    return languageProvider.isEnglish
                        ? 'Name must be at least 2 characters'
                        : 'نام کم از کم 2 حروف کا ہونا چاہیے';
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
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
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
            child: Text(subcategory == null
                ? (languageProvider.isEnglish ? 'Add' : 'شامل کریں')
                : (languageProvider.isEnglish ? 'Update' : 'اپ ڈیٹ کریں')),
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
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Delete Subcategory' : 'ذیلی کیٹگری حذف کریں'),
        content: Text(
          languageProvider.isEnglish
              ? 'Are you sure you want to delete this subcategory?'
              : 'کیا آپ واقعی اس ذیلی کیٹگری کو حذف کرنا چاہتے ہیں؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: Text(languageProvider.isEnglish ? 'Delete' : 'حذف کریں'),
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