import { common } from '@kit.AbilityKit';
import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { LogUtil } from '../common/utils/LogUtil';
import { TTS_DEFAULTS } from '../common/constants/ReaderConstants';
import { IBookParserHandler, htmlToPlainText } from './BookParser';

export type TtsState = 'idle' | 'playing' | 'paused' | 'stopped' | 'error';

export interface TtsEventCallback {
  onStateChange?: (state: TtsState) => void;
  onChapterLoaded?: (spineIndex: number, sentences: string[]) => void;
  onSentenceChange?: (spineIndex: number, sentenceIndex: number) => void;
  onChapterChange?: (spineIndex: number) => void;
  onError?: (message: string) => void;
}

export interface VoiceOption {
  person: number;
  name: string;
  description: string;
}

/**
 * 朗读服务（基于 HarmonyOS Core Speech Kit 的 textToSpeech 实现）。
 * 将章节文本按句拆分后逐句合成播报，并通过回调把状态/进度同步给 UI。
 */
export class TtsService {
  private isInited: boolean = false;
  private state: TtsState = 'idle';
  private ttsEngine: textToSpeech.TextToSpeechEngine | null = null;
  private bookParserHandler: IBookParserHandler | null = null;
  private currentSpineIndex: number = 0;
  private bookTitle: string = '';
  private bookAuthor: string = '';

  private sentences: string[] = [];
  private currentSentenceIndex: number = 0;
  private speed: number = 1.0;
  private voicePerson: number = TTS_DEFAULTS.VOICE_PERSON;
  private currentRequestId: string = '';
  private pendingAction: 'none' | 'pause' | 'stop' | 'speed' = 'none';
  private eventCallback: TtsEventCallback | null = null;

  setEventCallback(callback: TtsEventCallback | null): void {
    this.eventCallback = callback;
  }

  private emitState(): void {
    this.eventCallback?.onStateChange?.(this.state);
  }

  private emitChapterLoaded(): void {
    this.eventCallback?.onChapterLoaded?.(this.currentSpineIndex, this.sentences);
  }

  private emitSentenceChange(): void {
    this.eventCallback?.onSentenceChange?.(this.currentSpineIndex, this.currentSentenceIndex);
  }

  private emitChapterChange(): void {
    this.eventCallback?.onChapterChange?.(this.currentSpineIndex);
  }

  private emitError(message: string): void {
    this.eventCallback?.onError?.(message);
  }

  async init(context: common.UIAbilityContext, bookTitle: string, bookAuthor: string, voicePerson?: number): Promise<void> {
    if (this.isInited) {
      return;
    }
    this.bookTitle = bookTitle;
    this.bookAuthor = bookAuthor;
    if (voicePerson !== undefined) {
      this.voicePerson = voicePerson;
    }
    try {
      this.ttsEngine = await this.createEngine();
      this.setupListener();
      this.isInited = true;
      this.state = 'idle';
      LogUtil.info('TtsService initialized with SpeechKit');
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
          // 如果用户选择的音色创建失败，尝试回退到默认音色
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
   * 查询设备当前支持的音色列表（需要临时创建一个引擎实例）。
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
      onStart: (requestId: string, response: textToSpeech.StartResponse) => {
        if (requestId !== this.currentRequestId) {
          return;
        }
        LogUtil.info(`TTS onStart: ${requestId}`);
        if (this.pendingAction === 'none') {
          this.state = 'playing';
          this.emitState();
        }
      },
      onComplete: (requestId: string, response: textToSpeech.CompleteResponse) => {
        if (requestId !== this.currentRequestId) {
          return;
        }
        // type: 0 合成结束；1 播报结束。只在真正播完后再切到下一句
        LogUtil.info(`TTS onComplete: ${requestId}, type=${response.type}`);
        if (response.type !== 1) {
          return;
        }
        this.handleSpeakComplete();
      },
      onStop: (requestId: string, response: textToSpeech.StopResponse) => {
        if (requestId !== this.currentRequestId) {
          return;
        }
        LogUtil.info(`TTS onStop: ${requestId}, pending=${this.pendingAction}`);
        this.pendingAction = 'none';
      },
      onData: (requestId: string, audio: ArrayBuffer, response: textToSpeech.SynthesisResponse) => {
        // 不自行处理音频流，由引擎直接播报
      },
      onError: (requestId: string, errorCode: number, errorMessage: string) => {
        if (requestId !== this.currentRequestId) {
          return;
        }
        LogUtil.error(`TTS onError: ${requestId}, ${errorCode}, ${errorMessage}`);
        this.pendingAction = 'none';
        if (this.state === 'playing') {
          this.state = 'error';
          this.emitState();
          this.emitError(`朗读出错: ${errorMessage}`);
        }
      }
    };
    this.ttsEngine.setListener(listener);
  }

  private handleSpeakComplete(): void {
    if (this.pendingAction !== 'none') {
      this.pendingAction = 'none';
      return;
    }
    if (this.state !== 'playing') {
      return;
    }
    this.currentSentenceIndex++;
    if (this.currentSentenceIndex >= this.sentences.length) {
      this.playNextChapter();
      return;
    }
    this.emitSentenceChange();
    this.speakCurrentSentence();
  }

  async startReading(handler: IBookParserHandler, spineIndex: number): Promise<void> {
    if (!this.isInited || !handler) {
      return;
    }
    this.stopInternal('none');
    this.bookParserHandler = handler;
    this.currentSpineIndex = spineIndex;
    this.currentSentenceIndex = 0;
    this.state = 'playing';
    this.pendingAction = 'none';
    try {
      await this.loadChapterSentences();
      this.emitChapterLoaded();
      this.emitChapterChange();
      this.emitState();
      this.emitSentenceChange();
      if (this.sentences.length > 0) {
        this.speakCurrentSentence();
      } else {
        this.playNextChapter();
      }
    } catch (err) {
      LogUtil.error(`startReading failed: ${JSON.stringify(err)}`);
      this.state = 'error';
      this.emitState();
    }
  }

  private async loadChapterSentences(): Promise<void> {
    if (!this.bookParserHandler) {
      this.sentences = [];
      return;
    }
    const rawContent = await this.bookParserHandler.getSpineItemContent(this.currentSpineIndex);
    const plainText = rawContent.includes('<') ? htmlToPlainText(rawContent) : rawContent;
    // 将换行统一为句末标点，便于按句拆分
    const normalized = plainText.replace(/\n+/g, '。').replace(/\s+/g, '');
    const matches = normalized.match(/[^。！？.?!]+[。！？.?!]?/g);
    this.sentences = matches ? matches.filter((s) => s.trim().length > 0) : [];
  }

  private speakCurrentSentence(): void {
    if (!this.ttsEngine || this.currentSentenceIndex >= this.sentences.length) {
      return;
    }
    const text = this.sentences[this.currentSentenceIndex];
    this.currentRequestId = `${this.currentSpineIndex}-${this.currentSentenceIndex}-${Date.now()}`;
    LogUtil.info(`TTS speak: ${text.substring(0, 40)}...`);
    this.pendingAction = 'none';
    const speakParams: textToSpeech.SpeakParams = {
      requestId: this.currentRequestId,
      extraParams: { speed: this.speed }
    };
    this.ttsEngine.speak(text, speakParams);
  }

  pause(): void {
    if (this.state !== 'playing') {
      return;
    }
    this.state = 'paused';
    this.pendingAction = 'pause';
    this.stopEngine();
    this.emitState();
  }

  resume(): void {
    if (this.state !== 'paused') {
      return;
    }
    this.state = 'playing';
    this.pendingAction = 'none';
    this.emitState();
    this.speakCurrentSentence();
  }

  stop(): void {
    this.stopInternal('stop');
  }

  private stopInternal(action: 'none' | 'pause' | 'stop' | 'speed'): void {
    this.pendingAction = action;
    this.stopEngine();
    if (action === 'stop') {
      this.state = 'stopped';
      this.currentSentenceIndex = 0;
    } else if (action === 'pause') {
      this.state = 'paused';
    }
    this.emitState();
  }

  private stopEngine(): void {
    try {
      this.ttsEngine?.stop();
    } catch (e) {
      LogUtil.warn(`TTS stop failed: ${JSON.stringify(e)}`);
    }
  }

  playPrevChapter(): void {
    if (!this.bookParserHandler || this.currentSpineIndex <= 0) {
      return;
    }
    this.startReading(this.bookParserHandler, this.currentSpineIndex - 1);
  }

  playNextChapter(): void {
    if (!this.bookParserHandler) {
      return;
    }
    const spineList = this.bookParserHandler.getSpineList();
    if (this.currentSpineIndex >= spineList.length - 1) {
      this.state = 'stopped';
      this.emitState();
      LogUtil.info('Already at last chapter');
      return;
    }
    this.startReading(this.bookParserHandler, this.currentSpineIndex + 1);
  }

  getState(): TtsState {
    return this.state;
  }

  getCurrentSpineIndex(): number {
    return this.currentSpineIndex;
  }

  getVoicePerson(): number {
    return this.voicePerson;
  }

  async setVoicePerson(person: number): Promise<void> {
    if (this.voicePerson === person) {
      return;
    }
    this.voicePerson = person;
    LogUtil.info(`TTS setVoicePerson: ${person}`);
    if (!this.isInited || !this.ttsEngine) {
      return;
    }

    const wasPlaying = this.state === 'playing';
    const savedHandler = this.bookParserHandler;
    const savedSpineIndex = this.currentSpineIndex;
    const savedSentenceIndex = this.currentSentenceIndex;
    const savedSentences = this.sentences.slice();

    try {
      this.stopEngine();
      this.ttsEngine.shutdown();
      this.ttsEngine = null;
      this.isInited = false;
      this.pendingAction = 'none';
      this.currentRequestId = '';

      this.ttsEngine = await this.createEngine();
      this.setupListener();
      this.isInited = true;

      // 恢复播放上下文
      this.bookParserHandler = savedHandler;
      this.currentSpineIndex = savedSpineIndex;
      this.sentences = savedSentences;
      this.currentSentenceIndex = savedSentenceIndex;

      if (wasPlaying) {
        this.state = 'playing';
        this.emitState();
        this.speakCurrentSentence();
      }
    } catch (err) {
      this.state = 'error';
      this.emitState();
      this.emitError(`切换音色失败: ${(err as BusinessError).message}`);
    }
  }

  setSpeed(speed: number): void {
    this.speed = speed;
    LogUtil.info(`TTS setSpeed: ${speed}`);
    if (this.state === 'playing') {
      this.stopInternal('speed');
      this.state = 'playing';
      this.pendingAction = 'none';
      this.speakCurrentSentence();
      this.emitState();
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
    this.bookParserHandler = null;
    this.eventCallback = null;
    this.currentRequestId = '';
    LogUtil.info('TTS resources released');
  }
}
