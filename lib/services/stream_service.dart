import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

bool get isHarmonyOS {
  try {
    return GetPlatform.isWeb == false &&
        !GetPlatform.isAndroid &&
        !GetPlatform.isIOS &&
        !GetPlatform.isMacOS &&
        !GetPlatform.isWindows &&
        !GetPlatform.isLinux;
  } catch (_) {
    return false;
  }
}

class StreamProvider {
  final bool playable;
  final List<Audio>? audioFormats;
  final String statusMSG;
  StreamProvider(
      {required this.playable, this.audioFormats, this.statusMSG = ""});

  static Future<StreamProvider> fetch(String videoId) async {
    if (isHarmonyOS) {
      return fetchAudioFromInnerTube(videoId);
    }
    final yt = YoutubeExplode();

    try {
      final res = await yt.videos.streamsClient.getManifest(videoId);
      final audio = res.audioOnly;
      return StreamProvider(
          playable: true,
          statusMSG: "OK",
          audioFormats: audio
              .map((e) => Audio(
                  itag: e.tag,
                  audioCodec:
                      e.audioCodec.contains('mp') ? Codec.mp4a : Codec.opus,
                  bitrate: e.bitrate.bitsPerSecond,
                  duration: e.duration ?? 0,
                  loudnessDb: e.loudnessDb,
                  url: e.url.toString(),
                  size: e.size.totalBytes))
              .toList());
    } catch (e) {
      if (e is SocketException) {
        return StreamProvider(
          playable: false,
          statusMSG: "networkError",
        );
      } else if (e is VideoUnplayableException) {
        return StreamProvider(
          playable: false,
          statusMSG: e.reason ?? "Song is unplayable",
        );
      } else if (e is VideoRequiresPurchaseException) {
        return StreamProvider(
          playable: false,
          statusMSG: "Song requires purchase",
        );
      } else if (e is VideoUnavailableException) {
        return StreamProvider(
          playable: false,
          statusMSG: "Song is unavailable",
        );
      } else if (e is YoutubeExplodeException) {
        return StreamProvider(
          playable: false,
          statusMSG: e.message,
        );
      } else {
        return StreamProvider(
          playable: false,
          statusMSG: "Unknown error occurred",
        );
      }
    }
  }

  Audio? get highestQualityAudio =>
      audioFormats?.lastWhere((item) => item.itag == 251 || item.itag == 140,
          orElse: () => audioFormats!.first);

  Audio? get highestBitrateMp4aAudio =>
      audioFormats?.lastWhere((item) => item.itag == 140 || item.itag == 139,
          orElse: () => audioFormats!.first);

  Audio? get highestBitrateOpusAudio =>
      audioFormats?.lastWhere((item) => item.itag == 251 || item.itag == 250,
          orElse: () => audioFormats!.first);

  Audio? get lowQualityAudio =>
      audioFormats?.lastWhere((item) => item.itag == 249 || item.itag == 139,
          orElse: () => audioFormats!.first);

  Map<String, dynamic> get hmStreamingData {
    return {
      "playable": playable,
      "statusMSG": statusMSG,
      "lowQualityAudio": lowQualityAudio?.toJson(),
      "highQualityAudio": highestQualityAudio?.toJson()
    };
  }
}

/// Cliente InnerTube replicando el flujo exacto de OpenTune.
/// Solo los clientes móviles NO requieren poToken.
class _InnerTubeClient {
  final String clientName;
  final String clientVersion;
  final String clientId;
  final String userAgent;
  final String? osName;
  final String? osVersion;
  final String? deviceMake;
  final String? deviceModel;
  final String? androidSdkVersion;

  const _InnerTubeClient(
      {required this.clientName,
      required this.clientVersion,
      required this.clientId,
      required this.userAgent,
      this.osName,
      this.osVersion,
      this.deviceMake,
      this.deviceModel,
      this.androidSdkVersion});

  String get origin =>
      clientName.startsWith("TVHTML5") ? "https://www.youtube.com" : "https://music.youtube.com";

  String get referer => "$origin/";

  Map<String, dynamic> toContext(String? visitorData) => {
        'client': {
          'clientName': clientName,
          'clientVersion': clientVersion,
          if (osName != null) 'osName': osName,
          if (osVersion != null) 'osVersion': osVersion,
          if (deviceMake != null) 'deviceMake': deviceMake,
          if (deviceModel != null) 'deviceModel': deviceModel,
          if (androidSdkVersion != null) 'androidSdkVersion': androidSdkVersion,
          if (visitorData != null && visitorData.isNotEmpty)
            'visitorData': visitorData,
        },
        'user': {},
      };

  static const List<_InnerTubeClient> rotation = [
    _InnerTubeClient(
      clientName: "ANDROID_VR",
      clientVersion: "1.61.48",
      clientId: "28",
      userAgent:
          "com.google.android.apps.youtube.vr.oculus/1.61.48 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/132.0.6808.3)",
      osName: "Android",
      osVersion: "12",
      deviceMake: "Oculus",
      deviceModel: "Quest 3",
      androidSdkVersion: "32",
    ),
    _InnerTubeClient(
      clientName: "IOS",
      clientVersion: "19.29.1",
      clientId: "5",
      userAgent:
          "com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X;)",
      osVersion: "17.5.1.21F90",
    ),
    _InnerTubeClient(
      clientName: "ANDROID",
      clientVersion: "21.10.38",
      clientId: "3",
      userAgent:
          "com.google.android.youtube/21.10.38 (Linux; U; Android 15; en_US; Pixel 9 Pro; Build/AP4A.250205.002; Cronet/132.0.6834.79) gzip",
      osName: "Android",
      osVersion: "15",
      deviceMake: "Google",
      deviceModel: "Pixel 9 Pro",
      androidSdkVersion: "35",
    ),
    _InnerTubeClient(
      clientName: "ANDROID_MUSIC",
      clientVersion: "7.27.52",
      clientId: "21",
      userAgent:
          "com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 15; en_US; Pixel 9 Pro; Build/AP4A.250205.002; Cronet/132.0.6834.79) gzip",
      osName: "Android",
      osVersion: "15",
      deviceMake: "Google",
      deviceModel: "Pixel 9 Pro",
      androidSdkVersion: "35",
    ),
    _InnerTubeClient(
      clientName: "IOS_MUSIC",
      clientVersion: "7.27.0",
      clientId: "26",
      userAgent:
          "com.google.ios.youtubemusic/7.27.0 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X;)",
      osName: "iOS",
      osVersion: "17.5.1.21F90",
      deviceMake: "Apple",
      deviceModel: "iPhone16,2",
    ),
    _InnerTubeClient(
      clientName: "VISIONOS",
      clientVersion: "0.1",
      clientId: "101",
      userAgent:
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
      osName: "visionOS",
      osVersion: "1.3.21O771",
      deviceMake: "Apple",
      deviceModel: "RealityDevice14,1",
    ),
    _InnerTubeClient(
      clientName: "WEB_EMBEDDED_PLAYER",
      clientVersion: "1.20260114.00.00",
      clientId: "56",
      userAgent:
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36",
    ),
  ];

  static const String endpoint = "https://music.youtube.com/youtubei/v1/player";
}

/// Perfil de cliente resuelto desde el parámetro `c` de la URL de streaming.
/// Replica StreamClientUtils.resolveRequestProfile de OpenTune.
class _StreamProfile {
  final String requestedClientName;
  final String requestedClientVersion;
  final String resolvedClientFamily;
  final String resolvedClientVersion;
  final String userAgent;
  final String? origin;
  final String? referer;
  final bool requiresPlaybackProbeRanges;

  const _StreamProfile({
    required this.requestedClientName,
    required this.requestedClientVersion,
    required this.resolvedClientFamily,
    required this.resolvedClientVersion,
    required this.userAgent,
    this.origin,
    this.referer,
    required this.requiresPlaybackProbeRanges,
  });
}

/// Replica StreamClientUtils de OpenTune.
class _StreamClientUtils {
  static final Map<String, _InnerTubeClient> _registry = {
    for (final c in _InnerTubeClient.rotation) c.clientName: c,
    'WEB_REMIX': const _InnerTubeClient(
      clientName: "WEB_REMIX",
      clientVersion: "1.20260114.01.00",
      clientId: "67",
      userAgent:
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36",
    ),
    'WEB': const _InnerTubeClient(
      clientName: "WEB",
      clientVersion: "2.20260114.00.00",
      clientId: "1",
      userAgent:
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36",
    ),
    'TVHTML5': const _InnerTubeClient(
      clientName: "TVHTML5",
      clientVersion: "7.20260114.00.00",
      clientId: "7",
      userAgent:
          "Mozilla/5.0(SMART-TV; Linux; Tizen 4.0.0.2) AppleWebkit/605.1.15 (KHTML, like Gecko) SamsungBrowser/9.2 TV Safari/605.1.15",
    ),
  };

  static _InnerTubeClient _resolveClient(String name, [String version = ""]) {
    final upper = name.toUpperCase();
    final direct = _registry[upper];
    if (direct != null) return direct;
    if (upper.startsWith("ANDROID_VR")) {
      return _registry['ANDROID_VR']!;
    }
    if (upper.startsWith("IOS")) {
      return _registry['IOS']!;
    }
    if (upper.startsWith("ANDROID_MUSIC")) return _registry['ANDROID_MUSIC']!;
    if (upper.startsWith("ANDROID")) return _registry['ANDROID']!;
    if (upper.startsWith("VISIONOS")) return _registry['VISIONOS']!;
    return _registry['ANDROID_VR']!;
  }

  static bool _isWebLike(_InnerTubeClient c) {
    final n = c.clientName.toUpperCase();
    return n == "WEB" ||
        n == "WEB_REMIX" ||
        n == "WEB_CREATOR" ||
        n == "MWEB" ||
        n == "WEB_EMBEDDED_PLAYER" ||
        n == "TVHTML5";
  }

  static _StreamProfile resolveRequestProfile(String url) {
    final uri = Uri.tryParse(url);
    final clientParam = uri?.queryParameters['c'] ?? "";
    final clientVersion = uri?.queryParameters['cver'] ?? "";
    final requestedName = clientParam.trim();
    final requestedVersion = clientVersion.trim();
    final client = _resolveClient(requestedName, requestedVersion);
    final webLike = _isWebLike(client);
    return _StreamProfile(
      requestedClientName: requestedName.isEmpty ? client.clientName : requestedName,
      requestedClientVersion:
          requestedVersion.isEmpty ? client.clientVersion : requestedVersion,
      resolvedClientFamily: client.clientName,
      resolvedClientVersion: client.clientVersion,
      userAgent: client.userAgent,
      origin: webLike ? client.origin : null,
      referer: webLike ? client.referer : null,
      requiresPlaybackProbeRanges: webLike,
    );
  }

  static String patchClientVersion(String url, String clientVersion) {
    if (!url.contains("cver=")) return url;
    return url.replaceAll(RegExp(r"cver=[^&]+"), "cver=$clientVersion");
  }
}

/// Bloquea temporalmente un cliente para un video (tras 403).
final Map<String, List<String>> _blockedStreamClients = {};

Future<StreamProvider> fetchAudioFromInnerTube(String videoId) async {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
  ));

  final visitorData = await _resolveVisitorData();
  final blocked = _blockedStreamClients[videoId] ?? const <String>[];

  for (final client in _InnerTubeClient.rotation) {
    if (blocked.contains(client.clientName)) {
      // printINFO("${client.clientName} bloqueado para $videoId");
      continue;
    }

    Map<String, dynamic>? data;
    try {
      final body = {
        'videoId': videoId,
        'context': client.toContext(visitorData),
      };
      final response = await dio.post(
        '${_InnerTubeClient.endpoint}?prettyPrint=false',
        data: body,
        options: Options(headers: {
          'user-agent': client.userAgent,
          'content-type': 'application/json',
          'x-goog-api-format-version': '1',
          'x-youtube-client-name': client.clientId,
          'x-youtube-client-version': client.clientVersion,
          'x-origin': client.origin,
          'referer': client.referer,
          if (visitorData != null && visitorData.isNotEmpty)
            'x-goog-visitor-id': visitorData,
        }, validateStatus: (_) => true),
      );
      data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : (response.data as Map).cast<String, dynamic>();
    } catch (e) {
      // printINFO("${client.clientName} request error: $e");
      continue;
    }

    final playability = data['playabilityStatus']?['status'];
    if (playability != "OK") {
      continue;
    }

    final adaptiveFormats = (data['streamingData']?['adaptiveFormats'] as List? ?? [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    final audios = <Audio>[];
    for (final f in adaptiveFormats) {
      final mime = f['mimeType']?.toString() ?? "";
      if (!mime.contains("audio")) continue;
      var url = f['url']?.toString();
      if (url == null || url.isEmpty) continue;
      url = _StreamClientUtils.patchClientVersion(url, client.clientVersion);

      final profile = _StreamClientUtils.resolveRequestProfile(url);
      final playable = await _isUrlPlayable(dio, url, profile);
      if (!playable) continue;

      final itag = f['itag'] is int ? f['itag'] as int : int.tryParse(f['itag']?.toString() ?? "") ?? 0;
      final codecStr = f['mimeType']?.toString() ?? "";
      final bitrate = f['bitrate'] is int
          ? f['bitrate'] as int
          : int.tryParse(f['bitrate']?.toString() ?? "") ?? 0;
      final durationMs = f['approxDurationMs']?.toString();
      final size = f['contentLength']?.toString();

      audios.add(Audio(
        itag: itag,
        audioCodec: codecStr.contains("mp4a") ? Codec.mp4a : Codec.opus,
        bitrate: bitrate,
        duration: durationMs != null ? int.tryParse(durationMs) ?? 0 : 0,
        loudnessDb: (f['audioLoudnessDb']?.toString() == null)
            ? 0.0
            : double.tryParse(f['audioLoudnessDb'].toString()) ?? 0.0,
        url: url,
        size: size != null ? int.tryParse(size) ?? 0 : 0,
      ));
    }

    if (audios.isNotEmpty) {
      // printINFO("${client.clientName}: ${audios.length} audios válidos");
      return StreamProvider(playable: true, statusMSG: "OK", audioFormats: audios);
    }
  }

  return StreamProvider(
      playable: false, statusMSG: "Stream resolution failed");
}

/// Valida una URL de streaming con probe de rangos.
/// Móviles: bytes=0-0. Web: 3 rangos.
Future<bool> _isUrlPlayable(
    Dio dio, String url, _StreamProfile profile) async {
  try {
    final headers = {
      'user-agent': profile.userAgent,
      if (profile.origin != null) 'origin': profile.origin,
      if (profile.referer != null) 'referer': profile.referer,
    };

    if (profile.requiresPlaybackProbeRanges) {
      for (final end in [0, 262144, 1048576]) {
        final r = await dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {...headers, 'Range': 'bytes=$end-${end + 1}'},
            validateStatus: (_) => true,
          ),
        );
        if (r.statusCode == 403 || r.statusCode == 200 && r.data?.isEmpty == true) {
          return false;
        }
      }
      return true;
    } else {
      final r = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {...headers, 'Range': 'bytes=0-0'},
          validateStatus: (_) => true,
        ),
      );
      return r.statusCode == 200 || r.statusCode == 206;
    }
  } catch (_) {
    return false;
  }
}

/// Obtiene visitorData desde AppPrefs box o lo genera.
Future<String?> _resolveVisitorData() async {
  try {
    final box = Hive.box('AppPrefs');
    if (box.containsKey('visitorId')) {
      final v = box.get('visitorId') as Map?;
      final id = v?['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
  } catch (_) {}
  return null;
}

class Audio {
  final int itag;
  final Codec audioCodec;
  final int bitrate;
  final int duration;
  final int size;
  final double loudnessDb;
  final String url;
  Audio(
      {required this.itag,
      required this.audioCodec,
      required this.bitrate,
      required this.duration,
      required this.loudnessDb,
      required this.url,
      required this.size});

  Map<String, dynamic> toJson() => {
        "itag": itag,
        "audioCodec": audioCodec.toString(),
        "bitrate": bitrate,
        "loudnessDb": loudnessDb,
        "url": url,
        "approxDurationMs": duration,
        "size": size
      };

  factory Audio.fromJson(json) => Audio(
      audioCodec: (json["audioCodec"] as String).contains("mp4a")
          ? Codec.mp4a
          : Codec.opus,
      itag: json['itag'],
      duration: json["approxDurationMs"] ?? 0,
      bitrate: json["bitrate"] ?? 0,
      loudnessDb: (json['loudnessDb'])?.toDouble() ?? 0.0,
      url: json['url'],
      size: json["size"] ?? 0);
}

enum Codec { mp4a, opus }