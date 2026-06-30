import { window } from '@kit.ArkUI';
import { avPlayer } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';

class AudioBridge {
  private player: avPlayer.AVPlayer | null = null;
  private isInitialized: boolean = false;

  constructor() {
    this.initPlayer();
  }

  private async initPlayer(): Promise<void> {
    try {
      const audioManager = audio.getAudioManager();
      const audioRendererInfo: audio.AudioRendererInfo = {
        usage: audio.AudioUsageType.USAGE_MEDIA,
        rendererFlags: 0
      };
      this.player = await avPlayer.createAVPlayer();
      this.player.on('stateChange', (state: avPlayer.AVPlayerState) => {
        console.info(`NexusMusic AVPlayer state: ${state}`);
      });
      this.isInitialized = true;
    } catch (err) {
      console.error(`NexusMusic initPlayer error: ${err.message}`);
    }
  }

  async play(url: string): Promise<void> {
    if (!this.player || !this.isInitialized) {
      console.error('NexusMusic player not initialized');
      return;
    }
    try {
      await this.player.reset();
      await this.player.setFdSrc(url);
      await this.player.prepare();
      await this.player.play();
    } catch (err) {
      console.error(`NexusMusic play error: ${err.message}`);
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
