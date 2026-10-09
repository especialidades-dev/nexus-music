import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import { MethodChannel, MethodCall, MethodResult, MethodCallHandler } from '@ohos/flutter_ohos';

class UrlBridge {
  private context: common.Context | null = null;

  setContext(context: common.Context): void {
    this.context = context;
  }

  async openUrl(url: string): Promise<boolean> {
    if (!this.context) {
      console.error('NexusMusic openUrl: no context');
      return false;
    }
    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: url,
      };
      await (this.context as common.UIAbilityContext).startAbility(want);
      console.info(`NexusMusic openUrl ok: ${url}`);
      return true;
    } catch (e) {
      console.error(`NexusMusic openUrl error: ${JSON.stringify(e)}`);
      return false;
    }
  }
}

class UrlServiceHandler implements MethodCallHandler {
  private urlBridge: UrlBridge;

  constructor(urlBridge: UrlBridge) {
    this.urlBridge = urlBridge;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'openUrl': {
        const url = call.argument('url') as string;
        if (!url) {
          result.error('INVALID_URL', 'url required', null);
          return;
        }
        this.urlBridge.openUrl(url).then((ok) => {
          result.success(ok);
        }).catch((e: Error) => {
          result.error('OPEN_URL_ERROR', String(e), null);
        });
        break;
      }
      default:
        result.notImplemented();
    }
  }
}

export { UrlBridge, UrlServiceHandler };