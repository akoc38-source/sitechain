import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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

void showAddStructureSheet(BuildContext context,
    Map<String, dynamic> activeProj, Function(Map<String, dynamic>) onSave) {
  String selectedType = "Vantuz";
  final kmCtrl =
      TextEditingController(text: activeProj["montajKm"] ?? "12+000.00");
  final numberCtrl = TextEditingController();
  final betonCtrl = TextEditingController(text: "3.5");

  List<String> typeOptions = [
    "Vantuz",
    "Tahliye Vanası",
    "Hidrant",
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
                  const Text('Yapı Tipi Seçin:',
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
                              'Yapı No / Tanım (Örn: #5 veya A-Kolu)',
                              numberCtrl)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: buildInputField('Kilometraj (Km)', kmCtrl)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  buildInputField('Beton Miktarı (m³)', betonCtrl,
                      isNumber: true),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      String finalTitle = numberCtrl.text.trim().isNotEmpty
                          ? "$selectedType ${numberCtrl.text.trim()}"
                          : selectedType;
                      List<dynamic> currentList =
                          List.from(activeProj["sanatYapitlari"] ?? []);
                      currentList.add({
                        "tip": finalTitle,
                        "km": kmCtrl.text.trim(),
                        "beton": "${betonCtrl.text.trim()} m³",
                        "durum": "Bekliyor",
                      });
                      activeProj["sanatYapitlari"] = currentList;
                      onSave(activeProj);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                '✨ $finalTitle (Km: ${kmCtrl.text}) projeye eklendi!'),
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
${sanatList.map((y) => "  • ${y["tip"]} (Km: ${y["km"]}): ${y["durum"]} - ${y["beton"]}").join("\n")}""";

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
