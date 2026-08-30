// lib/services/excel_parser_service.dart

import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:xml/xml.dart';
import '../utils/line_calculator.dart';

class ExcelParserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<int> parseAndSaveExcelBytes({
    required List<int> bytes,
    required String projectId,
  }) async {
    int totalStructuresSaved = 0;

    var linesSnap = await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('lines')
        .get();

    if (linesSnap.docs.isEmpty) {
      debugPrint("❌ Veritabanında KML hattı bulunamadı.");
      return 0;
    }

    Map<String, List<LatLng>> lineGeometries = {};
    for (var doc in linesSnap.docs) {
      var data = doc.data();
      String code = data['code'] ?? doc.id;
      List<dynamic> rawCoords = data['coordinates'] ?? [];
      List<LatLng> pts = [];

      for (var c in rawCoords) {
        if (c is Map && c.containsKey('lat') && c.containsKey('lng')) {
          double? lat = double.tryParse(c['lat'].toString());
          double? lng = double.tryParse(c['lng'].toString());
          if (lat != null && lng != null) pts.add(LatLng(lat, lng));
        }
      }
      if (pts.isNotEmpty) {
        lineGeometries[code.toUpperCase()] = pts;
        lineGeometries[doc.id.toUpperCase()] = pts;
      }
    }

    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      List<String> sharedStrings = [];
      ArchiveFile? sstFile;
      for (var file in archive) {
        if (file.name.toLowerCase().contains('sharedstrings.xml')) {
          sstFile = file;
          break;
        }
      }

      if (sstFile != null) {
        String sstXmlStr =
            utf8.decode(sstFile.content as List<int>, allowMalformed: true);
        final sstDoc = XmlDocument.parse(sstXmlStr);
        for (var si in sstDoc.descendants
            .whereType<XmlElement>()
            .where((e) => e.name.local.toLowerCase() == 'si')) {
          String text = si.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local.toLowerCase() == 't')
              .map((e) => e.innerText)
              .join();
          sharedStrings.add(text);
        }
      }

      for (var file in archive) {
        if (file.name.toLowerCase().contains('xl/worksheets/sheet') &&
            file.name.toLowerCase().endsWith('.xml')) {
          String sheetXmlStr =
              utf8.decode(file.content as List<int>, allowMalformed: true);
          final sheetDoc = XmlDocument.parse(sheetXmlStr);

          Map<String, List<Map<String, dynamic>>> lineToStructures = {};

          final rows = sheetDoc.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local.toLowerCase() == 'row');

          for (var row in rows) {
            Map<String, String> rowCells = {};

            final cells = row.descendants
                .whereType<XmlElement>()
                .where((e) => e.name.local.toLowerCase() == 'c');

            for (var c in cells) {
              String? ref = c.getAttribute('r');
              if (ref == null) continue;

              String colLetters = RegExp(r'[A-Za-z]+')
                      .firstMatch(ref)
                      ?.group(0)
                      ?.toUpperCase() ??
                  '';
              if (colLetters.isEmpty) continue;

              String type = c.getAttribute('t') ?? '';
              String cellVal = '';

              if (type == 's') {
                final vNode = c.descendants
                    .whereType<XmlElement>()
                    .where((e) => e.name.local.toLowerCase() == 'v')
                    .firstOrNull;
                if (vNode != null) {
                  int? idx = int.tryParse(vNode.innerText.trim());
                  if (idx != null && idx >= 0 && idx < sharedStrings.length) {
                    cellVal = sharedStrings[idx];
                  }
                }
              } else if (type == 'inlineStr') {
                final tNode = c.descendants
                    .whereType<XmlElement>()
                    .where((e) => e.name.local.toLowerCase() == 't')
                    .firstOrNull;
                if (tNode != null) cellVal = tNode.innerText;
              } else {
                final vNode = c.descendants
                    .whereType<XmlElement>()
                    .where((e) => e.name.local.toLowerCase() == 'v')
                    .firstOrNull;
                if (vNode != null) cellVal = vNode.innerText;
              }

              rowCells[colLetters] = cellVal.trim();
            }

            String rawLineName = rowCells['A'] ?? '';
            String rawKm = rowCells['B'] ?? '';
            String rawName = rowCells['C'] ?? '';
            String rawType = rowCells['D'] ?? '';
            String rawFeature = rowCells['E'] ?? '';
            String rawDiameter = rowCells['F'] ?? '';

            if (rawKm.contains('+') ||
                RegExp(r'^\d+(\.\d+)?$').hasMatch(rawKm)) {
              String normalizedLineCode = _normalizeLineCode(rawLineName);
              List<LatLng>? baseLinePoints =
                  lineGeometries[normalizedLineCode.toUpperCase()];
              baseLinePoints ??= lineGeometries['S2'];

              if (baseLinePoints != null && baseLinePoints.isNotEmpty) {
                double meters = LineCalculator.parseKmToMeters(rawKm);
                LatLng? interpolatedPoint =
                    LineCalculator.getPointAtDistance(baseLinePoints, meters);

                if (interpolatedPoint != null) {
                  Map<String, dynamic> structureData = {
                    'name': rawName.isNotEmpty ? rawName : rawType,
                    'km': rawKm,
                    'type': rawType.isNotEmpty ? rawType : 'Sanat Yapısı',
                    'feature': rawFeature,
                    'diameter': rawDiameter,
                    'status': 'Bekliyor',
                    'lat': interpolatedPoint.latitude,
                    'lng': interpolatedPoint.longitude,
                    'targetLine': normalizedLineCode,
                  };

                  lineToStructures.putIfAbsent(normalizedLineCode, () => []);
                  lineToStructures[normalizedLineCode]!.add(structureData);
                  totalStructuresSaved++;
                }
              }
            }
          }

          if (lineToStructures.isNotEmpty) {
            WriteBatch batch = _firestore.batch();
            for (var entry in lineToStructures.entries) {
              String lineCode = entry.key;
              var lineDocRef = _firestore
                  .collection('projects')
                  .doc(projectId)
                  .collection('lines')
                  .doc(lineCode.replaceAll(RegExp(r'[^\w\-]'), '_'));

              // 🔑 MEVCUT YAPILARI SİLMEDEN ÜZERİNE EKLEMEK İÇİN arrayUnion VE merge
              batch.set(
                  lineDocRef,
                  {
                    'code': lineCode,
                    'sanatYapitlari': FieldValue.arrayUnion(entry.value),
                  },
                  SetOptions(merge: true));
            }
            await batch.commit();
          }
        }
      }

      return totalStructuresSaved;
    } catch (e) {
      debugPrint("Excel okuma hatası: $e");
      return 0;
    }
  }

  String _normalizeLineCode(String rawText) {
    RegExp regExp = RegExp(r'S\d+(?:-\d+)*', caseSensitive: false);
    Match? match = regExp.firstMatch(rawText);
    return match != null ? match.group(0)!.toUpperCase() : 'S2';
  }
}
