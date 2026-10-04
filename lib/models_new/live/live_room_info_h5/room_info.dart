class RoomInfo {
  int? uid;
  String? title;
  String? cover;
  String? appBackground;
  int? areaId;
  int? parentAreaId;

  RoomInfo({
    this.uid,
    this.title,
    this.cover,
    this.appBackground,
    this.areaId,
    this.parentAreaId,
  });

  factory RoomInfo.fromJson(Map<String, dynamic> json) => RoomInfo(
    uid: json['uid'] as int?,
    title: json['title'] as String?,
    cover: json['cover'] as String?,
    appBackground: customLiveBackground(json['app_background']),
    areaId: json['area_id'] as int?,
    parentAreaId: json['parent_area_id'] as int?,
  );
}

/// Empty/mobile default skins are omitted. Never substitute the web cover or
/// background: those are unrelated to the mobile room's custom skin.
String? customLiveBackground(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasAuthority || !['http', 'https'].contains(uri.scheme)) return null;
  const defaultFiles = {'785922a49980e1aa3239249c8360909488940d7d.jpg'};
  if (defaultFiles.contains(uri.pathSegments.lastOrNull)) return null;
  return uri.replace(scheme: 'https').toString();
}
