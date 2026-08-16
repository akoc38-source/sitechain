import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/dashboard_widgets.dart';
import '../dialogs/dashboard_sheets.dart';
import 'harita_sayfasi.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isProUser = false;
  String activeProjectDocId = "agcasar_s2";

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

  double parseKmToMeters(String kmText) {
    try {
      String cleanText = kmText.replaceAll('+', '').trim();
      return double.parse(cleanText);
    } catch (e) {
      return 0.0;
    }
  }

  List<String> checkCriticalWarnings(Map<String, dynamic> activeProj) {
    List<String> warnings = [];
    double currentMontajMeters =
        parseKmToMeters(activeProj["montajKm"] ?? "00+000.00");
    List<dynamic> rawSanatList = activeProj["sanatYapitlari"] ?? [];

    for (var yapi in rawSanatList) {
      if (yapi["durum"] == "Bekliyor") {
        double yapiMeters = parseKmToMeters(yapi["km"]?.toString() ?? "0");
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2638),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9F1C).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hub, color: Color(0xFFFF9F1C)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SiteChain',
                    style: GoogleFonts.titilliumWeb(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.white)),
                const Text('Doğrusal Altyapı Yönetimi',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map, color: Color(0xFFFF9F1C)),
            tooltip: "Canlı Saha Haritası",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HaritaSayfasi(),
                ),
              );
            },
          ),
          GestureDetector(
            onTap: () => showVipCodeDialog(context, isProUser, (success) {
              setState(() {
                isProUser = success;
              });
            }),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isProUser
                    ? const Color(0xFF2EC4B6).withValues(alpha: 0.2)
                    : Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isProUser ? const Color(0xFF2EC4B6) : Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(isProUser ? Icons.verified : Icons.lock_outline,
                      size: 14,
                      color:
                          isProUser ? const Color(0xFF2EC4B6) : Colors.orange),
                  const SizedBox(width: 4),
                  Text(isProUser ? "VIP PRO" : "KOD GİR",
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('projects')
            .doc(activeProjectDocId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF9F1C)));
          }

          Map<String, dynamic> activeProj;
          if (snapshot.hasData &&
              snapshot.data!.exists &&
              snapshot.data!.data() != null) {
            activeProj = snapshot.data!.data() as Map<String, dynamic>;
          } else {
            activeProj = {
              "id": activeProjectDocId,
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
              "sanatYapitlari": [
                {
                  "tip": "Vantuz #2",
                  "km": "12+250.00",
                  "beton": "4.5 m³",
                  "durum": "Bekliyor"
                },
                {
                  "tip": "Hidrant #4",
                  "km": "13+100.00",
                  "beton": "2.0 m³",
                  "durum": "Tamamlandı"
                },
              ]
            };
          }

          List<String> activeWarnings = checkCriticalWarnings(activeProj);
          List<dynamic> sanatList = activeProj["sanatYapitlari"] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProjectHeaderCard(
                  activeProj: activeProj,
                  onTap: () => showProjectSelectorSheet(context, (newCode) {
                    setState(() {
                      activeProjectDocId = newCode;
                    });
                  }),
                ),
                const SizedBox(height: 16),
                if (activeWarnings.isNotEmpty) ...[
                  ...activeWarnings
                      .map((warning) => WarningBanner(message: warning)),
                  const SizedBox(height: 16),
                ],
                Text(
                    'Hat İlerleme Durumu (${activeProj["pipeType"] ?? "Boru"})',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 12),
                ProgressCard(
                    title: '1. Kazı Aşaması',
                    currentKm: activeProj["kaziKm"] ?? "00+000.00",
                    progress: 0.85,
                    color: const Color(0xFFE71D36)),
                ProgressCard(
                    title: '2. Çakıl Yataklama',
                    currentKm: activeProj["yataklamaKm"] ?? "00+000.00",
                    progress: 0.72,
                    color: const Color(0xFFFF9F1C)),
                ProgressCard(
                    title: '3. Boru Montajı',
                    currentKm: activeProj["montajKm"] ?? "00+000.00",
                    progress: 0.65,
                    color: const Color(0xFF2EC4B6)),
                ProgressCard(
                    title: '4. Geri Dolgu / Kapama',
                    currentKm: activeProj["kapamaKm"] ?? "00+000.00",
                    progress: 0.58,
                    color: const Color(0xFF20A4F3)),
                const SizedBox(height: 20),
                const Text('Günlük Saha Özeti (Anlık Canlı)',
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
                            value: '${activeProj["cakilSefer"] ?? 0} Kamyon',
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text('Sanat Yapıları & Branşmanlar',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            overflow: TextOverflow.ellipsis)),
                    InkWell(
                      onTap: () => showAddStructureSheet(context, activeProj,
                          (updatedData) => syncDataToFirebase(updatedData)),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
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
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (sanatList.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1E2638),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Center(
                        child: Text(
                            'Henüz eklenmiş bir sanat yapısı veya branşman yok.',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 13))),
                  )
                else
                  ...List.generate(sanatList.length, (index) {
                    var yapi = Map<String, dynamic>.from(sanatList[index]);
                    return StructureTile(
                      yapi: yapi,
                      activeProj: activeProj,
                      index: index,
                      onUpdate: (updatedData) =>
                          syncDataToFirebase(updatedData),
                    );
                  }),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HaritaSayfasi(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2638),
                    foregroundColor: const Color(0xFFFF9F1C),
                    minimumSize: const Size(double.infinity, 52),
                    side:
                        const BorderSide(color: Color(0xFFFF9F1C), width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.map, size: 22),
                  label: const Text('CANLI SAHA HARİTASI & KML',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => showDataEntrySheet(context, activeProj,
                            (updatedData) => syncDataToFirebase(updatedData)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9F1C),
                          foregroundColor: Colors.black,
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_location_alt, size: 20),
                        label: const Text('VERİ GİR',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            showDsiReportDialog(context, activeProj),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2EC4B6),
                          foregroundColor: Colors.black,
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.description, size: 20),
                        label: const Text('DSİ RAPORU',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
