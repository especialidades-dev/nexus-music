import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { NexusMusicPluginRegistrant } from '../plugin/PluginRegistrant';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine)
    const registrant = new NexusMusicPluginRegistrant()
    registrant.registerPlugins(flutterEngine, this.context)
  }
}
