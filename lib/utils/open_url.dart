import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '/utils/helper.dart';

/// Method channel for opening external URLs on HarmonyOS. `url_launcher` has no
/// OHOS implementation there, so a [Want] with action `viewData` is opened
/// through the native UrlBridge instead.
const _urlChannel = MethodChannel('nexus_music/url');

/// True only on the Flutter OHOS engine, where every [GetPlatform] flag is
/// false and the web flag is also false. Kept local so this helper does not
/// pull in the whole HarmonyOS audio service on Android/Linux.
bool get _isHarmonyOS {
  try {
    return !GetPlatform.isWeb &&
        !GetPlatform.isAndroid &&
        !GetPlatform.isIOS &&
        !GetPlatform.isMacOS &&
        !GetPlatform.isWindows &&
        !GetPlatform.isLinux;
  } catch (_) {
    return false;
  }
}

/// Opens [urlString] in the system browser.
///
/// On HarmonyOS it goes through the native UrlBridge (startAbility with
/// `ohos.want.action.viewData`); on every other platform it falls back to
/// `url_launcher` with [LaunchMode.externalApplication].
Future<bool> openExternalUrl(String urlString) async {
  if (_isHarmonyOS) {
    try {
      final ok =
          await _urlChannel.invokeMethod<bool>('openUrl', {'url': urlString});
      if (ok ?? false) return true;
    } on PlatformException catch (e) {
      printINFO("openExternalUrl channel error: ${e.message}");
    } catch (_) {
      // ignore and fall back to url_launcher
    }
  }
  try {
    return await launchUrl(
      Uri.parse(urlString),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
