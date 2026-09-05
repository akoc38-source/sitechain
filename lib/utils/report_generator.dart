// lib/utils/report_generator.dart

import 'package:flutter/services.dart';
import '../models/daily_log_model.dart';

enum ReportPeriod { gunluk, haftalik, aylik }

class ReportGenerator {
  /// DSİ & İdare Şantiye Rapor Formatlayıcı (Günlük + Kümülatif Toplam)
  static String buildWhatsAppReport({
    required Map<String, dynamic> project,
    required List<DailyLogModel> dailyLogs,
    required List<Map<String, dynamic>> allLinesData,
    required ReportPeriod period,
  }) {
    DateTime now = DateTime.now();
    String dateStr =
        "${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}";

    StringBuffer buffer = StringBuffer();
    buffer.writeln(
        "📋 ${(project["name"] ?? "AĞCAŞAR S2 PROJESİ").toString().toUpperCase()}");
    buffer.writeln("📌 DSİ & KONTROLÖRLÜK SAHA İLERLEME RAPORU");
    buffer.writeln(
        "📍 Konum: ${project["city"] ?? "Kayseri"} / ${project["district"] ?? "Yahyalı"}");
    buffer.writeln("🗓 Tarih: $dateStr\n");

    // 1. GÜNLÜK YAPILAN İŞLER ÖZETİ
    buffer.writeln("----------------------------------");
    buffer.writeln("🚜 BÖLÜM 1: GÜNLÜK SAHA İLERLEMESİ ($dateStr)");
    buffer.writeln("----------------------------------");

    if (dailyLogs.isEmpty) {
      buffer.writeln(" Bugün için henüz yeni veri girişi yapılmadı.\n");
    } else {
      for (var log in dailyLogs) {
        buffer.writeln("📌 Hat: ${log.lineCode} (Ekip: ${log.personnelName})");
        if (log.kaziMeters > 0) {
          buffer.writeln(
              "  • Kazı: ${log.kaziStartKm} ➔ ${log.kaziEndKm} (${log.kaziMeters.toStringAsFixed(1)} m)");
        }
        if (log.yataklamaMeters > 0) {
          buffer.writeln(
              "  • Yataklama: ${log.yataklamaStartKm} ➔ ${log.yataklamaEndKm} (${log.yataklamaMeters.toStringAsFixed(1)} m)");
        }
        if (log.montajMeters > 0) {
          buffer.writeln(
              "  • Boru Montajı: ${log.montajStartKm} ➔ ${log.montajEndKm} (${log.montajMeters.toStringAsFixed(1)} m)");
        }
        if (log.kapamaMeters > 0) {
          buffer.writeln(
              "  • Geri Dolgu: ${log.kapamaStartKm} ➔ ${log.kapamaEndKm} (${log.kapamaMeters.toStringAsFixed(1)} m)");
        }
        if (log.cakilSefer > 0 || log.betonM3 > 0) {
          buffer.writeln(
              "  • Malzeme: ${log.cakilSefer} Kamyon Çakıl | ${log.betonM3} m³ Beton");
        }
        buffer.writeln("");
      }
    }

    // 2. TÜM HATLAR KÜMÜLATİF (TOPLAM) İLERLEME DURUMU
    buffer.writeln("----------------------------------");
    buffer.writeln("📊 BÖLÜM 2: HATLAR KÜMÜLATİF TOPLAM DURUM");
    buffer.writeln("----------------------------------");

    double totalNetworkKm = 0.0;

    if (allLinesData.isNotEmpty) {
      for (var line in allLinesData) {
        String code = line["code"] ?? "S2";
        double totalKm =
            double.tryParse(line["totalKm"]?.toString() ?? "0") ?? 0.0;
        String montajKm = line["montajKm"]?.toString() ?? "0+000";

        totalNetworkKm += totalKm;

        buffer.writeln(
            "🔹 Hat $code (Toplam: ${totalKm.toStringAsFixed(2)} km):");
        buffer.writeln("  • Son Montaj Km: $montajKm");
        buffer.writeln("  • Kazı Son Km: ${line["kaziKm"] ?? "0+000"}");
        buffer.writeln("  • Kapama Son Km: ${line["kapamaKm"] ?? "0+000"}");
      }

      buffer.writeln(
          "  • Toplam Hat Uzunluğu: ${totalNetworkKm.toStringAsFixed(2)} km");
    } else {
      buffer.writeln(
          "  • Toplam Hat Uzunluğu: ${project["totalKm"] ?? "20.00"} km");
      buffer.writeln(
          "  • Genel Montaj Km: ${project["montajKm"] ?? "12+000.00"}");
    }

    // 3. GENEL LOJİSTİK VE KANALLAR
    buffer.writeln("\n🚚 Toplam Malzeme Sevk:");
    buffer.writeln("  • Toplam Çakıl: ${project["cakilSefer"] ?? 0} Sefer");
    buffer.writeln("  • Toplam Beton: ${project["betonM3"] ?? 0} m³");

    List<dynamic> sanatList = project["sanatYapitlari"] ?? [];
    if (sanatList.isNotEmpty) {
      buffer.writeln("\n🏗 Sanat Yapıları / Branşmanlar:");
      for (var yapi in sanatList) {
        buffer.writeln(
            "  • ${yapi["tip"]} (${yapi["hatKodu"] ?? "S2-1"} Km: ${yapi["km"]}): ${yapi["durum"]}");
      }
    }

    buffer.writeln("\n🚀 SiteChain Global Infrastructure Platform");
    return buffer.toString();
  }

  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
