import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/permission_provider.dart';
import '../services/permission_service.dart';

class PermissionGuard extends ConsumerWidget {
  final Widget child;
  final List<Permission> requiredPermissions;
  final Widget Function(BuildContext, List<Permission> missingPermissions) onDenied;

  const PermissionGuard({
    super.key,
    required this.child,
    required this.requiredPermissions,
    required this.onDenied,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PermissionService service = ref.read(permissionServiceProvider);

    return FutureBuilder<List<Permission>>(
      future: service.missingPermissions(requiredPermissions),
      builder: (BuildContext context, AsyncSnapshot<List<Permission>> snapshot) {
        if (!snapshot.hasData) {
          return child;
        }

        final List<Permission> missingPermissions = snapshot.data!;
        if (missingPermissions.isEmpty) {
          return child;
        }

        return onDenied(context, missingPermissions);
      },
    );
  }
}