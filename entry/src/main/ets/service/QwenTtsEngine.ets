import { common } from '@kit.AbilityKit';
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { LogUtil } from '../common/utils/LogUtil';
import {
  ITtsEngine,
  TtsEngineEventCallback,
  TtsEngineInitParams,
  TtsEngineState
} from './ITtsEngine';

// 纯 C 引擎 NAPI 模块。需要在 entry/src/main/cpp 中编译 libqwentts.so
import qwentts from 'libqwentts.so';

export interface QwenVoiceOption {
  name: string;
  description: string;
  language: string;
}

/**
 * Qwen3-TTS 本地 TTS 引擎（基于纯 C 推理引擎 + NAPI）。
 * 每句合成一个 WAV 文件，然后用 AVPlayer 播放。
 */
export class QwenTtsEngine implements ITtsEngine {
  private isInited: boolean = false;
  private state: TtsEngineState = 'idle';
  private modelDir: string = '';
  private voice: string = 'Serena';
  private language: string = 'Chinese';
  private speed: number = 1.0;
  private context: common.UIAbilityContext | null = null;
  private avPlayer: media.AVPlayer | null = null;
  private eventCallback: TtsEngineEventCallback | null = null;
  private currentRequestId: string = '';
  private pendingRelease: boolean = false;

  // 纯 C 引擎 CustomVoice 0.6B 支持的 9 个预设音色（参考 docs/speaker-map.md）
  static readonly VOICES: QwenVoiceOption[] = [
    { name: 'Serena', description: '中文女声', language: 'Chinese' },
    { name: 'Vivian', description: '中文女声（温柔）', language: 'Chinese' },
    { name: 'ryan', description: '英文男声', language: 'English' },
    { name: 'Ono_Anna', description: '日文女声', language: 'Japanese' },
  ];

  setEventCallback(callback: TtsEngineEventCallback | null): void {
    this.eventCallback = callback;
  }

  async init(params: TtsEngineInitParams): Promise<void> {
    if (this.isInited) {
      return;
    }
    this.context = params.context;
    this.speed = params.speed ?? 1.0;
    this.voice = params.voice ?? 'Serena';
    this.language = this.resolveLanguage(this.voice);

    // 模型目录默认放在应用 filesDir 下的 qwen3-tts-model
    this.modelDir = params.modelDir ?? `${params.context.filesDir}/qwen3-tts-model`;

    if (!this.ensureModelDir()) {
      throw new Error(`模型目录不存在: ${this.modelDir}`);
    }

    const binaryPath = `${params.context.filesDir}/qwen_tts`;
    await this.ensureExecutableBinary(binaryPath);

    try {
      // 初始化原生引擎（传入可执行文件路径和模型目录）
      const result: number = qwentts.init(binaryPath, this.modelDir);
      if (result !== 0) {
        throw new Error(`原生引擎初始化失败，错误码: ${result}`);
      }
      this.isInited = true;
      this.state = 'idle';
      LogUtil.info(`QwenTtsEngine initialized, binary=${binaryPath}, modelDir=${this.modelDir}`);
    } catch (err) {
      this.state = 'error';
      this.emitState();
      const message = err instanceof Error ? err.message : String(err);
      this.emitError(`Qwen TTS 初始化失败: ${message}`);
      throw new Error(message);
    }
  }

  /**
   * 确保 qwen_tts 可执行文件存在且有执行权限。
   * 首次会从 rawfile 复制到 filesDir，然后通过 NAPI chmod。
   */
  private async ensureExecutableBinary(binaryPath: string): Promise<void> {
    try {
      const stat = fileIo.statSync(binaryPath);
      if (stat.isFile()) {
        LogUtil.info(`qwen_tts binary already exists: ${binaryPath}`);
        return;
      }
    } catch (e) {
      // 文件不存在，继续复制
    }

    if (!this.context) {
      throw new Error('context is null');
    }

    LogUtil.info('Copying qwen_tts binary from rawfile...');
    const resMgr = this.context.resourceManager;
    const rawData = await resMgr.getRawFileContent('qwen_tts');

    const tmpPath = `${binaryPath}.tmp`;
    const file = fileIo.openSync(tmpPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
    fileIo.writeSync(file.fd, rawData.buffer);
    fileIo.closeSync(file);

    const result: number = qwentts.prepareBinary(tmpPath, binaryPath);
    if (result !== 0) {
      throw new Error(`prepareBinary failed, code=${result}`);
    }

    try {
      fileIo.unlinkSync(tmpPath);
    } catch (e) {
      LogUtil.warn(`Failed to delete temp binary: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 确保模型目录存在。实际模型文件需要用户/打包流程提前放入。
   */
  private ensureModelDir(): boolean {
    try {
      const stat = fileIo.statSync(this.modelDir);
      return stat.isDirectory();
    } catch (e) {
      LogUtil.warn(`Model dir not found: ${this.modelDir}`);
      return false;
    }
  }

  /**
   * 根据音色名推断语言。用户也可后续通过设置覆盖。
   */
  private resolveLanguage(voice: string): string {
    const option = QwenTtsEngine.VOICES.find((v) => v.name === voice);
    return option?.language ?? 'Chinese';
  }

  /**
   * 合成并播放一句文本。
   */
  speak(text: string, requestId: string): void {
    if (!this.isInited || !this.context) {
      return;
    }
    this.currentRequestId = requestId;
    this.state = 'playing';
    this.emitState();

    const outputPath = `${this.context.cacheDir}/qwen_tts_${Date.now()}.wav`;

    qwentts.synthesize(text, this.voice, this.language, outputPath)
      .then(() => {
        if (this.pendingRelease) {
          return;
        }
        this.playAudio(outputPath);
      })
      .catch((err: Error) => {
        LogUtil.error(`Qwen synthesize failed: ${err.message}`);
        this.state = 'error';
        this.emitState();
        this.emitError(`合成失败: ${err.message}`);
      });
  }

  private async playAudio(path: string): Promise<void> {
    try {
      this.avPlayer = await media.createAVPlayer();
      const fd = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const fdPath = `fd://${fd.fd}`;

      this.avPlayer.on('stateChange', (state: media.AVPlayerState) => {
        LogUtil.info(`AVPlayer state: ${state}`);
        if (state === 'playing') {
          this.eventCallback?.onStart?.();
        }
      });

      this.avPlayer.on('error', (err: BusinessError) => {
        LogUtil.error(`AVPlayer error: ${err.code} ${err.message}`);
        this.state = 'error';
        this.emitState();
        this.emitError(`播放失败: ${err.message}`);
      });

      this.avPlayer.on('eof', () => {
        LogUtil.info('AVPlayer eof');
        this.eventCallback?.onComplete?.();
        this.cleanupPlayer(path);
      });

      // fdSrc 是 HarmonyOS AVPlayer 推荐的本地文件播放方式
      this.avPlayer.fdSrc = { fd: fd.fd };
      await this.avPlayer.prepare();
      fileIo.closeSync(fd);
      await this.avPlayer.play();
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      LogUtil.error(`AVPlayer play failed: ${message}`);
      this.state = 'error';
      this.emitState();
      this.emitError(`播放失败: ${message}`);
    }
  }

  private cleanupPlayer(path?: string): void {
    try {
      this.avPlayer?.stop();
      this.avPlayer?.release();
    } catch (e) {
      LogUtil.warn(`AVPlayer cleanup failed: ${JSON.stringify(e)}`);
    }
    this.avPlayer = null;
    if (path) {
      try {
        fileIo.unlinkSync(path);
      } catch (e) {
        LogUtil.warn(`Failed to delete temp wav: ${JSON.stringify(e)}`);
      }
    }
  }

  stop(): void {
    this.cleanupPlayer();
    this.state = 'stopped';
    this.emitState();
  }

  pause(): void {
    try {
      this.avPlayer?.pause();
      this.state = 'paused';
      this.emitState();
    } catch (e) {
      LogUtil.warn(`AVPlayer pause failed: ${JSON.stringify(e)}`);
    }
  }

  resume(): void {
    try {
      this.avPlayer?.play();
      this.state = 'playing';
      this.emitState();
    } catch (e) {
      LogUtil.warn(`AVPlayer resume failed: ${JSON.stringify(e)}`);
    }
  }

  setSpeed(speed: number): void {
    // Qwen 引擎原生没有语速控制，先记录；后续可做音频后处理
    this.speed = speed;
    LogUtil.info(`QwenTtsEngine setSpeed: ${speed} (reserved)`);
  }

  async setVoice(voice: string): Promise<void> {
    if (this.voice === voice) {
      return;
    }
    this.voice = voice;
    this.language = this.resolveLanguage(voice);
    LogUtil.info(`QwenTtsEngine setVoice: ${voice}, language=${this.language}`);
  }

  release(): void {
    this.pendingRelease = true;
    this.cleanupPlayer();
    try {
      qwentts.release();
    } catch (e) {
      LogUtil.warn(`Qwen native release failed: ${JSON.stringify(e)}`);
    }
    this.isInited = false;
    this.state = 'idle';
    this.pendingRelease = false;
    LogUtil.info('QwenTtsEngine released');
  }

  private emitState(): void {
    this.eventCallback?.onStateChange?.(this.state);
  }

  private emitError(message: string): void {
    this.eventCallback?.onError?.(message);
  }
}
