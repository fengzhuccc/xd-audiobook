import { router, promptAction } from '@kit.ArkUI';
import { bookParser, readerCore, ReadPageComponent } from '@kit.ReaderKit';
import { common } from '@kit.AbilityKit';
import { AppTheme } from '../common/theme/AppTheme';
import { READER_THEMES, READER_DEFAULTS } from '../common/constants/ReaderConstants';
import { BookInfo } from '../common/model/BookInfo';
import { BookProgress } from '../common/model/BookProgress';
import { ReaderSettings } from '../common/model/ReaderSettings';
import { PreferencesService } from '../service/PreferencesService';
import { BookDatabase } from '../service/BookDatabase';
import { LogUtil } from '../common/utils/LogUtil';
import { BusinessError } from '@kit.BasicServicesKit';

@Entry
@Component
struct ReaderPage {
  // 路由参数
  @State bookId: number = 0;
  @State filePath: string = '';
  @State bookTitle: string = '';

  // 阅读器状态
  @State showToolbar: boolean = true;
  @State currentPage: number = 0;
  @State totalPages: number = 0;
  @State readerSettings: ReaderSettings = { ...READER_DEFAULTS } as ReaderSettings;

  // 阅读器控制器
  private readerController: readerCore.ReaderComponentController = new readerCore.ReaderComponentController();
  private bookParserHandler: bookParser.BookParserHandler | null = null;

  aboutToAppear(): void {
    // 获取路由参数
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.bookId = params.bookId as number;
      this.filePath = params.filePath as string;
    }

    this.loadSettings();
    this.initReader();
  }

  onPageShow(): void {
    // 页面显示时恢复
  }

  onPageHide(): void {
    // 页面隐藏时保存进度
    this.saveProgress();
  }

  aboutToDisappear(): void {
    // 释放资源
    try {
      this.readerController.releaseBook();
      LogUtil.info('Reader resources released');
    } catch (err) {
      LogUtil.warn(`Release error: ${JSON.stringify(err)}`);
    }
  }

  private async loadSettings(): Promise<void> {
    const prefService = AppStorage.get('prefService') as PreferencesService;
    if (prefService) {
      this.readerSettings = await prefService.getReaderSettings();
    }
  }

  private async initReader(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;

      // 初始化解析器
      this.bookParserHandler = await bookParser.getDefaultHandler(this.filePath);
      const bookInfo = this.bookParserHandler.getBookInfo();
      this.bookTitle = bookInfo.bookTitle;

      // 获取已保存的进度
      const bookDb = AppStorage.get('bookDb') as BookDatabase;
      let savedSpineIndex = 0;
      let savedDomPos = '';
      if (bookDb && this.bookId) {
        const progress = await bookDb.getProgressByBookId(this.bookId);
        if (progress) {
          savedSpineIndex = progress.spineIndex;
          savedDomPos = progress.domPos;
        }
        // 更新最后阅读时间
        await bookDb.updateLastReadTime(this.bookId);
      }

      // 初始化阅读器控制器
      await this.readerController.init(context);
      this.readerController.registerBookParser(this.bookParserHandler);

      // 应用设置
      this.applySettings();

      // 开始阅读
      this.readerController.startPlay(savedSpineIndex, savedDomPos);

      LogUtil.info(`Reader initialized: ${this.bookTitle}`);
    } catch (err) {
      const error = err as BusinessError;
      LogUtil.error(`Failed to init reader: code=${error.code}, msg=${error.message}`);
      promptAction.showToast({ message: '打开书籍失败' });
    }
  }

  private applySettings(): void {
    const theme = READER_THEMES[this.readerSettings.theme];
    try {
      this.readerController.setPageConfig({
        fontSize: this.readerSettings.fontSize,
        fontColor: theme.fontColor,
        backgroundColor: theme.backgroundColor,
        lineHeight: this.readerSettings.lineHeight,
        letterSpacing: this.readerSettings.letterSpacing,
        flipMode: this.readerSettings.flipMode === 'click' ? 0 : 1,
      });
    } catch (err) {
      LogUtil.error(`Failed to apply settings: ${JSON.stringify(err)}`);
    }
  }

  private saveProgress(): void {
    if (!this.bookId) return;
    try {
      const bookDb = AppStorage.get('bookDb') as BookDatabase;
      if (bookDb) {
        const progress: BookProgress = {
          bookId: this.bookId,
          spineIndex: this.currentPage,
          domPos: '',
          updateTime: Date.now(),
        };
        bookDb.saveOrUpdateProgress(progress);
        LogUtil.info('Reading progress saved');
      }
    } catch (err) {
      LogUtil.error(`Failed to save progress: ${JSON.stringify(err)}`);
    }
  }

  private goBack(): void {
    this.saveProgress();
    router.back();
  }

  private openAudioPlayer(): void {
    router.pushUrl({
      url: 'pages/AudioPlayerPage',
      params: {
        bookId: this.bookId,
        filePath: this.filePath,
        bookTitle: this.bookTitle,
        currentSpineIndex: this.currentPage,
      }
    });
  }

  build() {
    Stack() {
      // 阅读器组件
      ReadPageComponent({
        controller: this.readerController,
        readerCallback: (err: BusinessError, data: readerCore.ReaderComponentController) => {
          if (!err) {
            this.readerController = data;
          }
        }
      })
      .width('100%')
      .height('100%')
      .onClick(() => {
        // 点击切换工具栏显隐
        this.showToolbar = !this.showToolbar;
      })

      // 顶部工具栏（毛玻璃效果）
      if (this.showToolbar) {
        Column() {
          Row() {
            // 返回按钮
            Row() {
              Image($r('app.media.ic_arrow_left'))
                .width(22)
                .height(22)
                .fillColor(AppTheme.textPrimary)
            }
            .width(40)
            .height(40)
            .justifyContent(FlexAlign.Center)
            .onClick(() => { this.goBack() })

            // 书名
            Text(this.bookTitle)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textPrimary)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: 40, right: 40 })

            // 朗读按钮
            Row() {
              Image($r('app.media.ic_headphone'))
                .width(22)
                .height(22)
                .fillColor(AppTheme.primary)
            }
            .width(40)
            .height(40)
            .justifyContent(FlexAlign.Center)
            .onClick(() => { this.openAudioPlayer() })

            // 更多按钮
            Row() {
              Image($r('app.media.ic_more'))
                .width(22)
                .height(22)
                .fillColor(AppTheme.textPrimary)
            }
            .width(40)
            .height(40)
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .height(56)
          .padding({ left: 4, right: 12 })
        }
        .width('100%')
        .backgroundColor(Color.Transparent)
        .backdropBlur(16)
        .backgroundEffect({ blur: 16, saturation: 0.8 })
        .padding({ top: 48 })
        .animation({ duration: 200 })

        // 底部页码指示器
        Row() {
          Text(`第 ${this.currentPage + 1} / ${this.totalPages || '?'} 页`)
            .fontSize(13)
            .fontColor(AppTheme.textSecondary)
        }
        .width('auto')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .borderRadius(16)
        .backgroundColor('rgba(253,251,247,0.85)')
        .margin({ bottom: 24 })
        .translate({ y: this.showToolbar ? 0 : 40 })
        .opacity(this.showToolbar ? 1 : 0)
        .animation({ duration: 200 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
