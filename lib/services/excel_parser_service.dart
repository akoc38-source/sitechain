// lib/services/excel_parser_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

class ExcelParserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 📊 1. GENEL EXCEL METRAJ OKUMA VE HAT OLUŞTURMA
  Future<int> parseAndSaveExcel({
    required Uint8List bytes,
    required String projectId,
  }) async {
    try {
      final excel = Excel.decodeBytes(bytes);
      int totalCount = 0;

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.rows.isEmpty) continue;

        for (int i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          String code = _getCellValue(row, 0);
          String name = _getCellValue(row, 1);
          double totalKm = _parseDoubleValue(row, 2);
          String pipeType = _getCellValue(row, 3);
          double startKm = _parseDoubleValue(row, 4);

          if (code.isNotEmpty) {
            String docId = code.replaceAll(' ', '_').replaceAll('/', '-');

            Map<String, dynamic> lineData = {
              'id': docId,
              'code': code,
              'name': name.isEmpty ? code : name,
              'totalKm': totalKm,
              'startKm': startKm,
              'pipeType': pipeType.isEmpty ? 'PE100' : pipeType,
              'kaziKm': startKm,
              'yataklamaKm': startKm,
              'montajKm': startKm,
              'kapamaKm': startKm,
              'sanatYapitlari': [],
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            };

            await _firestore
                .collection('projects')
                .doc(projectId)
                .collection('lines')
                .doc(docId)
                .set(lineData, SetOptions(merge: true));

            totalCount++;
          }
        }
      }
      return totalCount;
    } catch (e) {
      debugPrint("Excel Metraj Okuma Hatası: $e");
      rethrow;
    }
  }

  /// 🏗️ 2. SANAT YAPILARI VE BRANŞMANLARI EXCEL'DEN YÜKLEME
  Future<int> parseAndSaveExcelBytes({
    required Uint8List bytes,
    required String projectId,
  }) async {
    try {
      final excel = Excel.decodeBytes(bytes);
      int addedCount = 0;

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.rows.isEmpty) continue;

        for (int i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty || row.length < 3) continue;

          String lineCode = _getCellValue(row, 0); // Hat Kodu (Örn: S2-1)
          String kmStr = _getCellValue(row, 1); // Metraj (Örn: 0+120.00)
          String structureName = _getCellValue(row, 2); // Yapı Adı (Örn: SAV-1)
          String structureType =
              row.length > 3 ? _getCellValue(row, 3) : "Yapı"; // Tür
          String feature =
              row.length > 4 ? _getCellValue(row, 4) : ""; // Özellik
          String diameter = row.length > 5 ? _getCellValue(row, 5) : ""; // Çap

          if (lineCode.isEmpty || structureName.isEmpty) continue;

          // Projedeki ilgili Hat Kodu ile eşleşen hattı ara
          final linesSnapshot = await _firestore
              .collection('projects')
              .doc(projectId)
              .collection('lines')
              .where('code', isEqualTo: lineCode)
              .limit(1)
              .get();

          if (linesSnapshot.docs.isNotEmpty) {
            final lineDoc = linesSnapshot.docs.first;

            Map<String, dynamic> newStructure = {
              'id': "${DateTime.now().millisecondsSinceEpoch}_$i",
              'name': structureName,
              'km': kmStr.isEmpty ? "0+000" : kmStr,
              'type': structureType.isEmpty ? "Yapı" : structureType,
              'feature': feature,
              'diameter': diameter,
              'status': 'Bekliyor',
              'createdAt': DateTime.now().toIso8601String(),
            };

            await lineDoc.reference.update({
              'sanatYapitlari': FieldValue.arrayUnion([newStructure]),
              'updatedAt': FieldValue.serverTimestamp(),
            });

            addedCount++;
          }
        }
      }
      return addedCount;
    } catch (e) {
      debugPrint("Sanat Yapıları Excel Okuma Hatası: $e");
      rethrow;
    }
  }

  /// 📐 3. EXCEL HAKEDİŞ / İLERLEME METRAJI GÜNCELLEME
  Future<int> parseAndUpdateProgressExcel({
    required Uint8List bytes,
    required String projectId,
  }) async {
    try {
      final excel = Excel.decodeBytes(bytes);
      int updatedCount = 0;

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.rows.isEmpty) continue;

        for (int i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          String code = _getCellValue(row, 0);
          double kazi = _parseDoubleValue(row, 1);
          double yataklama = _parseDoubleValue(row, 2);
          double montaj = _parseDoubleValue(row, 3);
          double kapama = _parseDoubleValue(row, 4);

          if (code.isNotEmpty) {
            String docId = code.replaceAll(' ', '_').replaceAll('/', '-');

            await _firestore
                .collection('projects')
                .doc(projectId)
                .collection('lines')
                .doc(docId)
                .update({
              'kaziKm': kazi,
              'yataklamaKm': yataklama,
              'montajKm': montaj,
              'kapamaKm': kapama,
              'updatedAt': FieldValue.serverTimestamp(),
            });

            updatedCount++;
          }
        }
      }
      return updatedCount;
    } catch (e) {
      debugPrint("İlerleme Excel Okuma Hatası: $e");
      rethrow;
    }
  }

  /// 🔍 YARDIMCI METOT: Hücre değerini güvenli şekilde String'e dönüştürür
  String _getCellValue(List<Data?> row, int index) {
    if (index >= row.length ||
        row[index] == null ||
        row[index]?.value == null) {
      return "";
    }
    return row[index]!.value.toString().trim();
  }

  /// 🔢 YARDIMCI METOT: Hücre değerini güvenli şekilde double tipe dönüştürür
  double _parseDoubleValue(List<Data?> row, int index) {
    String val = _getCellValue(row, index);
    if (val.isEmpty) return 0.0;
    val = val.replaceAll(',', '.');
    return double.tryParse(val) ?? 0.0;
  }
}
