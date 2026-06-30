import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';

class HarmonyOSAudioHandler extends BaseAudioHandler {
  static const _channel = MethodChannel('nexus_music/audio');

  HarmonyOSAudioHandler() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPlayerStateChanged':
        final playing = call.arguments as bool;
        playbackState.add(playbackState.value.copyWith(
          playing: playing,
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const {MediaAction.seek},
          androidCompactActionIndices: const [0, 1, 2],
        ));
        break;
      case 'onPositionChanged':
        final position = call.arguments as int;
        playbackState.add(playbackState.value.copyWith(
          updatePosition: Duration(milliseconds: position),
        ));
        break;
      case 'onDurationChanged':
        final duration = call.arguments as int;
        final currentQueue = queue.value;
        if (currentQueue.isNotEmpty) {
          final idx = playbackState.value.queueIndex ?? 0;
          if (idx < currentQueue.length) {
            final updated = currentQueue[idx].copyWith(
              duration: Duration(milliseconds: duration),
            );
            mediaItem.add(updated);
          }
        }
        break;
    }
  }

  @override
  Future<void> play() async {
    await _channel.invokeMethod('play');
  }

  @override
  Future<void> pause() async {
    await _channel.invokeMethod('pause');
  }

  @override
  Future<void> stop() async {
    await _channel.invokeMethod('stop');
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _channel.invokeMethod('seek', {
      'position': position.inMilliseconds,
    });
  }

  Future<void> setVolume(double volume) async {
    await _channel.invokeMethod('setVolume', {
      'value': volume,
    });
  }

  @override
  Future<void> skipToNext() async {
    final idx = (playbackState.value.queueIndex ?? 0) + 1;
    if (idx < queue.value.length) {
      await skipToQueueItem(idx);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final idx = (playbackState.value.queueIndex ?? 0) - 1;
    if (idx >= 0) {
      await skipToQueueItem(idx);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    final item = queue.value[index];
    final url = item.extras?['url'] as String?;
    if (url != null) {
      await _channel.invokeMethod('play', {'url': url});
      mediaItem.add(item);
      playbackState.add(playbackState.value.copyWith(
        queueIndex: index,
        playing: true,
      ));
    }
  }

  void release() {
    _channel.invokeMethod('release');
  }
}

Future<AudioHandler> initHarmonyOSAudioService() async {
  return await AudioService.init(
    builder: () => HarmonyOSAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.nexusmusic.app.audio',
      androidNotificationChannelName: 'Nexus Music',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
