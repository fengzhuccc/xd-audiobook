import { router, AppStorageV2 } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppTheme } from '../common/theme/AppTheme';
import { TtsService, TtsState } from '../service/TtsService';
import { BookDatabase } from '../service/BookDatabase';
import { BookProgress } from '../common/model/BookProgress';
import { LogUtil } from '../common/utils/LogUtil';
import { BusinessError } from '@kit.BasicServicesKit';
import { BookParserFactory, IBookParserHandler, ParsedSpineItem, htmlToPlainText } from '../service/BookParser';

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

  // 语速
  @State speedIndex: number = 0;

  private timerHandle: number = -1;
  private ttsService: TtsService = new TtsService();
  private bookHandler: IBookParserHandler | null = null;
  private speedLabels: string[] = ['1.0x', '1.25x', '1.5x', '2.0x'];
  private speeds: number[] = [1.0, 1.25, 1.5, 2.0];

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
    if (this.bookHandler) {
      try {
        this.bookHandler.release();
      } catch (e) {
        LogUtil.warn(`Failed to release parser: ${JSON.stringify(e)}`);
      }
    }
    LogUtil.info('AudioPlayerPage destroyed');
  }

  private async initAudioPlayer(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.bookHandler = await BookParserFactory.createHandler(this.filePath, context.tempDir);

      const bookInfo = this.bookHandler.getBookInfo();
      const spineList = this.bookHandler.getSpineList();
      this.totalChapters = spineList.length;
      this.currentChapter = this.getChapterTitle(spineList, this.currentSpineIndex);

      // 获取当前章节纯文本用于高亮展示
      await this.loadChapterContent();

      // 初始化并开始朗读
      await this.ttsService.init(context, bookInfo.bookTitle, bookInfo.bookCreator || '');
      await this.ttsService.startReading(this.bookHandler, this.currentSpineIndex);
      this.ttsState = this.ttsService.getState();
    } catch (err) {
      const error = err as BusinessError;
      LogUtil.error(`AudioPlayer init failed: ${JSON.stringify(err)}`);
    }
  }

  private async loadChapterContent(): Promise<void> {
    if (!this.bookHandler) return;
    try {
      const rawContent = await this.bookHandler.getSpineItemContent(this.currentSpineIndex);
      if (!rawContent) {
        this.plainTextContent = '';
        this.sentences = [];
        return;
      }
      // 如果是 HTML，转为纯文本
      if (rawContent.includes('<')) {
        this.plainTextContent = htmlToPlainText(rawContent);
      } else {
        this.plainTextContent = rawContent;
      }

      this.sentences = this.plainTextContent.split(/[。！？\n]/g).filter((s: string) => s.trim().length > 0);
      this.currentSentenceIndex = 0;
    } catch (err) {
      LogUtil.error(`Failed to load chapter content: ${JSON.stringify(err)}`);
    }
  }

  private getChapterTitle(spineList: ParsedSpineItem[], index: number): string {
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
      if (this.bookHandler) {
        this.ttsService.startReading(this.bookHandler, this.currentSpineIndex);
        this.ttsState = this.ttsService.getState();
      }
    }
  }

  private goPrevChapter(): void {
    if (this.currentSpineIndex <= 0) return;
    this.currentSpineIndex--;
    if (this.bookHandler) {
      this.currentChapter = this.getChapterTitle(this.bookHandler.getSpineList(), this.currentSpineIndex);
    }
    this.loadChapterContent();
    if (this.bookHandler) {
      this.ttsService.startReading(this.bookHandler, this.currentSpineIndex);
      this.ttsState = this.ttsService.getState();
    }
  }

  private goNextChapter(): void {
    if (this.currentSpineIndex >= this.totalChapters - 1) return;
    this.currentSpineIndex++;
    if (this.bookHandler) {
      this.currentChapter = this.getChapterTitle(this.bookHandler.getSpineList(), this.currentSpineIndex);
    }
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

  private cycleSpeed(): void {
    this.speedIndex = (this.speedIndex + 1) % this.speeds.length;
    this.ttsService.setSpeed(this.speeds[this.speedIndex]);
  }

  build() {
    Column() {
      // 1. 状态栏占位
      Row().height(48).width('100%').backgroundColor(AppTheme.surfacePage);

      // 2. 顶部导航
      Row() {
        // 返回阅读器
        Row() {
          Image($r('app.media.ic_arrow_left'))
            .width(24).height(24).fillColor(AppTheme.textPrimary)
        }
        .width(40).height(40)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => { this.goBackToReader() })

        // 中间标题
        Column() {
          Text(this.bookTitle)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: 200 })
          Text(this.currentChapter)
            .fontSize(12)
            .fontColor(AppTheme.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: 200 })
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        // 返回书架
        Row() {
          Image($r('app.media.ic_home'))
            .width(22).height(22).fillColor(AppTheme.textPrimary)
        }
        .width(40).height(40)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => { this.goBackToShelf() })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })
      .alignItems(VerticalAlign.Center)

      // 3. 封面
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 135,
            colors: [[AppTheme.primaryLight, 0], [AppTheme.primary, 1]]
          })
        Text(this.bookTitle.charAt(0))
          .fontSize(72)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
      }
      .width(220)
      .height(220)
      .borderRadius(16)
      .clip(true)
      .shadow({ radius: 16, color: 'rgba(139,105,20,0.2)', offsetY: 8 })
      .margin({ top: 8, bottom: 16 })

      // 4. 文本高亮区
      Column() {
        // 头部
        Row() {
          Image($r('app.media.ic_voice'))
            .width(14).height(14).fillColor(AppTheme.primary)
          Text('正在朗读')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textTertiary)
            .margin({ left: 6 })
        }
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 12 })

        // 正文
        Column() {
          if (this.currentSentenceIndex > 0) {
            Text(this.sentences.slice(0, this.currentSentenceIndex).join('。') + '。')
              .fontSize(13)
              .fontFamily('serif')
              .lineHeight(28)
              .letterSpacing(0.5)
              .fontColor(AppTheme.textTertiary)
          }
          if (this.currentSentenceIndex < this.sentences.length) {
            Text(this.sentences[this.currentSentenceIndex] + '。')
              .fontSize(13)
              .fontFamily('serif')
              .lineHeight(28)
              .letterSpacing(0.5)
              .fontColor(AppTheme.textPrimary)
              .backgroundColor(AppTheme.primaryLighter)
              .borderRadius(4)
              .padding({ left: 4, right: 4, top: 2, bottom: 2 })
          }
          if (this.currentSentenceIndex + 1 < this.sentences.length) {
            Text(this.sentences.slice(this.currentSentenceIndex + 1, this.currentSentenceIndex + 3).join('。') + '。')
              .fontSize(13)
              .fontFamily('serif')
              .lineHeight(28)
              .letterSpacing(0.5)
              .fontColor(AppTheme.textSecondary)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 18, right: 18, top: 16, bottom: 16 })
      .backgroundColor(AppTheme.surfaceCard)
      .borderRadius(12)
      .shadow({ radius: 4, color: 'rgba(61,53,42,0.04)', offsetY: 1 })
      .margin({ left: 20, right: 20, bottom: 16 })

      // 5. 进度条
      Column() {
        Row() {
          Text('0:00')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textSecondary)
          Text('—')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textTertiary)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ bottom: 8 })

        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(4)
            .borderRadius(2)
            .backgroundColor(AppTheme.primaryLight)
          Stack({ alignContent: Alignment.End }) {
            Row()
              .width('100%')
              .height(4)
              .borderRadius(2)
              .backgroundColor(AppTheme.primary)
            Row()
              .width(12)
              .height(12)
              .borderRadius(6)
              .backgroundColor(AppTheme.primary)
              .shadow({ radius: 4, color: 'rgba(139,105,20,0.35)', offsetY: 1 })
          }
          .width(`${this.totalChapters > 0
            ? Math.min(100, ((this.currentSpineIndex + 1) / this.totalChapters) * 100)
            : 0}%`)
          .height(12)
        }
        .width('100%')
        .height(12)
      }
      .width('100%')
      .margin({ left: 24, right: 24, bottom: 8 })

      // 6. 播放控制
      Row({ space: 20 }) {
        // 后退 15s
        Column() {
          Image($r('app.media.ic_rewind'))
            .width(22).height(22).fillColor(AppTheme.textSecondary)
        }
        .width(44).height(44)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {})

        // 上一章
        Column() {
          Image($r('app.media.ic_skip_prev'))
            .width(24).height(24).fillColor(AppTheme.textPrimary)
        }
        .width(44).height(44)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => { this.goPrevChapter() })

        // 播放/暂停
        Column() {
          if (this.ttsState === 'playing') {
            Image($r('app.media.ic_pause'))
              .width(28).height(28).fillColor(Color.White)
          } else {
            Image($r('app.media.ic_play'))
              .width(28).height(28).fillColor(Color.White)
          }
        }
        .width(64).height(64)
        .borderRadius(32)
        .backgroundColor(AppTheme.primary)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .shadow({ radius: 20, color: 'rgba(139,105,20,0.35)', offsetY: 4 })
        .onClick(() => { this.togglePlayPause() })

        // 下一章
        Column() {
          Image($r('app.media.ic_skip_next'))
            .width(24).height(24).fillColor(AppTheme.textPrimary)
        }
        .width(44).height(44)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => { this.goNextChapter() })

        // 前进 15s
        Column() {
          Image($r('app.media.ic_forward'))
            .width(22).height(22).fillColor(AppTheme.textSecondary)
        }
        .width(44).height(44)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {})
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 16, bottom: 16, left: 24, right: 24 })

      // 7. 语速控制
      Text(this.speedLabels[this.speedIndex])
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.primary)
        .backgroundColor(AppTheme.surfaceCard)
        .borderRadius(999)
        .border({ width: 1, color: AppTheme.borderDefault })
        .padding({ left: 16, right: 16, top: 6, bottom: 6 })
        .margin({ bottom: 16 })
        .onClick(() => { this.cycleSpeed() })

      // 8. 附加控制栏
      Row() {
        Column() {
          Image($r('app.media.ic_timer'))
            .width(20).height(20).fillColor(AppTheme.textSecondary)
          Text('定时关闭')
            .fontSize(12)
            .fontColor(AppTheme.textSecondary)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          if (this.timerMinutes === 0) {
            this.startTimer(15);
          } else {
            this.clearTimer();
          }
        })

        Column() {
          Image($r('app.media.ic_voice'))
            .width(20).height(20).fillColor(AppTheme.textSecondary)
          Text('普通话女声')
            .fontSize(12)
            .fontColor(AppTheme.textSecondary)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {})

        Column() {
          Image($r('app.media.ic_speed'))
            .width(20).height(20).fillColor(AppTheme.textSecondary)
          Text('朗读速度')
            .fontSize(12)
            .fontColor(AppTheme.textSecondary)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {})
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
      .padding(12)
      .backgroundColor(AppTheme.surfaceCard)
      .borderRadius(12)
      .shadow({ radius: 4, color: 'rgba(61,53,42,0.04)', offsetY: 1 })
      .margin({ left: 20, right: 20, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.surfacePage)
    .alignItems(HorizontalAlign.Center)
  }
}
