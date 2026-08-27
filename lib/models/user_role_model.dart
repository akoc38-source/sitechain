// lib/models/user_role_model.dart

enum UserRole { admin, editor, reviewer, viewer }

extension UserRoleExtension on UserRole {
  String get title {
    switch (this) {
      case UserRole.admin:
        return "👑 Şantiye Şefi (Admin)";
      case UserRole.editor:
        return "🏗️ Saha Mühendisi (Editör)";
      case UserRole.reviewer:
        return "🛡️ İdare / Kontrolör";
      case UserRole.viewer:
        return "👁️ Saha Çalışanı (İzleyici)";
    }
  }

  // Yetki Kontrolleri
  bool get canEditData => this == UserRole.admin || this == UserRole.editor;
  bool get canApproveLogs => this == UserRole.admin;
  bool get canManageTeam => this == UserRole.admin;
}
