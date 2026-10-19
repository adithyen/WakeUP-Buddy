import 'package:flutter/material.dart';

class SavedPlace {
  final String id;
  final String label; // 'Home', 'Work', 'Gym', 'School', or custom label
  final String? customName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String iconType; // 'home', 'work', 'gym', 'school', 'star', 'location'
  final bool isSet;
  final DateTime updatedAt;

  const SavedPlace({
    required this.id,
    required this.label,
    this.customName,
    this.address,
    this.latitude,
    this.longitude,
    required this.iconType,
    this.isSet = false,
    required this.updatedAt,
  });

  IconData get iconData {
    switch (iconType.toLowerCase()) {
      case 'home':
        return Icons.home_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'gym':
        return Icons.fitness_center_rounded;
      case 'school':
      case 'university':
        return Icons.school_rounded;
      case 'star':
        return Icons.star_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  SavedPlace copyWith({
    String? id,
    String? label,
    String? customName,
    String? address,
    double? latitude,
    double? longitude,
    String? iconType,
    bool? isSet,
    DateTime? updatedAt,
  }) {
    return SavedPlace(
      id: id ?? this.id,
      label: label ?? this.label,
      customName: customName ?? this.customName,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      iconType: iconType ?? this.iconType,
      isSet: isSet ?? this.isSet,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'customName': customName,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'iconType': iconType,
        'isSet': isSet,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SavedPlace.fromJson(Map<String, dynamic> json) => SavedPlace(
        id: json['id'] as String,
        label: json['label'] as String,
        customName: json['customName'] as String?,
        address: json['address'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        iconType: json['iconType'] as String? ?? 'location',
        isSet: json['isSet'] as bool? ?? false,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
      );
}
