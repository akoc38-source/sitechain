// lib/utils/global_structure_dictionary.dart

import '../models/structure_type_model.dart';

class GlobalStructureDictionary {
  static final List<StructureTypeRule> defaultRules = [
    // 💧 BORU HATTI & SULAMA / SU
    StructureTypeRule(
      category: 'Piping',
      standardName: 'Vantuz (Air Valve)',
      keywords: [
        'VANTUZ',
        'HAVA VANASI',
        'AIR VALVE',
        'AIR RELEASE',
        'HV',
        'ARV'
      ],
      markerColor: '#FF9F1C',
      iconAsset: 'assets/icons/air_valve.png',
    ),
    StructureTypeRule(
      category: 'Piping',
      standardName: 'Tahliye Vanası (Blow-Off / Drain)',
      keywords: [
        'TAHLİYE',
        'TAHLIYE',
        'DRAIN',
        'BLOW OFF',
        'WASHOUT',
        'TV',
        'WOV'
      ],
      markerColor: '#E71D36',
      iconAsset: 'assets/icons/drain_valve.png',
    ),
    StructureTypeRule(
      category: 'Piping',
      standardName: 'Hidrant (Hydrant / Water Outlet)',
      keywords: ['HİDRANT', 'HIDRANT', 'HYDRANT', 'SAV', 'SU ALMA', 'HYD'],
      markerColor: '#2EC4B6',
      iconAsset: 'assets/icons/hydrant.png',
    ),
    StructureTypeRule(
      category: 'Piping',
      standardName: 'Ayrım Yapısı (Junction / Tee)',
      keywords: ['AYRIM', 'BRANŞMAN', 'BRANSMAN', 'JUNCTION', 'TEE', 'BRANCH'],
      markerColor: '#9C27B0',
      iconAsset: 'assets/icons/junction.png',
    ),
    StructureTypeRule(
      category: 'Piping',
      standardName: 'Baca / Rögar (Manhole)',
      keywords: ['BACA', 'RÖGAR', 'ROGAR', 'MANHOLE', 'MH', 'CHAMBER'],
      markerColor: '#607D8B',
      iconAsset: 'assets/icons/manhole.png',
    ),

    // ⚡ ELEKTRİK & TELEKOM
    StructureTypeRule(
      category: 'Electrical',
      standardName: 'Trafo (Transformer)',
      keywords: ['TRAFO', 'TRANSFORMER', 'SUBSTATION', 'TR'],
      markerColor: '#FFEB3B',
      iconAsset: 'assets/icons/transformer.png',
    ),
    StructureTypeRule(
      category: 'Electrical',
      standardName: 'Direk (Pole / Tower)',
      keywords: ['DİREK', 'DIREK', 'POLE', 'TOWER', 'MAST'],
      markerColor: '#795548',
      iconAsset: 'assets/icons/pole.png',
    ),

    // 🛣️ YOL & RAYLI SİSTEM
    StructureTypeRule(
      category: 'Civil',
      standardName: 'Menfez (Culvert)',
      keywords: ['MENFEZ', 'CULVERT', 'MNF', 'PIPE CULVERT'],
      markerColor: '#4CAF50',
      iconAsset: 'assets/icons/culvert.png',
    ),
  ];

  /// Metinden Tipi Otomatik Algılayan Fonksiyon
  static String detectType(String rawText,
      {List<StructureTypeRule>? customRules}) {
    List<StructureTypeRule> rulesToUse = customRules ?? defaultRules;

    for (var rule in rulesToUse) {
      if (rule.matches(rawText)) {
        return rule.standardName;
      }
    }
    return 'Sanat Yapısı (General Structure)';
  }
}
