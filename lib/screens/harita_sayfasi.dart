// lib/screens/harita_sayfasi.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:xml/xml.dart';
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../utils/line_calculator.dart';
import '../services/kml_parser_service.dart';
import '../services/excel_parser_service.dart';
import '../services/dynamic_icon_generator.dart';
import 'kml_yonetim_sayfasi.dart';

// 🚀 GÖKBÖRÜ HIGH-PERFORMANCE KML TILE ENGINE
class KmlTileProvider implements TileProvider {
  final List<Map<String, dynamic>> geometries;
  const KmlTileProvider(this.geometries);

  double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    if (zoom == null) {
      return TileProvider.noTile;
    }

    final double pixelRatio =
        ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final int size = (256 * pixelRatio).toInt();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final double n = math.pow(2.0, zoom).toDouble();
    final double lonMin = x / n * 360.0 - 180.0;
    final double lonMax = (x + 1) / n * 360.0 - 180.0;
    final double latMinRad = math.atan(_sinh(math.pi * (1 - 2 * (y + 1) / n)));
    final double latMaxRad = math.atan(_sinh(math.pi * (1 - 2 * y / n)));
    final double latMin = latMinRad * 180.0 / math.pi;
    final double latMax = latMaxRad * 180.0 / math.pi;

    bool hasData = false;

    for (var geo in geometries) {
      final double gMinLat = (geo['minLat'] ?? -90.0) as double;
      final double gMaxLat = (geo['maxLat'] ?? 90.0) as double;
      final double gMinLon = (geo['minLon'] ?? -180.0) as double;
      final double gMaxLon = (geo['maxLon'] ?? 180.0) as double;

      if (gMaxLat < latMin ||
          gMinLat > latMax ||
          gMaxLon < lonMin ||
          gMinLon > lonMax) {
        continue;
      }

      hasData = true;
      final paint = ui.Paint()
        ..color = geo['clr'] as Color
        ..strokeWidth = 2.5 * pixelRatio
        ..style = (geo['isPoly'] as bool)
            ? ui.PaintingStyle.fill
            : ui.PaintingStyle.stroke;
      final path = ui.Path();
      bool started = false;
      final List<LatLng> pts = geo['pts'] as List<LatLng>;
      for (var p in pts) {
        double px = (p.longitude - lonMin) / (lonMax - lonMin) * size;
        double py = size - (p.latitude - latMin) / (latMax - latMin) * size;
        if (!started) {
          path.moveTo(px, py);
          started = true;
        } else {
          path.lineTo(px, py);
        }
      }
      if (started) {
        canvas.drawPath(path, paint);
      }
    }

    if (!hasData) {
      return TileProvider.noTile;
    }

    final picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    if (byteData == null) {
      return TileProvider.noTile;
    }

    return Tile(size, size, byteData.buffer.asUint8List());
  }
}

class HaritaSayfasi extends StatefulWidget {
  final String activeProjectDocId;
  const HaritaSayfasi({
    super.key,
    this.activeProjectDocId = "agcasar_s2",
  });

  @override
  State<HaritaSayfasi> createState() => _HaritaSayfasiState();
}

class _HaritaSayfasiState extends State<HaritaSayfasi> {
  GoogleMapController? _mapController;
  final Set<Marker> _sahaElemaniMarkers = {};
  final Set<Polyline> _dinamikPolylineHatlari = {};
  Set<TileOverlay> _tileOverlays = {};
  bool _isLoading = false;
  bool _isKmlVisible = true;
  bool _showSanatYapitlari = true;
  bool _konumAktif = true;
  String? _selectedLineCode;

  int _loadedLineCount = 0;
  int _totalCoordinateCount = 0;
  String _statusMessage = "KML Katmanları Okunuyor...";

  StreamSubscription<QuerySnapshot>? _linesSubscription;
  StreamSubscription<DocumentSnapshot>? _mainProjectSubscription;
  StreamSubscription<Position>? _positionStreamSubscription;

  Map<String, dynamic>? _mainProjectData;
  List<QueryDocumentSnapshot> _linesDocs = [];

  bool _ilkKonumKilitlendi = false;
  bool _haritaOdaklandi = false;

  final Map<String, List<LatLng>> _rawLineGeometries = {};
  final List<String> _availableLineCodes = [];
  final KmlParserService _kmlParserService = KmlParserService();
  final ExcelParserService _excelParserService = ExcelParserService();

  /// 📐 KM GİRDİSİNİ HATTIN BAŞLANGICINA GÖRE NET METREYE ÇEVİREN YARDIMCI
  double _parseRelMeters(dynamic val, double startM) {
    if (val == null) {
      return 0.0;
    }
    double m = LineCalculator.parseKmToMeters(val.toString());
    if (m <= 0) {
      return 0.0;
    }
    if (m > startM) {
      return m - startM;
    } else if (m == startM) {
      return 0.0;
    } else {
      return m;
    }
  }

  @override
  void initState() {
    super.initState();
    _kimlikBilgileriniYukle();
    _loadGokboruEngine();
  }

  @override
  void dispose() {
    _linesSubscription?.cancel();
    _mainProjectSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _kimlikBilgileriniYukle() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _konumAktif = prefs.getBool('kvkk_konum_aktif') ?? true;
      });
    }

    if (_konumAktif) {
      await _izinleriKontrolEt();
      _canliGpsAkisiniBaslat();
    }
  }

  Future<void> _izinleriKontrolEt() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return;
    }
  }

  void _canliGpsAkisiniBaslat() {
    try {
      _positionStreamSubscription?.cancel();
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: Platform.isAndroid
            ? AndroidSettings(
                accuracy: LocationAccuracy.medium,
                distanceFilter: 5,
                intervalDuration: const Duration(seconds: 5),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 5,
              ),
      ).listen(
        (Position pos) {
          if (!mounted) {
            return;
          }
          if (!_ilkKonumKilitlendi &&
              !_haritaOdaklandi &&
              _mapController != null) {
            setState(() => _ilkKonumKilitlendi = true);
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(
                  LatLng(pos.latitude, pos.longitude), 16),
            );
          }
        },
        onError: (e) => debugPrint("GPS Hatası: $e"),
      );
    } catch (e) {
      debugPrint("Geolocator Hatası: $e");
    }
  }

  Future<void> _konumumaGit() async {
    try {
      await _izinleriKontrolEt();
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16),
      );
    } catch (e) {
      debugPrint("GPS kilitlenme hatası: $e");
    }
  }

  Future<void> _pickAndUploadExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'xlsm', 'csv'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _isLoading = true;
          _statusMessage =
              "${result.files.length} Adet Excel Ayrıştırılıyor...";
        });

        int totalSavedCount = 0;
        for (var file in result.files) {
          if (file.bytes != null) {
            int count = await _excelParserService.parseAndSaveExcelBytes(
              bytes: file.bytes!,
              projectId: widget.activeProjectDocId,
            );
            totalSavedCount += count;
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "🎉 ${result.files.length} dosyadan toplam $totalSavedCount adet yapı haritada çizildi!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Excel Okuma Hatası: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      _startCanliProjeDinleyicisi();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadGokboruEngine() async {
    if (_isLoading) {
      return;
    }
    setState(() {
      _isLoading = true;
      _statusMessage = "KML Katmanları Okunuyor...";
    });

    try {
      var snap =
          await FirebaseFirestore.instance.collection('kml_katmanlari').get();
      if (snap.docs.isEmpty) {
        _startCanliProjeDinleyicisi();
        return;
      }

      List<Map<String, dynamic>> allGeometries = [];

      for (var doc in snap.docs) {
        String? url = doc.data()['url'];
        if (url == null || url.isEmpty) {
          continue;
        }

        Uint8List? data;
        try {
          var response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            data = response.bodyBytes;
          }
        } catch (_) {
          final ref = FirebaseStorage.instance.refFromURL(url);
          data = await ref.getData(15 * 1024 * 1024);
        }

        if (data != null && data.isNotEmpty) {
          await _kmlParserService.parseAndSaveKmlBytes(
            bytes: data,
            projectId: widget.activeProjectDocId,
          );

          String kmlStr = "";
          try {
            final archive = ZipDecoder().decodeBytes(data);
            for (final f in archive) {
              if (f.name.toLowerCase().endsWith('.kml')) {
                kmlStr =
                    utf8.decode(f.content as List<int>, allowMalformed: true);
                break;
              }
            }
          } catch (_) {
            kmlStr = utf8.decode(data, allowMalformed: true);
          }

          if (kmlStr.isEmpty) {
            continue;
          }

          final xml = XmlDocument.parse(kmlStr);

          for (var pm in xml.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local.toLowerCase() == 'placemark')) {
            String lineName = "S2";
            final nameNode = pm.descendants
                .whereType<XmlElement>()
                .where((e) => e.name.local.toLowerCase() == 'name')
                .firstOrNull;
            if (nameNode != null && nameNode.innerText.trim().isNotEmpty) {
              lineName = nameNode.innerText.trim();
            }

            final coordsNode = pm.descendants
                .whereType<XmlElement>()
                .where((e) => e.name.local.toLowerCase() == 'coordinates')
                .firstOrNull;
            if (coordsNode == null) {
              continue;
            }

            final coords = coordsNode.innerText.trim();
            List<LatLng> pts = [];

            for (var r in coords.split(RegExp(r'[\s\n\r\t]+'))) {
              final p = r.split(',');
              if (p.length >= 2) {
                double? lon = double.tryParse(p[0]);
                double? lat = double.tryParse(p[1]);
                if (lat != null && lon != null) {
                  if (lon >= 36.0 &&
                      lon <= 42.5 &&
                      lat >= 26.0 &&
                      lat <= 36.0) {
                    pts.add(LatLng(lon, lat));
                  } else {
                    pts.add(LatLng(lat, lon));
                  }
                }
              }
            }

            if (pts.isNotEmpty) {
              _rawLineGeometries[lineName] = pts;

              double gMinLat = pts.map((p) => p.latitude).reduce(math.min);
              double gMaxLat = pts.map((p) => p.latitude).reduce(math.max);
              double gMinLon = pts.map((p) => p.longitude).reduce(math.min);
              double gMaxLon = pts.map((p) => p.longitude).reduce(math.max);

              allGeometries.add({
                'pts': pts,
                'clr': const Color(0xFF4A148C),
                'isPoly': false,
                'minLat': gMinLat,
                'maxLat': gMaxLat,
                'minLon': gMinLon,
                'maxLon': gMaxLon,
              });
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _tileOverlays = {
            TileOverlay(
              tileOverlayId: const TileOverlayId("gokboru_kml_layer"),
              tileProvider: KmlTileProvider(allGeometries),
            ),
          };
        });
      }
    } catch (e) {
      debugPrint("Tile Engine Hatası: $e");
    } finally {
      _startCanliProjeDinleyicisi();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 🔄 BİRLEŞİK CANLI DİNLEYİCİ (ANA PROJE + LINES ALT KOLEKSİYONU)
  void _startCanliProjeDinleyicisi() {
    _linesSubscription?.cancel();
    _mainProjectSubscription?.cancel();

    // 1. Ana Proje Dokümanı Canlı Dinle (Pano'dan güncellenen hatProgress verileri için)
    _mainProjectSubscription = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.activeProjectDocId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _mainProjectData = snapshot.data() as Map<String, dynamic>;
        _rebuildMapElements();
      }
    });

    // 2. Lines Alt Koleksiyonu Canlı Dinle (Excel ve KML ile oluşturulan çizgi ve yapılar için)
    _linesSubscription = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.activeProjectDocId)
        .collection('lines')
        .snapshots()
        .listen((querySnap) {
      _linesDocs = querySnap.docs;
      _rebuildMapElements();
    });
  }

  /// 🎨 CANLI HARİTA ELEMANLARINI BİRLEŞTİREREK RENKLENDİREN MERKEZİ MOTOR
  Future<void> _rebuildMapElements() async {
    if (!mounted) {
      return;
    }

    Map<String, dynamic> mainData = _mainProjectData ?? {};
    Map<String, dynamic> hatProgressMap =
        Map<String, dynamic>.from(mainData["hatProgress"] ?? {});
    List<dynamic> mainSanatList = mainData["sanatYapitlari"] ?? [];

    Set<Polyline> newPolylines = {};
    Set<Marker> newMarkers = {};
    List<String> codes = [];

    double? minLat, maxLat, minLon, maxLon;
    int totalPts = 0;

    // Eğer lines alt koleksiyonunda veri varsa oradan işle
    if (_linesDocs.isNotEmpty) {
      for (var doc in _linesDocs) {
        var data = doc.data() as Map<String, dynamic>;
        String lineCode = data["code"] ?? doc.id;
        codes.add(lineCode);

        if (_selectedLineCode != null && _selectedLineCode != lineCode) {
          continue;
        }

        List<LatLng> basePoints = [];
        if (data['coordinates'] != null &&
            (data['coordinates'] as List).isNotEmpty) {
          for (var c in (data['coordinates'] as List)) {
            if (c is Map && c.containsKey('lat') && c.containsKey('lng')) {
              double? lat = double.tryParse(c['lat'].toString());
              double? lng = double.tryParse(c['lng'].toString());
              if (lat != null && lng != null) {
                LatLng p = LatLng(lat, lng);
                basePoints.add(p);
                totalPts++;

                if (minLat == null || lat < minLat) {
                  minLat = lat;
                }
                if (maxLat == null || lat > maxLat) {
                  maxLat = lat;
                }
                if (minLon == null || lng < minLon) {
                  minLon = lng;
                }
                if (maxLon == null || lng > maxLon) {
                  maxLon = lng;
                }
              }
            }
          }
        } else if (_rawLineGeometries.containsKey(lineCode)) {
          basePoints = _rawLineGeometries[lineCode]!;
          totalPts += basePoints.length;
        }

        if (basePoints.isEmpty) {
          continue;
        }

        // 🟡 Base Polyline (Sarı/Turuncu Zemin - Genişlik 12 - zIndex: 0)
        newPolylines.add(Polyline(
          polylineId: PolylineId('${lineCode}_base'),
          points: basePoints,
          color: const Color(0x66FF9F1C),
          width: 12,
          zIndex: 0,
        ));

        // Metraj verilerini önce Pano'daki hatProgress'ten, yoksa alt koleksiyon çizgisinden al
        Map<String, dynamic> hData =
            Map<String, dynamic>.from(hatProgressMap[lineCode] ?? {});

        double startM = LineCalculator.parseKmToMeters(
            hData["startKm"] ?? data["startKm"]?.toString() ?? "0+000");

        dynamic kaziVal = hData["kaziKm"] ?? data["kaziKm"];
        dynamic yataklamaVal = hData["yataklamaKm"] ?? data["yataklamaKm"];
        dynamic montajVal = hData["montajKm"] ?? data["montajKm"];
        dynamic kapamaVal = hData["kapamaKm"] ?? data["kapamaKm"];

        // 🔴 KAZI (Kırmızı - Dış Katman - Genişlik 10 - %75 Opaklık - zIndex: 1)
        double relKazi = _parseRelMeters(kaziVal, startM);
        if (relKazi > 0) {
          List<LatLng> kaziPts =
              LineCalculator.getSubPolyline(basePoints, 0.0, relKazi);
          if (kaziPts.isNotEmpty) {
            newPolylines.add(Polyline(
              polylineId: PolylineId('${lineCode}_kazi'),
              points: kaziPts,
              color: const Color(0xCCE71D36),
              width: 10,
              zIndex: 1,
            ));
          }
        }

        // 🟡 YATAKLAMA (Turuncu - İç Katman - Genişlik 8 - %80 Opaklık - zIndex: 2)
        double relYataklama = _parseRelMeters(yataklamaVal, startM);
        if (relYataklama > 0) {
          List<LatLng> yataklamaPts =
              LineCalculator.getSubPolyline(basePoints, 0.0, relYataklama);
          if (yataklamaPts.isNotEmpty) {
            newPolylines.add(Polyline(
              polylineId: PolylineId('${lineCode}_yataklama'),
              points: yataklamaPts,
              color: const Color(0xCCFF9F1C),
              width: 8,
              zIndex: 2,
            ));
          }
        }

        // 🟢 MONTAJ (Turkuaz - İç Katman - Genişlik 6 - %85 Opaklık - zIndex: 3)
        double relMontaj = _parseRelMeters(montajVal, startM);
        if (relMontaj > 0) {
          List<LatLng> montajPts =
              LineCalculator.getSubPolyline(basePoints, 0.0, relMontaj);
          if (montajPts.isNotEmpty) {
            newPolylines.add(Polyline(
              polylineId: PolylineId('${lineCode}_montaj'),
              points: montajPts,
              color: const Color(0xCC2EC4B6),
              width: 6,
              zIndex: 3,
            ));
          }
        }

        // 🔵 KAPAMA (Mavi - Merkez Katman - Genişlik 4 - %90 Opaklık - zIndex: 4)
        double relKapama = _parseRelMeters(kapamaVal, startM);
        if (relKapama > 0) {
          List<LatLng> kapamaPts =
              LineCalculator.getSubPolyline(basePoints, 0.0, relKapama);
          if (kapamaPts.isNotEmpty) {
            newPolylines.add(Polyline(
              polylineId: PolylineId('${lineCode}_kapama'),
              points: kapamaPts,
              color: const Color(0xCC20A4F3),
              width: 4,
              zIndex: 4,
            ));
          }
        }

        // 📍 SANAT YAPILARI (Hidrant, Vantuz, Tahliye Vanası vb. Özel İkonlar)
        List<dynamic> sanatYapitlari = List.from(data["sanatYapitlari"] ?? []);

        // Pano/Ana Projedeki bu hatta ait sanat yapılarını da ekle
        for (var sy in mainSanatList) {
          if (sy is Map) {
            String h = (sy["hatKodu"] ?? sy["hatAd"] ?? sy["hat"] ?? "")
                .toString()
                .trim();
            if (h == lineCode && !sanatYapitlari.contains(sy)) {
              sanatYapitlari.add(sy);
            }
          }
        }

        for (int i = 0; i < sanatYapitlari.length; i++) {
          var yapi = sanatYapitlari[i];
          if (yapi is! Map) {
            continue;
          }

          double? lat = double.tryParse(
              yapi["lat"]?.toString() ?? yapi["latitude"]?.toString() ?? '');
          double? lng = double.tryParse(
              yapi["lng"]?.toString() ?? yapi["longitude"]?.toString() ?? '');
          LatLng? point;

          if (lat != null && lng != null) {
            point = LatLng(lat, lng);
          } else {
            double relYapiM =
                _parseRelMeters(yapi["km"] ?? yapi["Km"] ?? yapi["KM"], startM);
            point = LineCalculator.getPointAtDistance(basePoints, relYapiM);
          }

          if (point != null) {
            bool isCompleted = yapi["status"] == "Tamamlandı" ||
                yapi["durum"] == "Tamamlandı" ||
                yapi["completed"] == true ||
                yapi["isCompleted"] == true;

            String type = (yapi["type"] ??
                    yapi["tip"] ??
                    yapi["name"] ??
                    yapi["ad"] ??
                    yapi["tur"] ??
                    yapi["yapiTipi"] ??
                    "Yapı")
                .toString();
            String feature = (yapi["feature"] ??
                    yapi["ozellik"] ??
                    yapi["özelik"] ??
                    yapi["subType"] ??
                    yapi["detay"] ??
                    "")
                .toString();
            String diameter = (yapi["diameter"] ??
                    yapi["cap"] ??
                    yapi["çap"] ??
                    yapi["Cap"] ??
                    "")
                .toString();

            // Beton veya Açıklama metninden tür, özellik ve çap ayrıştırması yap
            String betonStr = (yapi["beton"] ??
                    yapi["aciklama"] ??
                    yapi["açıklama"] ??
                    yapi["details"] ??
                    "")
                .toString();
            if (betonStr.isNotEmpty) {
              List<String> parts =
                  betonStr.split("-").map((e) => e.trim()).toList();
              if (parts.isNotEmpty && (type == "Yapı" || type.isEmpty)) {
                type = parts[0];
              }
              if (parts.length > 1 && feature.isEmpty) {
                feature = parts[1];
              }
              if (parts.length > 2 && diameter.isEmpty) {
                diameter = parts[2];
              }
            }

            double rotation = double.tryParse(yapi["rotation"]?.toString() ??
                    yapi["aci"]?.toString() ??
                    '0') ??
                0.0;

            BitmapDescriptor autoIcon =
                await DynamicIconGenerator.createAutoIcon(
              type: type,
              feature: feature,
              diameter: diameter,
              isCompleted: isCompleted,
            );

            String subtitleDetails = [
              if (feature.isNotEmpty) feature,
              if (diameter.isNotEmpty) diameter,
            ].join(' - ');

            newMarkers.add(Marker(
              markerId: MarkerId(
                  '${lineCode}_sanat_${i}_${yapi["id"] ?? yapi["name"] ?? i}'),
              position: point,
              rotation: rotation,
              icon: autoIcon,
              infoWindow: InfoWindow(
                title:
                    "${yapi["name"] ?? yapi["ad"] ?? yapi["tip"] ?? type} ($lineCode)",
                snippet:
                    "Km: ${yapi["km"] ?? yapi["Km"] ?? "0+000"} | $type ${subtitleDetails.isNotEmpty ? '($subtitleDetails)' : ''} | Durum: ${isCompleted ? 'Tamamlandı' : 'Bekliyor'}",
              ),
            ));
          }
        }
      }
    } else {
      // Lines alt koleksiyonu henüz yoksa, Ana Proje ve KML Ham Geometrileri üzerinden çiz
      Set<String> allDetectedHats = {};
      for (var item in mainSanatList) {
        if (item is Map) {
          String h = (item["hatKodu"] ?? item["hatAd"] ?? item["hat"] ?? "")
              .toString()
              .trim();
          if (h.isNotEmpty) {
            allDetectedHats.add(h);
          }
        }
      }
      allDetectedHats.addAll(hatProgressMap.keys);
      allDetectedHats.addAll(_rawLineGeometries.keys);
      if (allDetectedHats.isEmpty) {
        allDetectedHats.add(mainData["code"] ?? "S2-1");
      }

      codes = allDetectedHats.toList();

      List<String> hatsToRender =
          (_selectedLineCode != null && _selectedLineCode!.isNotEmpty)
              ? [_selectedLineCode!]
              : codes;

      for (String lineCode in hatsToRender) {
        Map<String, dynamic> hData =
            Map<String, dynamic>.from(hatProgressMap[lineCode] ?? {});

        List<LatLng> basePoints = _rawLineGeometries[lineCode] ?? [];

        if (basePoints.isEmpty) {
          if (_rawLineGeometries.isNotEmpty) {
            basePoints = _rawLineGeometries.values.first;
          } else {
            basePoints = [
              const LatLng(38.35, 35.35),
              const LatLng(38.36, 35.36),
            ];
          }
        }

        totalPts += basePoints.length;

        newPolylines.add(Polyline(
          polylineId: PolylineId('${lineCode}_base'),
          points: basePoints,
          color: const Color(0x66FF9F1C),
          width: 12,
          zIndex: 0,
        ));

        double startM = LineCalculator.parseKmToMeters(
            hData["startKm"] ?? mainData["startKm"] ?? "0+000");

        double relKazi =
            _parseRelMeters(hData["kaziKm"] ?? mainData["kaziKm"], startM);
        if (relKazi > 0) {
          List<LatLng> kaziPts =
              LineCalculator.getSubPolyline(basePoints, 0.0, relKazi);
          if (kaziPts.isNotEmpty) {
            newPolylines.add(Polyline(
              polylineId: PolylineId('${lineCode}_kazi'),
              points: kaziPts,
              color: const Color(0xCCE71D36),
              width: 10,
              zIndex: 1,
            ));
          }
        }

        double relYataklama = _parseRelMeters(
            hData["yataklamaKm"] ?? mainData["yataklamaKm"], startM);
        if (relYataklama > 0) {
          List<LatLng> yataklamaPts =
              LineCalculator.getSubPolyline(basePoints, 0.0, relYataklama);
          if (yataklamaPts.isNotEmpty) {
            newPolylines.add(Polyline(
              polylineId: PolylineId('${lineCode}_yataklama'),
              points: yataklamaPts,
              color: const Color(0xCCFF9F1C),
              width: 8,
              zIndex: 2,
            ));
          }
        }

        double relMontaj =
            _parseRelMeters(hData["montajKm"] ?? mainData["montajKm"], startM);
        if (relMontaj > 0) {
          List<LatLng> montajPts =
              LineCalculator.getSubPolyline(basePoints, 0.0, relMontaj);
          if (montajPts.isNotEmpty) {
            newPolylines.add(Polyline(
              polylineId: PolylineId('${lineCode}_montaj'),
              points: montajPts,
              color: const Color(0xCC2EC4B6),
              width: 6,
              zIndex: 3,
            ));
          }
        }

        double relKapama =
            _parseRelMeters(hData["kapamaKm"] ?? mainData["kapamaKm"], startM);
        if (relKapama > 0) {
          List<LatLng> kapamaPts =
              LineCalculator.getSubPolyline(basePoints, 0.0, relKapama);
          if (kapamaPts.isNotEmpty) {
            newPolylines.add(Polyline(
              polylineId: PolylineId('${lineCode}_kapama'),
              points: kapamaPts,
              color: const Color(0xCC20A4F3),
              width: 4,
              zIndex: 4,
            ));
          }
        }

        List<dynamic> lineSanatList = mainSanatList.where((sy) {
          String h = (sy["hatKodu"] ?? sy["hatAd"] ?? sy["hat"] ?? "")
              .toString()
              .trim();
          return h.isEmpty || h == lineCode;
        }).toList();

        for (int i = 0; i < lineSanatList.length; i++) {
          var yapi = lineSanatList[i];
          if (yapi is! Map) {
            continue;
          }

          double? lat = double.tryParse(
              yapi["lat"]?.toString() ?? yapi["latitude"]?.toString() ?? '');
          double? lng = double.tryParse(
              yapi["lng"]?.toString() ?? yapi["longitude"]?.toString() ?? '');
          LatLng? point;

          if (lat != null && lng != null) {
            point = LatLng(lat, lng);
          } else {
            double relYapiM =
                _parseRelMeters(yapi["km"] ?? yapi["Km"] ?? yapi["KM"], startM);
            point = LineCalculator.getPointAtDistance(basePoints, relYapiM);
          }

          if (point != null) {
            bool isCompleted = yapi["status"] == "Tamamlandı" ||
                yapi["durum"] == "Tamamlandı" ||
                yapi["completed"] == true ||
                yapi["isCompleted"] == true;

            String type = (yapi["type"] ??
                    yapi["tip"] ??
                    yapi["name"] ??
                    yapi["ad"] ??
                    yapi["tur"] ??
                    yapi["yapiTipi"] ??
                    "Yapı")
                .toString();
            String feature = (yapi["feature"] ??
                    yapi["ozellik"] ??
                    yapi["özelik"] ??
                    yapi["subType"] ??
                    yapi["detay"] ??
                    "")
                .toString();
            String diameter = (yapi["diameter"] ??
                    yapi["cap"] ??
                    yapi["çap"] ??
                    yapi["Cap"] ??
                    "")
                .toString();

            BitmapDescriptor autoIcon =
                await DynamicIconGenerator.createAutoIcon(
              type: type,
              feature: feature,
              diameter: diameter,
              isCompleted: isCompleted,
            );

            newMarkers.add(Marker(
              markerId: MarkerId(
                  '${lineCode}_sanat_${i}_${yapi["id"] ?? yapi["name"] ?? i}'),
              position: point,
              icon: autoIcon,
              infoWindow: InfoWindow(
                title:
                    "${yapi["name"] ?? yapi["ad"] ?? yapi["tip"] ?? type} ($lineCode)",
                snippet:
                    "Km: ${yapi["km"] ?? yapi["Km"] ?? "0+000"} | Durum: ${isCompleted ? 'Tamamlandı' : 'Bekliyor'}",
              ),
            ));
          }
        }
      }
    }

    if (mounted) {
      List<String> sortedLineCodes = codes.toSet().toList()
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

      setState(() {
        _loadedLineCount = sortedLineCodes.length;
        _totalCoordinateCount = totalPts;
        _availableLineCodes.clear();
        _availableLineCodes.addAll(sortedLineCodes);
        _statusMessage =
            "✅ $_loadedLineCount Hat • ${newMarkers.length} Yapı Çizildi";
        _dinamikPolylineHatlari.clear();
        _dinamikPolylineHatlari.addAll(newPolylines);
        _sahaElemaniMarkers.clear();
        _sahaElemaniMarkers.addAll(newMarkers);
      });

      if (!_haritaOdaklandi &&
          _mapController != null &&
          minLat != null &&
          minLon != null) {
        _haritaOdaklandi = true;
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat, minLon),
              northeast: LatLng(maxLat!, maxLon!),
            ),
            60,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text("Sitechain Canlı Saha Haritası"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _showSanatYapitlari ? Icons.visibility : Icons.visibility_off,
              color:
                  _showSanatYapitlari ? const Color(0xFFFF9F1C) : Colors.grey,
            ),
            tooltip: _showSanatYapitlari ? "Yapıları Gizle" : "Yapıları Göster",
            onPressed: () {
              setState(() => _showSanatYapitlari = !_showSanatYapitlari);
            },
          ),
          IconButton(
            icon: Icon(
              _isKmlVisible ? Icons.layers : Icons.layers_clear,
              color: _isKmlVisible ? Colors.greenAccent : Colors.redAccent,
            ),
            tooltip: "KML Katmanını Aç/Kapat",
            onPressed: () {
              setState(() => _isKmlVisible = !_isKmlVisible);
              if (_isKmlVisible) {
                _loadGokboruEngine();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder_special, color: Color(0xFFFF9F1C)),
            tooltip: "KML Yönetimi",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const KmlYonetimSayfasi()),
              );
              _loadGokboruEngine();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(38.35, 35.35),
              zoom: 12,
            ),
            mapType: MapType.hybrid,
            markers: _showSanatYapitlari ? _sahaElemaniMarkers : <Marker>{},
            polylines: _dinamikPolylineHatlari,
            tileOverlays: _isKmlVisible ? _tileOverlays : <TileOverlay>{},
            onMapCreated: (c) {
              _mapController = c;
              _loadGokboruEngine();
            },
            myLocationEnabled: _konumAktif,
            myLocationButtonEnabled: false,
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF9F1C)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "📌 Proje ID: ${widget.activeProjectDocId}\n$_statusMessage ($_totalCoordinateCount Nokta)",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF9F1C),
                              side: const BorderSide(color: Color(0xFFFF9F1C)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _pickAndUploadExcel,
                            icon: const Icon(Icons.table_chart, size: 14),
                            label: const Text("EXCEL YÜKLE",
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh,
                                color: Color(0xFFFF9F1C), size: 20),
                            onPressed: _loadGokboruEngine,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_availableLineCodes.isNotEmpty) const SizedBox(height: 6),
                if (_availableLineCodes.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedLineCode,
                        dropdownColor: const Color(0xFF1E2638),
                        isExpanded: true,
                        icon: const Icon(Icons.tune, color: Color(0xFFFF9F1C)),
                        hint: Text(
                          "🌐 Tüm Şebekeyi Göster (${_availableLineCodes.length} Hat)",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text("🌐 Tüm Şebekeyi Göster",
                                style: TextStyle(
                                    color: Color(0xFFFF9F1C),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ),
                          ..._availableLineCodes.map((code) {
                            return DropdownMenuItem<String?>(
                              value: code,
                              child: Text("📍 Hat: $code",
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13)),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedLineCode = val);
                          _rebuildMapElements();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        onPressed: _konumumaGit,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
