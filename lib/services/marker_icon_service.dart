// lib/services/marker_icon_service.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerIconService {
  // İkon önbelleği (Performans için bir defa yüklenir)
  static final Map<String, BitmapDescriptor> _iconCache = {};

  /// Yapı Türü ve Durumuna Göre Doğru İkonu Getirir
  static Future<BitmapDescriptor> getIconForStructure({
    required String type,
    required String feature, // 'Çift Çıkışlı', 'Pompajlı' vb.
    required bool isCompleted,
  }) async {
    String cacheKey = "${type}_${feature}_$isCompleted";
    if (_iconCache.containsKey(cacheKey)) {
      return _iconCache[cacheKey]!;
    }

    BitmapDescriptor descriptor;

    // Tamamlanan İmalatlar İçin Yeşil Varsayılan/Özel Marker
    if (isCompleted) {
      descriptor =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      _iconCache[cacheKey] = descriptor;
      return descriptor;
    }

    // 🎯 YAPI TÜRLERİNE VE ALT TİPLERİNE GÖRE RENK/SİMGE ATAMASI
    String upperType = type.toUpperCase();
    String upperFeature = feature.toUpperCase();

    if (upperType.contains('HİDRANT') || upperType.contains('HIDRANT')) {
      if (upperFeature.contains('ÇİFT') || upperFeature.contains('CIFT')) {
        // Çift Çıkışlı Hidrant -> Mavi / Özel Mavi Simge
        descriptor =
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      } else {
        // Tek Çıkışlı Hidrant -> Sarı Simge
        descriptor =
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
      }
    } else if (upperType.contains('VANTUZ')) {
      // Vantuz (Hava Vanası) -> Turuncu Simge
      descriptor =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    } else if (upperType.contains('TAHLİYE') || upperType.contains('TAHLIYE')) {
      if (upperFeature.contains('POMPAJL')) {
        // Pompajlı Tahliye -> Mor Simge
        descriptor =
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      } else {
        // Cazibeli Tahliye -> Kırmızı Simge
        descriptor =
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      }
    } else if (upperType.contains('AYRIM') || upperType.contains('BRANŞMAN')) {
      // Ayrım Yapısı -> Camgöbeği (Cyan) Simge
      descriptor =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    } else {
      // Diğer Sanat Yapıları -> Gül Rengi Simge
      descriptor =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
    }

    _iconCache[cacheKey] = descriptor;
    return descriptor;
  }
}
