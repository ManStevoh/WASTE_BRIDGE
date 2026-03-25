import 'package:flutter/material.dart';
import 'package:waste_bridge/models/app_enums.dart';

class AuthRoleDropdown extends StatelessWidget {
  const AuthRoleDropdown({
    super.key,
    required this.selectedRole,
    required this.onChanged,
  });

  final UserRole selectedRole;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<UserRole>(
      value: selectedRole,
      decoration: const InputDecoration(labelText: 'Role'),
      items: UserRole.values
          .where((r) => r != UserRole.admin)
          .map(
            (role) => DropdownMenuItem(
              value: role,
              child: Text(role.toString().split('.').last.toUpperCase()),
            ),
          )
          .toList(),
      onChanged: (role) {
        if (role != null) onChanged(role);
      },
    );
  }
}
