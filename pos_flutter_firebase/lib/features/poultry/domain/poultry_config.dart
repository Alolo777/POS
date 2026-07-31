import 'poultry_section.dart';

class PoultryConfig {
  final List<PoultrySection> sections;
  final double tolerancePercent;
  final String? wholeProductId;

  const PoultryConfig({
    required this.sections,
    this.tolerancePercent = 5.0,
    this.wholeProductId,
  });

  Map<String, dynamic> toMap() => {
    'sections': sections.map((e) => e.toMap()).toList(),
    'tolerancePercent': tolerancePercent,
    if (wholeProductId != null) 'wholeProductId': wholeProductId,
  };

  factory PoultryConfig.fromMap(Map<String, dynamic> map) => PoultryConfig(
    sections: (map['sections'] as List<dynamic>?)
        ?.map((e) => PoultrySection.fromMap(e as Map<String, dynamic>))
        .toList() ?? const [],
    tolerancePercent: (map['tolerancePercent'] as num?)?.toDouble() ?? 5.0,
    wholeProductId: map['wholeProductId'] as String?,
  );

  double get sumDefaultPercents =>
      sections.fold(0.0, (sum, s) => sum + s.defaultPercent);
}
