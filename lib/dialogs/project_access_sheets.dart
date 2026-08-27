// lib/dialogs/project_access_sheets.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_role_model.dart';

class ProjectAccessSheets {
  // Projeye Koduyla Katılma Penceresi
  static void showJoinProjectSheet(BuildContext context, String currentUserId) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    UserRole requestedRole = UserRole.editor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E2638),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  "🔗 Projeye Koduyla Katıl",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF9F1C),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: "6 Haneli Proje Katılım Kodu (Örn: AGS892)",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText:
                      "Adınız ve Unvanınız (Örn: Ahmet Yılmaz - Saha Müh.)",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<UserRole>(
                initialValue: requestedRole,
                dropdownColor: const Color(0xFF121824),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: "Talep Edilen Rol",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                items: UserRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.title),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setModalState(() => requestedRole = v);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9F1C),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () async {
                  String code = codeCtrl.text.trim().toUpperCase();
                  if (code.isEmpty || nameCtrl.text.trim().isEmpty) return;

                  // Kod ile projeyi bul
                  var query = await FirebaseFirestore.instance
                      .collection('projects')
                      .where('joinCode', isEqualTo: code)
                      .limit(1)
                      .get();

                  if (query.docs.isNotEmpty) {
                    String projectId = query.docs.first.id;

                    // Katılım Talebi Ekle (Beklemede)
                    await FirebaseFirestore.instance
                        .collection('projects')
                        .doc(projectId)
                        .collection('pending_members')
                        .doc(currentUserId)
                        .set({
                      "userId": currentUserId,
                      "userName": nameCtrl.text.trim(),
                      "requestedRole": requestedRole.name,
                      "status": "pending",
                      "requestedAt": FieldValue.serverTimestamp(),
                    });

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              "Katılım talebiniz şantiye şefine iletildi!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Geçersiz Proje Kodu!"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text("KATILIM TALEBİ GÖNDER",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
