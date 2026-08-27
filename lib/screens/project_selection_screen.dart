import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project_model.dart';
import '../dialogs/project_access_sheets.dart';
import 'dashboard_screen.dart';

class ProjectSelectionScreen extends StatefulWidget {
  const ProjectSelectionScreen({super.key});

  @override
  State<ProjectSelectionScreen> createState() => _ProjectSelectionScreenState();
}

class _ProjectSelectionScreenState extends State<ProjectSelectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedCategoryFilter = "Tümü";

  // 🎲 6 Haneli Benzersiz Katılım Kodu Üretici
  String _generateJoinCode(String prefix) {
    var rng = Random();
    int code = 1000 + rng.nextInt(9000);
    String cleanPrefix =
        prefix.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (cleanPrefix.length > 3) cleanPrefix = cleanPrefix.substring(0, 3);
    return "${cleanPrefix.isEmpty ? 'PRJ' : cleanPrefix}-$code";
  }

  void _yeniProjeOlusturDiyalog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: "Kayseri");
    final districtCtrl = TextEditingController(text: "Yahyalı");
    final startKmCtrl = TextEditingController(text: "0+000.00");
    final totalKmCtrl = TextEditingController(text: "10.00");

    ProjectType selectedType = ProjectType.sulamaBoru;

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    "➕ Yeni Altyapı Projesi Oluştur",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF9F1C),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ProjectType>(
                  initialValue: selectedType,
                  dropdownColor: const Color(0xFF121824),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: "Proje Türü / Sektör",
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                  items: ProjectType.values.map((type) {
                    var config = ProjectTypeConfig.configs[type]!;
                    return DropdownMenuItem(
                      value: type,
                      child: Text("${config['icon']} ${config['title']}"),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setModalState(() => selectedType = v);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Proje Adı (Örn: Ağcaşar S2 Sulaması)",
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                TextField(
                  controller: codeCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Şantiye Kodu (Örn: AGS-S2)",
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cityCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "İl",
                          labelStyle: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: districtCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "İlçe",
                          labelStyle: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startKmCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Başlangıç Km",
                          labelStyle: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: totalKmCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Toplam Hat (km)",
                          labelStyle: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9F1C),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () async {
                    String rawCode = codeCtrl.text.trim().toUpperCase();
                    String docId = rawCode.toLowerCase().replaceAll(' ', '_');
                    if (docId.isEmpty) {
                      docId = DateTime.now().millisecondsSinceEpoch.toString();
                    }

                    var config = ProjectTypeConfig.configs[selectedType]!;
                    String generatedJoinCode =
                        _generateJoinCode(rawCode.isEmpty ? "PRJ" : rawCode);

                    await _firestore.collection('projects').doc(docId).set({
                      "id": docId,
                      "name": nameCtrl.text.trim().isEmpty
                          ? "Yeni Proje"
                          : nameCtrl.text.trim(),
                      "code": rawCode.isEmpty ? "AGS" : rawCode,
                      "joinCode": generatedJoinCode, // 🔑 Ekip Katılım Kodu
                      "city": cityCtrl.text.trim(),
                      "district": districtCtrl.text.trim(),
                      "projectType": selectedType.name,
                      "pipeType": config['title'],
                      "startKm": startKmCtrl.text.trim(),
                      "totalKm": totalKmCtrl.text.trim(),
                      "kaziKm": startKmCtrl.text.trim(),
                      "yataklamaKm": startKmCtrl.text.trim(),
                      "montajKm": startKmCtrl.text.trim(),
                      "kapamaKm": startKmCtrl.text.trim(),
                      "cakilSefer": 0,
                      "betonM3": 0.0,
                      "sanatYapitlari": [],
                      "createdAt": FieldValue.serverTimestamp(),
                    });

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text("PROJEYİ OLUŞTUR VE BAŞLA",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1420),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('projects').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF9F1C)),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            double totalKmSum = 0;
            for (var d in docs) {
              var data = d.data() as Map<String, dynamic>;
              totalKmSum +=
                  double.tryParse(data["totalKm"]?.toString() ?? "0") ?? 0;
            }

            return Column(
              children: [
                // Header Alanı
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0E1420),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            height: 180,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.hub,
                              color: Color(0xFFFF9F1C),
                              size: 90,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "SiteChain",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 30,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Global Infrastructure Platform",
                                  style: TextStyle(
                                    color: Color(0xFFFF9F1C),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Özet Metrik Kartları
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2638),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Aktif Projeler",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${docs.length} Şantiye",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2638),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFF9F1C)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Toplam Altyapı",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${totalKmSum.toStringAsFixed(1)} km",
                                    style: const TextStyle(
                                      color: Color(0xFFFF9F1C),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Kategori Filtreleri
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: ["Tümü", "Sulama", "Yol", "Elektrik", "İçme Suyu"]
                        .map((category) {
                      bool isSelected = _selectedCategoryFilter == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(category),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          selectedColor: const Color(0xFFFF9F1C),
                          backgroundColor: const Color(0xFF1E2638),
                          onSelected: (val) {
                            setState(() => _selectedCategoryFilter = category);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Proje Listesi
                Expanded(
                  child: docs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.account_tree_outlined,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text("Henüz bir altyapı projeniz yok.",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 16)),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF9F1C),
                                    foregroundColor: Colors.black),
                                onPressed: _yeniProjeOlusturDiyalog,
                                icon: const Icon(Icons.add),
                                label: const Text("İLK PROJENİ OLUŞTUR",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: docs.length,
                          itemBuilder: (context, i) {
                            var p = docs[i].data() as Map<String, dynamic>;
                            String typeName = p["projectType"] ?? "sulamaBoru";
                            ProjectType pType = ProjectType.values.firstWhere(
                              (e) => e.name == typeName,
                              orElse: () => ProjectType.sulamaBoru,
                            );
                            var config = ProjectTypeConfig.configs[pType]!;

                            return Card(
                              color: const Color(0xFF1E2638),
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Text(
                                  config['icon'],
                                  style: const TextStyle(fontSize: 28),
                                ),
                                title: Text(
                                  p["name"] ?? "İsimsiz Proje",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Text(
                                  "${p["city"] ?? ""} / ${p["district"] ?? ""} • ${config['title']}\nKatılım Kodu: ${p["joinCode"] ?? "AGS-1001"}",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Color(0xFFFF9F1C),
                                  size: 16,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DashboardScreen(
                                        activeProjectDocId:
                                            p["id"] ?? "agcasar_s2",
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      // 🚀 ÇİFT AKSİYON BUTONU: PROJEYE KATIL & YENİ PROJE EKLE
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "btnJoin",
            backgroundColor: const Color(0xFF2EC4B6),
            foregroundColor: Colors.black,
            onPressed: () {
              ProjectAccessSheets.showJoinProjectSheet(context, "user_demo_id");
            },
            icon: const Icon(Icons.link),
            label: const Text("KODLA KATIL",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: "btnAdd",
            backgroundColor: const Color(0xFFFF9F1C),
            foregroundColor: Colors.black,
            onPressed: _yeniProjeOlusturDiyalog,
            icon: const Icon(Icons.add),
            label: const Text("YENİ PROJE",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
