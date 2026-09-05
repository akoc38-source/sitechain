// lib/dialogs/dashboard_sheets.dart

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// 📏 Kilometraj Metin İfadesini ("0+200.00" veya "200") Metreye Çevirici Yardımcı
double _parseKmToMeters(String input) {
  String clean = input.trim().replaceAll(' ', '');
  if (clean.contains('+')) {
    List<String> parts = clean.split('+');
    double km = double.tryParse(parts[0]) ?? 0;
    double m = double.tryParse(parts[1]) ?? 0;
    return (km * 1000) + m;
  }
  return double.tryParse(clean) ?? 0;
}

/// 🔍 Excel Hücre Verisini Güvenli Okuma Yardımcısı
String _getCellValue(List<Data?> row, int index) {
  if (index >= row.length || row[index] == null || row[index]?.value == null) {
    return "";
  }
  return row[index]!.value.toString().trim();
}

/// 📝 Genel Giriş Kutusu Widget'ı
Widget buildInputField(String label, TextEditingController controller,
    {bool isNumber = false, Function(String)? onChanged}) {
  return TextField(
    controller: controller,
    keyboardType: isNumber
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    onChanged: onChanged,
    style: const TextStyle(color: Colors.white, fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 11),
      filled: true,
      fillColor: const Color(0xFF121824),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF9F1C))),
    ),
  );
}

/// 🛠️ KML/KMZ Dosyasından, Veritabanından ve Excel'den DİNAMİK Hat Listesi Çeken Fonksiyon
List<String> getAvailableHatList(Map<String, dynamic> activeProj) {
  Set<String> hatSet = {};

  // 1. KML/KMZ Dosyasından Ayrıştırılan Dinamik Çizgi/Hat İsimlerini Al
  if (activeProj["kmlLines"] is List) {
    for (var line in activeProj["kmlLines"]) {
      if (line is Map) {
        String name = (line["name"] ?? line["title"] ?? line["hatKodu"] ?? "")
            .toString()
            .trim();
        if (name.isNotEmpty) {
          hatSet.add(name);
        }
      }
    }
  }

  // 2. Hat İlerleme (hatProgress) Haritasındaki Dinamik Hat Kodlarını Al
  if (activeProj["hatProgress"] is Map) {
    Map<String, dynamic> hp =
        Map<String, dynamic>.from(activeProj["hatProgress"]);
    for (var key in hp.keys) {
      if (key.toString().trim().isNotEmpty) {
        hatSet.add(key.toString().trim());
      }
    }
  }

  // 3. Sanat Yapıları İçerisindeki Hat Kodlarını Al (S2-31-1, S2-20-3 vb.)
  List<dynamic> sanatList = activeProj["sanatYapitlari"] ?? [];
  for (var item in sanatList) {
    if (item is Map) {
      String h = (item["hatKodu"] ??
              item["hatAd"] ??
              item["hat"] ??
              item["hat_kodu"] ??
              item["lineCode"] ??
              "")
          .toString()
          .trim();
      if (h.isNotEmpty) {
        hatSet.add(h);
      }
    }
  }

  // 4. Projenin Ana Hat/Kod Bilgisini Al
  String mainCode = (activeProj["code"] ?? "").toString().trim();
  if (mainCode.isNotEmpty) {
    hatSet.add(mainCode);
  }

  // Eğer KML veya veri girilmemişse jenerik dinamik hat önerisi
  if (hatSet.isEmpty) {
    hatSet.add("Ana Hat (KML Yükleyin)");
  }

  // Doğal Sayısal/Metinsel Sıralama (S2-1, S2-2, S2-20-3, S2-31-1 ...)
  List<String> sortedList = hatSet.toList();
  sortedList.sort((a, b) {
    final reg = RegExp(r'(\d+|\D+)');
    final aMatches = reg.allMatches(a).map((m) => m.group(0)!).toList();
    final bMatches = reg.allMatches(b).map((m) => m.group(0)!).toList();
    for (int i = 0; i < aMatches.length && i < bMatches.length; i++) {
      final aNum = int.tryParse(aMatches[i]);
      final bNum = int.tryParse(bMatches[i]);
      if (aNum != null && bNum != null) {
        if (aNum != bNum) {
          return aNum.compareTo(bNum);
        }
      } else {
        if (aMatches[i] != bMatches[i]) {
          return aMatches[i].compareTo(bMatches[i]);
        }
      }
    }
    return a.length.compareTo(b.length);
  });

  return sortedList;
}

/// 🌟 VIP Promosyon / Davet Kodu Dialogu
void showVipCodeDialog(
    BuildContext context, bool isProUser, Function(bool) onSuccess) {
  final codeCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E2638),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFFFF9F1C)),
            SizedBox(width: 8),
            Text('Promosyon / Davet Kodu',
                style: TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isProUser
                  ? 'Tebrikler! Kendi şantiyeniz için ömür boyu VIP PRO erişimi tanımlanmıştır.'
                  : 'Şirketiniz veya şantiyeniz için verilen özel davet kodunu girerek uygulamayı tam sürüm yapabilirsiniz.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (!isProUser)
              TextField(
                controller: codeCtrl,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2),
                decoration: InputDecoration(
                  hintText: 'Örn: AGCASAR2026',
                  hintStyle:
                      TextStyle(color: Colors.grey.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: const Color(0xFF121824),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFFF9F1C))),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('KAPAT', style: TextStyle(color: Colors.grey)),
          ),
          if (!isProUser)
            ElevatedButton(
              onPressed: () {
                String enteredCode = codeCtrl.text.trim().toUpperCase();
                if (enteredCode == "AGCASAR2026" ||
                    enteredCode == "YAHYALI-FREE" ||
                    enteredCode == "SITECHAIN-PRO") {
                  onSuccess(true);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            '🎉 VIP Davet Kodu Doğrulandı! Sınırsız PRO Sürüm Aktif.'),
                        backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            '❌ Geçersiz Davet Kodu! Lütfen tekrar deneyin.'),
                        backgroundColor: Colors.redAccent),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9F1C),
                  foregroundColor: Colors.black),
              child: const Text('KODU ONAYLA',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      );
    },
  );
}

/// 🏗️ Şantiye Kodu Seçim/Bağlantı Penceresi
void showProjectSelectorSheet(
    BuildContext context, Function(String) onCodeSelected) {
  final customCodeCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E2638),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Şantiye Kodu İle Bağlan',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF9F1C))),
            const SizedBox(height: 8),
            const Text(
                'Kendi sahanızın canlı verilerine erişmek için Şantiye Kodunuzu girin:',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: customCodeCtrl,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Örn: bati_hatti veya agcasar_s2',
                hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5)),
                filled: true,
                fillColor: const Color(0xFF121824),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFF9F1C))),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                String newCode = customCodeCtrl.text
                    .trim()
                    .toLowerCase()
                    .replaceAll(' ', '_');
                if (newCode.isNotEmpty) {
                  onCodeSelected(newCode);
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9F1C),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 46),
              ),
              child: const Text('ŞANTİYEYE BAĞLAN / OLUŞTUR',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    },
  );
}

/// 📌 Sanat Yapısı / Branşman Ekleme Penceresi (Excel + Manuel + Akıllı Klasörleme)
void showAddStructureSheet(BuildContext context,
    Map<String, dynamic> activeProj, Function(Map<String, dynamic>) onSave) {
  List<String> availableHats = getAvailableHatList(activeProj);
  String defaultHatCode =
      availableHats.isNotEmpty ? availableHats.first : "Hat-1";

  String selectedType = "Hidrant";
  final hatKoduCtrl = TextEditingController(text: defaultHatCode);
  final kmCtrl =
      TextEditingController(text: activeProj["montajKm"] ?? "0+120.00");
  final numberCtrl = TextEditingController();
  final featureCtrl = TextEditingController();
  final diameterCtrl = TextEditingController();

  List<String> typeOptions = [
    "Hidrant",
    "Vantuz",
    "Tahliye Vanası",
    "Vana Odası",
    "Branşman",
    "Sayaç Odası",
    "Basınç Kırıcı",
    "Özel Yapı"
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E2638),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
                top: 20,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey[600],
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  const Text('Yeni Sanat Yapısı / Branşman Ekle',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF9F1C))),
                  const SizedBox(height: 16),

                  // 📊 EXCEL İLE TOPLU YÜKLEME BUTONU
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        FilePickerResult? result =
                            await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['xlsx', 'xls', 'xlsm', 'csv'],
                          withData: true,
                        );

                        if (result != null &&
                            result.files.isNotEmpty &&
                            result.files.first.bytes != null) {
                          final bytes = result.files.first.bytes!;
                          final excel = Excel.decodeBytes(bytes);
                          List<dynamic> currentList =
                              List.from(activeProj["sanatYapitlari"] ?? []);
                          Map<String, dynamic> hatProgressMap =
                              Map<String, dynamic>.from(
                                  activeProj["hatProgress"] ?? {});

                          int addedCount = 0;

                          for (var table in excel.tables.keys) {
                            final sheet = excel.tables[table];
                            if (sheet == null || sheet.rows.isEmpty) {
                              continue;
                            }

                            for (int i = 1; i < sheet.rows.length; i++) {
                              final row = sheet.rows[i];
                              if (row.isEmpty) {
                                continue;
                              }

                              String hatKodu = _getCellValue(row, 0);
                              String km = _getCellValue(row, 1);
                              String yapiAdi = _getCellValue(row, 2);
                              String yapiTuru =
                                  row.length > 3 ? _getCellValue(row, 3) : "";
                              String ozellik =
                                  row.length > 4 ? _getCellValue(row, 4) : "";
                              String cap =
                                  row.length > 5 ? _getCellValue(row, 5) : "";

                              if (hatKodu.isEmpty &&
                                  yapiAdi.isEmpty &&
                                  km.isEmpty) {
                                continue;
                              }

                              String hLower = hatKodu.toLowerCase();
                              if (hLower.contains("hat") &&
                                  hLower.contains("kod")) {
                                continue;
                              }

                              if (hatKodu.isEmpty) {
                                hatKodu = defaultHatCode;
                              }

                              String finalTitle = yapiAdi.isNotEmpty
                                  ? yapiAdi
                                  : (yapiTuru.isNotEmpty
                                      ? yapiTuru
                                      : "Sanat Yapısı");

                              List<String> detailParts = [];
                              if (yapiTuru.isNotEmpty) {
                                detailParts.add(yapiTuru);
                              }
                              if (ozellik.isNotEmpty) {
                                detailParts.add(ozellik);
                              }
                              if (cap.isNotEmpty) {
                                detailParts.add(cap);
                              }
                              String detailsStr = detailParts.isNotEmpty
                                  ? detailParts.join(" - ")
                                  : "Detay Belirtilmedi";

                              currentList.add({
                                "hatKodu": hatKodu,
                                "tip": finalTitle,
                                "km": km.isEmpty ? "0+000" : km,
                                "beton": detailsStr,
                                "durum": "Bekliyor",
                              });

                              if (!hatProgressMap.containsKey(hatKodu)) {
                                hatProgressMap[hatKodu] = {
                                  "hatKodu": hatKodu,
                                  "kaziKm": km.isEmpty ? "0+000.00" : km,
                                  "yataklamaKm": km.isEmpty ? "0+000.00" : km,
                                  "montajKm": km.isEmpty ? "0+000.00" : km,
                                  "kapamaKm": km.isEmpty ? "0+000.00" : km,
                                  "cakilSefer": 0,
                                  "betonM3": 0.0,
                                };
                              }

                              addedCount++;
                            }
                          }

                          if (addedCount > 0) {
                            activeProj["sanatYapitlari"] = currentList;
                            activeProj["hatProgress"] = hatProgressMap;
                            onSave(activeProj);

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '🎉 $addedCount adet Yapı ve Dinamik Hat Kütüphaneye Eklendi!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Excel Yükleme Hatası: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.table_chart, color: Colors.white),
                    label: const Text(
                      '📊 EXCEL DOSYASI İLE TOPLU YÜKLE',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2EC4B6),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('VEYA MANUEL EKLEYİN',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  buildInputField(
                      'Hat Kodu (Örn: S2-31-1, S2-20-3)', hatKoduCtrl),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                          child: buildInputField(
                              'Yapı Adı (Örn: SAV-1, HV-1)', numberCtrl)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: buildInputField('Kilometraj (Km)', kmCtrl)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text('Yapı Türü Seçin:',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        color: const Color(0xFF121824),
                        borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedType,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF121824),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        items: typeOptions
                            .map((String type) => DropdownMenuItem<String>(
                                value: type, child: Text(type)))
                            .toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setModalState(() {
                              selectedType = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: buildInputField(
                              'Özellik (Örn: Çift Çıkışlı)', featureCtrl)),
                      const SizedBox(width: 10),
                      Expanded(
                          child:
                              buildInputField('Çap (Örn: DN80)', diameterCtrl)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      String userHat = hatKoduCtrl.text.trim();
                      if (userHat.isEmpty) {
                        userHat = defaultHatCode;
                      }

                      String finalTitle = numberCtrl.text.trim().isNotEmpty
                          ? numberCtrl.text.trim()
                          : selectedType;

                      List<String> dt = [selectedType];
                      if (featureCtrl.text.trim().isNotEmpty) {
                        dt.add(featureCtrl.text.trim());
                      }
                      if (diameterCtrl.text.trim().isNotEmpty) {
                        dt.add(diameterCtrl.text.trim());
                      }

                      List<dynamic> currentList =
                          List.from(activeProj["sanatYapitlari"] ?? []);

                      currentList.add({
                        "hatKodu": userHat,
                        "tip": finalTitle,
                        "km": kmCtrl.text.trim().isEmpty
                            ? "0+000"
                            : kmCtrl.text.trim(),
                        "beton": dt.join(" - "),
                        "durum": "Bekliyor",
                      });

                      activeProj["sanatYapitlari"] = currentList;
                      onSave(activeProj);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                '✨ $finalTitle (Hat: $userHat) projeye eklendi!'),
                            backgroundColor: Colors.green),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9F1C),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('PROJEYE EKLE VE YAYINLA',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// 📂 Sanat Yapılarını Dinamik Hat Kodlarına Göre KLASÖRLÜ Listeleyen Widget
Widget buildGroupedStructuresList(List<dynamic> sanatList,
    {Function(int)? onDelete}) {
  if (sanatList.isEmpty) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2638).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: const Text(
        "Henüz eklenmiş bir sanat yapısı veya branşman yok.\nYukarıdaki + EKLE butonundan Excel veya KML ile yükleyebilirsiniz.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> groupedData = {};

  for (int i = 0; i < sanatList.length; i++) {
    Map<String, dynamic> mapItem = Map<String, dynamic>.from(sanatList[i]);
    mapItem["_originalIndex"] = i;

    String hat = (mapItem["hatKodu"] ??
            mapItem["hatAd"] ??
            mapItem["hat"] ??
            mapItem["hat_kodu"] ??
            mapItem["Hat Kodu"] ??
            mapItem["lineCode"] ??
            "")
        .toString()
        .trim();

    if (hat.isEmpty) {
      hat = "Ana Hat";
    }

    if (!groupedData.containsKey(hat)) {
      groupedData[hat] = [];
    }
    groupedData[hat]!.add(mapItem);
  }

  List<String> sortedHatKeys = groupedData.keys.toList()
    ..sort((a, b) {
      final reg = RegExp(r'(\d+|\D+)');
      final aMatches = reg.allMatches(a).map((m) => m.group(0)!).toList();
      final bMatches = reg.allMatches(b).map((m) => m.group(0)!).toList();
      for (int i = 0; i < aMatches.length && i < bMatches.length; i++) {
        final aNum = int.tryParse(aMatches[i]);
        final bNum = int.tryParse(bMatches[i]);
        if (aNum != null && bNum != null) {
          if (aNum != bNum) {
            return aNum.compareTo(bNum);
          }
        } else {
          if (aMatches[i] != bMatches[i]) {
            return aMatches[i].compareTo(bMatches[i]);
          }
        }
      }
      return a.length.compareTo(b.length);
    });

  return ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: sortedHatKeys.length,
    itemBuilder: (context, index) {
      String hatKodu = sortedHatKeys[index];
      List<Map<String, dynamic>> items = groupedData[hatKodu]!;

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
            initiallyExpanded: false,
            leading:
                const Icon(Icons.folder, color: Color(0xFFFF9F1C), size: 26),
            title: Text(
              "📁 $hatKodu Hattı Klasörü",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              "Toplam ${items.length} Adet Yapı (SAV / HV)",
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            trailing:
                const Icon(Icons.keyboard_arrow_down, color: Color(0xFFFF9F1C)),
            children: items.map((sy) {
              int origIdx = sy["_originalIndex"] ?? -1;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF121824),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                    "${sy["tip"] ?? sy["name"] ?? "Yapı"}",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Km: ${sy["km"] ?? "0+000"} | ${sy["beton"] ?? ""}",
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9F1C).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sy["durum"] ?? sy["status"] ?? "Bekliyor",
                          style: const TextStyle(
                              color: Color(0xFFFF9F1C),
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (onDelete != null && origIdx != -1) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 20),
                          onPressed: () => onDelete(origIdx),
                        ),
                      ],
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

/// 📊 KML İLE ENTEGRE VE DİNAMİK HAT VERİ GİRİŞİ MODALI
void showDataEntrySheet(BuildContext context, Map<String, dynamic> activeProj,
    Function(Map<String, dynamic>) onSave) {
  List<String> availableHats = getAvailableHatList(activeProj);

  String selectedHat = activeProj["lastSelectedHat"]?.toString() ??
      (availableHats.isNotEmpty ? availableHats.first : "Ana Hat");

  if (!availableHats.contains(selectedHat) && availableHats.isNotEmpty) {
    selectedHat = availableHats.first;
  }

  Map<String, dynamic> hatProgressMap =
      Map<String, dynamic>.from(activeProj["hatProgress"] ?? {});

  Map<String, dynamic> currentHatData =
      Map<String, dynamic>.from(hatProgressMap[selectedHat] ?? {});

  final kaziStartCtrl = TextEditingController(
      text: currentHatData["kaziStartKm"]?.toString() ?? "0+000.00");
  final kaziEndCtrl = TextEditingController(
      text: currentHatData["kaziKm"]?.toString() ?? "0+000.00");

  final yataklamaStartCtrl = TextEditingController(
      text: currentHatData["yataklamaStartKm"]?.toString() ?? "0+000.00");
  final yataklamaEndCtrl = TextEditingController(
      text: currentHatData["yataklamaKm"]?.toString() ?? "0+000.00");

  final montajStartCtrl = TextEditingController(
      text: currentHatData["montajStartKm"]?.toString() ?? "0+000.00");
  final montajEndCtrl = TextEditingController(
      text: currentHatData["montajKm"]?.toString() ?? "0+000.00");

  final kapamaStartCtrl = TextEditingController(
      text: currentHatData["kapamaStartKm"]?.toString() ?? "0+000.00");
  final kapamaEndCtrl = TextEditingController(
      text: currentHatData["kapamaKm"]?.toString() ?? "0+000.00");

  final cakilCtrl = TextEditingController(
      text: currentHatData["cakilSefer"]?.toString() ?? "0");
  final betonCtrl =
      TextEditingController(text: currentHatData["betonM3"]?.toString() ?? "0");

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E2638),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          void updateControllersForHat(String newHat) {
            Map<String, dynamic> hData =
                Map<String, dynamic>.from(hatProgressMap[newHat] ?? {});

            kaziStartCtrl.text = hData["kaziStartKm"]?.toString() ?? "0+000.00";
            kaziEndCtrl.text = hData["kaziKm"]?.toString() ?? "0+000.00";

            yataklamaStartCtrl.text =
                hData["yataklamaStartKm"]?.toString() ?? "0+000.00";
            yataklamaEndCtrl.text =
                hData["yataklamaKm"]?.toString() ?? "0+000.00";

            montajStartCtrl.text =
                hData["montajStartKm"]?.toString() ?? "0+000.00";
            montajEndCtrl.text = hData["montajKm"]?.toString() ?? "0+000.00";

            kapamaStartCtrl.text =
                hData["kapamaStartKm"]?.toString() ?? "0+000.00";
            kapamaEndCtrl.text = hData["kapamaKm"]?.toString() ?? "0+000.00";

            cakilCtrl.text = hData["cakilSefer"]?.toString() ?? "0";
            betonCtrl.text = hData["betonM3"]?.toString() ?? "0";
          }

          // Anlık Metre Hesapları
          double kaziMeters = (_parseKmToMeters(kaziEndCtrl.text) -
                  _parseKmToMeters(kaziStartCtrl.text))
              .clamp(0.0, 1000000.0);

          double yataklamaMeters = (_parseKmToMeters(yataklamaEndCtrl.text) -
                  _parseKmToMeters(yataklamaStartCtrl.text))
              .clamp(0.0, 1000000.0);

          double montajMeters = (_parseKmToMeters(montajEndCtrl.text) -
                  _parseKmToMeters(montajStartCtrl.text))
              .clamp(0.0, 1000000.0);

          double kapamaMeters = (_parseKmToMeters(kapamaEndCtrl.text) -
                  _parseKmToMeters(kapamaStartCtrl.text))
              .clamp(0.0, 1000000.0);

          return Padding(
            padding: EdgeInsets.only(
                top: 20,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey[600],
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('👷 Günlük İlerleme Kaydı',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF9F1C))),
                      // ➕ ANLIK YENİ HAT KODU TANIMLAMA BUTONU
                      InkWell(
                        onTap: () {
                          final newHatCtrl = TextEditingController();
                          showDialog(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E2638),
                              title: const Text("➕ Yeni Hat Kodu Tanımla",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15)),
                              content: TextField(
                                controller: newHatCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: "Örn: S2-31-1 veya S2-20-3",
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx),
                                  child: const Text("İPTAL",
                                      style: TextStyle(color: Colors.grey)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF9F1C)),
                                  onPressed: () {
                                    String code = newHatCtrl.text.trim();
                                    if (code.isNotEmpty) {
                                      setModalState(() {
                                        if (!availableHats.contains(code)) {
                                          availableHats.add(code);
                                        }
                                        selectedHat = code;
                                        updateControllersForHat(code);
                                      });
                                      Navigator.pop(dCtx);
                                    }
                                  },
                                  child: const Text("EKLE",
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFF9F1C).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFF9F1C)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add,
                                  size: 14, color: Color(0xFFFF9F1C)),
                              SizedBox(width: 4),
                              Text("Yeni Hat",
                                  style: TextStyle(
                                      color: Color(0xFFFF9F1C),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 🎯 DİNAMİK HAT SEÇİMİ AŞAĞI AÇILIR MENÜSÜ
                  const Text('KML / Proje Verisinden Hat Seçin:',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        color: const Color(0xFF121824),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFFF9F1C)
                                .withValues(alpha: 0.5))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedHat,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF121824),
                        icon: const Icon(Icons.alt_route,
                            color: Color(0xFFFF9F1C)),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                        items: availableHats
                            .map((String hat) => DropdownMenuItem<String>(
                                  value: hat,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.folder_open,
                                          color: Color(0xFFFF9F1C), size: 18),
                                      const SizedBox(width: 8),
                                      Text('$hat Hattı',
                                          style: const TextStyle(
                                              color: Colors.white)),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (String? newHat) {
                          if (newHat != null) {
                            setModalState(() {
                              selectedHat = newHat;
                              updateControllersForHat(newHat);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. KAZI AŞAMASI
                  _buildStageCard(
                    title: "1. Kazı Aşaması",
                    color: const Color(0xFFE71D36),
                    startCtrl: kaziStartCtrl,
                    endCtrl: kaziEndCtrl,
                    calculatedMeters: kaziMeters,
                    onChanged: () => setModalState(() {}),
                  ),

                  // 2. YATAKLAMA AŞAMASI
                  _buildStageCard(
                    title: "2. Çakıl Yataklama Aşaması",
                    color: const Color(0xFFFF9F1C),
                    startCtrl: yataklamaStartCtrl,
                    endCtrl: yataklamaEndCtrl,
                    calculatedMeters: yataklamaMeters,
                    onChanged: () => setModalState(() {}),
                  ),

                  // 3. BORU MONTAJI AŞAMASI
                  _buildStageCard(
                    title: "3. Boru Montajı Aşaması",
                    color: const Color(0xFF2EC4B6),
                    startCtrl: montajStartCtrl,
                    endCtrl: montajEndCtrl,
                    calculatedMeters: montajMeters,
                    onChanged: () => setModalState(() {}),
                  ),

                  // 4. GERİ DOLGU / KAPAMA AŞAMASI
                  _buildStageCard(
                    title: "4. Geri Dolgu / Kapama Aşaması",
                    color: const Color(0xFF20A4F3),
                    startCtrl: kapamaStartCtrl,
                    endCtrl: kapamaEndCtrl,
                    calculatedMeters: kapamaMeters,
                    onChanged: () => setModalState(() {}),
                  ),

                  const SizedBox(height: 8),
                  const Text('Lojistik & Malzeme Girişi',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: buildInputField('Çakıl (Sefer)', cakilCtrl,
                              isNumber: true)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: buildInputField('Beton (m³)', betonCtrl,
                              isNumber: true)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      int cSefer = int.tryParse(cakilCtrl.text) ?? 0;
                      double bM3 = double.tryParse(betonCtrl.text) ?? 0.0;

                      hatProgressMap[selectedHat] = {
                        "hatKodu": selectedHat,
                        "kaziStartKm": kaziStartCtrl.text,
                        "kaziKm": kaziEndCtrl.text,
                        "kaziTodayMeters": kaziMeters,
                        "yataklamaStartKm": yataklamaStartCtrl.text,
                        "yataklamaKm": yataklamaEndCtrl.text,
                        "yataklamaTodayMeters": yataklamaMeters,
                        "montajStartKm": montajStartCtrl.text,
                        "montajKm": montajEndCtrl.text,
                        "montajTodayMeters": montajMeters,
                        "kapamaStartKm": kapamaStartCtrl.text,
                        "kapamaKm": kapamaEndCtrl.text,
                        "kapamaTodayMeters": kapamaMeters,
                        "cakilSefer": cSefer,
                        "betonM3": bM3,
                        "updatedAt": DateTime.now().toIso8601String(),
                      };

                      List<dynamic> dailyLogs =
                          List.from(activeProj["dailyLogs"] ?? []);
                      dailyLogs.add({
                        "date": DateTime.now().toIso8601String(),
                        "hatKodu": selectedHat,
                        "kaziStartKm": kaziStartCtrl.text,
                        "kaziEndKm": kaziEndCtrl.text,
                        "kaziMeters": kaziMeters,
                        "montajStartKm": montajStartCtrl.text,
                        "montajEndKm": montajEndCtrl.text,
                        "montajMeters": montajMeters,
                        "cakilSefer": cSefer,
                        "betonM3": bM3,
                      });
                      activeProj["dailyLogs"] = dailyLogs;

                      activeProj["hatProgress"] = hatProgressMap;
                      activeProj["lastSelectedHat"] = selectedHat;

                      activeProj["kaziKm"] = kaziEndCtrl.text;
                      activeProj["yataklamaKm"] = yataklamaEndCtrl.text;
                      activeProj["montajKm"] = montajEndCtrl.text;
                      activeProj["kapamaKm"] = kapamaEndCtrl.text;

                      int totalCakil = 0;
                      double totalBeton = 0.0;
                      hatProgressMap.forEach((key, val) {
                        if (val is Map) {
                          totalCakil += (val["cakilSefer"] as int? ?? 0);
                          totalBeton +=
                              (val["betonM3"] as num? ?? 0).toDouble();
                        }
                      });
                      activeProj["cakilSefer"] = totalCakil;
                      activeProj["betonM3"] = totalBeton;

                      onSave(activeProj);

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                '⚡ $selectedHat Hattı verileri kümülatif toplama işlendi!'),
                            backgroundColor: Colors.green),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9F1C),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                        '$selectedHat HATTINI GÜNLÜK KAYDET VE TOPLAMA EKLE',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// 🛠️ Günlük İlerleme Kart Bileşeni
Widget _buildStageCard({
  required String title,
  required Color color,
  required TextEditingController startCtrl,
  required TextEditingController endCtrl,
  required double calculatedMeters,
  required VoidCallback onChanged,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF121824),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "Bugün Yapılan: ${calculatedMeters.toStringAsFixed(1)} m",
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: buildInputField('Başlangıç Km', startCtrl,
                  onChanged: (_) => onChanged()),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: buildInputField('Bitiş Km', endCtrl,
                  onChanged: (_) => onChanged()),
            ),
          ],
        ),
      ],
    ),
  );
}

/// 📋 DSİ Günlük ve Kümülatif Saha İlerleme Raporu Dialogu
void showDsiReportDialog(
    BuildContext context, Map<String, dynamic> activeProj) {
  List<dynamic> sanatList = activeProj["sanatYapitlari"] ?? [];
  Map<String, dynamic> hatProgressMap =
      Map<String, dynamic>.from(activeProj["hatProgress"] ?? {});

  DateTime now = DateTime.now();
  String dateStr =
      "${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}";

  StringBuffer buffer = StringBuffer();
  buffer.writeln(
      "📋 ${(activeProj["name"] ?? "AĞCAŞAR S2 PROJESİ").toString().toUpperCase()}");
  buffer.writeln("📌 DSİ & KONTROLÖRLÜK SAHA İLERLEME RAPORU");
  buffer.writeln(
      "📍 Konum: ${activeProj["city"] ?? "Kayseri"} / ${activeProj["district"] ?? "Yahyalı"}");
  buffer.writeln("🗓 Tarih: $dateStr\n");

  buffer.writeln("----------------------------------");
  buffer.writeln("📊 HATLAR KÜMÜLATİF (TOPLAM) İLERLEME");
  buffer.writeln("----------------------------------");

  if (hatProgressMap.isNotEmpty) {
    hatProgressMap.forEach((hat, data) {
      if (data is Map) {
        buffer.writeln("🔹 Hat $hat:");
        buffer.writeln("  • Kazı Son Km: ${data["kaziKm"] ?? "0+000"}");
        buffer.writeln("  • Montaj Son Km: ${data["montajKm"] ?? "0+000"}");
        buffer.writeln("  • Kapama Son Km: ${data["kapamaKm"] ?? "0+000"}");
      }
    });
  } else {
    buffer.writeln(
        "🔹 ${activeProj["pipeType"] ?? "C2000"} Ana Boru Hattı Durumu:");
    buffer.writeln("  • Kazı Son KM: ${activeProj["kaziKm"] ?? "0+000"}");
    buffer.writeln("  • Boru Montaj KM: ${activeProj["montajKm"] ?? "0+000"}");
    buffer.writeln("  • Geri Dolgu KM: ${activeProj["kapamaKm"] ?? "0+000"}");
  }

  buffer.writeln("\n🚚 Lojistik & Beton Toplamı:");
  buffer.writeln(
      "  • Çakıl Nakliyesi: ${activeProj["cakilSefer"] ?? 0} Kamyon Sefer");
  buffer.writeln("  • Dökülen Beton: ${activeProj["betonM3"] ?? 0} m³");

  if (sanatList.isNotEmpty) {
    buffer.writeln("\n🏗 Sanat Yapıları & Branşmanlar:");
    for (var y in sanatList) {
      buffer.writeln(
          "  • ${y["hatKodu"] ?? "Ana Hat"} - ${y["tip"]} (Km: ${y["km"]}): ${y["durum"]}");
    }
  }

  buffer.writeln("\n🚀 SiteChain Global Infrastructure Platform");

  String reportText = buffer.toString();

  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E2638),
        title: const Text('DSİ & İdare Hazır Raporu',
            style: TextStyle(color: Color(0xFFFF9F1C), fontSize: 16)),
        content: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFF121824),
                borderRadius: BorderRadius.circular(8)),
            child: Text(reportText,
                style:
                    GoogleFonts.firaCode(fontSize: 11, color: Colors.white70)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('KAPAT', style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: reportText));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        '📋 DSİ Rapor metni panoya kopyalandı! WhatsApp\'a yapıştırabilirsiniz.'),
                    backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2EC4B6)),
            icon: const Icon(Icons.copy, size: 18, color: Colors.black),
            label: const Text('KOPYALA',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    },
  );
}
