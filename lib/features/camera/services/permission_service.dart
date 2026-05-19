import 'package:permission_handler/permission_handler.dart';

enum PermissionFlowResult { granted, denied, permanentlyDenied }

/// Handles runtime permissions required by camera capture flow.
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  Future<PermissionFlowResult> ensureCameraFlowPermissions() async {
    final current = await Permission.camera.status;
    if (current.isGranted) {
      return PermissionFlowResult.granted;
    }

    if (current.isPermanentlyDenied || current.isRestricted) {
      return PermissionFlowResult.permanentlyDenied;
    }

    final requested = await Permission.camera.request();
    if (requested.isGranted) return PermissionFlowResult.granted;
    if (requested.isPermanentlyDenied || requested.isRestricted) {
      return PermissionFlowResult.permanentlyDenied;
    }
    return PermissionFlowResult.denied;
  }
}
