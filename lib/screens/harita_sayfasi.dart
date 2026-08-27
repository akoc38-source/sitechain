import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';

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
import 'kml_yonetim_sayfasi.dart';

// 🚀 GÖKBÖRÜ HIGH-PERFORMANCE KML TILE ENGINE
class KmlTileProvider implements TileProvider {
  final List<Map<String, dynamic>> geometries;
  const KmlTileProvider(this.geometries);

  double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    if (zoom == null) return TileProvider.noTile;

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
      if (started) canvas.drawPath(path, paint);
    }

    if (!hasData) return TileProvider.noTile;

    final picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    if (byteData == null) return TileProvider.noTile;

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
  bool _konumAktif = true;

  StreamSubscription<DocumentSnapshot>? _projectSubscription;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _ilkKonumKilitlendi = false;

  final Map<String, List<LatLng>> _rawLineGeometries = {};

  @override
  void initState() {
    super.initState();
    _kimlikBilgileriniYukle();
    _loadGokboruEngine();
  }

  @override
  void dispose() {
    _projectSubscription?.cancel();
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
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
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
          if (!mounted) return;
          if (!_ilkKonumKilitlendi && _mapController != null) {
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

  Future<void> _loadGokboruEngine() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      var snap =
          await FirebaseFirestore.instance.collection('kml_katmanlari').get();
      if (snap.docs.isEmpty) return;

      List<Map<String, dynamic>> allGeometries = [];
      double? minLat, maxLat, minLon, maxLon;

      for (var doc in snap.docs) {
        String? url = doc.data()['url'];
        if (url == null || url.isEmpty) continue;

        Uint8List? data;
        try {
          var response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) data = response.bodyBytes;
        } catch (_) {
          final ref = FirebaseStorage.instance.refFromURL(url);
          data = await ref.getData(15 * 1024 * 1024);
        }

        if (data != null && data.isNotEmpty) {
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

          if (kmlStr.isEmpty) continue;

          final xml = XmlDocument.parse(kmlStr);

          for (var pm in xml.findAllElements('Placemark')) {
            String lineName = "S2";
            final nameNode = pm.findElements('name').firstOrNull;
            if (nameNode != null && nameNode.innerText.trim().isNotEmpty) {
              lineName = nameNode.innerText.trim();
            }

            final coordsNode = pm.findAllElements('coordinates').firstOrNull;
            if (coordsNode == null) continue;

            final coords = coordsNode.innerText.trim();
            List<LatLng> pts = [];

            for (var r in coords.split(RegExp(r'[\s\n\r\t]+'))) {
              final p = r.split(',');
              if (p.length >= 2) {
                double? lon = double.tryParse(p[0]);
                double? lat = double.tryParse(p[1]);
                if (lat != null && lon != null) {
                  pts.add(LatLng(lat, lon));

                  if (minLat == null || lat < minLat) minLat = lat;
                  if (maxLat == null || lat > maxLat) maxLat = lat;
                  if (minLon == null || lon < minLon) minLon = lon;
                  if (maxLon == null || lon > maxLon) maxLon = lon;
                }
              }
            }

            if (pts.isNotEmpty) {
              _rawLineGeometries[lineName] = pts;

              allGeometries.add({
                'pts': pts,
                'clr': const Color(0xFF4A148C),
                'isPoly': false,
                'minLat': -90.0,
                'maxLat': 90.0,
                'minLon': -180.0,
                'maxLon': 180.0,
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

        if (_mapController != null && minLat != null && minLon != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(minLat, minLon),
                northeast: LatLng(maxLat!, maxLon!),
              ),
              50,
            ),
          );
        }

        // 🔗 TEK HAKİKAT KAYNAĞI CANLI CANLI DİNLENİYOR
        _startCanliProjeDinleyicisi();
      }
    } catch (e) {
      debugPrint("Tile Engine Hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 📡 DASHBOARD İLE %100 EŞ ZAMANLI CANLI DİNLEYİCİ
  void _startCanliProjeDinleyicisi() {
    _projectSubscription?.cancel();
    _projectSubscription = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.activeProjectDocId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return;

      var data = snapshot.data() as Map<String, dynamic>;
      double startM =
          LineCalculator.parseKmToMeters(data["startKm"] ?? "12+000.00");
      double kaziM = LineCalculator.parseKmToMeters(
          data["kaziKm"] ?? data["startKm"] ?? "12+000.00");
      double yataklamaM = LineCalculator.parseKmToMeters(
          data["yataklamaKm"] ?? data["startKm"] ?? "12+000.00");
      double montajM = LineCalculator.parseKmToMeters(
          data["montajKm"] ?? data["startKm"] ?? "12+000.00");
      double kapamaM = LineCalculator.parseKmToMeters(
          data["kapamaKm"] ?? data["startKm"] ?? "12+000.00");

      Set<Polyline> newPolylines = {};
      String primaryLineKey = _rawLineGeometries.keys.isNotEmpty
          ? _rawLineGeometries.keys.first
          : 'S2';

      if (_rawLineGeometries.containsKey(primaryLineKey)) {
        List<LatLng> basePoints = _rawLineGeometries[primaryLineKey]!;

        // 1. Kazı (Kırmızı / Kalınlık: 10)
        List<LatLng> kaziPts =
            LineCalculator.getSubPolyline(basePoints, startM, kaziM);
        if (kaziPts.isNotEmpty) {
          newPolylines.add(Polyline(
            polylineId: const PolylineId('phase_kazi'),
            points: kaziPts,
            color: const Color(0xFFE71D36),
            width: 10,
          ));
        }

        // 2. Çakıl Yataklama (Sarı / Kalınlık: 8)
        List<LatLng> yataklamaPts =
            LineCalculator.getSubPolyline(basePoints, startM, yataklamaM);
        if (yataklamaPts.isNotEmpty) {
          newPolylines.add(Polyline(
            polylineId: const PolylineId('phase_yataklama'),
            points: yataklamaPts,
            color: const Color(0xFFFF9F1C),
            width: 8,
          ));
        }

        // 3. Boru Montajı (Cyan-Yeşil / Kalınlık: 6)
        List<LatLng> montajPts =
            LineCalculator.getSubPolyline(basePoints, startM, montajM);
        if (montajPts.isNotEmpty) {
          newPolylines.add(Polyline(
            polylineId: const PolylineId('phase_montaj'),
            points: montajPts,
            color: const Color(0xFF2EC4B6),
            width: 6,
          ));
        }

        // 4. Geri Dolgu / Kapama (Mavi / Kalınlık: 4)
        List<LatLng> kapamaPts =
            LineCalculator.getSubPolyline(basePoints, startM, kapamaM);
        if (kapamaPts.isNotEmpty) {
          newPolylines.add(Polyline(
            polylineId: const PolylineId('phase_kapama'),
            points: kapamaPts,
            color: const Color(0xFF20A4F3),
            width: 4,
          ));
        }
      }

      // SANAT YAPILARI / MARKER CANLI SENKRONİZASYONU
      Set<Marker> newMarkers = {};
      List<dynamic> sanatYapitlari = data["sanatYapitlari"] ?? [];

      for (int i = 0; i < sanatYapitlari.length; i++) {
        var yapi = sanatYapitlari[i];
        double yapiMeters =
            LineCalculator.parseKmToMeters(yapi["km"]?.toString() ?? "0");

        if (_rawLineGeometries.containsKey(primaryLineKey)) {
          LatLng? point = LineCalculator.getPointAtDistance(
              _rawLineGeometries[primaryLineKey]!, yapiMeters);

          if (point != null) {
            bool isCompleted = yapi["durum"] == "Tamamlandı";
            double iconHue = isCompleted
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueOrange;

            newMarkers.add(Marker(
              markerId: MarkerId('sanat_$i'),
              position: point,
              icon: BitmapDescriptor.defaultMarkerWithHue(iconHue),
              infoWindow: InfoWindow(
                title: "${yapi["tip"]} (${yapi["durum"]})",
                snippet: "Km: ${yapi["km"]} | Beton: ${yapi["beton"]}",
              ),
            ));
          }
        }
      }

      if (mounted) {
        setState(() {
          _dinamikPolylineHatlari.clear();
          _dinamikPolylineHatlari.addAll(newPolylines);
          _sahaElemaniMarkers.clear();
          _sahaElemaniMarkers.addAll(newMarkers);
        });
      }
    });
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
              _isKmlVisible ? Icons.layers : Icons.layers_clear,
              color: _isKmlVisible ? Colors.greenAccent : Colors.redAccent,
            ),
            tooltip: "KML Katmanını Aç/Kapat",
            onPressed: () {
              setState(() => _isKmlVisible = !_isKmlVisible);
              if (_isKmlVisible) _loadGokboruEngine();
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
              target: LatLng(38.7205, 35.4826),
              zoom: 6,
            ),
            mapType: MapType.hybrid,
            markers: _sahaElemaniMarkers,
            polylines: _dinamikPolylineHatlari,
            tileOverlays: _isKmlVisible ? _tileOverlays : <TileOverlay>{},
            onMapCreated: (c) => _mapController = c,
            myLocationEnabled: _konumAktif,
            myLocationButtonEnabled: false,
          ),
          if (_isLoading)
            Positioned(
              top: 15,
              left: 15,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF9F1C),
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Gökbörü Tile Engine Çiziyor...",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
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
