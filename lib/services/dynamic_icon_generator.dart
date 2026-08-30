// lib/services/dynamic_icon_generator.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DynamicIconGenerator {
  static final Map<String, BitmapDescriptor> _iconCache = {};

  /// Kod ile Tam Otomatik Vektörel Sembol ve Çap Rozeti Çizer (KÜÇÜLTÜLMÜŞ BOYUT)
  static Future<BitmapDescriptor> createAutoIcon({
    required String type,
    required String feature,
    required String diameter,
    required bool isCompleted,
  }) async {
    String cacheKey = "${type}_${feature}_${diameter}_$isCompleted";
    if (_iconCache.containsKey(cacheKey)) {
      return _iconCache[cacheKey]!;
    }

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 56.0; // 🎯 Yarı yarıya küçültüldü (Eski: 110.0)

    // 🎨 RENGİ VE ŞEKLİ DİNAMİK BELİRLE
    Color mainColor = _getColorForType(type, feature, isCompleted);
    IconData iconData = _getIconDataForType(type, feature);

    // 1. DIŞ GÖLGE KATMANI
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawCircle(
        const Offset(size / 2, size / 2 + 1.5), 19.0, shadowPaint);

    // 2. ANA GÖVDE DAİRESİ
    final Paint circlePaint = Paint()
      ..color = mainColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), 18.0, circlePaint);

    // 3. BEYAZ KENARLIK (BORDER)
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(const Offset(size / 2, size / 2), 18.0, borderPaint);

    // 4. İÇ SEMBOL İKONU (Orantılı Ölçek)
    TextPainter iconPainter = TextPainter(textDirection: TextDirection.ltr);
    iconPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 18.0, // Orantılı küçültüldü
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        (size - iconPainter.width) / 2,
        (size - iconPainter.height) / 2 - (diameter.isNotEmpty ? 3 : 0),
      ),
    );

    // 5. ÇAP ROZETİ (Örn: DN80)
    if (diameter.isNotEmpty) {
      TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: " $diameter ",
        style: const TextStyle(
          fontSize: 8.0, // Orantılı küçültüldü
          fontWeight: FontWeight.bold,
          color: Colors.white,
          backgroundColor: Colors.black87,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset((size - textPainter.width) / 2, size / 2 + 6),
      );
    }

    // GÖRSELİ MARKER BITMAP'İNE DÖNÜŞTÜR
    final ui.Image img = await pictureRecorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    final ByteData? byteData =
        await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) return BitmapDescriptor.defaultMarker;

    BitmapDescriptor descriptor =
        BitmapDescriptor.bytes(byteData.buffer.asUint8List());
    _iconCache[cacheKey] = descriptor;
    return descriptor;
  }

  static Color _getColorForType(String type, String feature, bool isCompleted) {
    if (isCompleted) return Colors.green.shade600;

    String upperType = type.toUpperCase();
    String upperFeature = feature.toUpperCase();

    if (upperType.contains('HİDRANT') || upperType.contains('HIDRANT')) {
      return upperFeature.contains('ÇİFT') || upperFeature.contains('CIFT')
          ? Colors.blue.shade700
          : Colors.amber.shade700;
    } else if (upperType.contains('VANTUZ')) {
      return Colors.deepOrange.shade600;
    } else if (upperType.contains('TAHLİYE') || upperType.contains('TAHLIYE')) {
      return upperFeature.contains('POMPAJL')
          ? Colors.purple.shade700
          : Colors.red.shade700;
    } else if (upperType.contains('AYRIM') || upperType.contains('BRANŞMAN')) {
      return Colors.teal.shade700;
    }

    return Colors.indigo.shade600;
  }

  static IconData _getIconDataForType(String type, String feature) {
    String upperType = type.toUpperCase();
    String upperFeature = feature.toUpperCase();

    if (upperType.contains('HİDRANT') || upperType.contains('HIDRANT')) {
      return upperFeature.contains('ÇİFT') || upperFeature.contains('CIFT')
          ? Icons.water_drop
          : Icons.water_damage;
    } else if (upperType.contains('VANTUZ')) {
      return Icons.air;
    } else if (upperType.contains('TAHLİYE') || upperType.contains('TAHLIYE')) {
      return upperFeature.contains('POMPAJL') ? Icons.cyclone : Icons.south;
    } else if (upperType.contains('AYRIM') || upperType.contains('BRANŞMAN')) {
      return Icons.alt_route;
    }

    return Icons.location_on;
  }
}
