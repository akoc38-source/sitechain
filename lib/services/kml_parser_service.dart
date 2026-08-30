// lib/services/kml_parser_service.dart

import 'dart:convert';
import 'dart:math';
import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:xml/xml.dart';
import '../models/pipe_line_model.dart';

class KmlParserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<int> parseAndSaveKmlBytes({
    required List<int> bytes,
    required String projectId,
  }) async {
    String kmlContent = "";

    if (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      try {
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final file in archive) {
          if (file.name.toLowerCase().endsWith('.kml')) {
            kmlContent =
                utf8.decode(file.content as List<int>, allowMalformed: true);
            break;
          }
        }
      } catch (_) {
        kmlContent = utf8.decode(bytes, allowMalformed: true);
      }
    } else {
      kmlContent = utf8.decode(bytes, allowMalformed: true);
    }

    if (kmlContent.isEmpty) return 0;
    return parseAndSaveKml(kmlContent: kmlContent, projectId: projectId);
  }

  Future<int> parseAndSaveKml({
    required String kmlContent,
    required String projectId,
  }) async {
    final document = XmlDocument.parse(kmlContent);
    final placemarks = document.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local.toLowerCase() == 'placemark');

    Map<String, List<Map<String, double>>> lineCoordinatesMap = {};
    Map<String, List<Map<String, dynamic>>> lineStructuresMap = {};
    Map<String, String> lineNamesMap = {};

    for (var placemark in placemarks) {
      final nameElement = placemark.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local.toLowerCase() == 'name')
          .firstOrNull;

      final nameText = nameElement?.innerText.trim() ?? 'İsimsiz Öğe';

      final coordsNodes = placemark.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local.toLowerCase() == 'coordinates');

      final lineStrings = placemark.descendants.whereType<XmlElement>().where(
          (e) =>
              e.name.local.toLowerCase() == 'linestring' ||
              e.name.local.toLowerCase() == 'polygon');

      if (lineStrings.isNotEmpty) {
        for (var coordsNode in coordsNodes) {
          List<Map<String, double>> coordsList =
              _parseCoordinates(coordsNode.innerText);
          if (coordsList.isNotEmpty) {
            String lineCode = _extractLineCode(nameText);
            lineCoordinatesMap[lineCode] = coordsList;
            lineNamesMap[lineCode] = nameText;
          }
        }
      }
    }

    WriteBatch batch = _firestore.batch();
    int totalLinesSaved = 0;

    for (var entry in lineCoordinatesMap.entries) {
      String lineCode = entry.key;
      List<Map<String, double>> coords = entry.value;
      List<Map<String, dynamic>> structures = lineStructuresMap[lineCode] ?? [];

      double totalKm = _calculateTotalKm(coords);

      var lineDocRef = _firestore
          .collection('projects')
          .doc(projectId)
          .collection('lines')
          .doc(lineCode.replaceAll(RegExp(r'[^\w\-]'), '_'));

      PipeLine lineModel = PipeLine(
        id: lineDocRef.id,
        name: lineNamesMap[lineCode] ?? '$lineCode Boru Hattı',
        code: lineCode,
        pipeType: 'C1000 CTP',
        totalKm: totalKm,
        startKm: 0.0,
        kaziKm: 0.0,
        yataklamaKm: 0.0,
        montajKm: 0.0,
        kapamaKm: 0.0,
        sanatYapitlari: structures,
      );

      Map<String, dynamic> firestoreData = lineModel.toMap();
      firestoreData['coordinates'] = coords;

      batch.set(lineDocRef, firestoreData, SetOptions(merge: true));
      totalLinesSaved++;
    }

    await batch.commit();
    return totalLinesSaved;
  }

  /// Türkiye Enlem (36-42) ve Boylam (26-45) Doğru Eşleştirici
  List<Map<String, double>> _parseCoordinates(String rawCoords) {
    List<Map<String, double>> result = [];
    final regExp = RegExp(r'(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)');
    final matches = regExp.allMatches(rawCoords);

    for (final match in matches) {
      double? val1 =
          double.tryParse(match.group(1) ?? ''); // Longitude (Boylam ~35.x)
      double? val2 =
          double.tryParse(match.group(2) ?? ''); // Latitude (Enlem ~38.x)

      if (val1 != null && val2 != null) {
        double lat, lng;

        // KML Standardı: parts[0] = Longitude (~35.x), parts[1] = Latitude (~38.x)
        if (val1 >= 36.0 && val1 <= 42.5 && val2 >= 26.0 && val2 <= 36.0) {
          lat = val1;
          lng = val2;
        } else {
          lat = val2;
          lng = val1;
        }

        result.add({'lat': lat, 'lng': lng});
      }
    }
    return result;
  }

  String _extractLineCode(String rawName) {
    RegExp regExp =
        RegExp(r'[A-Za-z0-9_\.]+(?:[-_][0-9]+)*', caseSensitive: false);
    Match? match = regExp.firstMatch(rawName);
    return match != null ? match.group(0)! : rawName;
  }

  double _calculateTotalKm(List<Map<String, double>> coords) {
    if (coords.length < 2) return 0.0;
    double totalMeters = 0.0;

    for (int i = 0; i < coords.length - 1; i++) {
      double lat1 = coords[i]['lat']!;
      double lon1 = coords[i]['lng']!;
      double lat2 = coords[i + 1]['lat']!;
      double lon2 = coords[i + 1]['lng']!;

      totalMeters += _haversineDistance(lat1, lon1, lat2, lon2);
    }
    return totalMeters / 1000.0;
  }

  double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return r * c;
  }

  double _toRadians(double degree) => degree * pi / 180;
}
