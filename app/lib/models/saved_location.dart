class SavedLocation {
  SavedLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.countryCode,
    this.admin1,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? countryCode;
  final String? admin1;

  String get subtitle {
    final parts = <String>[];
    if (admin1 != null && admin1!.isNotEmpty) parts.add(admin1!);
    if (countryCode != null && countryCode!.isNotEmpty) {
      parts.add(countryCode!);
    }
    return parts.isEmpty ? '${latitude.toStringAsFixed(2)}, ${longitude.toStringAsFixed(2)}' : parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'countryCode': countryCode,
        'admin1': admin1,
      };

  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    return SavedLocation(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      countryCode: json['countryCode'] as String?,
      admin1: json['admin1'] as String?,
    );
  }
}
