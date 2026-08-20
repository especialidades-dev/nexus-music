import webview from '@ohos.web.webview';
import { gIndexSetter } from '../pages/Index';

class PoTokenStore {
  private static instance: PoTokenStore = new PoTokenStore();
  private _visitorData: string = '';
  private _poToken: string = '';
  private _dataSyncId: string = '';
  private _cookie: string = '';
  private _ready: boolean = false;

  static getInstance(): PoTokenStore {
    return PoTokenStore.instance;
  }

  setTokens(visitorData: string, poToken: string, dataSyncId: string, cookie: string): void {
    const clean = (v: string): string => {
      if (!v) return '';
      const t = v.replace(/^"|"$/g, '').trim();
      if (t === 'null' || t === 'undefined' || t.length < 10) return '';
      return t;
    };
    const cv = clean(visitorData);
    const cp = clean(poToken);
    const cd = clean(dataSyncId);
    if (cv.length > 0) this._visitorData = cv;
    if (cp.length > 0) this._poToken = cp;
    if (cd.length > 0) this._dataSyncId = cd;
    if (cookie && cookie.length > 0) this._cookie = cookie;
    this._ready = (this._visitorData.length > 0 && this._poToken.length > 0);
  }

  get visitorData(): string {
    return this._visitorData;
  }

  get poToken(): string {
    return this._poToken;
  }

  get dataSyncId(): string {
    return this._dataSyncId;
  }

  get cookie(): string {
    return this._cookie;
  }

  get isReady(): boolean {
    return this._ready;
  }
}

class PoTokenBridge {
  private static instance: PoTokenBridge = new PoTokenBridge();
  private controller: webview.WebviewController = new webview.WebviewController();
  private loaded: boolean = false;
  private extractionInProgress: boolean = false;
  private retrying: boolean = false;
  private streamingVideo: string = '';
  private streamAbort: boolean = false;

  static getInstance(): PoTokenBridge {
    return PoTokenBridge.instance;
  }

  getWebController(): webview.WebviewController {
    return this.controller;
  }

  isLoaded(): boolean {
    return this.loaded;
  }

  markLoaded(): void {
    this.loaded = true;
  }

  async loadAndExtract(): Promise<void> {
    if (this.extractionInProgress) return;
    if (this.streamingVideo.length > 0) return;
    this.extractionInProgress = true;
    try {
      const store = PoTokenStore.getInstance();
      if (store.isReady && store.visitorData.length > 0) {
        return;
      }
      this.controller.loadUrl('https://www.youtube.com/watch?v=jNQXAC9IVRw');
    } catch (e) {
      console.error(`NexusMusic PoTokenBridge load error: ${JSON.stringify(e)}`);
    } finally {
      this.extractionInProgress = false;
    }
  }

  async onPageEnd(): Promise<void> {
    // Si estamos extrayendo streams del reproductor de un video concreto,
    // no interferir con cargas ni re-extracciones.
    if (this.streamingVideo.length > 0) {
      return;
    }
    const store = PoTokenStore.getInstance();
    if (store.isReady && store.visitorData.length > 0) {
      return;
    }
    await this.extractTokens();
    // Si aún no hay tokens, forzar recarga de YouTube (primera carga puede
    // ser about:blank).
    if (!store.isReady && !this.retrying) {
      this.retrying = true;
      this.controller.loadUrl('https://www.youtube.com/watch?v=jNQXAC9IVRw');
      setTimeout(() => { this.retrying = false; }, 8000);
    }
  }

  async extractTokens(): Promise<void> {
    try {
      const store = PoTokenStore.getInstance();
      const visitorData = await this.controller.runJavaScript(
        "(function(){try{var c=window.ytcfg;if(c&&c.get){var v=c.get('VISITOR_DATA');if(v)return v}if(window.yt&&window.yt.config_&&window.yt.config_.VISITOR_DATA)return window.yt.config_.VISITOR_DATA;var s=document.documentElement.outerHTML;var m=s.match(/\"VISITOR_DATA\":\"([^\"]+)\"/);if(m)return m[1]}catch(e){}return ''})()"
      );
      const poToken = await this.controller.runJavaScript(
        "(function(){try{var c=window.ytcfg;if(c&&c.get){var t=c.get('PO_TOKEN');if(t)return t}var s=document.documentElement.outerHTML;var m=s.match(/\"PO_TOKEN\":\"([^\"]+)\"/);if(m)return m[1]}catch(e){}return ''})()"
      );
      const dataSyncId = await this.controller.runJavaScript(
        "(function(){try{var c=window.ytcfg;if(c&&c.get){var d=c.get('DATASYNC_ID');if(d)return d}if(window.yt&&window.yt.config_&&window.yt.config_.DATASYNC_ID)return window.yt.config_.DATASYNC_ID}catch(e){}return ''})()"
      );
      const cookie = await webview.WebCookieManager.fetchCookie('https://www.youtube.com');
      store.setTokens(
        (visitorData || '').toString(),
        (poToken || '').toString(),
        (dataSyncId || '').toString(),
        cookie || ''
      );
      console.info(`NexusMusic PoTokenBridge tokens: visitor=${store.visitorData.length} chars po=${store.poToken.length} chars dsid=${store.dataSyncId.length} cookie=${store.cookie.length}`);
      console.info(`NexusMusic PoTokenBridge visitor head=${store.visitorData.substring(0, 30)}`);
      console.info(`NexusMusic PoTokenBridge po head=${store.poToken.substring(0, 30)}`);
    } catch (e) {
      console.error(`NexusMusic PoTokenBridge extract error: ${JSON.stringify(e)}`);
    }
  }

  async getVideoStreams(videoId: string): Promise<string> {
    console.error(`NexusMusic getVideoStreams START for ${videoId}`);
    try {
      this.streamingVideo = videoId;
      if (gIndexSetter) {
        gIndexSetter(true, 500)
        await this.delay(500)
      }
      this.controller.loadUrl(`https://www.youtube.com/watch?v=${videoId}`);
      
      let json = '';
      let lastLen = 0;
      for (let i = 0; i < 30; i++) {
        await this.delay(2000);
        // Click play button to trigger player initialization
        if (i === 3 || i === 8 || i === 13 || i === 18 || i === 23) {
          try {
            await this.controller.runJavaScript(
              "document.querySelector('.ytp-large-play-button')?.click(); " +
              "document.querySelector('button[aria-label*=\"Play\"]')?.click(); " +
              "document.querySelector('video')?.play();"
            );
          } catch (e) {}
        }
        try {
          // Try ytInitialPlayerResponse first
          json = await this.controller.runJavaScript(
            "(function(){try{var w=window.ytInitialPlayerResponse;if(w&&w.streamingData&&w.streamingData.adaptiveFormats){return JSON.stringify(w.streamingData.adaptiveFormats)}var s=document.documentElement.outerHTML;var m=s.match(/ytInitialPlayerResponse\\s*=\\s*({.*?});(?:\\s*var|\\s*</script>)/s);if(m){try{var d=JSON.parse(m[1]);if(d.streamingData&&d.streamingData.adaptiveFormats)return JSON.stringify(d.streamingData.adaptiveFormats)}catch(e){}}return ''})()"
          );
        } catch (e) {
          continue;
        }
        const text = (json || '').toString().trim();
        if (i < 3 || text.length !== lastLen) {
          lastLen = text.length;
          let loc = '';
          try {
            const lr = await this.controller.runJavaScript("location.href");
            loc = (lr || '').toString();
          } catch (e) {}
          console.error(`NexusMusic getVideoStreams i=${i} len=${text.length} head=${text.substring(0, 120)} loc=${loc.substring(0, 80)}`);
        }
        if (text.length > 100 && text.startsWith('[')) {
          console.error(`NexusMusic getVideoStreams json len=${text.length} for ${videoId}`);
          return text;
        }
        // Fallback: try to get video URL directly from <video> element
        if (i >= 10) {
          try {
            const videoSrc = await this.controller.runJavaScript(
              "document.querySelector('video')?.src || ''"
            );
            const srcText = (videoSrc || '').toString().trim();
            if (srcText.length > 50 && srcText.startsWith('http')) {
              console.error(`NexusMusic getVideoStreams video src found len=${srcText.length}`);
              return JSON.stringify([{url: srcText, mimeType: 'video/mp4', itag: 22, bitrate: 1000000, approxDurationMs: 0, contentLength: 0}]);
            }
          } catch (e) {}
        }
      }
      // Log what we got in last iteration
      const finalText = (json || '').toString().trim();
      console.error(`NexusMusic getVideoStreams FINAL: len=${finalText.length} head=${finalText.substring(0, 300)}`);
      console.error(`NexusMusic getVideoStreams FAILED for ${videoId}`);
      return '';
    } catch (e) {
      console.error(`NexusMusic getVideoStreams error: ${JSON.stringify(e)}`);
      return '';
    } finally {
      this.streamingVideo = '';
      if (gIndexSetter) {
        gIndexSetter(false, 1)
      }
    }
  }

  getTokens(): Map<string, string> {
    const store = PoTokenStore.getInstance();
    return new Map<string, string>([
      ['visitorData', store.visitorData],
      ['poToken', store.poToken],
      ['dataSyncId', store.dataSyncId],
      ['cookie', store.cookie],
      ['ready', store.isReady ? 'true' : 'false']
    ]);
  }

  private delay(ms: number): Promise<void> {
    return new Promise<void>(resolve => setTimeout(resolve, ms));
  }

  /**
   * Extrae poToken ejecutando BotGuard en el WebView.
   * Carga la página del video, hace scroll/interacción para activar BotGuard,
   * y extrae el PO_TOKEN de ytcfg.
   */
  async extractBotGuardPoToken(videoId: string): Promise<string> {
    try {
      this.streamingVideo = videoId;
      if (gIndexSetter) {
        gIndexSetter(true, 500)
        await this.delay(500)
      }
      this.controller.loadUrl(`https://www.youtube.com/watch?v=${videoId}`);
      
      // Esperar carga inicial
      await this.delay(3000);
      
      // Verificar URL actual
      let loc = '';
      try {
        const lr = await this.controller.runJavaScript("location.href");
        loc = (lr || '').toString();
        console.info(`NexusMusic BotGuard: current URL=${loc.substring(0, 100)}`);
      } catch (e) {}
      
      // Verificar si ytcfg existe
      try {
        const ytcfg = await this.controller.runJavaScript("typeof window.ytcfg !== 'undefined'");
        console.info(`NexusMusic BotGuard: ytcfg exists=${ytcfg}`);
      } catch (e) {}
      
      // Ejecutar BotGuard: scroll + click + wait para que se genere el token
      for (let i = 0; i < 4; i++) {
        await this.delay(800);
        try {
          await this.controller.runJavaScript(
            "window.scrollTo(0, document.body.scrollHeight / 2);"
          );
          // Intentar click en botón de play si existe
          await this.controller.runJavaScript(
            "document.querySelector('.ytp-large-play-button')?.click(); " +
            "document.querySelector('button[aria-label*=\"Play\"]')?.click(); " +
            "document.querySelector('video')?.play();"
          );
        } catch (e) {}
      }
      
      // Esperar a que BotGuard complete
      await this.delay(2000);
      
      // Extraer PO_TOKEN de ytcfg (donde BotGuard lo pone)
      let poToken = '';
      console.error(`NexusMusic BotGuard: starting dump loop`);
      const dumpResults: Array<string> = [];
      for (let i = 0; i < 8; i++) {
        await this.delay(800);
        try {
          const result = await this.controller.runJavaScript(
            "(function(){try{var c=window.ytcfg;var out={}; if(c&&c.get){out.PO_TOKEN=c.get('PO_TOKEN'); out.SID=c.get('SERVICE_INTEGRITY_DIMENSIONS'); out.DELEGATED_SESSION_ID=c.get('DELEGATED_SESSION_ID'); out.VISITOR_DATA=c.get('VISITOR_DATA'); out.INNERTUBE_API_KEY=c.get('INNERTUBE_API_KEY');} if(window.ytInitialData&&window.ytInitialData.serviceIntegrityDimensions) out.ytInitialData_SID=window.ytInitialData.serviceIntegrityDimensions; return JSON.stringify(out);}catch(e){return 'err:'+e}})()"
          );
          const text = (result || '').toString().trim();
          dumpResults.push(text);
          if (i === 0) {
            console.error(`NexusMusic BotGuard first dump: ${text.substring(0, 300)}`);
          }

            try {
              const poTokenMatch = text.match(/"PO_TOKEN"\s*:\s*"([^"]{20,})"/);
              if (poTokenMatch) {
                console.error(`NexusMusic BotGuard poToken found len=${poTokenMatch[1].length}`);
                return poTokenMatch[1];
              }
              const sidMatch = text.match(/"SERVICE_INTEGRITY_DIMENSIONS"[^}]*"poToken"\s*:\s*"([^"]{20,})"/);
              if (sidMatch) {
                console.error(`NexusMusic BotGuard poToken in SID len=${sidMatch[1].length}`);
                return sidMatch[1];
              }
              const ytInitialMatch = text.match(/"serviceIntegrityDimensions"[^}]*"poToken"\s*:\s*"([^"]{20,})"/);
              if (ytInitialMatch) {
                console.error(`NexusMusic BotGuard poToken in ytInitialData len=${ytInitialMatch[1].length}`);
                return ytInitialMatch[1];
              }
            } catch (e) {}


















        } catch (e) {
          console.error(`NexusMusic BotGuard dump error ${i}: ${JSON.stringify(e)}`);
        }
      }
      console.error(`NexusMusic BotGuard all dumps: ${JSON.stringify(dumpResults).substring(0, 500)}`);
      
      console.info(`NexusMusic BotGuard poToken NOT found for ${videoId}`);
      return '';
    } catch (e) {
      console.error(`NexusMusic extractBotGuardPoToken error: ${JSON.stringify(e)}`);
      return '';
    } finally {
      this.streamingVideo = '';
      if (gIndexSetter) {
        gIndexSetter(false, 1)
      }
    }
  }
}

export { PoTokenBridge, PoTokenStore };