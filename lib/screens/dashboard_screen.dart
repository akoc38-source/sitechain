// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/dashboard_widgets.dart';
import '../dialogs/dashboard_sheets.dart';
import '../utils/line_calculator.dart';
import 'harita_sayfasi.dart';

class DashboardScreen extends StatefulWidget {
  final String activeProjectDocId;

  const DashboardScreen({
    super.key,
    this.activeProjectDocId = "agcasar_s2",
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentTab = 0;
  bool isProUser = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> syncDataToFirebase(Map<String, dynamic> projectData) async {
    try {
      await _firestore.collection('projects').doc(projectData["id"]).set({
        ...projectData,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Firebase Senkronizasyon Hatası: $e");
    }
  }

  List<String> checkCriticalWarnings(Map<String, dynamic> activeProj) {
    List<String> warnings = [];
    double currentMontajMeters =
        LineCalculator.parseKmToMeters(activeProj["montajKm"] ?? "12+000.00");
    List<dynamic> rawSanatList = activeProj["sanatYapitlari"] ?? [];

    for (var yapi in rawSanatList) {
      if (yapi["durum"] == "Bekliyor") {
        double yapiMeters =
            LineCalculator.parseKmToMeters(yapi["km"]?.toString() ?? "0");
        double distance = yapiMeters - currentMontajMeters;

        if (distance >= 0 && distance <= 100) {
          warnings.add(
              "⚠️ DİKKAT: Boru montajınız ${yapi["tip"]} noktasına ${distance.toStringAsFixed(1)} metre yaklaştı! T-Parçasını koymayı unutmayın!");
        } else if (distance < 0 && distance >= -20) {
          warnings.add(
              "🔴 TEHLİKE: ${yapi["tip"]} (Km: ${yapi["km"]}) noktası geçildi! Vantuz/Yapı montajı yapılmadıysa üzerini kapatmayın!");
        }
      }
    }
    return warnings;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('projects')
          .doc(widget.activeProjectDocId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF121824),
            body: Center(
                child: CircularProgressIndicator(color: Color(0xFFFF9F1C))),
          );
        }

        Map<String, dynamic> activeProj;
        if (snapshot.hasData &&
            snapshot.data!.exists &&
            snapshot.data!.data() != null) {
          activeProj = snapshot.data!.data() as Map<String, dynamic>;
        } else {
          activeProj = {
            "id": widget.activeProjectDocId,
            "name": "Ağcaşar S2 Projesi (Yahyalı)",
            "code": "AGS-S2",
            "pipeType": "C2000 CTP",
            "startKm": "12+000.00",
            "totalKm": "20.00",
            "kaziKm": "12+000.00",
            "yataklamaKm": "12+000.00",
            "montajKm": "12+000.00",
            "kapamaKm": "12+000.00",
            "cakilSefer": 0,
            "betonM3": 0.0,
            "sanatYapitlari": []
          };
        }

        List<String> activeWarnings = checkCriticalWarnings(activeProj);
        List<dynamic> sanatList = activeProj["sanatYapitlari"] ?? [];

        return Scaffold(
          backgroundColor: const Color(0xFF121824),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E2638),
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9F1C).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.hub, color: Color(0xFFFF9F1C), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activeProj["name"] ?? "SiteChain",
                          style: GoogleFonts.titilliumWeb(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white),
                          overflow: TextOverflow.ellipsis),
                      Text('Kod: ${activeProj["code"] ?? "AGS"}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              GestureDetector(
                onTap: () => showVipCodeDialog(context, isProUser, (success) {
                  setState(() => isProUser = success);
                }),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isProUser
                        ? const Color(0xFF2EC4B6).withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isProUser
                            ? const Color(0xFF2EC4B6)
                            : Colors.orange),
                  ),
                  child: Row(
                    children: [
                      Icon(isProUser ? Icons.verified : Icons.lock_outline,
                          size: 14,
                          color: isProUser
                              ? const Color(0xFF2EC4B6)
                              : Colors.orange),
                      const SizedBox(width: 4),
                      Text(isProUser ? "PRO" : "KOD",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isProUser
                                  ? const Color(0xFF2EC4B6)
                                  : Colors.orange)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 📱 SADELEŞTİRİLMİŞ SEKME İÇERİKLERİ
          body: IndexedStack(
            index: _currentTab,
            children: [
              // 📊 SEKME 1: PANO (GENEL ÖZET & UYARILAR)
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProjectHeaderCard(
                      activeProj: activeProj,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 16),
                    if (activeWarnings.isNotEmpty) ...[
                      ...activeWarnings.map((w) => WarningBanner(message: w)),
                      const SizedBox(height: 16),
                    ],
                    const Text('Günlük Saha Özeti',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: StatCard(
                                title: 'Çakıl Sefer',
                                value:
                                    '${activeProj["cakilSefer"] ?? 0} Kamyon',
                                icon: Icons.local_shipping,
                                color: Colors.amber)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: StatCard(
                                title: 'Dökülen Beton',
                                value: '${activeProj["betonM3"] ?? 0} m³',
                                icon: Icons.foundation,
                                color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => showDataEntrySheet(
                                context,
                                activeProj,
                                (updatedData) =>
                                    syncDataToFirebase(updatedData)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF9F1C),
                              foregroundColor: Colors.black,
                              minimumSize: const Size(0, 48),
                            ),
                            icon: const Icon(Icons.add_location_alt, size: 18),
                            label: const Text('VERİ GİR',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                showDsiReportDialog(context, activeProj),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2EC4B6),
                              foregroundColor: Colors.black,
                              minimumSize: const Size(0, 48),
                            ),
                            icon: const Icon(Icons.description, size: 18),
                            label: const Text('DSİ RAPORU',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 🏗️ SEKME 2: İLERLEME & YAPILAR (HAT KLASÖRLÜ LİSTELEME)
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Hat İlerleme Durumu (${activeProj["pipeType"] ?? "Boru"})',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 12),
                    ProgressCard(
                        title: '1. Kazı Aşaması',
                        currentKm: activeProj["kaziKm"] ?? "12+000.00",
                        progress: 0.85,
                        color: const Color(0xFFE71D36)),
                    ProgressCard(
                        title: '2. Çakıl Yataklama',
                        currentKm: activeProj["yataklamaKm"] ?? "12+000.00",
                        progress: 0.72,
                        color: const Color(0xFFFF9F1C)),
                    ProgressCard(
                        title: '3. Boru Montajı',
                        currentKm: activeProj["montajKm"] ?? "12+000.00",
                        progress: 0.65,
                        color: const Color(0xFF2EC4B6)),
                    ProgressCard(
                        title: '4. Geri Dolgu / Kapama',
                        currentKm: activeProj["kapamaKm"] ?? "12+000.00",
                        progress: 0.58,
                        color: const Color(0xFF20A4F3)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sanat Yapıları & Branşmanlar',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        InkWell(
                          onTap: () => showAddStructureSheet(
                              context,
                              activeProj,
                              (updatedData) => syncDataToFirebase(updatedData)),
                          child: const Row(
                            children: [
                              Icon(Icons.add_circle,
                                  size: 16, color: Color(0xFFFF9F1C)),
                              SizedBox(width: 4),
                              Text('EKLE',
                                  style: TextStyle(
                                      color: Color(0xFFFF9F1C),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 📁 AKILLI KLASÖRLÜ HAT LİSTESİ
                    buildGroupedStructuresList(
                      sanatList,
                      onDelete: (indexToDelete) {
                        List<dynamic> updatedList = List.from(sanatList);
                        updatedList.removeAt(indexToDelete);
                        activeProj["sanatYapitlari"] = updatedList;
                        syncDataToFirebase(activeProj);
                      },
                    ),
                  ],
                ),
              ),

              // 🗺️ SEKME 3: CANLI HARİTA
              HaritaSayfasi(
                activeProjectDocId: widget.activeProjectDocId,
              ),
            ],
          ),

          // ⚓ ALT DOKUNMATİK SEKMELER (BOTTOM NAV BAR)
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentTab,
            backgroundColor: const Color(0xFF1E2638),
            selectedItemColor: const Color(0xFFFF9F1C),
            unselectedItemColor: Colors.grey,
            onTap: (index) => setState(() => _currentTab = index),
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard), label: "Pano"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.format_list_bulleted),
                  label: "İlerleme & Yapılar"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.map), label: "Canlı Harita"),
            ],
          ),
        );
      },
    );
  }
}
