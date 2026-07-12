import { FlutterEngine, MethodChannel, MethodCall, MethodCallHandler, MethodResult } from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import PathUtils from '@ohos/flutter_ohos/src/main/ets/util/PathUtils';
import AudioBridge from './AudioBridge';

class AudioServiceHandler implements MethodCallHandler {
  private audioBridge: AudioBridge

  constructor(audioBridge: AudioBridge) {
    this.audioBridge = audioBridge
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'play':
        this.audioBridge.play(call.argument('url') as string);
        result.success(true);
        break;
      case 'pause':
        this.audioBridge.pause();
        result.success(true);
        break;
      case 'stop':
        this.audioBridge.stop();
        result.success(true);
        break;
      case 'seek':
        this.audioBridge.seek(call.argument('position') as number);
        result.success(true);
        break;
      case 'setVolume':
        this.audioBridge.setVolume(call.argument('value') as number);
        result.success(true);
        break;
      case 'getPosition':
        result.success(this.audioBridge.getCurrentTime());
        break;
      case 'getDuration':
        result.success(this.audioBridge.getDuration());
        break;
      case 'release':
        this.audioBridge.release();
        result.success(true);
        break;
      default:
        result.notImplemented();
    }
  }
}

export class NexusMusicPluginRegistrant {
  private audioBridge: AudioBridge = new AudioBridge();

  registerPlugins(flutterEngine: FlutterEngine, context: common.Context): void {
    this.registerAudioService(flutterEngine);
    this.registerAudioServicePlatform(flutterEngine);
    this.registerPathProvider(flutterEngine, context);
  }

  private registerPathProvider(flutterEngine: FlutterEngine, context: common.Context): void {
    const channel = new MethodChannel(flutterEngine.getDartExecutor(), 'plugins.flutter.io/path_provider');
    channel.setMethodCallHandler({
      onMethodCall(call: MethodCall, result: MethodResult): void {
        try {
          switch (call.method) {
            case 'getApplicationDocumentsDirectory':
              result.success(PathUtils.getDataDirectory(context) ?? context.filesDir);
              break;
            case 'getApplicationSupportDirectory':
              result.success(PathUtils.getFilesDir(context));
              break;
            case 'getTemporaryDirectory':
            case 'getApplicationCacheDirectory':
              result.success(context.cacheDir);
              break;
            case 'getDownloadsDirectory':
              result.success(context.filesDir + '/Download');
              break;
            case 'getExternalStorageDirectory':
              result.success(context.filesDir);
              break;
            case 'getExternalCacheDirectories':
              result.success([context.cacheDir]);
              break;
            case 'getExternalStorageDirectories':
              result.success([context.filesDir]);
              break;
            default:
              result.notImplemented();
          }
        } catch (e) {
          result.error('PATH_PROVIDER_ERROR', String(e), null);
        }
      }
    } as ESObject);
  }

  private registerAudioService(flutterEngine: FlutterEngine): void {
    const channel = new MethodChannel(flutterEngine.getDartExecutor(), 'nexus_music/audio')
    channel.setMethodCallHandler(new AudioServiceHandler(this.audioBridge))
    this.audioBridge.setCallbackChannel(channel)
  }

  private registerAudioServicePlatform(flutterEngine: FlutterEngine): void {
    const ack = (call: MethodCall, result: MethodResult): void => {
      result.success(null)
    }
    new MethodChannel(flutterEngine.getDartExecutor(), 'com.ryanheise.audio_service.client.methods')
      .setMethodCallHandler({ onMethodCall: ack } as ESObject)
    new MethodChannel(flutterEngine.getDartExecutor(), 'com.ryanheise.audio_service.handler.methods')
      .setMethodCallHandler({ onMethodCall: ack } as ESObject)
  }
}
