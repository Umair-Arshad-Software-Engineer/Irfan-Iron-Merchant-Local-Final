import 'package:flutter/material.dart';

class CustomDropdown extends StatelessWidget {
  final String? value;
  final String label;
  final String hintText;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool isExpanded;
  final bool enabled;

  const CustomDropdown({
    super.key,
    this.value,
    required this.label,
    required this.hintText,
    required this.items,
    this.onChanged,
    this.validator,
    this.isExpanded = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: Color(0xFFE5E7EB),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: Color(0xFF7C3AED),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: const Color(0xFFF5F6FA),
            ),
            hint: Text(
              hintText,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            items: items,
            onChanged: onChanged,
            validator: validator,
            isExpanded: isExpanded,
            style: const TextStyle(
              color: Color(0xFF2D3142),
              fontSize: 14,
            ),
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: Colors.grey[500],
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            elevation: 4,
          ),
        ),
      ],
    );
  }
}