import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../main.dart';
import '../utils/helper.dart';

/// Obtiene visitorData y PO token desde el WebView nativo (ArkWeb en Harmony).
/// Replica el metodo de OpenTune: el WebView del dispositivo genera tokens de
/// alta confianza que YouTube acepta para streaming completo.
class WebViewTokenProvider {
  static const _channel = MethodChannel('nexus_music/potoken');

  static String? _visitorData;
  static String? _poToken;
  static String? _dataSyncId;
  static String? _cookie;
  static bool _ready = false;
  static bool _refreshing = false;

  static bool get isHarmony => isHarmonyOS;

  static Future<Map<String, String>> getTokens() async {
    if (!isHarmony) return {};
    try {
      final result = await _channel.invokeMethod<Map>('getTokens');
      if (result == null) return {};
      _visitorData = result['visitorData'] as String?;
      _poToken = result['poToken'] as String?;
      _dataSyncId = result['dataSyncId'] as String?;
      _cookie = result['cookie'] as String?;
      _ready = result['ready'] == 'true';
      printINFO(
          "WebView tokens: visitor=${(_visitorData ?? '').length > 0}, "
          "po=${(_poToken ?? '').length > 0}, "
          "dsid=${(_dataSyncId ?? '').length > 0}, "
          "cookie=${(_cookie ?? '').length > 0}, ready=$_ready");
      return {
        'visitorData': _visitorData ?? '',
        'poToken': _poToken ?? '',
        'dataSyncId': _dataSyncId ?? '',
        'cookie': _cookie ?? '',
      };
    } catch (e) {
      printINFO("getTokens error: $e");
      return {};
    }
  }

  static Future<void> refresh() async {
    if (!isHarmony || _refreshing) return;
    _refreshing = true;
    try {
      await _channel.invokeMethod('refresh');
      await Future.delayed(const Duration(milliseconds: 1500));
      await getTokens();
    } catch (e) {
      printINFO("refresh error: $e");
    } finally {
      _refreshing = false;
    }
  }

/// Obtiene el JSON de streams de audio del reproductor real del WebView
  /// (ytInitialPlayerResponse), replicando el metodo de OpenTune.
  static Future<List<Map<String, dynamic>>> getVideoStreams(
      String videoId) async {
    printINFO("getVideoStreams ENTER for $videoId, isHarmony=$isHarmony");
    if (!isHarmony) {
      printINFO("getVideoStreams: not harmony, returning empty");
      return [];
    }
    printINFO("getVideoStreams START for $videoId");
    printINFO("getVideoStreams START for $videoId");
    try {
      final result = await _channel
          .invokeMethod<String>('getVideoStreams', {'videoId': videoId})
          .timeout(const Duration(seconds: 60));
      printINFO("getVideoStreams result: ${result != null ? 'len=${result.length}' : 'null'}");
      if (result == null || result.length < 100 || !result.startsWith('[')) {
        printINFO("getVideoStreams: empty or invalid result");
        return [];
      }
      final decoded = json.decode(result) as List<dynamic>;
      final streams = decoded.whereType<Map<String, dynamic>>().toList();
      printINFO("getVideoStreams parsed ${streams.length} streams");
      return streams;
    } on TimeoutException {
      printINFO("getVideoStreams timeout");
      return [];
    } catch (e) {
      printINFO("getVideoStreams error: $e");
      return [];
    }
  }

  /// Extrae poToken ejecutando BotGuard en el WebView (visible + interacción)
  static Future<String> extractBotGuardPoToken(String videoId) async {
    if (!isHarmony) return '';
    try {
      final result = await _channel
          .invokeMethod<String>('extractBotGuardPoToken', {'videoId': videoId})
          .timeout(const Duration(seconds: 45));
      return result ?? '';
    } on TimeoutException {
      printINFO("extractBotGuardPoToken timeout");
      return '';
    } catch (e) {
      printINFO("extractBotGuardPoToken error: $e");
      return '';
    }
  }

  static String? get visitorData => _visitorData;
  static String? get poToken => _poToken;
  static bool get ready => _ready;
}
