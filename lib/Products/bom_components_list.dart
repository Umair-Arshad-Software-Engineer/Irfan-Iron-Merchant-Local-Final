// lib/widgets/bom_components_list.dart
import 'package:flutter/material.dart';
import '../models/product_model.dart';

class BomComponentsList extends StatelessWidget {
  final List<BomComponent> components;
  final Function(int) onRemove;
  final Function(BomComponent) onEdit;

  const BomComponentsList({
    Key? key,
    required this.components,
    required this.onRemove,
    required this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (components.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E8)),
        ),
        child: const Column(
          children: [
            Icon(Icons.inventory, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No components added yet',
              style: TextStyle(color: Colors.grey),
            ),
            Text(
              'Search and add products to build your BOM',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Separate materials and byproducts for better display
    final materials = components.where((c) => c.quantity > 0).toList();
    final byproducts = components.where((c) => c.quantity < 0).toList();
    final totalCost = components.fold(0.0, (sum, c) => sum + c.totalCost);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Components (${components.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear All Components'),
                    content: const Text('Are you sure you want to remove all components?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          for (int i = components.length - 1; i >= 0; i--) {
                            onRemove(i);
                          }
                          Navigator.pop(ctx);
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_sweep, size: 18, color: Colors.red),
              label: const Text('Clear All', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Materials section
        if (materials.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Materials (Consumed) - ${materials.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ..._buildComponentList(materials, isByproduct: false),
        ],

        if (materials.isNotEmpty && byproducts.isNotEmpty)
          const SizedBox(height: 16),

        // Byproducts section
        if (byproducts.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.recycling, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Byproducts / Wastage (Produced) - ${byproducts.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ..._buildComponentList(byproducts, isByproduct: true),
        ],

        const SizedBox(height: 16),

        // Total cost summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total BOM Cost:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '${totalCost.abs().toStringAsFixed(2)} PKR',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
              if (totalCost < 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Warning: Net BOM cost is negative. Consider adjusting quantities.',
                          style: TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Suggested Selling Price:',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    '${(totalCost.abs() * 1.3).toStringAsFixed(2)} PKR (30% margin)',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildComponentList(List<BomComponent> components, {required bool isByproduct}) {
    final List<Widget> widgets = [];

    for (int index = 0; index < components.length; index++) {
      final component = components[index];

      widgets.add(
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isByproduct ? Colors.orange.shade200 : const Color(0xFFE0E0E8),
            ),
          ),
          child: ExpansionTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isByproduct ? Colors.orange.shade100 : const Color(0xFFEDE9FB),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                isByproduct ? Icons.recycling : Icons.inventory,
                size: 20,
                color: isByproduct ? Colors.orange : const Color(0xFF7C3AED),
              ),
            ),
            title: Text(
              component.productName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Qty: ${component.quantity.abs().toStringAsFixed(4)} ${component.unit}',
                      style: TextStyle(
                        color: isByproduct ? Colors.orange : Colors.grey[600],
                        fontWeight: isByproduct ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                    if (isByproduct) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'WASTE/PRODUCED',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Cost: ${component.totalCost.abs().toStringAsFixed(2)} PKR ${isByproduct ? '(reduces total)' : ''}',
                  style: TextStyle(
                    color: isByproduct ? Colors.orange : Colors.green,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF7C3AED), size: 20),
                  onPressed: () => onEdit(component),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () {
                    // Find the actual index in the main components list
                    final actualIndex = components.indexOf(component);
                    onRemove(actualIndex);
                  },
                ),
              ],
            ),
            children: [
              if (component.notes != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notes:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          component.notes!,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

      // Add separator between items (except after the last one)
      if (index < components.length - 1) {
        widgets.add(const SizedBox(height: 8));
      }
    }

    return widgets;
  }
}