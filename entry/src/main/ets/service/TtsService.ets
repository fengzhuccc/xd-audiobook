import { common } from '@kit.AbilityKit';
import { LogUtil } from '../common/utils/LogUtil';
import { IBookParserHandler } from './BookParser';

export type TtsState = 'idle' | 'playing' | 'paused' | 'stopped';

/**
 * 朗读服务（当前为占位实现，用于通过编译）。
 * 如需接入系统 TextReader，请根据本地 SpeechKit 版本替换为真实实现。
 */
export class TtsService {
  private isInited: boolean = false;
  private state: TtsState = 'idle';
  private bookParserHandler: IBookParserHandler | null = null;
  private currentSpineIndex: number = 0;
  private bookTitle: string = '';
  private bookAuthor: string = '';

  async init(context: common.UIAbilityContext, bookTitle: string, bookAuthor: string): Promise<void> {
    this.isInited = true;
    this.bookTitle = bookTitle;
    this.bookAuthor = bookAuthor;
    LogUtil.info('TtsService initialized (stub)');
  }

  async startReading(
    handler: IBookParserHandler,
    spineIndex: number
  ): Promise<void> {
    if (!this.isInited || !handler) return;

    this.bookParserHandler = handler;
    this.currentSpineIndex = spineIndex;
    this.state = 'playing';

    const spineList = handler.getSpineList();
    const chapterTitle = spineList[spineIndex]?.href?.split('/').pop()?.replace(/\.\w+$/, '') || `第${spineIndex + 1}章`;
    LogUtil.info(`TTS started (stub): ${chapterTitle}`);
  }

  pause(): void {
    if (this.state !== 'playing') return;
    this.state = 'paused';
    LogUtil.info('TTS paused (stub)');
  }

  resume(): void {
    if (this.state !== 'paused') return;
    this.state = 'playing';
    LogUtil.info('TTS resumed (stub)');
  }

  stop(): void {
    this.state = 'stopped';
    LogUtil.info('TTS stopped (stub)');
  }

  playPrevChapter(): void {
    if (!this.bookParserHandler || this.currentSpineIndex <= 0) return;
    this.startReading(this.bookParserHandler, this.currentSpineIndex - 1);
  }

  playNextChapter(): void {
    if (!this.bookParserHandler) return;
    const spineList = this.bookParserHandler.getSpineList();
    if (this.currentSpineIndex >= spineList.length - 1) {
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

  setSpeed(speed: number): void {
    LogUtil.info(`TTS setSpeed (stub): ${speed}`);
  }

  showVoicePanel(): void {
    LogUtil.info('TTS showVoicePanel (stub)');
  }

  release(): void {
    this.stop();
    this.isInited = false;
    LogUtil.info('TTS resources released (stub)');
  }
}
