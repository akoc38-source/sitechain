// lib/screens/progress_structures_screen.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/pipe_line_model.dart';
import '../services/kml_parser_service.dart';
import '../services/excel_parser_service.dart';

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
  final KmlParserService _kmlService = KmlParserService();
  final ExcelParserService _excelService = ExcelParserService();

  String? _selectedLineId;
  bool _isUploading = false;
  String _uploadStatusText = "";

  // 📂 KML Dosyası Yükleme
  Future<void> _pickAndUploadKml() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['kml'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _isUploading = true;
          _uploadStatusText = "KML Dosyası Ayrıştırılıyor...";
        });

        String kmlContent = utf8.decode(result.files.single.bytes!);
        int savedCount = await _kmlService.parseAndSaveKml(
          kmlContent: kmlContent,
          projectId: widget.activeProjectId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("🎉 $savedCount adet hat aktarıldı!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("❌ KML Hatası: $e"),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // 📊 Excel Dosyasından Toplu Sanat Yapıları Yükleme
  Future<void> _pickAndUploadExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'xlsm', 'csv'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _isUploading = true;
          _uploadStatusText =
              "Excel Dosyası Ayrıştırılıyor ve Klasörleniyor...";
        });

        var file = result.files.first;
        if (file.bytes != null) {
          int count = await _excelService.parseAndSaveExcelBytes(
            bytes: file.bytes!,
            projectId: widget.activeProjectId,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    "🎉 Toplam $count adet Sanat Yapısı hat klasörlerine aktarıldı!"),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("❌ Excel Hatası: $e"),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // ➕ Yeni Sanat Yapısı Ekleme Modal Penceresi (Manuel + Excel)
  void _showAddStructureDialog(PipeLine currentLine) {
    final nameCtrl = TextEditingController();
    final kmCtrl = TextEditingController(text: "0+120.00");
    final featureCtrl = TextEditingController();
    final diameterCtrl = TextEditingController();
    final hatKoduCtrl = TextEditingController(text: currentLine.code);
    String selectedType = "Hidrant";

    final List<String> structureTypes = [
      "Hidrant",
      "Vantuz",
      "Tahliye Vanası",
      "Vana Odası",
      "Branşman",
      "Sayaç Odası",
      "Basınç Kırıcı",
      "Özel Yapı",
    ];

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
            top: 16,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  "Yeni Sanat Yapısı / Branşman Ekle",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF9F1C)),
                ),
                const SizedBox(height: 16),

                // 📊 EXCEL İLE TOPLU YÜKLE
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2EC4B6),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _pickAndUploadExcel();
                  },
                  icon: const Icon(Icons.table_chart, color: Colors.white),
                  label: const Text(
                    "📊 EXCEL DOSYASI İLE TOPLU YÜKLE",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),

                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text("VEYA MANUEL EKLEYİN",
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: hatKoduCtrl,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: "Hat Kodu (Örn: S2-1, S2-2)",
                    labelStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Yapı Adı (Örn: SAV-1)",
                          labelStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: kmCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Kilometraj (Km)",
                          labelStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  dropdownColor: const Color(0xFF1E2638),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: "Yapı Türü",
                    labelStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                  ),
                  items: structureTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedType = val);
                    }
                  },
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: featureCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Özellik (Örn: Çift Çıkışlı)",
                          labelStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: diameterCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Çap (Örn: DN80)",
                          labelStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(),
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
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    String targetHat = hatKoduCtrl.text.trim().isEmpty
                        ? currentLine.code
                        : hatKoduCtrl.text.trim();
                    if (nameCtrl.text.trim().isEmpty) {
                      return;
                    }

                    Map<String, dynamic> newStructure = {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'hatKodu': targetHat,
                      'name': nameCtrl.text.trim(),
                      'km': kmCtrl.text.trim().isEmpty
                          ? "0+000"
                          : kmCtrl.text.trim(),
                      'type': selectedType,
                      'feature': featureCtrl.text.trim(),
                      'diameter': diameterCtrl.text.trim(),
                      'status': 'Bekliyor',
                      'createdAt': DateTime.now().toIso8601String(),
                    };

                    String docId =
                        targetHat.replaceAll(' ', '_').replaceAll('/', '-');

                    await _firestore
                        .collection('projects')
                        .doc(widget.activeProjectId)
                        .collection('lines')
                        .doc(docId)
                        .set({
                      'sanatYapitlari': FieldValue.arrayUnion([newStructure]),
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("PROJEYE EKLE VE YAYINLA",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✏️ Hat İlerleme Metrajı Güncelleme
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
                "📝 İlerleme Güncelle: ${line.code}",
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF9F1C)),
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

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
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
      body: _isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFFF9F1C)),
                  const SizedBox(height: 16),
                  Text(_uploadStatusText,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('projects')
                  .doc(widget.activeProjectId)
                  .collection('lines')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFFF9F1C)));
                }

                final docs = snapshot.data?.docs ?? [];
                List<PipeLine> allLines = docs
                    .map((d) => PipeLine.fromMap(
                        d.data() as Map<String, dynamic>, d.id))
                    .toList();

                if (allLines.isEmpty) {
                  return _buildEmptyState();
                }

                PipeLine currentLine = allLines.firstWhere(
                  (l) => l.id == _selectedLineId,
                  orElse: () => allLines.first,
                );

                return Column(
                  children: [
                    _buildDetailHeader(allLines, currentLine),
                    Expanded(
                      child: _buildLineDetailView(allLines, currentLine),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildDetailHeader(List<PipeLine> lines, PipeLine activeLine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF1E2638),
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
            items: lines.map((line) {
              return DropdownMenuItem<String>(
                value: line.id,
                child: Text(
                  "📌 ${line.code} (${line.pipeType})",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
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
    );
  }

  Widget _buildLineDetailView(List<PipeLine> allLines, PipeLine activeLine) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Hat İlerleme Durumu (${activeLine.pipeType})",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFFFF9F1C)),
                onPressed: () => _editProgressDialog(activeLine),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStageCard("1. Kazı Aşaması", activeLine.kaziKm,
              activeLine.totalKm, Colors.redAccent),
          _buildStageCard("2. Çakıl Yataklama", activeLine.yataklamaKm,
              activeLine.totalKm, Colors.orangeAccent),
          _buildStageCard("3. Boru Montajı", activeLine.montajKm,
              activeLine.totalKm, const Color(0xFF2EC4B6)),
          _buildStageCard("4. Geri Dolgu / Kapama", activeLine.kapamaKm,
              activeLine.totalKm, Colors.blueAccent),
          const SizedBox(height: 24),

          // 📌 SANAT YAPILARI BAŞLIĞI VE + EKLE BUTONU
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Sanat Yapıları & Branşmanlar",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
              InkWell(
                onTap: () => _showAddStructureDialog(activeLine),
                child: const Row(
                  children: [
                    Icon(Icons.add_circle, color: Color(0xFFFF9F1C), size: 18),
                    SizedBox(width: 4),
                    Text(
                      "EKLE",
                      style: TextStyle(
                          color: Color(0xFFFF9F1C),
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 📁 TÜM HATLARIN SANAT YAPILARINI HAT KODLARINA GÖRE KLASÖRLÜ LİSTELEME
          _buildGroupedStructuresView(allLines),
        ],
      ),
    );
  }

  /// 📁 Hat Koduna (S2-1, S2-2 vb.) Göre Gruplanmış Akordeon Klasör Widget'ı
  Widget _buildGroupedStructuresView(List<PipeLine> lines) {
    Map<String, List<Map<String, dynamic>>> groupedData = {};

    for (var line in lines) {
      String lineCode = line.code.trim().isEmpty ? "S2-1" : line.code.trim();

      if (!groupedData.containsKey(lineCode)) {
        groupedData[lineCode] = [];
      }

      for (var sy in line.sanatYapitlari) {
        Map<String, dynamic> item = Map<String, dynamic>.from(sy);
        String hatKey = item["hatKodu"]?.toString().trim() ?? lineCode;
        if (hatKey.isEmpty) {
          hatKey = lineCode;
        }

        if (!groupedData.containsKey(hatKey)) {
          groupedData[hatKey] = [];
        }
        groupedData[hatKey]!.add(item);
      }
    }

    if (groupedData.isEmpty || groupedData.values.every((l) => l.isEmpty)) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2638).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: const Text(
          "Henüz eklenmiş bir sanat yapısı veya branşman yok.\nYukarıdaki + EKLE butonunu kullanarak Excel yükleyebilirsiniz.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    List<String> sortedHatKeys = groupedData.keys.toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedHatKeys.length,
      itemBuilder: (context, index) {
        String hatKodu = sortedHatKeys[index];
        List<Map<String, dynamic>> items = groupedData[hatKodu]!;

        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          color: const Color(0xFF1E2638),
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white12),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded:
                  false, // 👈 KAPALI OLARAK BAŞLAR; TIKLANDIĞINDA İÇERİĞİ AÇILIR
              leading:
                  const Icon(Icons.folder, color: Color(0xFFFF9F1C), size: 28),
              title: Text(
                "📁 $hatKodu Hattı Klasörü",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                "Toplam ${items.length} Adet Yapı (SAV / HV)",
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              trailing: const Icon(Icons.keyboard_arrow_down,
                  color: Color(0xFFFF9F1C)),
              children: items.map((sy) {
                String name = sy["name"] ?? sy["tip"] ?? "Yapı";
                String km = sy["km"] ?? "0+000";
                String type = sy["type"] ?? sy["tip"] ?? "Yapı";
                String feature = sy["feature"] ?? "";
                String diameter = sy["diameter"] ?? "";
                String status = sy["status"] ?? sy["durum"] ?? "Bekliyor";

                String descText = "Km: $km";
                if (type.isNotEmpty && type != name) {
                  descText += " | Tür: $type";
                }
                if (feature.isNotEmpty || diameter.isNotEmpty) {
                  List<String> details = [feature, diameter]
                      .where((element) => element.isNotEmpty)
                      .toList();
                  descText += " (${details.join(" - ")})";
                }

                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121824),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9F1C).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFFF9F1C), size: 20),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      descText,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFF9F1C).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              color: Color(0xFFFF9F1C),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 20),
                          onPressed: () async {
                            String docId = hatKodu
                                .replaceAll(' ', '_')
                                .replaceAll('/', '-');
                            await _firestore
                                .collection('projects')
                                .doc(widget.activeProjectId)
                                .collection('lines')
                                .doc(docId)
                                .update({
                              'sanatYapitlari': FieldValue.arrayRemove([sy]),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
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
                  "Km: ${currentKm.toStringAsFixed(2)}",
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 12),
                ),
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
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: _pickAndUploadKml,
            icon: const Icon(Icons.file_upload),
            label: const Text("KML DOSYASI SEÇ VE YÜKLE",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
