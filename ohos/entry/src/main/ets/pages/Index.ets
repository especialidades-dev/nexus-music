import { FlutterPage } from '@ohos/flutter_ohos'
import common from '@ohos.app.ability.common';
import webview from '@ohos.web.webview';
import { PoTokenBridge } from '../plugin/PoTokenBridge'

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'
let gIndexInstance: Index | undefined

// Global reference for PoTokenBridge to access Index methods
export let gIndexSetter: ((visible: boolean, size: number) => void) | undefined

@Entry(storage)
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext
  @LocalStorageLink('viewId') viewId: string = "";
  private controller: webview.WebviewController = PoTokenBridge.getInstance().getWebController()
  @State webViewVisible: boolean = false
  @State webViewSize: number = 1

  aboutToAppear(): void {
    gIndexInstance = this
    gIndexSetter = (visible: boolean, size: number) => {
      this.setWebViewVisible(visible, size)
    }
  }

  aboutToDisappear(): void {
    gIndexInstance = undefined
  }

  build() {
    Column() {
      FlutterPage({ viewId: this.viewId })
      if (this.webViewVisible) {
        Web({ src: 'about:blank', controller: this.controller })
          .width(this.webViewSize)
          .height(this.webViewSize)
          .opacity(1)
          .position({ x: 0, y: 0 })
          .onPageEnd(() => {
            PoTokenBridge.getInstance().onPageEnd()
            if (!PoTokenBridge.getInstance().isLoaded()) {
              PoTokenBridge.getInstance().loadAndExtract()
            }
          })
      } else {
        Web({ src: 'about:blank', controller: this.controller })
          .width(1)
          .height(1)
          .opacity(0)
          .position({ x: 0, y: 0 })
          .onPageEnd(() => {
            PoTokenBridge.getInstance().onPageEnd()
            if (!PoTokenBridge.getInstance().isLoaded()) {
              PoTokenBridge.getInstance().loadAndExtract()
            }
          })
      }
    }
  }

  setWebViewVisible(visible: boolean, size: number = 500): void {
    this.webViewVisible = visible
    this.webViewSize = size
  }

  static getInstance(): Index | undefined {
    return gIndexInstance
  }

  onBackPress(): boolean {
    this.context.eventHub.emit(EVENT_BACK_PRESS)
    return true
  }
}