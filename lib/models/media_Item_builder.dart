// ignore_for_file: file_names

import 'package:audio_service/audio_service.dart';
import '../models/thumbnail.dart';

class MediaItemBuilder {
  static MediaItem fromJson(dynamic json, {String? url}) {
    String? artistName;
    if (json['artists'] is List) {
      try {
        artistName = (json['artists'] as List)
            .map((e) => e is Map ? e['name'] : null)
            .whereType<Object>()
            .toList()
            .join(', ')
            .toString();
      } catch (_) {
        artistName = null;
      }
    }

    Map? album;
    if (json['album'] is Map) {
      if (json['album']['id'] != null) {
        album = json['album'] as Map;
      }
    }

    // Defensive thumbnail handling: a stored favorite/local song may lack a
    // thumbnail (e.g. artUri was null when it was saved). Never let one bad
    // entry crash the whole list (which made favorites unplayable).
    String? thumbUrl;
    final thumbnails = json['thumbnails'];
    if (thumbnails is List && thumbnails.isNotEmpty) {
      final first = thumbnails[0];
      final raw = first is Map ? first['url']?.toString() : null;
      if (raw != null && raw.isNotEmpty && raw != 'null') thumbUrl = raw;
    }

    return MediaItem(
        id: json["videoId"] ?? json["id"] ?? '',
        title: json["title"] ?? '',
        duration: (json['duration'] is int)
            ? Duration(seconds: json['duration'] as int)
            : toDuration(json['length']),
        album: album != null ? album['name'] : null,
        artist: artistName,
        artUri: thumbUrl != null ? Uri.parse(Thumbnail(thumbUrl).high) : null,
        extras: {
          'url': json['url'] ?? url,
          'length': json['length'],
          'album': album,
          'artists': json['artists'],
          'date': json['date'],
          'trackDetails': json['trackDetails'],
          'year': json['year']
        });
  }

  static Duration? toDuration(String? time) {
    if (time == null || time.isEmpty) {
      return null;
    }

    try {
      int sec = 0;
      final splitted = time.split(":");
      if (splitted.length == 3) {
        sec += int.parse(splitted[0]) * 3600 +
            int.parse(splitted[1]) * 60 +
            int.parse(splitted[2]);
      } else if (splitted.length == 2) {
        sec += int.parse(splitted[0]) * 60 + int.parse(splitted[1]);
      } else if (splitted.length == 1) {
        sec += int.parse(splitted[0]);
      }
      return Duration(seconds: sec);
    } catch (_) {
      // Malformed duration (e.g. legacy/corrupt entry) must never abort the
      // library load.
      return null;
    }
  }

  static Map<String, dynamic> toJson(MediaItem mediaItem) => {
        "videoId": mediaItem.id,
        "title": mediaItem.title,
        'album': mediaItem.extras?['album'],
        'artists': mediaItem.extras?['artists'],
        'length': mediaItem.extras?['length'],
        'duration': mediaItem.duration?.inSeconds,
        'date': mediaItem.extras?['date'],
        // Only persist a thumbnail when there really is one, otherwise a null
        // artUri was stored as the literal string "null" and broke reloads.
        'thumbnails': mediaItem.artUri != null
            ? [
                {'url': mediaItem.artUri.toString()}
              ]
            : <Map<String, dynamic>>[],
        'url': mediaItem.extras?['url'],
        'trackDetails': mediaItem.extras?['trackDetails'],
        'year': mediaItem.extras?['year']
      };
}
