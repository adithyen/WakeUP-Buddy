class MapLayersConfig {
  final bool showTrafficFlow;
  final bool showRoadClosures;
  final bool showDelayBadges;
  final bool showIncidents;
  final String mapStyleType; // 'standard', 'dark', 'satellite', 'terrain'

  const MapLayersConfig({
    this.showTrafficFlow = true,
    this.showRoadClosures = true,
    this.showDelayBadges = true,
    this.showIncidents = true,
    this.mapStyleType = 'standard',
  });

  bool get isDarkMode => mapStyleType == 'dark';

  MapLayersConfig copyWith({
    bool? showTrafficFlow,
    bool? showRoadClosures,
    bool? showDelayBadges,
    bool? showIncidents,
    String? mapStyleType,
  }) {
    return MapLayersConfig(
      showTrafficFlow: showTrafficFlow ?? this.showTrafficFlow,
      showRoadClosures: showRoadClosures ?? this.showRoadClosures,
      showDelayBadges: showDelayBadges ?? this.showDelayBadges,
      showIncidents: showIncidents ?? this.showIncidents,
      mapStyleType: mapStyleType ?? this.mapStyleType,
    );
  }

  Map<String, dynamic> toJson() => {
        'showTrafficFlow': showTrafficFlow,
        'showRoadClosures': showRoadClosures,
        'showDelayBadges': showDelayBadges,
        'showIncidents': showIncidents,
        'mapStyleType': mapStyleType,
      };

  factory MapLayersConfig.fromJson(Map<String, dynamic> json) => MapLayersConfig(
        showTrafficFlow: json['showTrafficFlow'] as bool? ?? true,
        showRoadClosures: json['showRoadClosures'] as bool? ?? true,
        showDelayBadges: json['showDelayBadges'] as bool? ?? true,
        showIncidents: json['showIncidents'] as bool? ?? true,
        mapStyleType: json['mapStyleType'] as String? ?? 'standard',
      );
}
