import { FlutterAbility } from '@ohos/flutter_ohos';

export default class EntryAbility extends FlutterAbility {
  onWindowStageCreate(windowStage: Window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        console.error(`Failed to load content: ${err.message}`);
        return;
      }
      console.info('Nexus Music loaded successfully');
    });
  }

  onForeground(): void {
    super.onForeground();
  }

  onBackground(): void {
    super.onBackground();
  }
}
