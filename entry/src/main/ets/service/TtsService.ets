import { common } from '@kit.AbilityKit';
import { LogUtil } from '../common/utils/LogUtil';
import { TTS_DEFAULTS } from '../common/constants/ReaderConstants';
import { IBookParserHandler, htmlToPlainText } from './BookParser';
import { ITtsEngine, TtsEngineEventCallback, TtsEngineState, TtsEngineType } from './ITtsEngine';
import { SpeechKitTtsEngine, VoiceOption } from './SpeechKitTtsEngine';
import { QwenTtsEngine } from './QwenTtsEngine';

export type TtsState = TtsEngineState;
export type { TtsEngineType } from './ITtsEngine';

export interface TtsEventCallback {
  onStateChange?: (state: TtsState) => void;
  onChapterLoaded?: (spineIndex: number, sentences: string[]) => void;
  onSentenceChange?: (spineIndex: number, sentenceIndex: number) => void;
  onChapterChange?: (spineIndex: number) => void;
  onError?: (message: string) => void;
}

/**
 * 朗读服务。
 * 根据设置选择系统 TTS（SpeechKit）或本地 Qwen3-TTS 引擎，
 * 将章节文本按句拆分后逐句合成播报。
 */
export class TtsService {
  private isInited: boolean = false;
  private state: TtsState = 'idle';
  private context: common.UIAbilityContext | null = null;
  private engine: ITtsEngine | null = null;
  private engineType: TtsEngineType = 'system';
  private bookParserHandler: IBookParserHandler | null = null;
  private currentSpineIndex: number = 0;
  private bookTitle: string = '';
  private bookAuthor: string = '';

  private sentences: string[] = [];
  private currentSentenceIndex: number = 0;
  private speed: number = 1.0;
  private voice: string = `${TTS_DEFAULTS.VOICE_PERSON}`;
  private currentRequestId: string = '';
  private pendingAction: 'none' | 'pause' | 'stop' | 'speed' = 'none';
  private eventCallback: TtsEventCallback | null = null;

  setEventCallback(callback: TtsEventCallback | null): void {
    this.eventCallback = callback;
  }

  async init(
    context: common.UIAbilityContext,
    bookTitle: string,
    bookAuthor: string,
    options?: { voicePerson?: number; engineType?: TtsEngineType }
  ): Promise<void> {
    if (this.isInited) {
      return;
    }
    this.context = context;
    this.bookTitle = bookTitle;
    this.bookAuthor = bookAuthor;
    this.engineType = options?.engineType ?? 'system';
    this.voice = options?.voicePerson !== undefined ? `${options.voicePerson}` : `${TTS_DEFAULTS.VOICE_PERSON}`;

    try {
      this.engine = await this.createEngine(context);
      this.isInited = true;
      this.state = 'idle';
      LogUtil.info(`TtsService initialized, engineType=${this.engineType}`);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      this.state = 'error';
      this.emitState();
      this.emitError(`TTS 初始化失败: ${message}`);
      throw new Error(message);
    }
  }

  private async createEngine(context: common.UIAbilityContext): Promise<ITtsEngine> {
    const engineCallback: TtsEngineEventCallback = {
      onStateChange: (state: TtsEngineState) => {
        this.state = state;
        this.emitState();
      },
      onStart: () => {
        if (this.pendingAction === 'none' && this.state !== 'playing') {
          this.state = 'playing';
          this.emitState();
        }
      },
      onComplete: () => {
        this.handleSpeakComplete();
      },
      onError: (message: string) => {
        this.pendingAction = 'none';
        this.emitError(message);
      }
    };

    if (this.engineType === 'qwen') {
      const qwenEngine = new QwenTtsEngine();
      qwenEngine.setEventCallback(engineCallback);
      await qwenEngine.init({
        context,
        voice: this.voice,
        speed: this.speed
      });
      return qwenEngine;
    }

    const speechEngine = new SpeechKitTtsEngine();
    speechEngine.setEventCallback(engineCallback);
    await speechEngine.init({
      context,
      voice: this.voice,
      speed: this.speed
    });
    return speechEngine;
  }

  /**
   * 查询设备当前支持的系统音色列表。
   */
  static getAvailableVoices(context: common.UIAbilityContext): Promise<VoiceOption[]> {
    return SpeechKitTtsEngine.getAvailableVoices(context);
  }

  /**
   * 返回 Qwen 引擎支持的预设音色。
   */
  static getQwenVoiceOptions(): VoiceOption[] {
    return QwenTtsEngine.VOICES.map((v) => ({
      person: v.name as unknown as number,
      name: v.description,
      description: `${v.name} (${v.language})`
    }));
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
    const normalized = plainText.replace(/\n+/g, '。').replace(/\s+/g, '');
    const matches = normalized.match(/[^。！？.?!]+[。！？.?!]?/g);
    this.sentences = matches ? matches.filter((s) => s.trim().length > 0) : [];
  }

  private speakCurrentSentence(): void {
    if (!this.engine || this.currentSentenceIndex >= this.sentences.length) {
      return;
    }
    const text = this.sentences[this.currentSentenceIndex];
    this.currentRequestId = `${this.currentSpineIndex}-${this.currentSentenceIndex}-${Date.now()}`;
    LogUtil.info(`TTS speak: ${text.substring(0, 40)}...`);
    this.pendingAction = 'none';
    this.engine.speak(text, this.currentRequestId);
  }

  pause(): void {
    if (this.state !== 'playing') {
      return;
    }
    this.state = 'paused';
    this.pendingAction = 'pause';
    this.engine?.pause();
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
    this.engine?.stop();
    if (action === 'stop') {
      this.state = 'stopped';
      this.currentSentenceIndex = 0;
    } else if (action === 'pause') {
      this.state = 'paused';
    }
    this.emitState();
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
    return Number(this.voice);
  }

  async setVoicePerson(person: number): Promise<void> {
    if (this.voice === `${person}`) {
      return;
    }
    this.voice = `${person}`;
    LogUtil.info(`TTS setVoicePerson: ${person}`);
    if (!this.isInited || !this.engine) {
      return;
    }

    const wasPlaying = this.state === 'playing';
    const savedHandler = this.bookParserHandler;
    const savedSpineIndex = this.currentSpineIndex;
    const savedSentenceIndex = this.currentSentenceIndex;
    const savedSentences = this.sentences.slice();

    try {
      this.engine.stop();
      this.engine.release();
      this.engine = null;
      this.isInited = false;
      this.pendingAction = 'none';
      this.currentRequestId = '';

      if (!this.context) {
        throw new Error('无法获取 UIAbilityContext');
      }
      this.engine = await this.createEngine(this.context);
      this.isInited = true;

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
      const message = err instanceof Error ? err.message : String(err);
      this.emitError(`切换音色失败: ${message}`);
    }
  }

  setSpeed(speed: number): void {
    this.speed = speed;
    LogUtil.info(`TTS setSpeed: ${speed}`);
    this.engine?.setSpeed(speed);
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
      this.engine?.release();
    } catch (e) {
      LogUtil.warn(`TTS release failed: ${JSON.stringify(e)}`);
    }
    this.engine = null;
    this.isInited = false;
    this.state = 'idle';
    this.bookParserHandler = null;
    this.eventCallback = null;
    this.currentRequestId = '';
    LogUtil.info('TTS resources released');
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
}
