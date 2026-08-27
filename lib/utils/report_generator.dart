// lib/utils/report_generator.dart

import 'package:flutter/services.dart';

enum ReportPeriod { gunluk, haftalik, aylik }

class ReportGenerator {
  // WhatsApp Metin Raporu Oluşturucu
  static String buildWhatsAppReport({
    required Map<String, dynamic> project,
    required ReportPeriod period,
  }) {
    String periodTitle = period == ReportPeriod.gunluk
        ? "GÜNLÜK SAHA İLERLEME RAPORU"
        : period == ReportPeriod.haftalik
            ? "HAFTALIK SAHA ÖZET RAPORU"
            : "AYLIK GENEL İLERLEME RAPORU";

    List<dynamic> sanatList = project["sanatYapitlari"] ?? [];
    DateTime now = DateTime.now();

    String dateStr = period == ReportPeriod.gunluk
        ? "${now.day}.${now.month}.${now.year}"
        : period == ReportPeriod.haftalik
            ? "Hafta: ${now.day - 7}.${now.month} - ${now.day}.${now.month}.${now.year}"
            : "Ay: ${now.month}.${now.year}";

    StringBuffer buffer = StringBuffer();
    buffer
        .writeln("📋 ${(project["name"] ?? "SAHA").toString().toUpperCase()}");
    buffer.writeln("📌 $periodTitle");
    buffer.writeln(
        "📍 Konum: ${project["city"] ?? "Kayseri"} / ${project["district"] ?? "Yahyalı"}");
    buffer.writeln("🗓 Tarih: $dateStr\n");

    buffer.writeln("🔹 Hat İlerleme Durumu:");
    buffer.writeln("  • 1. Aşama Kazı Km: ${project["kaziKm"] ?? "0+000"}");
    buffer.writeln(
        "  • 2. Aşama Yataklama Km: ${project["yataklamaKm"] ?? "0+000"}");
    buffer.writeln(
        "  • 3. Aşama Montaj/Döşeme Km: ${project["montajKm"] ?? "0+000"}");
    buffer.writeln(
        "  • 4. Aşama Dolgu/Kapama Km: ${project["kapamaKm"] ?? "0+000"}\n");

    buffer.writeln("🚚 Lojistik & Malzeme:");
    buffer.writeln("  • Nakliye / Kamyon: ${project["cakilSefer"] ?? 0} Sefer");
    buffer.writeln("  • Dökülen Beton: ${project["betonM3"] ?? 0} m³\n");

    if (sanatList.isNotEmpty) {
      buffer.writeln("🏗 Sanat Yapıları & Elemanlar:");
      for (var yapi in sanatList) {
        buffer.writeln(
            "  • ${yapi["tip"]} (Km: ${yapi["km"]}): ${yapi["durum"]} - ${yapi["beton"]}");
      }
    }

    buffer.writeln("\n🚀 SiteChain Global Infrastructure Platform");
    return buffer.toString();
  }

  // Panoya Kopyalama İşlemi
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
