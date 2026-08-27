import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_role_model.dart';

void showTeamManagementSheet(BuildContext context, String projectId) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E2638),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('pending_members')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        final requests = snapshot.data?.docs ?? [];

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "👥 Bekleyen Ekip Katılım Talepleri",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 12),
              if (requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text("Bekleyen katılım talebi bulunmuyor.",
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: requests.length,
                    itemBuilder: (context, i) {
                      var data = requests[i].data() as Map<String, dynamic>;
                      String reqRoleName = data["requestedRole"] ?? "viewer";
                      UserRole reqRole = UserRole.values
                          .firstWhere((e) => e.name == reqRoleName);

                      return ListTile(
                        title: Text(data["userName"] ?? "İsimsiz Kullanıcı",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text("Talep Edilen: ${reqRole.title}",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle,
                                  color: Colors.green),
                              onPressed: () async {
                                // Ekip üyesi olarak projeye kaydet
                                await FirebaseFirestore.instance
                                    .collection('projects')
                                    .doc(projectId)
                                    .collection('members')
                                    .doc(data["userId"])
                                    .set({
                                  "userName": data["userName"],
                                  "role": reqRole.name,
                                  "approvedAt": FieldValue.serverTimestamp(),
                                });

                                // Bekleyen talebi sil
                                await requests[i].reference.delete();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () async {
                                await requests[i].reference.delete();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
