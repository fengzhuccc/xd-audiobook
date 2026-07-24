import { common } from '@kit.AbilityKit';
import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { LogUtil } from '../common/utils/LogUtil';
import { TTS_DEFAULTS } from '../common/constants/ReaderConstants';
import {
  ITtsEngine,
  TtsEngineEventCallback,
  TtsEngineInitParams,
  TtsEngineState
} from './ITtsEngine';

export interface VoiceOption {
  person: number;
  name: string;
  description: string;
}

/**
 * 基于 HarmonyOS Core SpeechKit 的系统 TTS 引擎。
 */
export class SpeechKitTtsEngine implements ITtsEngine {
  private isInited: boolean = false;
  private state: TtsEngineState = 'idle';
  private ttsEngine: textToSpeech.TextToSpeechEngine | null = null;
  private speed: number = 1.0;
  private voicePerson: number = TTS_DEFAULTS.VOICE_PERSON;
  private currentRequestId: string = '';
  private eventCallback: TtsEngineEventCallback | null = null;

  setEventCallback(callback: TtsEngineEventCallback | null): void {
    this.eventCallback = callback;
  }

  async init(params: TtsEngineInitParams): Promise<void> {
    if (this.isInited) {
      return;
    }
    this.speed = params.speed ?? 1.0;
    this.voicePerson = params.voice ? Number(params.voice) : TTS_DEFAULTS.VOICE_PERSON;

    try {
      this.ttsEngine = await this.createEngine();
      this.setupListener();
      this.isInited = true;
      this.state = 'idle';
      LogUtil.info('SpeechKitTtsEngine initialized');
    } catch (err) {
      const e = err as BusinessError;
      this.state = 'error';
      this.emitState();
      this.emitError(`TTS 初始化失败: ${e.message}`);
      throw new Error(String(e.message));
    }
  }

  private createEngine(): Promise<textToSpeech.TextToSpeechEngine> {
    return new Promise((resolve, reject) => {
      const initParams: textToSpeech.CreateEngineParams = {
        language: 'zh-CN',
        person: this.voicePerson,
        online: 1,
        extraParams: {
          style: 'interaction-broadcast',
          locate: 'CN',
          name: 'AudioBookTTS'
        }
      };
      textToSpeech.createEngine(initParams, (err: BusinessError, engine: textToSpeech.TextToSpeechEngine) => {
        if (err) {
          LogUtil.error(`Failed to create TTS engine with person=${this.voicePerson}: ${err.code} ${err.message}`);
          if (this.voicePerson !== TTS_DEFAULTS.VOICE_PERSON) {
            LogUtil.warn(`Fallback to default voice person=${TTS_DEFAULTS.VOICE_PERSON}`);
            this.voicePerson = TTS_DEFAULTS.VOICE_PERSON;
            this.createEngine().then(resolve).catch(reject);
          } else {
            reject(err);
          }
        } else {
          LogUtil.info(`TTS engine created with person=${this.voicePerson}`);
          resolve(engine);
        }
      });
    });
  }

  /**
   * 查询设备当前支持的音色列表。
   */
  static getAvailableVoices(context: common.UIAbilityContext): Promise<VoiceOption[]> {
    return new Promise((resolve, reject) => {
      const initParams: textToSpeech.CreateEngineParams = {
        language: 'zh-CN',
        person: 0,
        online: 1,
        extraParams: {
          style: 'interaction-broadcast',
          locate: 'CN',
          name: 'AudioBookVoiceQuery'
        }
      };
      textToSpeech.createEngine(initParams, async (err: BusinessError, engine: textToSpeech.TextToSpeechEngine) => {
        if (err) {
          LogUtil.error(`Failed to create temp TTS engine for voice query: ${err.code} ${err.message}`);
          reject(err);
          return;
        }
        try {
          const query: textToSpeech.VoiceQuery = {
            requestId: `voice-query-${Date.now()}`,
            online: 1
          };
          const voices = await engine.listVoices(query);
          const options: VoiceOption[] = voices
            .filter((v) => v.status === 'GA')
            .map((v): VoiceOption => ({
              person: v.person,
              name: v.description || `${v.language}-${v.person}`,
              description: v.description || ''
            }));
          LogUtil.info(`Available TTS voices: ${options.map((o) => `${o.person}:${o.name}`).join(', ')}`);
          resolve(options);
        } catch (listErr) {
          LogUtil.error(`Failed to list voices: ${(listErr as BusinessError).message}`);
          reject(listErr);
        } finally {
          try {
            engine.shutdown();
          } catch (e) {
            LogUtil.warn(`Failed to shutdown temp TTS engine: ${JSON.stringify(e)}`);
          }
        }
      });
    });
  }

  private setupListener(): void {
    if (!this.ttsEngine) {
      return;
    }
    const listener: textToSpeech.SpeakListener = {
      onStart: (requestId: string) => {
        if (requestId !== this.currentRequestId) {
          return;
        }
        LogUtil.info(`TTS onStart: ${requestId}`);
        if (this.state === 'playing') {
          this.eventCallback?.onStart?.();
        }
      },
      onComplete: (requestId: string, response: textToSpeech.CompleteResponse) => {
        if (requestId !== this.currentRequestId) {
          return;
        }
        LogUtil.info(`TTS onComplete: ${requestId}, type=${response.type}`);
        if (response.type !== 1) {
          return;
        }
        this.eventCallback?.onComplete?.();
      },
      onStop: (requestId: string) => {
        if (requestId !== this.currentRequestId) {
          return;
        }
        LogUtil.info(`TTS onStop: ${requestId}`);
      },
      onData: () => {
        // 不自行处理音频流，由引擎直接播报
      },
      onError: (requestId: string, errorCode: number, errorMessage: string) => {
        if (requestId !== this.currentRequestId) {
          return;
        }
        LogUtil.error(`TTS onError: ${requestId}, ${errorCode}, ${errorMessage}`);
        if (this.state === 'playing') {
          this.state = 'error';
          this.emitState();
          this.emitError(`朗读出错: ${errorMessage}`);
        }
      }
    };
    this.ttsEngine.setListener(listener);
  }

  speak(text: string, requestId: string): void {
    if (!this.ttsEngine) {
      return;
    }
    this.currentRequestId = requestId;
    this.state = 'playing';
    this.emitState();
    const speakParams: textToSpeech.SpeakParams = {
      requestId: this.currentRequestId,
      extraParams: { speed: this.speed }
    };
    this.ttsEngine.speak(text, speakParams);
  }

  stop(): void {
    try {
      this.ttsEngine?.stop();
    } catch (e) {
      LogUtil.warn(`TTS stop failed: ${JSON.stringify(e)}`);
    }
  }

  pause(): void {
    // SpeechKit 没有独立 pause，用 stop 模拟
    this.stop();
    this.state = 'paused';
    this.emitState();
  }

  resume(): void {
    this.state = 'idle';
    this.emitState();
  }

  setSpeed(speed: number): void {
    this.speed = speed;
  }

  async setVoice(voice: string): Promise<void> {
    const person = Number(voice);
    if (this.voicePerson === person) {
      return;
    }
    this.voicePerson = person;
    if (!this.isInited || !this.ttsEngine) {
      return;
    }

    try {
      this.stop();
      this.ttsEngine.shutdown();
      this.ttsEngine = null;
      this.isInited = false;
      this.currentRequestId = '';

      this.ttsEngine = await this.createEngine();
      this.setupListener();
      this.isInited = true;
    } catch (err) {
      this.state = 'error';
      this.emitState();
      this.emitError(`切换音色失败: ${(err as BusinessError).message}`);
    }
  }

  release(): void {
    try {
      this.ttsEngine?.stop();
      this.ttsEngine?.shutdown();
    } catch (e) {
      LogUtil.warn(`TTS release failed: ${JSON.stringify(e)}`);
    }
    this.ttsEngine = null;
    this.isInited = false;
    this.state = 'idle';
    this.currentRequestId = '';
    LogUtil.info('SpeechKitTtsEngine released');
  }

  private emitState(): void {
    this.eventCallback?.onStateChange?.(this.state);
  }

  private emitError(message: string): void {
    this.eventCallback?.onError?.(message);
  }
}
