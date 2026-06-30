import { FlutterPluginRegistrant } from '@ohos/flutter_ohos';
import AudioBridge from './AudioBridge';

export class NexusMusicPluginRegistrant extends FlutterPluginRegistrant {
  private audioBridge: AudioBridge = new AudioBridge();

  registerPlugins(): void {
    this.registerAudioService();
    this.registerPathProvider();
    this.registerHiveStorage();
    this.registerConnectivity();
    this.registerUrlLauncher();
  }

  private registerAudioService(): void {
    this.registerMethodChannel('nexus_music/audio', {
      onMethodCall: (call, result) => {
        switch (call.method) {
          case 'play':
            this.audioBridge.play(call.args.url);
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
            this.audioBridge.seek(call.args.position);
            result.success(true);
            break;
          case 'setVolume':
            this.audioBridge.setVolume(call.args.value);
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
    });
  }

  private registerPathProvider(): void {
    this.registerPlugin('path_provider', {});
  }

  private registerHiveStorage(): void {
    this.registerPlugin('hive', {});
  }

  private registerConnectivity(): void {
    this.registerPlugin('connectivity', {});
  }

  private registerUrlLauncher(): void {
    this.registerPlugin('url_launcher', {});
  }
}
