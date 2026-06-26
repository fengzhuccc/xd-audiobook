import { router, AppStorageV2 } from '@kit.ArkUI';
import { bookParser } from '@kit.ReaderKit';
import { common } from '@kit.AbilityKit';
import { AppTheme } from '../common/theme/AppTheme';
import { TtsService, TtsState } from '../service/TtsService';
import { BookDatabase } from '../service/BookDatabase';
import { BookProgress } from '../common/model/BookProgress';
import { LogUtil } from '../common/utils/LogUtil';
import { BusinessError } from '@kit.BasicServicesKit';

@Entry
@Component
struct AudioPlayerPage {
  // 路由参数
  @State bookId: number = 0;
  @State filePath: string = '';
  @State bookTitle: string = '';
  @State currentSpineIndex: number = 0;

  // 朗读状态
  @State ttsState: TtsState = 'idle';
  @State currentChapter: string = '';
  @State totalChapters: number = 0;
  @State plainTextContent: string = '';
  @State currentSentenceIndex: number = 0;
  @State sentences: string[] = [];

  // 定时关闭
  @State timerMinutes: number = 0;
  @State timerSecondsLeft: number = 0;
  private timerHandle: number = -1;

  private ttsService: TtsService = new TtsService();
  private bookHandler: bookParser.BookParserHandler | null = null;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.bookId = params.bookId as number;
      this.filePath = params.filePath as string;
      this.bookTitle = params.bookTitle as string;
      this.currentSpineIndex = params.currentSpineIndex as number;
    }
    if (!this.filePath) {
      router.back();
      return;
    }
    this.initAudioPlayer();
  }

  aboutToDisappear(): void {
    this.clearTimer();
    this.saveAudioProgress();
    this.ttsService.release();
    LogUtil.info('AudioPlayerPage destroyed');
  }

  private async initAudioPlayer(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const handler = await bookParser.getDefaultHandler(this.filePath);
      this.bookHandler = handler;

      const bookInfo = handler.getBookInfo();
      const spineList = handler.getSpineList();
      this.totalChapters = spineList.length;
      this.currentChapter = this.getChapterTitle(spineList, this.currentSpineIndex);

      // 获取当前章节纯文本用于高亮展示
      await this.loadChapterContent();

      // 初始化并开始朗读
      await this.ttsService.init(context, bookInfo.bookTitle, bookInfo.bookCreator || '');
      await this.ttsService.startReading(handler, this.currentSpineIndex);
      this.ttsState = this.ttsService.getState();

    } catch (err) {
      const error = err as BusinessError;
      LogUtil.error(`AudioPlayer init failed: code=${error.code}, msg=${error.message}`);
    }
  }

  private async loadChapterContent(): Promise<void> {
    if (!this.bookHandler) return;
    try {
      const htmlContent = await this.bookHandler.getSpineItemContent(this.currentSpineIndex);
      if (!htmlContent) {
        this.plainTextContent = '';
        this.sentences = [];
        return;
      }
      this.plainTextContent = htmlContent
        .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
        .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
        .replace(/<[^>]+>/g, '')
        .replace(/&nbsp;/g, ' ')
        .replace(/\n{2,}/g, '\n')
        .trim();

      this.sentences = this.plainTextContent.split(/[。！？\n]/g).filter((s) => s.trim().length > 0);
      this.currentSentenceIndex = 0;
    } catch (err) {
      LogUtil.error(`Failed to load chapter content: ${JSON.stringify(err)}`);
    }
  }

  private getChapterTitle(spineList: bookParser.SpineItem[], index: number): string {
    if (index >= 0 && index < spineList.length) {
      const href = spineList[index].href;
      return href?.split('/').pop()?.replace(/\.\w+$/, '') || `第${index + 1}章`;
    }
    return `第${index + 1}章`;
  }

  private togglePlayPause(): void {
    if (this.ttsState === 'playing') {
      this.ttsService.pause();
      this.ttsState = 'paused';
    } else if (this.ttsState === 'paused') {
      this.ttsService.resume();
      this.ttsState = 'playing';
    } else {
      // idle 或 stopped 状态，重新开始朗读
      if (this.bookHandler) {
        this.ttsService.startReading(this.bookHandler, this.currentSpineIndex);
        this.ttsState = this.ttsService.getState();
      }
    }
  }

  private goPrevChapter(): void {
    if (this.currentSpineIndex <= 0) return;
    this.currentSpineIndex--;
    this.currentChapter = this.getChapterTitle(
      this.bookHandler?.getSpineList() || [], this.currentSpineIndex);
    this.loadChapterContent();
    if (this.bookHandler) {
      this.ttsService.startReading(this.bookHandler, this.currentSpineIndex);
      this.ttsState = this.ttsService.getState();
    }
  }

  private goNextChapter(): void {
    if (this.currentSpineIndex >= this.totalChapters - 1) return;
    this.currentSpineIndex++;
    this.currentChapter = this.getChapterTitle(
      this.bookHandler?.getSpineList() || [], this.currentSpineIndex);
    this.loadChapterContent();
    if (this.bookHandler) {
      this.ttsService.startReading(this.bookHandler, this.currentSpineIndex);
      this.ttsState = this.ttsService.getState();
    }
  }

  private saveAudioProgress(): void {
    if (!this.bookId) return;
    try {
      const bookDb = AppStorageV2.connect(BookDatabase, 'bookDb') as BookDatabase;
      if (bookDb) {
        const progress: BookProgress = {
          bookId: this.bookId,
          spineIndex: this.currentSpineIndex,
          domPos: '',
          updateTime: Date.now(),
        };
        bookDb.saveOrUpdateProgress(progress);
      }
    } catch (err) {
      LogUtil.error(`Failed to save audio progress: ${JSON.stringify(err)}`);
    }
  }

  private goBackToReader(): void {
    this.ttsService.stop();
    router.back();
  }

  private goBackToShelf(): void {
    this.ttsService.stop();
    router.back({ url: 'pages/Index' });
  }

  private startTimer(minutes: number): void {
    this.clearTimer();
    this.timerMinutes = minutes;
    this.timerSecondsLeft = minutes * 60;
    this.timerHandle = setInterval(() => {
      this.timerSecondsLeft--;
      if (this.timerSecondsLeft <= 0) {
        this.ttsService.pause();
        this.ttsState = 'paused';
        this.clearTimer();
      }
    }, 1000);
  }

  private clearTimer(): void {
    if (this.timerHandle !== -1) {
      clearInterval(this.timerHandle);
      this.timerHandle = -1;
      this.timerMinutes = 0;
      this.timerSecondsLeft = 0;
    }
  }

  build() {
    Column() {
      Row().height(48).width('100%').backgroundColor(AppTheme.surfacePage);

      // 顶部导航
      Row() {
        Image($r('app.media.ic_arrow_left'))
          .width(22).height(22).fillColor(AppTheme.textPrimary)
          .margin({ left: 8 })
          .onClick(() => { this.goBackToReader() })

        Text(this.bookTitle)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.textPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Image($r('app.media.ic_home'))
          .width(22).height(22).fillColor(AppTheme.textPrimary)
          .margin({ right: 8 })
          .onClick(() => { this.goBackToShelf() })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .alignItems(VerticalAlign.Center)

      Text(this.currentChapter)
        .fontSize(13)
        .fontColor(AppTheme.textTertiary)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 4, bottom: 16 })

      Scroll() {
        Column() {
          // 封面展示区
          Stack() {
            Column()
              .width('100%')
              .height('100%')
              .borderRadius(16)
              .linearGradient({
                angle: 135,
                colors: [[AppTheme.primaryLight, 0], [AppTheme.primary, 1]]
              })
              .shadow({ radius: 16, color: 'rgba(139,105,20,0.2)', offsetY: 8 })
            Text(this.bookTitle.charAt(0))
              .fontSize(48)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
          }
          .width(180)
          .height(180)
          .margin({ bottom: 24 })

          // 文本高亮区域
          Column() {
            // 已读文字（灰）
            if (this.currentSentenceIndex > 0) {
              Text(this.sentences.slice(0, this.currentSentenceIndex).join('。') + '。')
                .fontSize(14)
                .fontColor(AppTheme.textTertiary)
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ bottom: 8 })
            }

            // 当前朗读句（高亮）
            if (this.currentSentenceIndex < this.sentences.length) {
              Text(this.sentences[this.currentSentenceIndex] + '。')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.textPrimary)
                .backgroundColor(AppTheme.primaryLighter)
                .borderRadius(6)
                .padding(10)
                .margin({ bottom: 8 })
                .shadow({ radius: 8, color: 'rgba(232,213,163,0.5)', offsetY: 2 })
            }

            // 待读文字（正常）
            if (this.currentSentenceIndex + 1 < this.sentences.length) {
              Text(this.sentences.slice(this.currentSentenceIndex + 1, this.currentSentenceIndex + 3).join('。') + '。')
                .fontSize(14)
                .fontColor(AppTheme.textSecondary)
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .width('100%')
          .padding(20)
          .backgroundColor(AppTheme.surfaceCard)
          .borderRadius(12)
          .shadow({ radius: 4, color: 'rgba(61,53,42,0.04)', offsetY: 1 })
          .margin({ bottom: 24 })

          // 章节进度条
          Row() {
            Text(`第 ${this.currentSpineIndex + 1} 章`)
              .fontSize(12)
              .fontColor(AppTheme.textTertiary)
            Text(`共 ${this.totalChapters} 章`)
              .fontSize(12)
              .fontColor(AppTheme.textTertiary)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .margin({ bottom: 8 })

          // 进度条
          Stack({ alignContent: Alignment.Start }) {
            Row()
              .height(4)
              .borderRadius(2)
              .backgroundColor(AppTheme.primaryLight)
              .width('100%')
            Row()
              .height(4)
              .borderRadius(2)
              .backgroundColor(AppTheme.primary)
              .width(this.totalChapters > 0 ?
                `${Math.min(100, ((this.currentSpineIndex + 1) / this.totalChapters) * 100)}%`
                : '0%')
          }
          .width('100%')
          .margin({ bottom: 32 })

          // 播放控制按钮组
          Row({ space: 24 }) {
            // 后退15秒
            Column() {
              Image($r('app.media.ic_rewind'))
                .width(28).height(28).fillColor(AppTheme.textSecondary)
            }
            .onClick(() => { /* rewind */ })

            // 上一章
            Column() {
              Image($r('app.media.ic_skip_prev'))
                .width(28).height(28).fillColor(AppTheme.textSecondary)
            }
            .onClick(() => { this.goPrevChapter() })

            // 播放/暂停（大按钮）
            Column() {
              if (this.ttsState === 'playing') {
                Image($r('app.media.ic_pause'))
                  .width(32).height(32).fillColor(Color.White)
              } else {
                Image($r('app.media.ic_play'))
                  .width(32).height(32).fillColor(Color.White)
              }
            }
            .width(64)
            .height(64)
            .borderRadius(32)
            .backgroundColor(AppTheme.primary)
            .justifyContent(FlexAlign.Center)
            .shadow({ radius: 16, color: 'rgba(139,105,20,0.3)', offsetY: 4 })
            .onClick(() => { this.togglePlayPause() })

            // 下一章
            Column() {
              Image($r('app.media.ic_skip_next'))
                .width(28).height(28).fillColor(AppTheme.textSecondary)
            }
            .onClick(() => { this.goNextChapter() })

            // 前进15秒
            Column() {
              Image($r('app.media.ic_forward'))
                .width(28).height(28).fillColor(AppTheme.textSecondary)
            }
            .onClick(() => { /* forward */ })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ bottom: 32 })

          // 语速控制
          Text('1.0x')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.primary)
            .backgroundColor(AppTheme.primaryLightest)
            .borderRadius(16)
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .margin({ bottom: 24 })

          // 附加控制栏
          Row() {
            Row({ space: 6 }) {
              Image($r('app.media.ic_timer'))
                .width(18).height(18).fillColor(AppTheme.textSecondary)
              Text('定时关闭')
                .fontSize(13)
                .fontColor(AppTheme.textSecondary)
            }
            .padding(12)
            .backgroundColor(AppTheme.surfaceCard)
            .borderRadius(10)
            .onClick(() => {
              // 弹出定时选项
            })

            Row({ space: 6 }) {
              Image($r('app.media.ic_voice'))
                .width(18).height(18).fillColor(AppTheme.textSecondary)
              Text('普通话女声')
                .fontSize(13)
                .fontColor(AppTheme.textSecondary)
            }
            .layoutWeight(1)
            .margin({ left: 8 })
            .padding(12)
            .backgroundColor(AppTheme.surfaceCard)
            .borderRadius(10)
            .onClick(() => {
              this.ttsService.showVoicePanel();
            })

            Row({ space: 6 }) {
              Image($r('app.media.ic_speed'))
                .width(18).height(18).fillColor(AppTheme.textSecondary)
              Text('朗读速度')
                .fontSize(13)
                .fontColor(AppTheme.textSecondary)
            }
            .padding(12)
            .backgroundColor(AppTheme.surfaceCard)
            .borderRadius(10)
            .onClick(() => {
              this.ttsService.showVoicePanel();
            })
          }
          .width('100%')
          .margin({ bottom: 24 })
        }
        .width('100%')
        .padding({ left: 24, right: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.surfacePage)
  }
}
