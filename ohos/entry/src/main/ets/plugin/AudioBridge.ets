import media from '@ohos.multimedia.media';
import { MethodChannel } from '@ohos/flutter_ohos';

class AudioBridge {
  private player: media.AVPlayer | null = null;
  private isInitialized: boolean = false;
  private callbackChannel: MethodChannel | null = null;
  private lastUrl: string | null = null;
  private isPlaying: boolean = false;

  constructor() {
    this.initPlayer();
  }

  setCallbackChannel(channel: MethodChannel): void {
    this.callbackChannel = channel;
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
        this.onStateChange(state);
      });
      this.player.on('timeUpdate', (time: number) => {
        if (this.isPlaying) {
          this.notify('onPositionChanged', time);
        }
      });
      this.isInitialized = true;
    } catch (err) {
      console.error(`NexusMusic initPlayer error: ${JSON.stringify(err)}`);
    }
  }

  private onStateChange(state: media.AVPlayerState): void {
    console.info(`NexusMusic AVPlayer state: ${state}`);
    if (state === 'playing') {
      this.isPlaying = true;
      this.notify('onPlayerStateChanged', true);
    } else if (state === 'paused') {
      this.isPlaying = false;
      this.notify('onPlayerStateChanged', false);
    } else if (state === 'completed') {
      this.isPlaying = false;
      this.notify('onPlayerStateChanged', false);
      this.notify('onCompleted', null);
    } else if (state === 'prepared') {
      if (this.player) {
        this.notify('onDurationChanged', this.player.duration);
      }
    } else if (state === 'error') {
      this.isPlaying = false;
      this.notify('onPlayerStateChanged', false);
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
    this.lastUrl = playUrl;
    try {
      await this.player.reset();
      // Wait for player to reach idle state before setting URL, otherwise
      // AVPlayer throws 5400102 (operation not allowed in current state)
      await this.delay(300);
      (this.player as ESObject).url = playUrl;
      await this.delay(100);
      await this.player.prepare();
      await this.delay(100);
      await this.player.play();
    } catch (err) {
      console.error(`NexusMusic play error: ${JSON.stringify(err)}`);
      this.notify('onPlayerStateChanged', false);
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
    if (this.player) {
      this.player.release();
      this.isInitialized = false;
    }
  }
}

export default AudioBridge;
