// lib/models/pipe_line_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PipeLine {
  final String id;
  final String name;
  final String code;
  final String pipeType;
  final double totalKm;
  final double startKm;
  final double kaziKm;
  final double yataklamaKm;
  final double montajKm;
  final double kapamaKm;
  final List<Map<String, dynamic>> sanatYapitlari;

  PipeLine({
    required this.id,
    required this.name,
    required this.code,
    required this.pipeType,
    required this.totalKm,
    required this.startKm,
    required this.kaziKm,
    required this.yataklamaKm,
    required this.montajKm,
    required this.kapamaKm,
    required this.sanatYapitlari,
  });

  // İlerleme Yüzdesi Hesaplayıcı (Ağırlıklı Montaj)
  double get progressPercentage {
    if (totalKm <= 0) return 0.0;
    double progress = ((montajKm - startKm) / (totalKm - startKm)) * 100;
    return progress.clamp(0.0, 100.0);
  }

  factory PipeLine.fromMap(Map<String, dynamic> map, String docId) {
    return PipeLine(
      id: docId,
      name: map['name'] ?? 'İsimsiz Hat',
      code: map['code'] ?? 'S2-0',
      pipeType: map['pipeType'] ?? 'C1000 CTP',
      totalKm: double.tryParse(map['totalKm']?.toString() ?? '0') ?? 0.0,
      startKm: double.tryParse(map['startKm']?.toString() ?? '0') ?? 0.0,
      kaziKm: double.tryParse(map['kaziKm']?.toString() ?? '0') ?? 0.0,
      yataklamaKm:
          double.tryParse(map['yataklamaKm']?.toString() ?? '0') ?? 0.0,
      montajKm: double.tryParse(map['montajKm']?.toString() ?? '0') ?? 0.0,
      kapamaKm: double.tryParse(map['kapamaKm']?.toString() ?? '0') ?? 0.0,
      sanatYapitlari:
          List<Map<String, dynamic>>.from(map['sanatYapitlari'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'pipeType': pipeType,
      'totalKm': totalKm,
      'startKm': startKm,
      'kaziKm': kaziKm,
      'yataklamaKm': yataklamaKm,
      'montajKm': montajKm,
      'kapamaKm': kapamaKm,
      'sanatYapitlari': sanatYapitlari,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
