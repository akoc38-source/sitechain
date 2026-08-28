// lib/models/project_model.dart

import 'pipe_line_model.dart';

enum ProjectType { sulamaBoru, yol, icmeSuyu, elektrik }

class ProjectTypeConfig {
  static Map<ProjectType, Map<String, dynamic>> configs = {
    ProjectType.sulamaBoru: {
      'title': 'Sulama Boru Hattı',
      'icon': '🌊',
      'unit': 'km',
      'stages': [
        'Kazı Aşaması',
        'Çakıl Yataklama',
        'Boru Montajı',
        'Geri Dolgu / Kapama'
      ]
    },
    ProjectType.yol: {
      'title': 'Yol & Karayolu',
      'icon': '🛣️',
      'unit': 'km',
      'stages': [
        'Kazı / Yarma',
        'Dolgu / Sıkıştırma',
        'Alt Temel & Temel',
        'Asfalt / Kaplama'
      ]
    },
    ProjectType.icmeSuyu: {
      'title': 'İçme Suyu Şebekesi',
      'icon': '🚰',
      'unit': 'km',
      'stages': [
        'Hat Kazısı',
        'Boru / Yataklama',
        'Vana Odaları',
        'Test & Kapatma'
      ]
    },
    ProjectType.elektrik: {
      'title': 'Elektrik & Enerji Hatları',
      'icon': '⚡',
      'unit': 'km',
      'stages': [
        'Kanal Kazısı',
        'Kablo / Boru',
        'Direk / Trafo',
        'Enerjilendirme'
      ]
    },
  };
}

class ProjectModel {
  final String id;
  final String name;
  final String code;
  final String joinCode;
  final String city;
  final String district;
  final ProjectType projectType;
  final String pipeType;
  final double totalKm;
  final double startKm;
  final double kaziKm;
  final double yataklamaKm;
  final double montajKm;
  final double kapamaKm;
  final List<PipeLine> lines; // 🚀 Çoklu Hat Desteği (S2, S2-1, S2-2...)

  ProjectModel({
    required this.id,
    required this.name,
    required this.code,
    required this.joinCode,
    required this.city,
    required this.district,
    required this.projectType,
    required this.pipeType,
    required this.totalKm,
    required this.startKm,
    required this.kaziKm,
    required this.yataklamaKm,
    required this.montajKm,
    required this.kapamaKm,
    this.lines = const [],
  });

  // 📊 Toplam Şebeke Uzunluğu (Tüm Hatların Uzunluk Toplamı)
  double get totalNetworkKm {
    if (lines.isEmpty) return totalKm;
    return lines.fold(0.0, (sum, line) => sum + (line.totalKm - line.startKm));
  }

  // 📈 Proje Geneli Ağırlıklı İlerleme Yüzdesi
  double get overallProgressPercentage {
    if (lines.isEmpty) {
      if (totalKm <= 0) return 0.0;
      return (((montajKm - startKm) / (totalKm - startKm)) * 100)
          .clamp(0.0, 100.0);
    }

    double totalLength = totalNetworkKm;
    if (totalLength <= 0) return 0.0;

    double completedLength = lines.fold(0.0, (sum, line) {
      double lineDone = (line.montajKm - line.startKm)
          .clamp(0.0, line.totalKm - line.startKm);
      return sum + lineDone;
    });

    return ((completedLength / totalLength) * 100).clamp(0.0, 100.0);
  }

  factory ProjectModel.fromMap(Map<String, dynamic> map, String docId,
      {List<PipeLine> lines = const []}) {
    String typeStr = map['projectType'] ?? 'sulamaBoru';
    ProjectType pType = ProjectType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => ProjectType.sulamaBoru,
    );

    return ProjectModel(
      id: docId,
      name: map['name'] ?? 'İsimsiz Proje',
      code: map['code'] ?? 'AGS',
      joinCode: map['joinCode'] ?? 'PRJ-1001',
      city: map['city'] ?? '',
      district: map['district'] ?? '',
      projectType: pType,
      pipeType: map['pipeType'] ?? 'C1000 CTP',
      totalKm: double.tryParse(map['totalKm']?.toString() ?? '0') ?? 0.0,
      startKm: double.tryParse(map['startKm']?.toString() ?? '0') ?? 0.0,
      kaziKm: double.tryParse(map['kaziKm']?.toString() ?? '0') ?? 0.0,
      yataklamaKm:
          double.tryParse(map['yataklamaKm']?.toString() ?? '0') ?? 0.0,
      montajKm: double.tryParse(map['montajKm']?.toString() ?? '0') ?? 0.0,
      kapamaKm: double.tryParse(map['kapamaKm']?.toString() ?? '0') ?? 0.0,
      lines: lines,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'joinCode': joinCode,
      'city': city,
      'district': district,
      'projectType': projectType.name,
      'pipeType': pipeType,
      'totalKm': totalKm,
      'startKm': startKm,
      'kaziKm': kaziKm,
      'yataklamaKm': yataklamaKm,
      'montajKm': montajKm,
      'kapamaKm': kapamaKm,
    };
  }
}
