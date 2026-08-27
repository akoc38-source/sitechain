import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LineCalculator {
  // "16+300.00", "16+300" veya "16300" formatlarını metreye çevirir
  static double parseKmToMeters(String input) {
    String clean = input.trim().replaceAll(' ', '');
    if (clean.contains('+')) {
      List<String> parts = clean.split('+');
      double km = double.tryParse(parts[0]) ?? 0;
      double m = double.tryParse(parts[1]) ?? 0;
      return (km * 1000) + m;
    }
    return double.tryParse(clean) ?? 0;
  }

  // Ham KML çizgi noktalarının toplam metrajını hesaplar
  static double getLineTotalDistance(List<LatLng> points) {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += Geolocator.distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return total;
  }

  // Belirli bir metredeki (Örn: 3250m) LatLng koordinatını bulur (Vantuz/Vana için)
  static LatLng? getPointAtDistance(List<LatLng> points, double targetMeters) {
    double accumulated = 0;
    for (int i = 0; i < points.length - 1; i++) {
      double segDist = Geolocator.distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );

      if (accumulated + segDist >= targetMeters) {
        double ratio = (targetMeters - accumulated) / segDist;
        double lat = points[i].latitude +
            (points[i + 1].latitude - points[i].latitude) * ratio;
        double lng = points[i].longitude +
            (points[i + 1].longitude - points[i].longitude) * ratio;
        return LatLng(lat, lng);
      }
      accumulated += segDist;
    }
    return points.isNotEmpty ? points.last : null;
  }

  // Belirli iki metre arasındaki (Örn: 0m - 5500m) alt çizgi parçalarını çıkarır
  static List<LatLng> getSubPolyline(
      List<LatLng> points, double startM, double endM) {
    List<LatLng> subPoints = [];
    double accumulated = 0;

    for (int i = 0; i < points.length - 1; i++) {
      double p1Lat = points[i].latitude;
      double p1Lng = points[i].longitude;
      double p2Lat = points[i + 1].latitude;
      double p2Lng = points[i + 1].longitude;

      double segDist = Geolocator.distanceBetween(p1Lat, p1Lng, p2Lat, p2Lng);
      double segStart = accumulated;
      double segEnd = accumulated + segDist;

      if (segEnd >= startM && segStart <= endM) {
        if (subPoints.isEmpty && startM > segStart) {
          double r = (startM - segStart) / segDist;
          subPoints.add(
              LatLng(p1Lat + (p2Lat - p1Lat) * r, p1Lng + (p2Lng - p1Lng) * r));
        } else if (subPoints.isEmpty) {
          subPoints.add(points[i]);
        }

        if (endM < segEnd) {
          double r = (endM - segStart) / segDist;
          subPoints.add(
              LatLng(p1Lat + (p2Lat - p1Lat) * r, p1Lng + (p2Lng - p1Lng) * r));
          break;
        } else {
          subPoints.add(points[i + 1]);
        }
      }
      accumulated += segDist;
    }
    return subPoints;
  }
}
