import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:nexusmusic/services/stream_service.dart';
import 'package:path_provider/path_provider.dart';

Future<Map<String, dynamic>> getStreamInfo(String songId, dynamic token) async {
  if (songId.substring(0, 4) == "MPED") {
    songId = songId.substring(4);
  }
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  if (!Hive.isBoxOpen('AppPrefs')) {
    final appDir = await getApplicationDocumentsDirectory();
    Hive.init(appDir.path);
    await Hive.openBox('AppPrefs');
  }
  final playerResponse = (await StreamProvider.fetch(songId));
  return playerResponse.hmStreamingData;
}