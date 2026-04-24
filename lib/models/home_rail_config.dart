class HomeRailConfig {
  final String id;
  final String label;
  final bool visible;

  const HomeRailConfig({
    required this.id,
    required this.label,
    this.visible = true,
  });

  HomeRailConfig copyWith({bool? visible, String? label}) =>
      HomeRailConfig(
        id: id, 
        label: label ?? this.label, 
        visible: visible ?? this.visible,
      );

  Map<String, dynamic> toJson() => {
    'id': id, 
    'label': label, 
    'visible': visible,
  };

  factory HomeRailConfig.fromJson(Map<String, dynamic> json) => HomeRailConfig(
        id: json['id'] as String,
        label: json['label'] as String,
        visible: (json['visible'] as bool?) ?? true,
      );
}
