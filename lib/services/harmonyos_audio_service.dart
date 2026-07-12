import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';
// ignore: depend_on_referenced_packages
import 'package:rxdart/rxdart.dart';
import '/services/stream_service.dart';

import '/models/album.dart';
import '../models/playlist.dart';
import '/models/hm_streaming_data.dart';
import '/models/media_Item_builder.dart';
import '/services/background_task.dart';
import '/services/permission_service.dart';
import '../utils/helper.dart';
import '/services/utils.dart';
import '../ui/screens/Settings/settings_screen_controller.dart';
import '../ui/screens/Library/library_controller.dart';
import '/ui/player/player_controller.dart';

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

class HarmonyOSAudioHandler extends BaseAudioHandler {
  static const _channel = MethodChannel('nexus_music/audio');

  HarmonyOSAudioHandler() {
    _channel.setMethodCallHandler(_handleMethodCall);
    _initPrefs();
  }

  // --- state ---
  // ignore: prefer_typing_uninitialized_variables
  dynamic currentIndex;
  int currentShuffleIndex = 0;
  String? currentSongUrl;
  bool isPlayingUsingLockCachingSource = false;
  bool loopModeEnabled = false;
  bool queueLoopModeEnabled = false;
  bool shuffleModeEnabled = false;
  bool loudnessNormalizationEnabled = false;
  bool isSongLoading = true;
  List<String> shuffledQueue = [];
  String? _cacheDir;

  Future<void> _initPrefs() async {
    try {
      _cacheDir = (await getTemporaryDirectory()).path;
    } catch (_) {
      _cacheDir = null;
    }
    final appPrefs = Hive.box("AppPrefs");
    loopModeEnabled = appPrefs.get("isLoopModeEnabled") ?? false;
    shuffleModeEnabled = appPrefs.get("isShuffleModeEnabled") ?? false;
    queueLoopModeEnabled = appPrefs.get("queueLoopModeEnabled") ?? false;
    loudnessNormalizationEnabled =
        appPrefs.get("loudnessNormalizationEnabled") ?? false;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPlayerStateChanged':
        final playing = call.arguments as bool;
        playbackState.add(playbackState.value.copyWith(
          playing: playing,
          processingState:
              playing ? AudioProcessingState.ready : AudioProcessingState.idle,
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
        if (currentIndex != null &&
            currentIndex < currentQueue.length &&
            duration > 0) {
          final updated = currentQueue[currentIndex]
              .copyWith(duration: Duration(milliseconds: duration));
          mediaItem.add(updated);
        }
        break;
      case 'onCompleted':
        if (loopModeEnabled) {
          await _channel.invokeMethod('seek', {'position': 0});
          await _channel.invokeMethod('play', {'url': currentSongUrl});
        } else {
          await skipToNext();
        }
        break;
    }
  }

  // --- url resolution (mirrors MyAudioHandler.checkNGetUrl) ---
  Future<HMStreamingData> checkNGetUrl(String songId,
      {bool generateNewUrl = false, bool offlineReplacementUrl = false}) async {
    printINFO("Requested id : $songId");
    final songDownloadsBox = Hive.box("SongDownloads");
    if (!offlineReplacementUrl &&
        (await Hive.openBox("SongsCache")).containsKey(songId)) {
      printINFO("Got Song from cachedbox ($songId)");
      final streamInfo = Hive.box("SongsCache").get(songId)["streamInfo"];
      Audio? cacheAudioPlaceholder;
      if (streamInfo != null && streamInfo.isNotEmpty) {
        streamInfo[1]['url'] = "file://$_cacheDir/cachedSongs/$songId.mp3";
        cacheAudioPlaceholder = Audio.fromJson(streamInfo[1]);
      } else {
        cacheAudioPlaceholder = Audio(
            audioCodec: Codec.mp4a,
            bitrate: 0,
            loudnessDb: 0,
            duration: 0,
            size: 0,
            url: "file://$_cacheDir/cachedSongs/$songId.mp3",
            itag: 0);
      }
      return HMStreamingData(
          playable: true,
          statusMSG: "OK",
          lowQualityAudio: cacheAudioPlaceholder,
          highQualityAudio: cacheAudioPlaceholder);
    } else if (!offlineReplacementUrl && songDownloadsBox.containsKey(songId)) {
      final song = songDownloadsBox.get(songId);
      final streamInfoJson = song["streamInfo"];
      Audio? audio;
      final path = song['url'];
      if (streamInfoJson != null && streamInfoJson.isNotEmpty) {
        audio = Audio.fromJson(streamInfoJson[1]);
      } else {
        audio = Audio(
            itag: 140,
            audioCodec: Codec.mp4a,
            bitrate: 0,
            duration: 0,
            loudnessDb: 0,
            url: path,
            size: 0);
      }
      final streamInfo = HMStreamingData(
          playable: true,
          statusMSG: "OK",
          highQualityAudio: audio,
          lowQualityAudio: audio);
      if (path.contains(
          "${Get.find<SettingsScreenController>().supportDirPath}/Music")) {
        return streamInfo;
      }
      bool hasAccess = false;
      try {
        hasAccess = await PermissionService.getExtStoragePermission();
      } catch (_) {
        hasAccess = false;
      }
      if (hasAccess && await File(path).exists()) {
        return streamInfo;
      }
      return checkNGetUrl(songId, offlineReplacementUrl: true);
    } else {
      final songsUrlCacheBox = Hive.box("SongsUrlCache");
      final qualityIndex = Hive.box('AppPrefs').get('streamingQuality') ?? 1;
      HMStreamingData? streamInfo;
      if (songsUrlCacheBox.containsKey(songId) && !generateNewUrl) {
        final streamInfoJson = songsUrlCacheBox.get(songId);
        if (streamInfoJson.runtimeType.toString().contains("Map") &&
            streamInfoJson['lowQualityAudio'] != null &&
            !isExpired(url: (streamInfoJson['lowQualityAudio']['url']))) {
          final itag = streamInfoJson['lowQualityAudio']['itag'];
          if (itag == 140 || itag == 139) {
            printINFO("Got cached Url ($songId)");
            streamInfo = HMStreamingData.fromJson(streamInfoJson);
          } else {
            printINFO("Cached Opus URL (itag=$itag), fetching AAC");
          }
        }
      }
      if (streamInfo == null) {
        Map<String, dynamic>? streamInfoJson;
        try {
          printINFO("Fetching stream via StreamProvider.fetch");
          final sp = await StreamProvider.fetch(songId).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception("Stream fetch timed out"),
          );
          final aacAudio = sp.highestBitrateMp4aAudio;
          if (aacAudio != null) {
            streamInfoJson = {
              "playable": true,
              "statusMSG": "OK",
              "lowQualityAudio": aacAudio.toJson(),
              "highQualityAudio": aacAudio.toJson(),
            };
            printINFO("AAC audio fetched (itag=${aacAudio.itag})");
          } else {
            streamInfoJson = sp.hmStreamingData;
            printINFO("No AAC available, using default (may fail on AVPlayer)");
          }
        } catch (e) {
          printINFO("Stream fetch failed: $e");
          streamInfo = HMStreamingData(
            playable: false,
            statusMSG: "Stream resolution failed: $e",
          );
        }
        if (streamInfoJson != null) {
          streamInfo = HMStreamingData.fromJson(streamInfoJson);
          if (streamInfo.playable) {
            songsUrlCacheBox.put(songId, streamInfoJson);
          }
        }
      }
      streamInfo ??= HMStreamingData(playable: false, statusMSG: "Stream resolution failed");
      streamInfo.setQualityIndex(qualityIndex as int);
      return streamInfo;
    }
  }

  // --- queue management ---
  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    final newQueue = queue.value..addAll(mediaItems);
    queue.add(newQueue);
    if (shuffleModeEnabled) {
      final mediaItemsIds = mediaItems.toList().map((item) => item.id).toList();
      final notPlayedshuffledQueue = shuffledQueue.isNotEmpty
          ? shuffledQueue.toList().sublist(currentShuffleIndex + 1)
          : shuffledQueue;
      notPlayedshuffledQueue.addAll(mediaItemsIds);
      notPlayedshuffledQueue.shuffle();
      shuffledQueue.replaceRange(
          currentShuffleIndex, shuffledQueue.length, notPlayedshuffledQueue);
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    final replaced = queue.value
      ..replaceRange(0, queue.value.length, newQueue);
    queue.add(replaced);
  }

  @override
  // ignore: avoid_renaming_method_parameters
  Future<void> removeQueueItem(MediaItem mediaItem_) async {
    if (shuffleModeEnabled) {
      final id = mediaItem_.id;
      final itemIndex = shuffledQueue.indexOf(id);
      if (currentShuffleIndex > itemIndex) {
        currentShuffleIndex -= 1;
      }
      shuffledQueue.remove(id);
    }
    final currentQueue = queue.value;
    final currentSong = mediaItem.value;
    final itemIndex = currentQueue.indexOf(mediaItem_);
    if (currentIndex > itemIndex) {
      currentIndex -= 1;
    }
    currentQueue.remove(mediaItem_);
    queue.add(currentQueue);
    mediaItem.add(currentSong);
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    if (shuffleModeEnabled) {
      shuffledQueue.add(mediaItem.id);
    }
    final newQueue = queue.value..add(mediaItem);
    queue.add(newQueue);
  }

  // --- transport controls (HarmonyOS native via channel) ---
  @override
  Future<void> play() async {
    if (currentSongUrl == null) {
      if (currentIndex == null || queue.value.isEmpty) return;
      await customAction("playByIndex", {'index': currentIndex});
      return;
    }
    await _channel.invokeMethod('play', {'url': currentSongUrl});
  }

  @override
  Future<void> pause() async => _channel.invokeMethod('pause');

  @override
  Future<void> stop() async {
    await _channel.invokeMethod('stop');
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async =>
      _channel.invokeMethod('seek', {'position': position.inMilliseconds});

  Future<void> setVolume(double volume) async =>
      _channel.invokeMethod('setVolume', {'value': volume});

  Future<void> release() async => _channel.invokeMethod('release');

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await customAction("playByIndex", {'index': index});
  }

  int _getNextSongIndex() {
    if (shuffleModeEnabled) {
      if (currentShuffleIndex + 1 >= shuffledQueue.length) {
        shuffledQueue.shuffle();
        currentShuffleIndex = 0;
      } else {
        currentShuffleIndex += 1;
      }
      return queue.value
          .indexWhere((item) => item.id == shuffledQueue[currentShuffleIndex]);
    }
    if (queue.value.length > currentIndex + 1) {
      return currentIndex + 1;
    } else if (queueLoopModeEnabled) {
      return 0;
    } else {
      return currentIndex;
    }
  }

  int _getPrevSongIndex() {
    if (shuffleModeEnabled) {
      if (currentShuffleIndex - 1 < 0) {
        shuffledQueue.shuffle();
        currentShuffleIndex = shuffledQueue.length - 1;
      } else {
        currentShuffleIndex -= 1;
      }
      return queue.value
          .indexWhere((item) => item.id == shuffledQueue[currentShuffleIndex]);
    }
    if (currentIndex - 1 >= 0) {
      return currentIndex - 1;
    } else {
      return currentIndex;
    }
  }

  @override
  Future<void> skipToNext() async {
    final index = _getNextSongIndex();
    if (index != currentIndex) {
      await customAction("playByIndex", {'index': index});
    } else {
      await _channel.invokeMethod('seek', {'position': 0});
      await pause();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final pos = playbackState.value.updatePosition;
    if (pos.inMilliseconds > 5000) {
      await _channel.invokeMethod('seek', {'position': 0});
      return;
    }
    final index = _getPrevSongIndex();
    if (index != currentIndex) {
      await customAction("playByIndex", {'index': index});
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    loopModeEnabled = repeatMode != AudioServiceRepeatMode.none;
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == AudioServiceShuffleMode.none) {
      shuffleModeEnabled = false;
      shuffledQueue.clear();
    } else {
      _shuffleCmd(currentIndex);
      shuffleModeEnabled = true;
    }
  }

  // --- custom actions ---
  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'dispose':
        await release();
        break;

      case 'playByIndex':
        try {
          final songIndex = extras?['index'];
          if (songIndex == null || songIndex >= queue.value.length) {
            printINFO("playByIndex: invalid index $songIndex");
            return;
          }
          currentIndex = songIndex;
          final isNewUrlReq = extras?['newUrl'] ?? false;
          final currentSong = queue.value[currentIndex];
          if (currentSong == null) return;
          final futureStreamInfo =
              checkNGetUrl(currentSong.id, generateNewUrl: isNewUrlReq);
          final bool restoreSession = extras?['restoreSession'] ?? false;
          isSongLoading = true;
          playbackState.add(playbackState.value
              .copyWith(processingState: AudioProcessingState.loading));
          mediaItem.add(currentSong);
          final streamInfo = await futureStreamInfo;
          if (songIndex != currentIndex) {
            return;
          } else if (!streamInfo.playable) {
            currentSongUrl = null;
            isSongLoading = false;
            try {
              Get.find<PlayerController>().notifyPlayError(streamInfo.statusMSG);
            } catch (_) {}
            playbackState.add(playbackState.value.copyWith(
                processingState: AudioProcessingState.error,
                errorCode: 404,
                errorMessage: streamInfo.statusMSG));
            return;
          }
          final audio = streamInfo.audio;
          if (audio == null || audio.url.isEmpty) {
            printINFO("playByIndex: no audio url for ${currentSong.id}");
            currentSongUrl = null;
            isSongLoading = false;
            playbackState.add(playbackState.value.copyWith(
                processingState: AudioProcessingState.error,
                errorCode: 404,
                errorMessage: "No audio stream available"));
            return;
          }
          currentSongUrl = currentSong.extras!['url'] = audio.url;
          playbackState.add(playbackState.value.copyWith(queueIndex: currentIndex));
          isSongLoading = false;
          if (loudnessNormalizationEnabled &&
              (GetPlatform.isAndroid || isHarmonyOS)) {
            _normalizeVolume(audio.loudnessDb);
          }
          if (restoreSession) {
            final position = extras?['position'];
            await _channel.invokeMethod('play', {'url': currentSongUrl});
            if (position != null) {
              await _channel.invokeMethod('seek', {'position': position});
            }
          } else {
            await _channel.invokeMethod('play', {'url': currentSongUrl});
            playbackState.add(playbackState.value.copyWith(
              processingState: AudioProcessingState.ready,
              playing: true,
            controls: [
              MediaControl.skipToPrevious,
              MediaControl.pause,
              MediaControl.skipToNext,
            ],
            systemActions: const {MediaAction.seek},
            androidCompactActionIndices: const [0, 1, 2],
          ));
        }
      } catch (e) {
        printINFO("playByIndex error: $e");
        isSongLoading = false;
        currentSongUrl = null;
        playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            errorCode: 500,
            errorMessage: "Playback error: $e"));
      }
        break;

      case 'setSourceNPlay':
        try {
          final currMed = extras?['mediaItem'] as MediaItem?;
          if (currMed == null) return;
          final futureStreamInfo = checkNGetUrl(currMed.id);
          isSongLoading = true;
          currentIndex = 0;
          mediaItem.add(currMed);
          queue.add([currMed]);
          final streamInfo = (await futureStreamInfo);
          if (!streamInfo.playable) {
            currentSongUrl = null;
            isSongLoading = false;
            try {
              Get.find<PlayerController>().notifyPlayError(streamInfo.statusMSG);
            } catch (_) {}
            playbackState.add(playbackState.value
                .copyWith(processingState: AudioProcessingState.error));
            return;
          }
          final audio = streamInfo.audio;
          if (audio == null || audio.url.isEmpty) {
            currentSongUrl = null;
            isSongLoading = false;
            return;
          }
          currentSongUrl = currMed.extras!['url'] = audio.url;
          isSongLoading = false;
          if (loudnessNormalizationEnabled &&
              (GetPlatform.isAndroid || isHarmonyOS)) {
            _normalizeVolume(audio.loudnessDb);
          }
          await _channel.invokeMethod('play', {'url': currentSongUrl});
        } catch (e) {
          printINFO("setSourceNPlay error: $e");
        }
        break;

      case 'toggleSkipSilence':
        // AVPlayer has no equivalent simple toggle; no-op on HarmonyOS.
        break;

      case 'toggleLoudnessNormalization':
        loudnessNormalizationEnabled = (extras!['enable'] as bool);
        if (!loudnessNormalizationEnabled) {
          await setVolume(1.0);
          return;
        }
        if (loudnessNormalizationEnabled) {
          try {
            final currentSongId = (queue.value[currentIndex]).id;
            if (Hive.box("SongsUrlCache").containsKey(currentSongId)) {
              final songJson = Hive.box("SongsUrlCache").get(currentSongId);
              _normalizeVolume((songJson)["highQualityAudio"]["loudnessDb"]);
              return;
            }
            if (Hive.box("SongDownloads").containsKey(currentSongId)) {
              final streamInfo =
                  (Hive.box("SongDownloads").get(currentSongId))["streamInfo"];
              _normalizeVolume(
                  streamInfo == null ? 0 : streamInfo[1]["loudnessDb"]);
            }
          } catch (e) {
            printERROR(e);
          }
        }
        break;

      case 'shuffleQueue':
        final currentQueue = queue.value;
        final currentItem = currentQueue[currentIndex];
        currentQueue.remove(currentItem);
        currentQueue.shuffle();
        currentQueue.insert(0, currentItem);
        queue.add(currentQueue);
        mediaItem.add(currentItem);
        currentIndex = 0;
        break;

      case 'reorderQueue':
        final oldIndex = extras!['oldIndex'];
        int newIndex = extras['newIndex'];
        if (oldIndex < newIndex) {
          newIndex--;
        }
        final currentQueue = queue.value;
        final currentItem = currentQueue[currentIndex];
        final item = currentQueue.removeAt(oldIndex);
        currentQueue.insert(newIndex, item);
        currentIndex = currentQueue.indexOf(currentItem);
        queue.add(currentQueue);
        mediaItem.add(currentItem);
        break;

      case 'addPlayNextItem':
        final song = extras!['mediaItem'] as MediaItem;
        final currentQueue = queue.value;
        currentQueue.insert(currentIndex + 1, song);
        queue.add(currentQueue);
        if (shuffleModeEnabled) {
          shuffledQueue.insert(currentShuffleIndex + 1, song.id);
        }
        break;

      case 'openEqualizer':
        // No equalizer service on HarmonyOS.
        break;

      case 'saveSession':
        await saveSessionData();
        break;

      case 'setVolume':
        await setVolume((extras!['value'] as num) / 100);
        break;

      case 'shuffleCmd':
        final songIndex = extras!['index'];
        _shuffleCmd(songIndex);
        break;

      case 'upadateMediaItemInAudioService':
        final songIndex = extras!['index'];
        currentIndex = songIndex;
        mediaItem.add(queue.value[currentIndex]);
        break;

      case 'toggleQueueLoopMode':
        queueLoopModeEnabled = extras!['enable'];
        break;

      case 'checkWithCacheDb':
        if (isPlayingUsingLockCachingSource) {
          final song = extras!['mediaItem'] as MediaItem;
          final songsCacheBox = Hive.box("SongsCache");
          if (!songsCacheBox.containsKey(song.id) &&
              await File("$_cacheDir/cachedSongs/${song.id}.mp3").exists()) {
            song.extras!['url'] = currentSongUrl;
            song.extras!['date'] = DateTime.now().millisecondsSinceEpoch;
            final dbStreamData = Hive.box("SongsUrlCache").get(song.id);
            final jsonData = MediaItemBuilder.toJson(song);
            jsonData['duration'] = mediaItem.value?.duration?.inSeconds ?? 0;
            jsonData['streamInfo'] = dbStreamData != null
                ? [
                    2,
                    dbStreamData[
                        Hive.box('AppPrefs').get('streamingQuality') == 0
                            ? 'lowQualityAudio'
                            : "highQualityAudio"]
                  ]
                : null;
            songsCacheBox.put(song.id, jsonData);
            try {
              final librarySongsController =
                  Get.find<LibrarySongsController>();
              if (!librarySongsController.isClosed) {
                librarySongsController.librarySongsList.value =
                    librarySongsController.librarySongsList.toList() + [song];
              }
            } catch (_) {}
          }
        }
        break;

      case 'clearQueue':
        await customAction("reorderQueue",
            {'oldIndex': currentIndex, 'newIndex': 0});
        break;
    }
  }

  void _shuffleCmd(int index) {
    final queueIds = queue.value.toList().map((item) => item.id).toList();
    final currentSongId = queueIds.removeAt(index);
    queueIds.shuffle();
    queueIds.insert(0, currentSongId);
    shuffledQueue.replaceRange(0, shuffledQueue.length, queueIds);
    currentShuffleIndex = 0;
  }

  void _normalizeVolume(double currentLoudnessDb) {
    final loudnessDifference = -5 - currentLoudnessDb;
    final volumeAdjustment = pow(10.0, loudnessDifference / 20.0);
    printINFO("loudness:$currentLoudnessDb Normalized volume: $volumeAdjustment");
    setVolume(volumeAdjustment.toDouble().clamp(0, 1.0));
  }

  Future<void> saveSessionData() async {
    if (Get.find<SettingsScreenController>().restorePlaybackSession.isFalse) {
      return;
    }
    final currQueue = queue.value;
    if (currQueue.isNotEmpty) {
      final queueData = currQueue.map((e) => MediaItemBuilder.toJson(e)).toList();
      final currIndex = currentIndex ?? 0;
      final position = playbackState.value.updatePosition.inMilliseconds;
      final prevSessionData = await Hive.openBox("prevSessionData");
      await prevSessionData.clear();
      await prevSessionData.putAll(
          {"queue": queueData, "position": position, "index": currIndex});
      await prevSessionData.close();
      printINFO("Saved session data");
    }
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
