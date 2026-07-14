import media from '@ohos.multimedia.media';
import avSession from '@ohos.multimedia.avsession';
import image from '@ohos.multimedia.image';
import http from '@ohos.net.http';
import { MethodChannel } from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import wantAgent from '@ohos.wantAgent';

class AudioBridge {
  private player: media.AVPlayer | null = null;
  private isInitialized: boolean = false;
  private callbackChannel: MethodChannel | null = null;
  private lastUrl: string | null = null;
  private isPlaying: boolean = false;
  private isTransitioning: boolean = false;
  private session: avSession.AVSession | null = null;
  private context: common.Context | null = null;
  private sessionActive: boolean = false;
  private currentMetadata: avSession.AVMetadata | null = null;
  private lastSessionUpdate: number = 0;
  private pendingMetadata: avSession.AVMetadata | null = null;

  constructor() {
    this.initPlayer();
  }

  setCallbackChannel(channel: MethodChannel): void {
    this.callbackChannel = channel;
  }

  setContext(context: common.Context): void {
    this.context = context;
  }

  private notify(method: string, args: Object | null): void {
    try {
      this.callbackChannel?.invokeMethod(method, args);
    } catch (e) {
      console.error(`NexusMusic notify error: ${JSON.stringify(e)}`);
    }
  }

  private async initPlayer(): Promise<void> {
    try {
      this.player = await media.createAVPlayer();
      this.player.on('stateChange', (state: media.AVPlayerState) => {
        try {
          this.onStateChange(state);
        } catch (e) {
          console.error(`NexusMusic stateChange handler error: ${JSON.stringify(e)}`);
        }
      });
      this.player.on('timeUpdate', (time: number) => {
        try {
          this.notify('onPositionChanged', time);
          this.refreshSessionPosition();
        } catch (e) {
          console.error(`NexusMusic timeUpdate handler error: ${JSON.stringify(e)}`);
        }
      });
      this.player.on('error', (err) => {
        console.error(`NexusMusic AVPlayer error: ${err.code} ${err.message}`);
        this.sessionActive = false;
      });
      this.isInitialized = true;
    } catch (err) {
      console.error(`NexusMusic initPlayer error: ${JSON.stringify(err)}`);
    }
  }

  private async setupAVSession(): Promise<void> {
    if (!this.context || this.sessionActive) return;
    try {
      this.session = await avSession.createAVSession(this.context, 'Nexus Music', 'audio');

      this.currentMetadata = {
        assetId: 'nexus-music',
        title: 'Nexus Music',
        artist: 'Now Playing'
      };
      this.session.setAVMetadata(this.currentMetadata);

      const playbackState: avSession.AVPlaybackState = {
        state: avSession.PlaybackState.PLAYBACK_STATE_PLAY,
        position: { elapsedTime: 0, updateTime: new Date().getTime() }
      };
      this.session.setAVPlaybackState(playbackState);

      this.session.on('play', () => {
        if (this.player && this.player.state === 'playing') return;
        this.play();
      });
      this.session.on('pause', () => {
        if (this.player && this.player.state !== 'playing') return;
        this.pause();
      });
      this.session.on('stop', () => {
        this.stop();
      });
      this.session.on('playNext', () => {
        this.notify('onCommand', JSON.parse('{"command":"next"}'));
      });
      this.session.on('playPrevious', () => {
        this.notify('onCommand', JSON.parse('{"command":"previous"}'));
      });

      this.session.activate();
      this.sessionActive = true;
      if (this.pendingMetadata) {
        this.applyMetadata();
      }
      this.startBackgroundTask();
    } catch (err) {
      console.error(`NexusMusic AVSession setup error: ${JSON.stringify(err)}`);
    }
  }

  private async startBackgroundTask(): Promise<void> {
    if (!this.context) return;
    try {
      const infoStr = '{"wants":[{"bundleName":"io.github.nexusmusic.app","abilityName":"EntryAbility"}],"operationType":1,"requestCode":0}';
      const agent = await wantAgent.getWantAgent(JSON.parse(infoStr) as ESObject);
      const modes: string[] = ['audioPlayback'];
      await backgroundTaskManager.startBackgroundRunning(
        this.context,
        modes,
        agent
      );
      console.info('NexusMusic background task started');
    } catch (err) {
      console.error(`NexusMusic background task error: ${JSON.stringify(err)}`);
    }
  }

  private onStateChange(state: media.AVPlayerState): void {
    console.info(`NexusMusic AVPlayer state: ${state}`);
    if (state === 'playing') {
      this.isPlaying = true;
      this.notify('onPlayerStateChanged', true);
      this.updateSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PLAY);
    } else if (state === 'paused') {
      this.isPlaying = false;
      this.notify('onPlayerStateChanged', false);
      this.updateSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
    } else if (state === 'completed') {
      this.isPlaying = false;
      this.notify('onPlayerStateChanged', false);
      this.notify('onCompleted', null);
      this.updateSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_COMPLETED);
    } else if (state === 'prepared') {
      if (this.player) {
        const dur = this.player.duration;
        this.notify('onDurationChanged', dur);
        if (this.session && this.sessionActive && dur > 0) {
          if (this.currentMetadata) {
            this.currentMetadata.duration = dur;
            this.session.setAVMetadata(this.currentMetadata);
          }
        }
        this.updateSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PLAY);
      }
    } else if (state === 'stopped' || state === 'idle') {
      this.isPlaying = false;
      this.notify('onPlayerStateChanged', false);
    } else if (state === 'error') {
      this.isPlaying = false;
      this.notify('onPlayerStateChanged', false);
    }
  }

  private async updateSessionPlaybackState(state: avSession.PlaybackState): Promise<void> {
    if (!this.session) return;
    try {
      this.session.setAVPlaybackState({
        state: state,
        position: {
          elapsedTime: this.player ? this.player.currentTime : 0,
          updateTime: new Date().getTime()
        }
      });
    } catch (err) {
      console.error(`NexusMusic updateSessionPlaybackState error: ${JSON.stringify(err)}`);
      this.sessionActive = false;
    }
  }

  private refreshSessionPosition(): void {
    if (!this.session || !this.sessionActive) return;
    if (!this.player || this.player.state !== 'playing') return;
    const now = new Date().getTime();
    if (now - this.lastSessionUpdate < 2000) return;
    this.lastSessionUpdate = now;
    try {
      this.session.setAVPlaybackState({
        state: avSession.PlaybackState.PLAYBACK_STATE_PLAY,
        position: {
          elapsedTime: this.player.currentTime,
          updateTime: now
        }
      });
    } catch (err) {
      console.error(`NexusMusic refreshSessionPosition error: ${JSON.stringify(err)}`);
      this.sessionActive = false;
    }
  }

  private async delay(ms: number): Promise<void> {
    return new Promise<void>(resolve => setTimeout(resolve, ms));
  }

  async play(url?: string): Promise<void> {
    if (!this.player || !this.isInitialized) {
      console.error('NexusMusic player not initialized');
      return;
    }
    const playUrl = url ?? this.lastUrl;
    if (!playUrl) {
      console.error('NexusMusic play: no url');
      return;
    }
    if (this.isTransitioning) {
      console.info('NexusMusic play: already transitioning, requeuing');
      setTimeout(() => { this.play(playUrl); }, 500);
      return;
    }
    this.isTransitioning = true;
    this.lastUrl = playUrl;
    try {
      if (!this.sessionActive && this.context) {
        await this.setupAVSession();
      }
      if (this.player.state === 'paused' && (url === undefined || url === this.lastUrl)) {
        await this.player.play();
        return;
      }
      await this.player.reset();
      await this.delay(300);
      (this.player as ESObject).url = playUrl;
      await this.delay(100);
      await this.player.prepare();
      await this.delay(100);
      await this.player.play();
    } catch (err) {
      console.error(`NexusMusic play error: ${JSON.stringify(err)}`);
      this.notify('onPlayerStateChanged', false);
    } finally {
      this.isTransitioning = false;
    }
  }

  async updateMetadata(title: string, artist: string, imageUrl: string, album?: string, duration?: number): Promise<void> {
    this.pendingMetadata = {
      assetId: 'nexus-music',
      title: title || 'Nexus Music',
      artist: artist || 'Now Playing',
      album: album || '',
      duration: duration || 0,
      mediaImage: imageUrl || undefined,
    };
    if (this.session) {
      this.applyMetadata();
    }
  }

  private applyMetadata(): void {
    if (!this.session || !this.pendingMetadata) return;
    try {
      this.currentMetadata = this.pendingMetadata;
      this.session.setAVMetadata(this.currentMetadata);
      const imageUrl = typeof this.currentMetadata.mediaImage === 'string' ? this.currentMetadata.mediaImage : '';
      if (imageUrl) {
        this.downloadAndSetImage(imageUrl);
      }
    } catch (err) {
      console.error(`NexusMusic applyMetadata error: ${JSON.stringify(err)}`);
      this.sessionActive = false;
    }
  }

  private async downloadAndSetImage(imageUrl: string): Promise<void> {
    if (!this.session) return;
    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(imageUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
      });
      const imageData = response.result as ArrayBuffer;
      const imageSource = image.createImageSource(imageData);
      const pixelMap = await imageSource.createPixelMap();
      if (this.currentMetadata) {
        this.currentMetadata.mediaImage = pixelMap;
        this.session.setAVMetadata(this.currentMetadata);
      }
      imageSource.release();
      httpRequest.destroy();
    } catch (imgErr) {
      console.error(`NexusMusic download image error: ${JSON.stringify(imgErr)}`);
    }
  }

  async pause(): Promise<void> {
    if (this.player && this.isInitialized) {
      await this.player.pause();
    }
  }

  async stop(): Promise<void> {
    if (this.player && this.isInitialized) {
      await this.player.stop();
    }
  }

  async seek(positionMs: number): Promise<void> {
    if (this.player && this.isInitialized) {
      await this.player.seek(positionMs);
    }
  }

  setVolume(volume: number): void {
    if (this.player && this.isInitialized) {
      this.player.setVolume(volume);
    }
  }

  getCurrentTime(): number {
    return this.player?.currentTime ?? 0;
  }

  getDuration(): number {
    return this.player?.duration ?? 0;
  }

  release(): void {
    if (this.context) {
      try {
        backgroundTaskManager.stopBackgroundRunning(this.context, () => {});
      } catch (e) {
        console.error(`NexusMusic stopBackgroundTask error: ${JSON.stringify(e)}`);
      }
    }
    if (this.session) {
      this.session.destroy();
      this.session = null;
      this.sessionActive = false;
    }
    if (this.player) {
      this.player.release();
      this.isInitialized = false;
    }
  }
}

export default AudioBridge;
