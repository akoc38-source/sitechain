// lib/screens/progress_structures_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/pipe_line_model.dart';

class ProgressStructuresScreen extends StatefulWidget {
  final String activeProjectId;

  const ProgressStructuresScreen({
    super.key,
    required this.activeProjectId,
  });

  @override
  State<ProgressStructuresScreen> createState() =>
      _ProgressStructuresScreenState();
}

class _ProgressStructuresScreenState extends State<ProgressStructuresScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedLineId;
  String _searchQuery = "";

  // ✏️ Hat İlerleme Metrajı Güncelleme Diyaloğu
  void _editProgressDialog(PipeLine line) {
    final kaziCtrl =
        TextEditingController(text: line.kaziKm.toStringAsFixed(2));
    final yataklamaCtrl =
        TextEditingController(text: line.yataklamaKm.toStringAsFixed(2));
    final montajCtrl =
        TextEditingController(text: line.montajKm.toStringAsFixed(2));
    final kapamaCtrl =
        TextEditingController(text: line.kapamaKm.toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E2638),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
              Text(
                "📝 İlerleme Güncelle: ${line.code} (${line.name})",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF9F1C),
                ),
              ),
              const SizedBox(height: 16),
              _buildKmInput("1. Kazı Aşaması (km)", kaziCtrl),
              _buildKmInput("2. Çakıl Yataklama (km)", yataklamaCtrl),
              _buildKmInput("3. Boru Montajı (km)", montajCtrl),
              _buildKmInput("4. Geri Dolgu / Kapama (km)", kapamaCtrl),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9F1C),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () async {
                  await _firestore
                      .collection('projects')
                      .doc(widget.activeProjectId)
                      .collection('lines')
                      .doc(line.id)
                      .update({
                    'kaziKm':
                        double.tryParse(kaziCtrl.text.trim()) ?? line.kaziKm,
                    'yataklamaKm': double.tryParse(yataklamaCtrl.text.trim()) ??
                        line.yataklamaKm,
                    'montajKm': double.tryParse(montajCtrl.text.trim()) ??
                        line.montajKm,
                    'kapamaKm': double.tryParse(kapamaCtrl.text.trim()) ??
                        line.kapamaKm,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text("KAYDET VE GÜNCELLE",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKmInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1420),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('projects')
            .doc(widget.activeProjectId)
            .collection('lines')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF9F1C)));
          }

          final docs = snapshot.data?.docs ?? [];
          List<PipeLine> allLines = docs
              .map((d) =>
                  PipeLine.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();

          if (allLines.isEmpty) {
            return _buildEmptyState();
          }

          PipeLine? currentLine;
          if (_selectedLineId != null) {
            currentLine = allLines.firstWhere(
              (l) => l.id == _selectedLineId,
              orElse: () => allLines.first,
            );
          }

          return Column(
            children: [
              _selectedLineId == null
                  ? _buildOverviewHeader(allLines)
                  : _buildDetailHeader(allLines, currentLine!),
              Expanded(
                child: _selectedLineId == null
                    ? _buildOverviewList(allLines)
                    : _buildLineDetailView(currentLine!),
              ),
            ],
          );
        },
      ),
    );
  }

  // 1️⃣ ŞEBEKE ÖZET PANOSU HEADER
  Widget _buildOverviewHeader(List<PipeLine> lines) {
    double totalNetworkKm =
        lines.fold(0.0, (acc, l) => acc + (l.totalKm - l.startKm));
    double completedKm = lines.fold(
        0.0,
        (acc, l) =>
            acc + (l.montajKm - l.startKm).clamp(0.0, l.totalKm - l.startKm));
    double totalProgress =
        totalNetworkKm > 0 ? (completedKm / totalNetworkKm) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      color: const Color(0xFF1E2638),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "🗺️ Şebeke İlerleme Özet Panosu",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9F1C).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${lines.length} Hat",
                  style: const TextStyle(
                      color: Color(0xFFFF9F1C),
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: totalProgress / 100,
                    minHeight: 10,
                    backgroundColor: Colors.white10,
                    color: const Color(0xFFFF9F1C),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "%${totalProgress.toStringAsFixed(1)}",
                style: const TextStyle(
                    color: Color(0xFFFF9F1C),
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (val) =>
                setState(() => _searchQuery = val.trim().toLowerCase()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: "Hat Ara (Örn: S2-1, S2-22)...",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.grey, size: 20),
              filled: true,
              fillColor: const Color(0xFF0E1420),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  // 2️⃣ HAT DETAY HEADER (Hızlı Geçiş Seçicili)
  Widget _buildDetailHeader(List<PipeLine> lines, PipeLine activeLine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF1E2638),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFFFF9F1C)),
            onPressed: () => setState(() => _selectedLineId = null),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1420),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: activeLine.id,
                  dropdownColor: const Color(0xFF1E2638),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down,
                      color: Color(0xFFFF9F1C)),
                  items: lines.map((line) {
                    return DropdownMenuItem<String>(
                      value: line.id,
                      child: Text(
                        "📌 ${line.code} (${line.pipeType} • ${line.totalKm.toStringAsFixed(1)} km)",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (newId) {
                    if (newId != null) {
                      setState(() => _selectedLineId = newId);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3️⃣ ÖZET LİSTESİ (Tüm Hat Kartları)
  Widget _buildOverviewList(List<PipeLine> lines) {
    final filteredLines = lines.where((l) {
      return l.code.toLowerCase().contains(_searchQuery) ||
          l.name.toLowerCase().contains(_searchQuery);
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredLines.length,
      itemBuilder: (context, i) {
        final line = filteredLines[i];
        double progress = line.progressPercentage;

        return Card(
          color: const Color(0xFF1E2638),
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(line.code,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text("%${progress.toStringAsFixed(1)}",
                    style: const TextStyle(
                        color: Color(0xFFFF9F1C),
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                    "${line.name} • ${line.pipeType} • Uzunluk: ${line.totalKm.toStringAsFixed(2)} km",
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    color: const Color(0xFF2EC4B6),
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              setState(() => _selectedLineId = line.id);
            },
          ),
        );
      },
    );
  }

  // 4️⃣ SEÇİLİ HAT DETAY GÖRÜNÜMÜ (4 Aşamalı İlerleme & Sanat Yapıları)
  Widget _buildLineDetailView(PipeLine line) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Hat İlerleme Durumu (${line.pipeType})",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFFFF9F1C)),
                onPressed: () => _editProgressDialog(line),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStageCard(
              "1. Kazı Aşaması", line.kaziKm, line.totalKm, Colors.redAccent),
          _buildStageCard("2. Çakıl Yataklama", line.yataklamaKm, line.totalKm,
              Colors.orangeAccent),
          _buildStageCard("3. Boru Montajı", line.montajKm, line.totalKm,
              const Color(0xFF2EC4B6)),
          _buildStageCard("4. Geri Dolgu / Kapama", line.kapamaKm, line.totalKm,
              Colors.blueAccent),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  "Sanat Yapıları & Branşmanlar (${line.sanatYapitlari.length})",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16, color: Color(0xFFFF9F1C)),
                label: const Text("EKLE",
                    style: TextStyle(color: Color(0xFFFF9F1C), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (line.sanatYapitlari.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: Text("Bu hatta ait henüz sanat yapısı bulunmuyor.",
                      style: TextStyle(color: Colors.grey, fontSize: 12))),
            )
          else
            Column(
              children: line.sanatYapitlari.map((sy) {
                return Card(
                  color: const Color(0xFF1E2638),
                  child: ListTile(
                    leading: const Icon(Icons.settings_input_component,
                        color: Color(0xFFFF9F1C)),
                    title: Text(sy["name"] ?? "Sanat Yapısı",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        "Km: ${sy["km"] ?? "0+000"} • Metraj: ${sy["beton"] ?? "0"} m³",
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 11)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(sy["status"] ?? "Tamamlandı",
                          style: const TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStageCard(
      String title, double currentKm, double totalKm, Color color) {
    double ratio = totalKm > 0 ? (currentKm / totalKm).clamp(0.0, 1.0) : 0.0;
    return Card(
      color: const Color(0xFF1E2638),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(
                    "Km: ${currentKm.toStringAsFixed(2)} / ${totalKm.toStringAsFixed(2)}",
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: Colors.white10,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.alt_route, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("Bu projede henüz kayıtlı hat bulunmuyor.",
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9F1C),
                foregroundColor: Colors.black),
            onPressed: () async {
              WriteBatch batch = _firestore.batch();
              List<String> lineCodes = [
                "S2 Ana Hat",
                "S2-1",
                "S2-2",
                "S2-2-1",
                "S2-2-2"
              ];
              for (var code in lineCodes) {
                var docRef = _firestore
                    .collection('projects')
                    .doc(widget.activeProjectId)
                    .collection('lines')
                    .doc();
                batch.set(docRef, {
                  'id': docRef.id,
                  'name': '$code Boru Hattı',
                  'code': code,
                  'pipeType': 'C1000 CTP',
                  'totalKm': 5.0,
                  'startKm': 0.0,
                  'kaziKm': 2.5,
                  'yataklamaKm': 2.0,
                  'montajKm': 1.5,
                  'kapamaKm': 1.0,
                  'sanatYapitlari': [],
                });
              }
              await batch.commit();
            },
            icon: const Icon(Icons.playlist_add),
            label: const Text("ÖRNEK ŞEBEKE HATLARINI YÜKLE",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
