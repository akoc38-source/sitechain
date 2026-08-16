import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:archive/archive.dart';
import 'kml_yonetim_sayfasi.dart';

class HaritaSayfasi extends StatefulWidget {
  const HaritaSayfasi({super.key});

  @override
  State<HaritaSayfasi> createState() => _HaritaSayfasiState();
}

class _HaritaSayfasiState extends State<HaritaSayfasi> {
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.hybrid;
  LatLng _initialPosition = const LatLng(38.7205, 35.4826);
  bool _olcumModu = false;
  final List<LatLng> _olcumNoktalari = [];
  double _toplamMesafeMetre = 0.0;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _kmlYukleniyor = false;

  @override
  void initState() {
    super.initState();
    _mevcutKonumuAl();
    _kmlKatmanlariniYukle();
  }

  Future<void> _mevcutKonumuAl() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    LatLng pos = LatLng(position.latitude, position.longitude);

    setState(() {
      _initialPosition = pos;
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(pos, 16),
    );
  }

  Future<void> _kmlKatmanlariniYukle() async {
    setState(() => _kmlYukleniyor = true);

    try {
      var snapshot =
          await FirebaseFirestore.instance.collection('kml_katmanlari').get();
      Set<Polyline> yeniPolylines = {};
      Set<Marker> yeniMarkers = {};
      int lineIdCounter = 0;
      int markerIdCounter = 0;

      for (var doc in snapshot.docs) {
        var data = doc.data();
        String? url = data['url'];
        if (url == null || url.isEmpty) continue;

        String kmlContent = "";

        var response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          if (url.toLowerCase().contains('.kmz')) {
            var archive = ZipDecoder().decodeBytes(response.bodyBytes);
            for (var file in archive) {
              if (file.name.endsWith('.kml')) {
                kmlContent = String.fromCharCodes(file.content as List<int>);
                break;
              }
            }
          } else {
            kmlContent = response.body;
          }

          if (kmlContent.isNotEmpty) {
            var document = xml.XmlDocument.parse(kmlContent);

            // Coordinates parse - LineString
            var lineStringElements = document.findAllElements('LineString');
            for (var lineNode in lineStringElements) {
              var coordNode = lineNode.findElements('coordinates').firstOrNull;
              if (coordNode != null) {
                List<LatLng> points = _parseCoordinates(coordNode.innerText);
                if (points.isNotEmpty) {
                  lineIdCounter++;
                  yeniPolylines.add(
                    Polyline(
                      polylineId: PolylineId('kml_line_$lineIdCounter'),
                      points: points,
                      color: const Color(0xFF00E676),
                      width: 5,
                    ),
                  );
                }
              }
            }

            // Coordinates parse - Point
            var pointElements = document.findAllElements('Placemark');
            for (var placemark in pointElements) {
              var pointNode = placemark.findElements('Point').firstOrNull;
              var nameNode = placemark.findElements('name').firstOrNull;

              if (pointNode != null) {
                var coordNode =
                    pointNode.findElements('coordinates').firstOrNull;
                if (coordNode != null) {
                  List<LatLng> points = _parseCoordinates(coordNode.innerText);
                  if (points.isNotEmpty) {
                    markerIdCounter++;
                    yeniMarkers.add(
                      Marker(
                        markerId: MarkerId('kml_marker_$markerIdCounter'),
                        position: points.first,
                        infoWindow: InfoWindow(
                          title: nameNode?.innerText ?? "KML Noktası",
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueCyan,
                        ),
                      ),
                    );
                  }
                }
              }
            }
          }
        }
      }

      setState(() {
        _polylines.addAll(yeniPolylines);
        _markers.addAll(yeniMarkers);
      });
    } catch (e) {
      debugPrint("KML Parse Hatası: $e");
    } finally {
      if (mounted) {
        setState(() => _kmlYukleniyor = false);
      }
    }
  }

  List<LatLng> _parseCoordinates(String coordString) {
    List<LatLng> points = [];
    var lines = coordString.trim().split(RegExp(r'\s+'));

    for (var line in lines) {
      var parts = line.split(',');
      if (parts.length >= 2) {
        try {
          double lon = double.parse(parts[0].trim());
          double lat = double.parse(parts[1].trim());
          points.add(LatLng(lat, lon));
        } catch (_) {}
      }
    }
    return points;
  }

  void _noktaEkle(LatLng point) {
    if (!_olcumModu) return;

    setState(() {
      _olcumNoktalari.add(point);
      _mesafeHesapla();
    });
  }

  void _mesafeHesapla() {
    if (_olcumNoktalari.length < 2) {
      _toplamMesafeMetre = 0.0;
      return;
    }

    double mesafe = 0.0;
    for (int i = 0; i < _olcumNoktalari.length - 1; i++) {
      mesafe += Geolocator.distanceBetween(
        _olcumNoktalari[i].latitude,
        _olcumNoktalari[i].longitude,
        _olcumNoktalari[i + 1].latitude,
        _olcumNoktalari[i + 1].longitude,
      );
    }

    setState(() {
      _toplamMesafeMetre = mesafe;
    });
  }

  void _olcumTemizle() {
    setState(() {
      _olcumNoktalari.clear();
      _toplamMesafeMetre = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    Set<Polyline> polylines = Set.from(_polylines);
    if (_olcumNoktalari.length > 1) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('olcum_hatti'),
          points: _olcumNoktalari,
          color: const Color(0xFFFF9F1C),
          width: 4,
        ),
      );
    }

    Set<Marker> markers = Set.from(_markers);
    for (int i = 0; i < _olcumNoktalari.length; i++) {
      markers.add(
        Marker(
          markerId: MarkerId('olcum_$i'),
          position: _olcumNoktalari[i],
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: 'Nokta ${i + 1}'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121824),
      appBar: AppBar(
        title: const Text("Canlı Saha Haritası"),
        backgroundColor: const Color(0xFF1E2638),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _currentMapType == MapType.hybrid ? Icons.map : Icons.satellite,
              color: Colors.white,
            ),
            tooltip: "Harita Tipi Değiştir",
            onPressed: () {
              setState(() {
                _currentMapType = _currentMapType == MapType.hybrid
                    ? MapType.normal
                    : MapType.hybrid;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.layers, color: Color(0xFFFF9F1C)),
            tooltip: "KML Katmanları",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const KmlYonetimSayfasi(),
                ),
              );
              _kmlKatmanlariniYukle();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 15,
            ),
            mapType: _currentMapType,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: markers,
            polylines: polylines,
            onMapCreated: (controller) => _mapController = controller,
            onTap: _olcumModu ? _noktaEkle : null,
          ),
          if (_kmlYukleniyor)
            Positioned(
              top: 15,
              left: 15,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2638).withValues(alpha: 0.9),
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
                    SizedBox(width: 8),
                    Text(
                      "KML Katmanları Çiziliyor...",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          if (_olcumModu)
            Positioned(
              top: 15,
              left: 15,
              right: 15,
              child: Card(
                color: const Color(0xFF1E2638).withValues(alpha: 0.95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Saha Ölçüm Modu",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            "${_toplamMesafeMetre >= 1000 ? (_toplamMesafeMetre / 1000).toStringAsFixed(2) : _toplamMesafeMetre.toStringAsFixed(1)} ${_toplamMesafeMetre >= 1000 ? 'km' : 'm'}",
                            style: const TextStyle(
                              color: Color(0xFFFF9F1C),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon:
                                const Icon(Icons.refresh, color: Colors.white),
                            onPressed: _olcumTemizle,
                            tooltip: "Sıfırla",
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.redAccent),
                            onPressed: () {
                              setState(() {
                                _olcumModu = false;
                                _olcumTemizle();
                              });
                            },
                            tooltip: "Ölçüm Modundan Çık",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 25,
            right: 15,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'olcum_btn',
                  backgroundColor: _olcumModu
                      ? const Color(0xFFFF9F1C)
                      : const Color(0xFF1E2638),
                  foregroundColor: _olcumModu ? Colors.black : Colors.white,
                  onPressed: () {
                    setState(() {
                      _olcumModu = !_olcumModu;
                      if (!_olcumModu) _olcumTemizle();
                    });
                  },
                  child: const Icon(Icons.straighten),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'konum_btn',
                  backgroundColor: const Color(0xFF1E2638),
                  foregroundColor: Colors.white,
                  onPressed: _mevcutKonumuAl,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
