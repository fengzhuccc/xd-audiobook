import { router, promptAction, AppStorageV2, display } from '@kit.ArkUI';
import { bookParser, readerCore, ReadPageComponent } from '@kit.ReaderKit';
import { common } from '@kit.AbilityKit';
import { AppTheme } from '../common/theme/AppTheme';
import { READER_THEMES, ReaderTheme, createDefaultReaderSettings } from '../common/constants/ReaderConstants';
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
  @State currentSpineIndex: number = 0;
  @State totalSpines: number = 0;
  @State isLoading: boolean = true;
  @State readerSettings: ReaderSettings = createDefaultReaderSettings();

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

    if (!this.filePath) {
      promptAction.showToast({ message: '文件路径无效' });
      router.back();
      return;
    }

    this.loadSettings();
    this.initReader();
  }

  onPageHide(): void {
    // 页面隐藏时保存进度
    this.saveProgress();
  }

  aboutToDisappear(): void {
    // 保存进度并释放资源
    this.saveProgress();
    try {
      this.readerController.releaseBook();
      LogUtil.info('Reader resources released');
    } catch (err) {
      LogUtil.warn(`Release error: ${JSON.stringify(err)}`);
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

      // 初始化解析器
      this.bookParserHandler = await bookParser.getDefaultHandler(this.filePath);
      const bookInfo = this.bookParserHandler.getBookInfo();
      this.bookTitle = bookInfo.bookTitle;

      // 获取总章节数
      const spineList = this.bookParserHandler.getSpineList();
      this.totalSpines = spineList.length;

      // 获取已保存的进度
      const bookDb = AppStorageV2.connect(BookDatabase, 'bookDb') as BookDatabase;
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

      // 注册翻页回调，跟踪当前章节
      this.readerController.on('pageShow', (data: readerCore.PageDataInfo) => {
        if (data && data.resourceIndex >= 0) {
          this.currentSpineIndex = data.resourceIndex;
        }
      });

      // 开始阅读
      this.readerController.startPlay(savedSpineIndex, savedDomPos);
      this.currentSpineIndex = savedSpineIndex;

      this.isLoading = false;
      LogUtil.info(`Reader initialized: ${this.bookTitle}, totalSpines=${this.totalSpines}`);
    } catch (err) {
      const error = err as BusinessError;
      LogUtil.error(`Failed to init reader: code=${error.code}, msg=${error.message}`);
      this.isLoading = false;
      promptAction.showToast({ message: '打开书籍失败' });
    }
  }

  private getThemeByKey(key: string): ReaderTheme | null {
    if (key === 'warm') return READER_THEMES.warm;
    if (key === 'white') return READER_THEMES.white;
    if (key === 'night') return READER_THEMES.night;
    return null;
  }

  private applySettings(): void {
    const theme = this.getThemeByKey(this.readerSettings.theme);
    if (!theme) return;
    try {
      const pageConfig: readerCore.ReaderSetting = {
        fontName: '系统字体',
        fontPath: '',
        fontSize: this.readerSettings.fontSize,
        fontWeight: 400,
        fontColor: theme.fontColor,
        lineHeight: this.readerSettings.lineHeight,
        nightMode: theme.name === '夜间',
        themeColor: theme.backgroundColor,
        themeBgImg: '',
        flipMode: this.readerSettings.flipMode === 'slide' ? '1' : '0',
        scaledDensity: display.getDefaultDisplaySync().scaledDensity > 0 ? display.getDefaultDisplaySync().scaledDensity : 1,
        viewPortWidth: display.getDefaultDisplaySync().width,
        viewPortHeight: display.getDefaultDisplaySync().height,
      };
      this.readerController.setPageConfig(pageConfig);
    } catch (err) {
      LogUtil.error(`Failed to apply settings: ${JSON.stringify(err)}`);
    }
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

  build() {
    Stack() {
      // 阅读器组件
      ReadPageComponent({
        controller: this.readerController,
        readerCallback: (err: BusinessError, data: readerCore.ReaderComponentController) => {
          if (!err && data) {
            // 使用回调返回的控制器实例，但不替换原始引用以避免资源泄漏
            LogUtil.info('ReadPageComponent callback success');
          }
        }
      })
      .width('100%')
      .height('100%')
      .onClick(() => {
        // 点击切换工具栏显隐
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
        .backgroundEffect({ radius: 16, saturation: 0.8 })
        .padding({ top: 48 })

        // 底部页码指示器
        Row() {
          Text(`第 ${this.currentSpineIndex + 1} / ${this.totalSpines || '?'} 章`)
            .fontSize(13)
            .fontColor(AppTheme.textSecondary)
        }
        .width('auto')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .borderRadius(16)
        .backgroundColor('rgba(253,251,247,0.85)')
        .margin({ bottom: 24 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
