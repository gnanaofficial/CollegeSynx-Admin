import 'package:flutter/material.dart';
import '../../../core/config/role_config.dart';
import '../../../core/theme/app_colors.dart';

class RoleSelector extends StatelessWidget {
  final UserRole selectedRole;
  final ValueChanged<UserRole> onRoleSelected;

  const RoleSelector({
    super.key,
    required this.selectedRole,
    required this.onRoleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: UserRole.values.map((role) {
          final isSelected = role == selectedRole;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(role.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) onRoleSelected(role);
              },
              selectedColor: AppColors.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
