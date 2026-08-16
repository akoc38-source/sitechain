import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'kml_yonetim_sayfasi.dart';

class HaritaSayfasi extends StatefulWidget {
  const HaritaSayfasi({super.key});

  @override
  State<HaritaSayfasi> createState() => _HaritaSayfasiState();
}

class _HaritaSayfasiState extends State<HaritaSayfasi> {
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.hybrid;
  LatLng _initialPosition = const LatLng(38.7205, 35.4826); // Varsayılan merkez
  bool _olcumModu = false;
  final List<LatLng> _olcumNoktalari = [];
  double _toplamMesafeMetre = 0.0;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _mevcutKonumuAl();
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const KmlYonetimSayfasi(),
                ),
              );
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
