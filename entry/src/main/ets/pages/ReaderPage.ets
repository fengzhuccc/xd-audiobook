import { router, promptAction, AppStorageV2 } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppTheme } from '../common/theme/AppTheme';
import { READER_THEMES, ReaderTheme, createDefaultReaderSettings } from '../common/constants/ReaderConstants';
import { BookProgress } from '../common/model/BookProgress';
import { ReaderSettings } from '../common/model/ReaderSettings';
import { PreferencesService } from '../service/PreferencesService';
import { BookDatabase } from '../service/BookDatabase';
import { LogUtil } from '../common/utils/LogUtil';
import { BookParserFactory, IBookParserHandler, ParsedCatalogItem, htmlToPlainText } from '../service/BookParser';

@Entry
@Component
struct ReaderPage {
  // 路由参数
  @State bookId: number = 0;
  @State filePath: string = '';
  @State bookTitle: string = '';

  // 阅读器状态
  @State showToolbar: boolean = true;
  @State currentSpineIndex: number = 0;
  @State totalSpines: number = 0;
  @State isLoading: boolean = true;
  @State chapterContent: string = '';
  @State readerSettings: ReaderSettings = createDefaultReaderSettings();
  @State catalogVisible: boolean = false;

  // 解析器
  private parserHandler: IBookParserHandler | null = null;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.bookId = params.bookId as number;
      this.filePath = params.filePath as string;
    }

    if (!this.filePath) {
      promptAction.showToast({ message: '文件路径无效' });
      router.back();
      return;
    }

    this.loadSettings();
    this.initReader();
  }

  onPageHide(): void {
    this.saveProgress();
  }

  aboutToDisappear(): void {
    this.saveProgress();
    if (this.parserHandler) {
      try {
        this.parserHandler.release();
        LogUtil.info('Parser resources released');
      } catch (err) {
        LogUtil.warn(`Release error: ${JSON.stringify(err)}`);
      }
    }
  }

  private async loadSettings(): Promise<void> {
    const prefService = AppStorageV2.connect(PreferencesService, 'prefService') as PreferencesService;
    if (prefService) {
      this.readerSettings = await prefService.getReaderSettings();
    }
  }

  private async initReader(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;

      // 使用自建解析器
      this.parserHandler = await BookParserFactory.createHandler(this.filePath, context.tempDir);
      const bookInfo = this.parserHandler.getBookInfo();
      this.bookTitle = bookInfo.bookTitle;

      const spineList = this.parserHandler.getSpineList();
      this.totalSpines = spineList.length;

      // 获取已保存的进度
      const bookDb = AppStorageV2.connect(BookDatabase, 'bookDb') as BookDatabase;
      if (bookDb && this.bookId) {
        const progress = await bookDb.getProgressByBookId(this.bookId);
        if (progress && progress.spineIndex < this.totalSpines) {
          this.currentSpineIndex = progress.spineIndex;
        }
        await bookDb.updateLastReadTime(this.bookId);
      }

      // 加载章节内容
      await this.loadChapter();
      this.isLoading = false;
      LogUtil.info(`Reader initialized: ${this.bookTitle}, totalSpines=${this.totalSpines}`);
    } catch (err) {
      LogUtil.error(`Failed to init reader: ${JSON.stringify(err)}`);
      this.isLoading = false;
      promptAction.showToast({ message: '打开书籍失败' });
    }
  }

  private async loadChapter(): Promise<void> {
    if (!this.parserHandler) return;
    try {
      const rawContent = await this.parserHandler.getSpineItemContent(this.currentSpineIndex);
      if (rawContent.startsWith('<') || rawContent.includes('<')) {
        // HTML 内容，转为纯文本
        this.chapterContent = htmlToPlainText(rawContent);
      } else {
        // 纯文本
        this.chapterContent = rawContent;
      }
      this.scroller.scrollEdge(Edge.Top);
    } catch (err) {
      LogUtil.error(`Failed to load chapter: ${JSON.stringify(err)}`);
      this.chapterContent = '';
    }
  }

  private getCurrentChapterTitle(): string {
    if (!this.parserHandler) {
      return `第 ${this.currentSpineIndex + 1} 章`;
    }
    const catalog = this.parserHandler.getCatalogList();
    if (this.currentSpineIndex >= 0 && this.currentSpineIndex < catalog.length) {
      return catalog[this.currentSpineIndex].title || `第 ${this.currentSpineIndex + 1} 章`;
    }
    return `第 ${this.currentSpineIndex + 1} 章`;
  }

  private getThemeByKey(key: string): ReaderTheme | null {
    if (key === 'warm') return READER_THEMES.warm;
    if (key === 'white') return READER_THEMES.white;
    if (key === 'night') return READER_THEMES.night;
    return null;
  }

  private saveProgress(): void {
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
        LogUtil.info(`Reading progress saved: spineIndex=${this.currentSpineIndex}`);
      }
    } catch (err) {
      LogUtil.error(`Failed to save progress: ${JSON.stringify(err)}`);
    }
  }

  private goPrevChapter(): void {
    if (this.currentSpineIndex > 0) {
      this.currentSpineIndex--;
      this.loadChapter();
      this.saveProgress();
    }
  }

  private goNextChapter(): void {
    if (this.currentSpineIndex < this.totalSpines - 1) {
      this.currentSpineIndex++;
      this.loadChapter();
      this.saveProgress();
    }
  }

  private goBack(): void {
    router.back();
  }

  private openAudioPlayer(): void {
    this.saveProgress();
    router.pushUrl({
      url: 'pages/AudioPlayerPage',
      params: {
        bookId: this.bookId,
        filePath: this.filePath,
        bookTitle: this.bookTitle,
        currentSpineIndex: this.currentSpineIndex,
      }
    });
  }

  private jumpToChapter(index: number): void {
    this.currentSpineIndex = index;
    this.catalogVisible = false;
    this.loadChapter();
    this.saveProgress();
  }

  build() {
    Stack() {
      // 纸纹背景纹理（仅暖纸主题，模拟设计稿的多层 radial-gradient 纸纹效果）
      if (this.readerSettings.theme === 'warm') {
        Column()
          .width('100%')
          .height('100%')
          .radialGradient({
            center: ['0%', '0%'],
            radius: 450,
            colors: [
              ['rgba(218,195,150,0.08)', 0],
              ['rgba(218,195,150,0)', 0.5]
            ]
          })
          .hitTestBehavior(HitTestMode.None)

        Column()
          .width('100%')
          .height('100%')
          .radialGradient({
            center: ['100%', '100%'],
            radius: 450,
            colors: [
              ['rgba(218,195,150,0.07)', 0],
              ['rgba(218,195,150,0)', 0.5]
            ]
          })
          .hitTestBehavior(HitTestMode.None)

        Column()
          .width('100%')
          .height('100%')
          .radialGradient({
            center: ['50%', '50%'],
            radius: 550,
            colors: [
              ['rgba(218,195,150,0)', 0.4],
              ['rgba(218,195,150,0.04)', 1]
            ]
          })
          .hitTestBehavior(HitTestMode.None)
      }

      // 阅读内容
      Scroll(this.scroller) {
        Column() {
          // 章节标题
          Text(this.getCurrentChapterTitle())
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.textPrimary)
            .letterSpacing(2)
            .fontFamily('serif')
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 16, bottom: 24 })

          // 装饰性分隔线
          Row() {
            Divider()
              .vertical(false)
              .strokeWidth(1)
              .color(AppTheme.borderDefault)
              .layoutWeight(1)

            Image($r('app.media.ic_sparkle'))
              .width(16)
              .height(16)
              .fillColor(AppTheme.primary)
              .opacity(0.4)

            Divider()
              .vertical(false)
              .strokeWidth(1)
              .color(AppTheme.borderDefault)
              .layoutWeight(1)
          }
          .width('100%')
          .height(16)
          .justifyContent(FlexAlign.Center)
          .padding({ left: 24, right: 24 })
          .margin({ bottom: 24 })

          // 正文
          Text(this.chapterContent)
            .fontSize(this.readerSettings.fontSize)
            .fontColor(this.getThemeByKey(this.readerSettings.theme)?.fontColor || AppTheme.textPrimary)
            .lineHeight(this.readerSettings.fontSize * this.readerSettings.lineHeight)
            .letterSpacing(this.readerSettings.letterSpacing * this.readerSettings.fontSize)
            .textAlign(TextAlign.JUSTIFY)
            .width('100%')
            .padding({ left: 24, right: 24, top: 0, bottom: 120 })
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .onClick(() => {
        this.showToolbar = !this.showToolbar;
      })

      // 加载中遮罩
      if (this.isLoading) {
        Column() {
          Text('加载中...')
            .fontSize(15)
            .fontColor(AppTheme.textTertiary)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.surfacePage)
      }

      // 顶部工具栏
      if (this.showToolbar) {
        Column() {
          Row() {
            // 返回
            Row() {
              Image($r('app.media.ic_arrow_left'))
                .width(22)
                .height(22)
                .fillColor(AppTheme.textPrimary)
            }
            .width(36)
            .height(36)
            .justifyContent(FlexAlign.Center)
            .onClick(() => { this.goBack() })

            // 书名
            Text(this.bookTitle)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textPrimary)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: 40, right: 40 })

            // 听书模式
            Row() {
              Image($r('app.media.ic_headphone'))
                .width(20)
                .height(20)
                .fillColor(AppTheme.textPrimary)
            }
            .width(36)
            .height(36)
            .justifyContent(FlexAlign.Center)
            .onClick(() => { this.openAudioPlayer() })

            // 更多 / 目录
            Row() {
              Image($r('app.media.ic_more'))
                .width(20)
                .height(20)
                .fillColor(AppTheme.textPrimary)
            }
            .width(36)
            .height(36)
            .justifyContent(FlexAlign.Center)
            .onClick(() => { this.catalogVisible = true })
          }
          .width('100%')
          .height(48)
          .padding({ left: 8, right: 8 })
        }
        .width('100%')
        .backgroundColor('rgba(253,251,247,0.85)')
        .backdropBlur(16)
        .padding({ top: 44 })
        .align(Alignment.Top)

        // 底部翻页控制
        Row() {
          // 上一章
          Row() {
            Image($r('app.media.ic_skip_prev'))
              .width(20)
              .height(20)
              .fillColor(this.currentSpineIndex > 0 ? AppTheme.textPrimary : AppTheme.textTertiary)
          }
          .width(40)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.goPrevChapter() })

          Text(`第 ${this.currentSpineIndex + 1} / ${this.totalSpines} 章`)
            .fontSize(13)
            .fontColor(AppTheme.textSecondary)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          // 下一章
          Row() {
            Image($r('app.media.ic_skip_next'))
              .width(20)
              .height(20)
              .fillColor(this.currentSpineIndex < this.totalSpines - 1 ? AppTheme.textPrimary : AppTheme.textTertiary)
          }
          .width(40)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.goNextChapter() })
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16, bottom: 24 })
        .backgroundColor('rgba(253,251,247,0.9)')
        .backdropBlur(16)
        .justifyContent(FlexAlign.SpaceBetween)
        .align(Alignment.Bottom)
      }

      // 页面指示器（始终可见，悬浮于底部居中）
      Row() {
        Text(`第 ${this.currentSpineIndex + 1} 章 / 共 ${this.totalSpines} 章`)
          .fontSize(11)
          .fontColor(AppTheme.textTertiary)
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
          .backgroundColor('rgba(253,251,247,0.6)')
          .backdropBlur(8)
          .borderRadius(100)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .align(Alignment.Bottom)
      .margin({ bottom: 72 })

      // 目录侧边栏
      if (this.catalogVisible) {
        Row() {
          // 遮罩
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0,0,0,0.4)')
            .onClick(() => { this.catalogVisible = false })

          // 目录面板
          Column() {
            Row() {
              Text('目录')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.textPrimary)
              Text(`${this.parserHandler?.getCatalogList().length || 0} 章`)
                .fontSize(13)
                .fontColor(AppTheme.textTertiary)
                .margin({ left: 8 })
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 20, bottom: 16 })

            List({ space: 4 }) {
              ForEach(this.parserHandler?.getCatalogList() || [], (item: ParsedCatalogItem, index: number) => {
                ListItem() {
                  Text(item.title)
                    .fontSize(14)
                    .fontColor(index === this.currentSpineIndex ? AppTheme.primary : AppTheme.textSecondary)
                    .padding({ left: 20 + item.level * 16, right: 20, top: 12, bottom: 12 })
                    .width('100%')
                    .onClick(() => { this.jumpToChapter(index) })
                }
              }, (item: ParsedCatalogItem, index: number) => `${index}_${item.href}`)
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
          }
          .width('75%')
          .height('100%')
          .backgroundColor(AppTheme.surfacePage)
          .position({ x: '25%', y: 0 })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemeByKey(this.readerSettings.theme)?.backgroundColor || AppTheme.surfacePage)
  }
}
