// lib/models/daily_log_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DailyLogModel {
  final String id;
  final String lineCode; // Örn: "S2-1", "S2-20"
  final DateTime date;
  final String personnelName;

  // Kazı Aşaması
  final String kaziStartKm;
  final String kaziEndKm;
  final double kaziMeters;

  // Çakıl Yataklama Aşaması
  final String yataklamaStartKm;
  final String yataklamaEndKm;
  final double yataklamaMeters;

  // Boru Montajı Aşaması
  final String montajStartKm;
  final String montajEndKm;
  final double montajMeters;

  // Geri Dolgu / Kapama Aşaması
  final String kapamaStartKm;
  final String kapamaEndKm;
  final double kapamaMeters;

  // Lojistik & Malzeme
  final int cakilSefer;
  final double betonM3;
  final String note;

  DailyLogModel({
    required this.id,
    required this.lineCode,
    required this.date,
    required this.personnelName,
    required this.kaziStartKm,
    required this.kaziEndKm,
    required this.kaziMeters,
    required this.yataklamaStartKm,
    required this.yataklamaEndKm,
    required this.yataklamaMeters,
    required this.montajStartKm,
    required this.montajEndKm,
    required this.montajMeters,
    required this.kapamaStartKm,
    required this.kapamaEndKm,
    required this.kapamaMeters,
    required this.cakilSefer,
    required this.betonM3,
    this.note = "",
  });

  factory DailyLogModel.fromMap(Map<String, dynamic> map, String docId) {
    return DailyLogModel(
      id: docId,
      lineCode: map['lineCode'] ?? 'S2-1',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      personnelName: map['personnelName'] ?? 'Saha Personeli',
      kaziStartKm: map['kaziStartKm'] ?? '0+000.00',
      kaziEndKm: map['kaziEndKm'] ?? '0+000.00',
      kaziMeters: (map['kaziMeters'] as num?)?.toDouble() ?? 0.0,
      yataklamaStartKm: map['yataklamaStartKm'] ?? '0+000.00',
      yataklamaEndKm: map['yataklamaEndKm'] ?? '0+000.00',
      yataklamaMeters: (map['yataklamaMeters'] as num?)?.toDouble() ?? 0.0,
      montajStartKm: map['montajStartKm'] ?? '0+000.00',
      montajEndKm: map['montajEndKm'] ?? '0+000.00',
      montajMeters: (map['montajMeters'] as num?)?.toDouble() ?? 0.0,
      kapamaStartKm: map['kapamaStartKm'] ?? '0+000.00',
      kapamaEndKm: map['kapamaEndKm'] ?? '0+000.00',
      kapamaMeters: (map['kapamaMeters'] as num?)?.toDouble() ?? 0.0,
      cakilSefer: (map['cakilSefer'] as num?)?.toInt() ?? 0,
      betonM3: (map['betonM3'] as num?)?.toDouble() ?? 0.0,
      note: map['note'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lineCode': lineCode,
      'date': Timestamp.fromDate(date),
      'personnelName': personnelName,
      'kaziStartKm': kaziStartKm,
      'kaziEndKm': kaziEndKm,
      'kaziMeters': kaziMeters,
      'yataklamaStartKm': yataklamaStartKm,
      'yataklamaEndKm': yataklamaEndKm,
      'yataklamaMeters': yataklamaMeters,
      'montajStartKm': montajStartKm,
      'montajEndKm': montajEndKm,
      'montajMeters': montajMeters,
      'kapamaStartKm': kapamaStartKm,
      'kapamaEndKm': kapamaEndKm,
      'kapamaMeters': kapamaMeters,
      'cakilSefer': cakilSefer,
      'betonM3': betonM3,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
