import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/custom_dropdown.dart';
import '../components/custom_text_field.dart';
import '../models/unit.dart';
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
    _nameController.text = unit?.name ?? '';
    _symbolController.text = unit?.symbol ?? '';
    _selectedType = unit?.type ?? 'custom';
    _selectedBaseUnitId = unit?.baseUnitId;
    _conversionFactor = unit?.conversionFactor ?? 1.0;
    _selectedUnitId = unit?.id;

    showDialog(
      context: context,
      builder: (context) => CustomDialog(
        title: unit == null ? 'Add Unit' : 'Edit Unit',
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: _nameController,
                  labelText: 'Unit Name',
                  hintText: 'e.g., Kilogram',
                  prefixIcon: Icons.square_foot,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter unit name';
                    }
                    if (value.length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _symbolController,
                  labelText: 'Symbol',
                  hintText: 'e.g., kg',
                  prefixIcon: Icons.text_fields,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter unit symbol';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Consumer<UnitProvider>(
                  builder: (context, provider, child) {
                    return CustomDropdown(
                      value: _selectedType,
                      label: 'Unit Type',
                      hintText: 'Select unit type',
                      items: UnitType.all.map((type) {
                        return DropdownMenuItem(
                          value: type.value,
                          child: Text(type.label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select unit type';
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
                            label: 'Base Unit (Optional)',
                            hintText: 'Select base unit',
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('None (Base Unit)'),
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
                        labelText: 'Conversion Factor',
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
            child: const Text('Cancel'),
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
            child: Text(unit == null ? 'Add' : 'Update'),
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
            title: 'Unit Converter',
            content: Form(
              key: _convertFormKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomTextField(
                      controller: _convertValueController,
                      labelText: 'Value to Convert',
                      hintText: 'Enter value',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.numbers,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter value';
                        }
                        final numValue = double.tryParse(value);
                        if (numValue == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Consumer<UnitProvider>(
                      builder: (context, provider, child) {
                        return CustomDropdown(
                          value: _convertFromUnitId,
                          label: 'From Unit',
                          hintText: 'Select unit',
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
                              return 'Please select from unit';
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
                          label: 'To Unit',
                          hintText: 'Select unit',
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
                              return 'Please select to unit';
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
                child: const Text('Close'),
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
                child: const Text('Convert'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteUnit(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Unit'),
        content: const Text('Are you sure you want to delete this unit?'),
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
                        const Text(
                          'Units Management',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure measurement units for your inventory',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        CustomButton(
                          text: 'Converter',
                          icon: Icons.swap_horiz,
                          onPressed: _showConversionDialog,
                          backgroundColor: Colors.white,
                          textColor: const Color(0xFF7C3AED),
                          width: 140,
                          height: 48,
                        ),
                        const SizedBox(width: 12),
                        CustomButton(
                          text: 'Add Unit',
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
                          decoration: InputDecoration(
                            hintText: 'Search units...',
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
                              hint: const Text('Filter by type'),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('All Types'),
                                ),
                                ...UnitType.all.map((type) {
                                  return DropdownMenuItem(
                                    value: type.value,
                                    child: Text(type.label),
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
                              const Text('Active Only'),
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
                    _buildStatCard('Total Units', provider.units.length.toString(), Icons.square_foot),
                    const SizedBox(width: 16),
                    _buildStatCard('Active Units', provider.activeUnits.length.toString(), Icons.check_circle),
                    const SizedBox(width: 16),
                    _buildStatCard('Base Units', provider.getBaseUnits().length.toString(), Icons.layers),
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
                      const Text(
                        'No units found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first unit or seed default units',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        text: 'Seed Default Units',
                        icon: Icons.download,
                        onPressed: () async {
                          final result = await provider.seedDefaultUnits();
                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result['success']
                                    ? 'Default units seeded successfully'
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
                                unit.typeDisplay,
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
                              'Symbol: ${unit.symbol}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (unit.baseUnit != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Base: ${unit.baseUnit!.name}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                            if (unit.conversionFactor != 1) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Conversion: ${unit.conversionFactor}x',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
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
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              onPressed: () => _deleteUnit(unit.id),
                              icon: Icon(Icons.delete,
                                  color: Colors.red[400], size: 20),
                              tooltip: 'Delete',
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
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
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