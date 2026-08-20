import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main() async {
  final yt = YoutubeExplode();
  final videoId = 'mNEUkkoUoIA';
  try {
    final manifest = await yt.videos.streamsClient.getManifest(videoId);
    final audio = manifest.audioOnly;
    print('audioOnly: ${audio.length}');
    for (final a in audio.take(4)) {
      print('  itag=${a.tag} codec=${a.audioCodec} url=${a.url.toString().substring(0, 70)}...');
    }
  } catch (e) {
    print('ERROR: $e');
  }
  yt.close();
}
