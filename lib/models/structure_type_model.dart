// lib/models/structure_type_model.dart

class StructureTypeRule {
  final String category; // 'Piping', 'Electrical', 'Civil', 'Railway'
  final String standardName; // 'Air Release Valve'
  final List<String> keywords; // ['VANTUZ', 'AIR VALVE', 'VENTIL', 'HV']
  final String markerColor; // Hex renk kodu
  final String iconAsset; // İkon simgesi

  StructureTypeRule({
    required this.category,
    required this.standardName,
    required this.keywords,
    required this.markerColor,
    required this.iconAsset,
  });

  bool matches(String text) {
    String upper = text.toUpperCase();
    return keywords.any((kw) => upper.contains(kw.toUpperCase()));
  }
}
