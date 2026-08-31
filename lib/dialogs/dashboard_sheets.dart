// lib/dialogs/dashboard_sheets.dart

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🔍 Excel Hücre Verisini Güvenli Okuma Yardımcısı
String _getCellValue(List<Data?> row, int index) {
  if (index >= row.length || row[index] == null || row[index]?.value == null) {
    return "";
  }
  return row[index]!.value.toString().trim();
}

/// 📝 Genel Giriş Kutusu Widget'ı
Widget buildInputField(String label, TextEditingController controller,
    {bool isNumber = false}) {
  return TextField(
    controller: controller,
    keyboardType: isNumber ? TextInputType.number : TextInputType.text,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF121824),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF9F1C))),
    ),
  );
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

/// 📌 Sanat Yapısı / Branşman Ekleme Penceresi (Excel + Manuel + 31 Hat İçin Akıllı Klasörleme)
void showAddStructureSheet(BuildContext context,
    Map<String, dynamic> activeProj, Function(Map<String, dynamic>) onSave) {
  String defaultHatCode =
      (activeProj["code"] ?? activeProj["name"] ?? "S2-1").toString().trim();
  if (defaultHatCode.isEmpty) {
    defaultHatCode = "S2-1";
  }

  String selectedType = "Hidrant";
  final hatKoduCtrl = TextEditingController(text: defaultHatCode);
  final kmCtrl =
      TextEditingController(text: activeProj["montajKm"] ?? "0+120.00");
  final numberCtrl = TextEditingController(); // Yapı Adı (SAV-1)
  final featureCtrl = TextEditingController(); // Özellik (Çift Çıkışlı)
  final diameterCtrl = TextEditingController(); // Çap (DN80)

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
                              addedCount++;
                            }
                          }

                          if (addedCount > 0) {
                            activeProj["sanatYapitlari"] = currentList;
                            onSave(activeProj);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '🎉 $addedCount adet Sanat Yapısı hat klasörlerine bölünerek kütüphaneye eklendi!'),
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

                  buildInputField('Hat Kodu (Örn: S2-1, S2-2)', hatKoduCtrl),
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

/// 📂 Sanat Yapılarını Hat Kodlarına (S2-1, S2-2 ... S2-31) Göre KLASÖRLÜ Listeleyen Widget
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
        "Henüz eklenmiş bir sanat yapısı veya branşman yok.\nYukarıdaki + EKLE butonundan Excel veya manuel ekleme yapabilirsiniz.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }

  // Hat Koduna göre esnek dinamik gruplama
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
      hat = "S2-1";
    }

    if (!groupedData.containsKey(hat)) {
      groupedData[hat] = [];
    }
    groupedData[hat]!.add(mapItem);
  }

  // Hat kodlarını doğal sayısal/alfabetik sıraya koyma
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
            initiallyExpanded: false, // 👈 Varsayılan olarak kapalı klasör
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

/// 📊 Günlük İlerleme Veri Girişi Penceresi
void showDataEntrySheet(BuildContext context, Map<String, dynamic> activeProj,
    Function(Map<String, dynamic>) onSave) {
  final kaziCtrl = TextEditingController(
      text: activeProj["kaziKm"]?.toString() ?? "12+000.00");
  final yataklamaCtrl = TextEditingController(
      text: activeProj["yataklamaKm"]?.toString() ?? "12+000.00");
  final montajCtrl = TextEditingController(
      text: activeProj["montajKm"]?.toString() ?? "12+000.00");
  final kapamaCtrl = TextEditingController(
      text: activeProj["kapamaKm"]?.toString() ?? "12+000.00");
  final cakilCtrl =
      TextEditingController(text: activeProj["cakilSefer"]?.toString() ?? "0");
  final betonCtrl =
      TextEditingController(text: activeProj["betonM3"]?.toString() ?? "0");

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E2638),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
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
              Text(
                  '${activeProj["code"] ?? "SAHA"} - Günlük İlerleme Girişi (Canlı Yayın)',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF9F1C))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: buildInputField('Kazı KM', kaziCtrl)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: buildInputField('Yataklama KM', yataklamaCtrl)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: buildInputField('Montaj KM', montajCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: buildInputField('Kapama KM', kapamaCtrl)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Lojistik & Beton',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: buildInputField('Çakıl Kamyon (Sefer)', cakilCtrl,
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
                  activeProj["kaziKm"] = kaziCtrl.text;
                  activeProj["yataklamaKm"] = yataklamaCtrl.text;
                  activeProj["montajKm"] = montajCtrl.text;
                  activeProj["kapamaKm"] = kapamaCtrl.text;
                  activeProj["cakilSefer"] =
                      int.tryParse(cakilCtrl.text) ?? activeProj["cakilSefer"];
                  activeProj["betonM3"] =
                      double.tryParse(betonCtrl.text) ?? activeProj["betonM3"];

                  onSave(activeProj);

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            '⚡ Veriler canlı yayınlandı! Tüm ekip arkadaşlarının ekranı güncellendi.'),
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
                child: const Text('CANLI YAYINLA VE CANLI SENKRONİZE ET',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 📋 DSİ Günlük Saha İlerleme Raporu Dialogu
void showDsiReportDialog(
    BuildContext context, Map<String, dynamic> activeProj) {
  List<dynamic> sanatList = activeProj["sanatYapitlari"] ?? [];

  String reportText =
      """📋 ${(activeProj["name"] ?? "SAHA").toString().toUpperCase()} - GÜNLÜK SAHA İLERLEME RAPORU
🗓 Tarih: ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}

🔹 ${activeProj["pipeType"]} Boru Hattı Durumu:
  • Kazı KM: ${activeProj["kaziKm"]}
  • Çakıl Yataklama KM: ${activeProj["yataklamaKm"]}
  • Boru Montaj KM: ${activeProj["montajKm"]}
  • Geri Dolgu KM: ${activeProj["kapamaKm"]}

🚚 Lojistik & Beton:
  • Çakıl Nakliyesi: ${activeProj["cakilSefer"]} Kamyon
  • Dökülen Beton: ${activeProj["betonM3"]} m³

🏗 Sanat Yapıları & Branşmanlar:
${sanatList.map((y) => "  • ${y["hatKodu"] ?? activeProj["code"] ?? "Hat"} - ${y["tip"]} (Km: ${y["km"]}): ${y["durum"]} - ${y["beton"]}").join("\n")}""";

  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E2638),
        title: const Text('DSİ Hazır Saha Raporu',
            style: TextStyle(color: Color(0xFFFF9F1C))),
        content: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFF121824),
                borderRadius: BorderRadius.circular(8)),
            child: Text(reportText,
                style:
                    GoogleFonts.firaCode(fontSize: 12, color: Colors.white70)),
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
                        'DSİ Rapor metni panoya kopyalandı! WhatsApp\'a yapıştırabilirsiniz.'),
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
