import { TextReader, textToSpeech } from '@kit.SpeechKit';
import { bookParser } from '@kit.ReaderKit';
import { common } from '@kit.AbilityKit';
import { LogUtil } from '../common/utils/LogUtil';
import { BusinessError } from '@kit.BasicServicesKit';

export type TtsState = 'idle' | 'playing' | 'paused' | 'stopped';

export class TtsService {
  private isInited: boolean = false;
  private state: TtsState = 'idle';
  private bookParserHandler: bookParser.BookParserHandler | null = null;
  private currentSpineIndex: number = 0;
  private bookTitle: string = '';
  private bookAuthor: string = '';

  /**
   * 初始化 TTS 引擎
   */
  async init(context: common.UIAbilityContext, bookTitle: string, bookAuthor: string): Promise<void> {
    try {
      const readerParams: TextReader.ReaderParam = {
        isVoiceBrandVisible: true,
        businessBrandInfo: {
          panelName: '书声朗读',
          panelIcon: $r('app.media.app_icon'),
        },
      };
      await TextReader.init(context, readerParams);
      this.isInited = true;
      this.bookTitle = bookTitle;
      this.bookAuthor = bookAuthor;

      // 注册状态监听
      TextReader.on('stateChange', (state: string) => {
        LogUtil.info(`TTS state changed: ${state}`);
        switch (state) {
          case 'STATE_PLAYING':
            this.state = 'playing';
            break;
          case 'STATE_PAUSED':
            this.state = 'paused';
            break;
          case 'STATE_STOPPED':
            this.state = 'stopped';
            break;
          default:
            break;
        }
      });

      LogUtil.info('TtsService initialized');
    } catch (err) {
      const error = err as BusinessError;
      LogUtil.error(`TTS init failed: code=${error.code}, msg=${error.message}`);
    }
  }

  /**
   * 开始朗读指定章节
   */
  async startReading(
    handler: bookParser.BookParserHandler,
    spineIndex: number
  ): Promise<void> {
    if (!this.isInited || !handler) return;

    try {
      this.bookParserHandler = handler;
      this.currentSpineIndex = spineIndex;

      // 获取章节内容并去除 HTML 标签
      const htmlContent = await handler.getSpineItemContent(spineIndex);
      const plainText = this.stripHtml(htmlContent);

      // 构建朗读内容
      const spineList = handler.getSpineList();
      const chapterTitle = spineList[spineIndex]?.href?.split('/').pop()?.replace(/\.\w+$/, '') || `第${spineIndex + 1}章`;

      const readInfoList: TextReader.ReadInfo[] = [{
        id: `chapter_${spineIndex}`,
        title: { text: chapterTitle, isClickable: true },
        author: { text: this.bookAuthor, isClickable: true },
        bodyInfo: plainText,
      }];

      const articleId = `article_${spineIndex}`;
      await TextReader.start(readInfoList, articleId);
      this.state = 'playing';

      // 注册翻章回调
      TextReader.on('requestMore', (requestInfo: TextReader.RequestInfo) => {
        LogUtil.info(`TTS requestMore: ${JSON.stringify(requestInfo)}`);
        // 翻到下一章
        this.playNextChapter();
      });

      LogUtil.info(`TTS started: chapter ${chapterTitle}`);
    } catch (err) {
      const error = err as BusinessError;
      LogUtil.error(`TTS start failed: code=${error.code}, msg=${error.message}`);
    }
  }

  /**
   * 暂停朗读
   */
  pause(): void {
    if (this.state !== 'playing') return;
    try {
      TextReader.pause();
      this.state = 'paused';
    } catch (err) {
      LogUtil.error(`TTS pause failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 继续朗读
   */
  resume(): void {
    if (this.state !== 'paused') return;
    try {
      TextReader.resume();
      this.state = 'playing';
    } catch (err) {
      LogUtil.error(`TTS resume failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 停止朗读
   */
  stop(): void {
    try {
      TextReader.stop();
      TextReader.hidePanel();
      this.state = 'stopped';
    } catch (err) {
      LogUtil.error(`TTS stop failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 上一章
   */
  playPrevChapter(): void {
    if (!this.bookParserHandler || this.currentSpineIndex <= 0) return;
    this.startReading(this.bookParserHandler, this.currentSpineIndex - 1);
  }

  /**
   * 下一章
   */
  playNextChapter(): void {
    if (!this.bookParserHandler) return;
    const spineList = this.bookParserHandler.getSpineList();
    if (this.currentSpineIndex >= spineList.length - 1) {
      LogUtil.info('Already at last chapter');
      return;
    }
    this.startReading(this.bookParserHandler, this.currentSpineIndex + 1);
  }

  /**
   * 获取当前状态
   */
  getState(): TtsState {
    return this.state;
  }

  /**
   * 获取当前章节索引
   */
  getCurrentSpineIndex(): number {
    return this.currentSpineIndex;
  }

  /**
   * 设置语速
   */
  setSpeed(speed: number): void {
    try {
      TextReader.setSpeed(speed);
    } catch (err) {
      LogUtil.error(`TTS setSpeed failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 显示系统语音选择面板
   */
  showVoicePanel(): void {
    try {
      TextReader.showPanel();
    } catch (err) {
      LogUtil.error(`TTS showPanel failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 释放资源
   */
  release(): void {
    try {
      this.stop();
      TextReader.release();
      this.isInited = false;
      LogUtil.info('TTS resources released');
    } catch (err) {
      LogUtil.error(`TTS release failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 去除 HTML 标签，提取纯文本
   */
  private stripHtml(html: string): string {
    return html
      .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
      .replace(/<[^>]+>/g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .replace(/&nbsp;/g, ' ')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&amp;/g, '&')
      .trim();
  }
}
