import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/custom_dropdown.dart';
import '../components/custom_text_field.dart';
import '../models/unit.dart';
import '../providers/lanprovider.dart';
import '../providers/unit_provider.dart';
import '../components/custom_button.dart';
import '../components/custom_dialog.dart';

class UnitScreen extends StatefulWidget {
  const UnitScreen({super.key});

  @override
  State<UnitScreen> createState() => _UnitScreenState();
}

class _UnitScreenState extends State<UnitScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _symbolController = TextEditingController();
  final TextEditingController _conversionController = TextEditingController();

  String? _selectedUnitId;
  String? _selectedType;
  String? _selectedBaseUnitId;
  double _conversionFactor = 1.0;

  // Conversion fields
  final TextEditingController _convertValueController = TextEditingController();
  String? _convertFromUnitId;
  String? _convertToUnitId;

  final _formKey = GlobalKey<FormState>();
  final _convertFormKey = GlobalKey<FormState>();

  // Responsive breakpoints
  bool get _isMobile => MediaQuery.of(context).size.width < 600;
  bool get _isTablet => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1200;
  bool get _isDesktop => MediaQuery.of(context).size.width >= 1200;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final provider = Provider.of<UnitProvider>(context, listen: false);
    await provider.loadUnits();
  }

  void _showUnitDialog({Unit? unit}) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    _nameController.text = unit?.name ?? '';
    _symbolController.text = unit?.symbol ?? '';
    _selectedType = unit?.type ?? 'custom';
    _selectedBaseUnitId = unit?.baseUnitId;
    _conversionFactor = unit?.conversionFactor ?? 1.0;
    _selectedUnitId = unit?.id;

    showDialog(
      context: context,
      builder: (context) => CustomDialog(
        title: unit == null
            ? (languageProvider.isEnglish ? 'Add Unit' : 'یونٹ شامل کریں')
            : (languageProvider.isEnglish ? 'Edit Unit' : 'یونٹ میں ترمیم کریں'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: _nameController,
                  labelText: languageProvider.isEnglish ? 'Unit Name' : 'یونٹ کا نام',
                  hintText: languageProvider.isEnglish ? 'e.g., Kilogram' : 'مثال: کلوگرام',
                  prefixIcon: Icons.square_foot,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return languageProvider.isEnglish
                          ? 'Please enter unit name'
                          : 'براہ کرم یونٹ کا نام درج کریں';
                    }
                    if (value.length < 2) {
                      return languageProvider.isEnglish
                          ? 'Name must be at least 2 characters'
                          : 'نام کم از کم 2 حروف کا ہونا چاہیے';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _symbolController,
                  labelText: languageProvider.isEnglish ? 'Symbol' : 'علامت',
                  hintText: languageProvider.isEnglish ? 'e.g., kg' : 'مثال: کلو',
                  prefixIcon: Icons.text_fields,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return languageProvider.isEnglish
                          ? 'Please enter unit symbol'
                          : 'براہ کرم یونٹ کی علامت درج کریں';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Consumer<UnitProvider>(
                  builder: (context, provider, child) {
                    return CustomDropdown(
                      value: _selectedType,
                      label: languageProvider.isEnglish ? 'Unit Type' : 'یونٹ کی قسم',
                      hintText: languageProvider.isEnglish ? 'Select unit type' : 'یونٹ کی قسم منتخب کریں',
                      items: UnitType.all.map((type) {
                        return DropdownMenuItem(
                          value: type.value,
                          child: Text(languageProvider.isEnglish ? type.label : type.labelUrdu),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return languageProvider.isEnglish
                              ? 'Please select unit type'
                              : 'براہ کرم یونٹ کی قسم منتخب کریں';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (_isDesktop)
                  Row(
                    children: [
                      Expanded(
                        child: _buildBaseUnitDropdown(languageProvider),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildConversionField(languageProvider),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildBaseUnitDropdown(languageProvider),
                      const SizedBox(height: 12),
                      _buildConversionField(languageProvider),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearForm();
            },
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                await _saveUnit();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            child: Text(unit == null
                ? (languageProvider.isEnglish ? 'Add' : 'شامل کریں')
                : (languageProvider.isEnglish ? 'Update' : 'اپ ڈیٹ کریں')),
          ),
        ],
      ),
    );
  }

  Widget _buildBaseUnitDropdown(LanguageProvider languageProvider) {
    return Consumer<UnitProvider>(
      builder: (context, provider, child) {
        final baseUnits = provider.getBaseUnits();
        return CustomDropdown(
          value: _selectedBaseUnitId,
          label: languageProvider.isEnglish ? 'Base Unit (Optional)' : 'بنیادی یونٹ (اختیاری)',
          hintText: languageProvider.isEnglish ? 'Select base unit' : 'بنیادی یونٹ منتخب کریں',
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(languageProvider.isEnglish ? 'None (Base Unit)' : 'کوئی نہیں (بنیادی یونٹ)'),
            ),
            ...baseUnits.map((unit) {
              return DropdownMenuItem(
                value: unit.id,
                child: Text(unit.displayName),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedBaseUnitId = value;
            });
          },
        );
      },
    );
  }

  Widget _buildConversionField(LanguageProvider languageProvider) {
    return CustomTextField(
      controller: TextEditingController(
        text: _conversionFactor.toStringAsFixed(4),
      ),
      labelText: languageProvider.isEnglish ? 'Conversion Factor' : 'تبادلوں کا عنصر',
      hintText: '1.0',
      keyboardType: TextInputType.number,
      onChanged: (value) {
        _conversionFactor = double.tryParse(value) ?? 1.0;
      },
    );
  }

  Future<void> _saveUnit() async {
    final provider = Provider.of<UnitProvider>(context, listen: false);

    if (_selectedUnitId == null) {
      await provider.createUnit(
        name: _nameController.text.trim(),
        symbol: _symbolController.text.trim(),
        type: _selectedType!,
        conversionFactor: _conversionFactor,
        baseUnitId: _selectedBaseUnitId,
      );
    } else {
      await provider.updateUnit(
        id: _selectedUnitId!,
        name: _nameController.text.trim(),
        symbol: _symbolController.text.trim(),
        type: _selectedType,
        conversionFactor: _conversionFactor,
        baseUnitId: _selectedBaseUnitId,
      );
    }

    _clearForm();
  }

  void _clearForm() {
    _nameController.clear();
    _symbolController.clear();
    _selectedType = 'custom';
    _selectedBaseUnitId = null;
    _conversionFactor = 1.0;
    _selectedUnitId = null;
  }

  void _showConversionDialog() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    _convertValueController.clear();
    _convertFromUnitId = null;
    _convertToUnitId = null;

    final provider = Provider.of<UnitProvider>(context, listen: false);
    provider.clearConversion();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return CustomDialog(
            title: languageProvider.isEnglish ? 'Unit Converter' : 'یونٹ کنورٹر',
            content: Form(
              key: _convertFormKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomTextField(
                      controller: _convertValueController,
                      labelText: languageProvider.isEnglish ? 'Value to Convert' : 'تبدیل کرنے کی قیمت',
                      hintText: languageProvider.isEnglish ? 'Enter value' : 'قیمت درج کریں',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.numbers,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return languageProvider.isEnglish
                              ? 'Please enter value'
                              : 'براہ کرم قیمت درج کریں';
                        }
                        final numValue = double.tryParse(value);
                        if (numValue == null) {
                          return languageProvider.isEnglish
                              ? 'Please enter a valid number'
                              : 'براہ کرم ایک درست نمبر درج کریں';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Consumer<UnitProvider>(
                      builder: (context, provider, child) {
                        return CustomDropdown(
                          value: _convertFromUnitId,
                          label: languageProvider.isEnglish ? 'From Unit' : 'بنیادی یونٹ',
                          hintText: languageProvider.isEnglish ? 'Select unit' : 'یونٹ منتخب کریں',
                          items: provider.activeUnits.map((unit) {
                            return DropdownMenuItem(
                              value: unit.id,
                              child: Text(unit.displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _convertFromUnitId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return languageProvider.isEnglish
                                  ? 'Please select from unit'
                                  : 'براہ کرم بنیادی یونٹ منتخب کریں';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Consumer<UnitProvider>(
                      builder: (context, provider, child) {
                        return CustomDropdown(
                          value: _convertToUnitId,
                          label: languageProvider.isEnglish ? 'To Unit' : 'تبدیل شدہ یونٹ',
                          hintText: languageProvider.isEnglish ? 'Select unit' : 'یونٹ منتخب کریں',
                          items: provider.activeUnits.map((unit) {
                            return DropdownMenuItem(
                              value: unit.id,
                              child: Text(unit.displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _convertToUnitId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return languageProvider.isEnglish
                                  ? 'Please select to unit'
                                  : 'براہ کرم تبدیل شدہ یونٹ منتخب کریں';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Consumer<UnitProvider>(
                      builder: (context, provider, child) {
                        if (provider.isConverting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (provider.conversionError.isNotEmpty) {
                          return Text(
                            provider.conversionError,
                            style: const TextStyle(color: Colors.red),
                          );
                        }

                        if (provider.conversionResult != null) {
                          final result = provider.conversionResult!;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${result.originalValue} ${result.fromUnit} =',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${result.convertedValue.toStringAsFixed(4)} ${result.symbol}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '(${result.toUnit})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return const SizedBox();
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(languageProvider.isEnglish ? 'Close' : 'بند کریں'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_convertFormKey.currentState!.validate()) {
                    final provider = Provider.of<UnitProvider>(context, listen: false);
                    await provider.convertUnits(
                      fromUnitId: _convertFromUnitId!,
                      toUnitId: _convertToUnitId!,
                      value: double.parse(_convertValueController.text),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                ),
                child: Text(languageProvider.isEnglish ? 'Convert' : 'تبدیل کریں'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteUnit(String id) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Delete Unit' : 'یونٹ حذف کریں'),
        content: Text(languageProvider.isEnglish
            ? 'Are you sure you want to delete this unit?'
            : 'کیا آپ واقعی اس یونٹ کو حذف کرنا چاہتے ہیں؟'),
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
      final provider = Provider.of<UnitProvider>(context, listen: false);
      await provider.deleteUnit(id);
    }
  }

  Future<void> _toggleUnitStatus(Unit unit) async {
    final provider = Provider.of<UnitProvider>(context, listen: false);
    await provider.updateUnit(
      id: unit.id,
      isActive: !unit.isActive,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Consumer<UnitProvider>(
          builder: (context, provider, child) {
            return Scaffold(
              backgroundColor: const Color(0xFFFAFAFC),
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Responsive Header
                    _buildHeader(languageProvider, provider),

                    // Stats Cards - Responsive Grid
                    if (!_isMobile)
                      _buildStatsCards(languageProvider, provider)
                    else
                      _buildMobileStatsCards(languageProvider, provider),

                    // Responsive Search and Filter Bar
                    _buildSearchFilterBar(languageProvider, provider),

                    // Units List
                    if (provider.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (provider.units.isEmpty)
                      _buildEmptyState(languageProvider, provider)
                    else
                      _isDesktop
                          ? _buildDesktopUnitList(languageProvider, provider)
                          : _buildMobileUnitList(languageProvider, provider),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(LanguageProvider languageProvider, UnitProvider provider) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 16 : (_isTablet ? 20 : 24),
        vertical: _isMobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: _isMobile
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.isEnglish ? 'Units Management' : 'یونٹس کا انتظام',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            languageProvider.isEnglish
                ? 'Configure measurement units for your inventory'
                : 'اپنی انوینٹری کے لیے پیمائش کے یونٹس ترتیب دیں',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontFamily: languageProvider.fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: languageProvider.isEnglish ? 'Converter' : 'کنورٹر',
                  icon: Icons.swap_horiz,
                  onPressed: _showConversionDialog,
                  backgroundColor: Colors.white,
                  textColor: const Color(0xFF7C3AED),
                  height: 36,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomButton(
                  text: languageProvider.isEnglish ? 'Add Unit' : 'یونٹ شامل',
                  icon: Icons.add,
                  onPressed: () => _showUnitDialog(),
                  height: 36,
                  useGradient: true,
                  gradientColors: const [Color(0xFF7C3AED), Color(0xFF6366F1)],
                ),
              ),
            ],
          ),
        ],
      )
          : Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.isEnglish ? 'Units Management' : 'یونٹس کا انتظام',
                style: TextStyle(
                  fontSize: _isDesktop ? 22 : 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3142),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                languageProvider.isEnglish
                    ? 'Configure measurement units for your inventory'
                    : 'اپنی انوینٹری کے لیے پیمائش کے یونٹس ترتیب دیں',
                style: TextStyle(
                  fontSize: _isDesktop ? 13 : 12,
                  color: Colors.grey[600],
                  fontFamily: languageProvider.fontFamily,
                ),
              ),
            ],
          ),
          Row(
            children: [
              CustomButton(
                text: languageProvider.isEnglish ? 'Converter' : 'کنورٹر',
                icon: Icons.swap_horiz,
                onPressed: _showConversionDialog,
                backgroundColor: Colors.white,
                textColor: const Color(0xFF7C3AED),
                width: _isDesktop ? 120 : 100,
                height: 38,
              ),
              const SizedBox(width: 10),
              CustomButton(
                text: languageProvider.isEnglish ? 'Add Unit' : 'یونٹ شامل',
                icon: Icons.add,
                onPressed: () => _showUnitDialog(),
                width: _isDesktop ? 120 : 100,
                height: 38,
                useGradient: true,
                gradientColors: const [Color(0xFF7C3AED), Color(0xFF6366F1)],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilterBar(LanguageProvider languageProvider, UnitProvider provider) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 16 : 24,
        vertical: _isMobile ? 10 : 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F5))),
      ),
      child: _isMobile
          ? Column(
        children: [
          _buildSearchField(languageProvider, provider),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildTypeFilter(languageProvider, provider),
              ),
              const SizedBox(width: 6),
              _buildActiveFilter(languageProvider, provider),
            ],
          ),
        ],
      )
          : Row(
        children: [
          Expanded(
            child: _buildSearchField(languageProvider, provider),
          ),
          const SizedBox(width: 10),
          _buildTypeFilter(languageProvider, provider),
          const SizedBox(width: 10),
          _buildActiveFilter(languageProvider, provider),
        ],
      ),
    );
  }

  Widget _buildSearchField(LanguageProvider languageProvider, UnitProvider provider) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(fontFamily: languageProvider.fontFamily, fontSize: _isMobile ? 13 : 14),
        decoration: InputDecoration(
          hintText: languageProvider.isEnglish ? 'Search units...' : 'یونٹس تلاش کریں...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: _isMobile ? 12 : 13),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: _isMobile ? 18 : 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        ),
        onChanged: (value) {
          provider.searchUnits(value);
        },
      ),
    );
  }

  Widget _buildTypeFilter(LanguageProvider languageProvider, UnitProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedType,
          hint: Text(
            languageProvider.isEnglish ? 'Filter' : 'فلٹر',
            style: TextStyle(fontSize: _isMobile ? 11 : 13),
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(
                languageProvider.isEnglish ? 'All Types' : 'تمام اقسام',
                style: TextStyle(fontSize: _isMobile ? 11 : 13),
              ),
            ),
            ...UnitType.all.map((type) {
              return DropdownMenuItem(
                value: type.value,
                child: Text(
                  languageProvider.isEnglish ? type.label : type.labelUrdu,
                  style: TextStyle(fontSize: _isMobile ? 11 : 13),
                ),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedType = value;
            });
            provider.filterByType(value);
          },
        ),
      ),
    );
  }

  Widget _buildActiveFilter(LanguageProvider languageProvider, UnitProvider provider) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _isMobile ? 6 : 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isMobile)
            Icon(Icons.filter_list, color: const Color(0xFF6B7280), size: 18),
          if (!_isMobile) const SizedBox(width: 6),
          Switch(
            value: provider.showActiveOnly,
            onChanged: (value) {
              provider.filterActive(value);
            },
            activeColor: const Color(0xFF7C3AED),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          if (!_isMobile) ...[
            const SizedBox(width: 2),
            Text(
              languageProvider.isEnglish ? 'Active Only' : 'صرف فعال',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCards(LanguageProvider languageProvider, UnitProvider provider) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 16 : 24,
        vertical: _isMobile ? 10 : 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F5))),
      ),
      child: _isDesktop
          ? Row(
        children: [
          _buildStatCard(
            languageProvider.isEnglish ? 'Total Units' : 'کل یونٹس',
            provider.units.length.toString(),
            Icons.square_foot,
            languageProvider,
            isDesktop: true,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            languageProvider.isEnglish ? 'Active Units' : 'فعال یونٹس',
            provider.activeUnits.length.toString(),
            Icons.check_circle,
            languageProvider,
            isDesktop: true,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            languageProvider.isEnglish ? 'Base Units' : 'بنیادی یونٹس',
            provider.getBaseUnits().length.toString(),
            Icons.layers,
            languageProvider,
            isDesktop: true,
          ),
        ],
      )
          : Row(
        children: [
          Expanded(
            child: _buildStatCard(
              languageProvider.isEnglish ? 'Total' : 'کل',
              provider.units.length.toString(),
              Icons.square_foot,
              languageProvider,
              isDesktop: false,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              languageProvider.isEnglish ? 'Active' : 'فعال',
              provider.activeUnits.length.toString(),
              Icons.check_circle,
              languageProvider,
              isDesktop: false,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              languageProvider.isEnglish ? 'Base' : 'بنیادی',
              provider.getBaseUnits().length.toString(),
              Icons.layers,
              languageProvider,
              isDesktop: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStatsCards(LanguageProvider languageProvider, UnitProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F5))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMobileStatCard(
              languageProvider.isEnglish ? 'Total' : 'کل',
              provider.units.length.toString(),
              Icons.square_foot,
              languageProvider,
            ),
            const SizedBox(width: 6),
            _buildMobileStatCard(
              languageProvider.isEnglish ? 'Active' : 'فعال',
              provider.activeUnits.length.toString(),
              Icons.check_circle,
              languageProvider,
            ),
            const SizedBox(width: 6),
            _buildMobileStatCard(
              languageProvider.isEnglish ? 'Base' : 'بنیادی',
              provider.getBaseUnits().length.toString(),
              Icons.layers,
              languageProvider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileStatCard(String title, String value, IconData icon, LanguageProvider languageProvider) {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF7C3AED), size: 16),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
              fontFamily: languageProvider.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider languageProvider, UnitProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.square_foot_outlined, size: _isMobile ? 60 : 80, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              languageProvider.isEnglish ? 'No units found' : 'کوئی یونٹ نہیں ملا',
              style: TextStyle(
                fontSize: _isMobile ? 15 : 17,
                color: Colors.grey,
                fontFamily: languageProvider.fontFamily,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              languageProvider.isEnglish
                  ? 'Add your first unit or seed default units'
                  : 'اپنا پہلا یونٹ شامل کریں یا ڈیفالٹ یونٹس سیڈ کریں',
              style: TextStyle(
                color: Colors.grey[400],
                fontFamily: languageProvider.fontFamily,
                fontSize: _isMobile ? 11 : 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: languageProvider.isEnglish ? 'Add Units' : 'یو نٹس ایڈ کریں',
              icon: Icons.download,
              onPressed: () async {
                final result = await provider.seedDefaultUnits();
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result['success']
                          ? (languageProvider.isEnglish ? 'Default units seeded successfully' : 'ڈیفالٹ یونٹس کامیابی سے سیڈ ہوگئے')
                          : result['message'],
                    ),
                    backgroundColor: result['success'] ? Colors.green : Colors.red,
                  ),
                );
              },
              width: _isMobile ? 160 : 180,
              height: _isMobile ? 36 : 42,
              backgroundColor: Colors.white,
              textColor: const Color(0xFF7C3AED),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopUnitList(LanguageProvider languageProvider, UnitProvider provider) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: provider.units.length,
      itemBuilder: (context, index) {
        final unit = provider.units[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: unit.isActive ? const Color(0xFFF0F0F5) : Colors.grey[300]!,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _getUnitColor(unit.type),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getUnitIcon(unit.type),
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          unit.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: unit.isActive ? const Color(0xFF2D3142) : Colors.grey[500],
                            decoration: unit.isActive ? null : TextDecoration.lineThrough,
                            fontFamily: languageProvider.fontFamily,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: _getUnitColor(unit.type).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            languageProvider.isEnglish ? unit.typeDisplay : unit.typeDisplayUrdu,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: _getUnitColor(unit.type),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${languageProvider.isEnglish ? 'Symbol' : 'علامت'}: ${unit.symbol}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontFamily: languageProvider.fontFamily,
                          ),
                        ),
                        if (unit.baseUnit != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            '${languageProvider.isEnglish ? 'Base' : 'بنیادی'}: ${unit.baseUnit!.name}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontFamily: languageProvider.fontFamily,
                            ),
                          ),
                        ],
                        if (unit.conversionFactor != 1) ...[
                          const SizedBox(width: 12),
                          Text(
                            '${languageProvider.isEnglish ? 'Conversion' : 'تبادلوں'}: ${unit.conversionFactor}x',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontFamily: languageProvider.fontFamily,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: unit.isActive,
                    onChanged: (_) => _toggleUnitStatus(unit),
                    activeColor: const Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _showUnitDialog(unit: unit),
                    icon: Icon(Icons.edit, color: Colors.grey[600], size: 18),
                    tooltip: languageProvider.isEnglish ? 'Edit' : 'ترمیم کریں',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _deleteUnit(unit.id),
                    icon: Icon(Icons.delete, color: Colors.red[400], size: 18),
                    tooltip: languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileUnitList(LanguageProvider languageProvider, UnitProvider provider) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: provider.units.length,
      itemBuilder: (context, index) {
        final unit = provider.units[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: unit.isActive ? const Color(0xFFF0F0F5) : Colors.grey[300]!,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getUnitColor(unit.type),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getUnitIcon(unit.type),
                color: Colors.white,
                size: 16,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    unit.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: unit.isActive ? const Color(0xFF2D3142) : Colors.grey[500],
                      decoration: unit.isActive ? null : TextDecoration.lineThrough,
                      fontFamily: languageProvider.fontFamily,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _getUnitColor(unit.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    languageProvider.isEnglish ? unit.typeDisplay : unit.typeDisplayUrdu,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: _getUnitColor(unit.type),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  '${languageProvider.isEnglish ? 'Symbol' : 'علامت'}: ${unit.symbol}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontFamily: languageProvider.fontFamily,
                  ),
                ),
                if (unit.baseUnit != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    '${languageProvider.isEnglish ? 'Base' : 'بنیادی'}: ${unit.baseUnit!.name}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontFamily: languageProvider.fontFamily,
                    ),
                  ),
                ],
                if (unit.conversionFactor != 1) ...[
                  const SizedBox(height: 1),
                  Text(
                    '${languageProvider.isEnglish ? 'Conversion' : 'تبادلوں'}: ${unit.conversionFactor}x',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontFamily: languageProvider.fontFamily,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: unit.isActive,
                  onChanged: (_) => _toggleUnitStatus(unit),
                  activeColor: const Color(0xFF7C3AED),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                IconButton(
                  onPressed: () => _showUnitDialog(unit: unit),
                  icon: Icon(Icons.edit, color: Colors.grey[600], size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  onPressed: () => _deleteUnit(unit.id),
                  icon: Icon(Icons.delete, color: Colors.red[400], size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, LanguageProvider languageProvider, {required bool isDesktop}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: isDesktop ? 32 : 28,
              height: isDesktop ? 32 : 28,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: const Color(0xFF7C3AED), size: isDesktop ? 16 : 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isDesktop ? 10 : 9,
                      color: Colors.grey[600],
                      fontFamily: languageProvider.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3142),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getUnitColor(String type) {
    switch (type) {
      case 'weight':
        return const Color(0xFF7C3AED);
      case 'volume':
        return const Color(0xFF10B981);
      case 'count':
        return const Color(0xFFF59E0B);
      case 'length':
        return const Color(0xFF3B82F6);
      case 'area':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getUnitIcon(String type) {
    switch (type) {
      case 'weight':
        return Icons.fitness_center;
      case 'volume':
        return Icons.water_drop;
      case 'count':
        return Icons.numbers;
      case 'length':
        return Icons.straighten;
      case 'area':
        return Icons.crop_square;
      default:
        return Icons.square_foot;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _symbolController.dispose();
    _convertValueController.dispose();
    super.dispose();
  }
}