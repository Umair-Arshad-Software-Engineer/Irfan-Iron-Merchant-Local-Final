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
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Consumer<UnitProvider>(
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
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        controller: TextEditingController(
                          text: _conversionFactor.toStringAsFixed(4),
                        ),
                        labelText: languageProvider.isEnglish ? 'Conversion Factor' : 'تبادلوں کا عنصر',
                        hintText: '1.0',
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _conversionFactor = double.tryParse(value) ?? 1.0;
                        },
                      ),
                    ),
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
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
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
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${result.originalValue} ${result.fromUnit} =',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${result.convertedValue.toStringAsFixed(4)} ${result.symbol}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '(${result.toUnit})',
                                  style: const TextStyle(
                                    fontSize: 14,
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
                              languageProvider.isEnglish ? 'Units Management' : 'یونٹس کا انتظام',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3142),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              languageProvider.isEnglish
                                  ? 'Configure measurement units for your inventory'
                                  : 'اپنی انوینٹری کے لیے پیمائش کے یونٹس ترتیب دیں',
                              style: TextStyle(
                                fontSize: 14,
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
                              width: 140,
                              height: 48,
                            ),
                            const SizedBox(width: 12),
                            CustomButton(
                              text: languageProvider.isEnglish ? 'Add Unit' : 'یونٹ شامل ',
                              icon: Icons.add,
                              onPressed: () => _showUnitDialog(),
                              width: 140,
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
                                hintText: languageProvider.isEnglish ? 'Search units...' : 'یونٹس تلاش کریں...',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onChanged: (value) {
                                provider.searchUnits(value);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Consumer<UnitProvider>(
                          builder: (context, provider, child) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F6FA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedType,
                                  hint: Text(languageProvider.isEnglish ? 'Filter by type' : 'قسم کے لحاظ سے فلٹر کریں'),
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text(languageProvider.isEnglish ? 'All Types' : 'تمام اقسام'),
                                    ),
                                    ...UnitType.all.map((type) {
                                      return DropdownMenuItem(
                                        value: type.value,
                                        child: Text(languageProvider.isEnglish ? type.label : type.labelUrdu),
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
                          },
                        ),
                        const SizedBox(width: 12),
                        Consumer<UnitProvider>(
                          builder: (context, provider, child) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F6FA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.filter_list, color: Color(0xFF6B7280), size: 20),
                                  const SizedBox(width: 8),
                                  Switch(
                                    value: provider.showActiveOnly,
                                    onChanged: (value) {
                                      provider.filterActive(value);
                                    },
                                    activeColor: const Color(0xFF7C3AED),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(languageProvider.isEnglish ? 'Active Only' : 'صرف فعال'),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Stats Cards
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Color(0xFFF0F0F5))),
                    ),
                    child: Row(
                      children: [
                        _buildStatCard(
                          languageProvider.isEnglish ? 'Total Units' : 'کل یونٹس',
                          provider.units.length.toString(),
                          Icons.square_foot,
                          languageProvider,
                        ),
                        const SizedBox(width: 16),
                        _buildStatCard(
                          languageProvider.isEnglish ? 'Active Units' : 'فعال یونٹس',
                          provider.activeUnits.length.toString(),
                          Icons.check_circle,
                          languageProvider,
                        ),
                        const SizedBox(width: 16),
                        _buildStatCard(
                          languageProvider.isEnglish ? 'Base Units' : 'بنیادی یونٹس',
                          provider.getBaseUnits().length.toString(),
                          Icons.layers,
                          languageProvider,
                        ),
                      ],
                    ),
                  ),

                  // Units List
                  Expanded(
                    child: provider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : provider.units.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.square_foot_outlined,
                              size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            languageProvider.isEnglish ? 'No units found' : 'کوئی یونٹ نہیں ملا',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontFamily: languageProvider.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            languageProvider.isEnglish
                                ? 'Add your first unit or seed default units'
                                : 'اپنا پہلا یونٹ شامل کریں یا ڈیفالٹ یونٹس سیڈ کریں',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontFamily: languageProvider.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: languageProvider.isEnglish ? 'Seed Default Units' : 'ڈیفالٹ یونٹس سیڈ کریں',
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
                                  backgroundColor: result['success']
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              );
                            },
                            width: 200,
                            backgroundColor: Colors.white,
                            textColor: const Color(0xFF7C3AED),
                          ),
                        ],
                      ),
                    )
                        : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: provider.units.length,
                      itemBuilder: (context, index) {
                        final unit = provider.units[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: unit.isActive
                                  ? const Color(0xFFF0F0F5)
                                  : Colors.grey[300]!,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _getUnitColor(unit.type),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getUnitIcon(unit.type),
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  unit.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: unit.isActive
                                        ? const Color(0xFF2D3142)
                                        : Colors.grey[500],
                                    decoration: unit.isActive
                                        ? null
                                        : TextDecoration.lineThrough,
                                    fontFamily: languageProvider.fontFamily,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getUnitColor(unit.type)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    languageProvider.isEnglish ? unit.typeDisplay : unit.typeDisplayUrdu,
                                    style: TextStyle(
                                      fontSize: 10,
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
                                const SizedBox(height: 4),
                                Text(
                                  '${languageProvider.isEnglish ? 'Symbol' : 'علامت'}: ${unit.symbol}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontFamily: languageProvider.fontFamily,
                                  ),
                                ),
                                if (unit.baseUnit != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${languageProvider.isEnglish ? 'Base' : 'بنیادی'}: ${unit.baseUnit!.name}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontFamily: languageProvider.fontFamily,
                                    ),
                                  ),
                                ],
                                if (unit.conversionFactor != 1) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${languageProvider.isEnglish ? 'Conversion' : 'تبادلوں'}: ${unit.conversionFactor}x',
                                    style: TextStyle(
                                      fontSize: 12,
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
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => _showUnitDialog(unit: unit),
                                  icon: Icon(Icons.edit,
                                      color: Colors.grey[600], size: 20),
                                  tooltip: languageProvider.isEnglish ? 'Edit' : 'ترمیم کریں',
                                ),
                                IconButton(
                                  onPressed: () => _deleteUnit(unit.id),
                                  icon: Icon(Icons.delete,
                                      color: Colors.red[400], size: 20),
                                  tooltip: languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, LanguageProvider languageProvider) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF7C3AED), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: languageProvider.fontFamily,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
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