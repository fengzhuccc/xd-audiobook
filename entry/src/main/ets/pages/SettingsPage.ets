import { AppStorageV2 } from '@kit.ArkUI';
import { AppTheme } from '../common/theme/AppTheme';
import { READER_THEMES, READER_DEFAULTS, TTS_DEFAULTS, ReaderTheme } from '../common/constants/ReaderConstants';
import { ReaderSettings } from '../common/model/ReaderSettings';
import { TtsSettings } from '../common/model/TtsSettings';
import { PreferencesService } from '../service/PreferencesService';
import { FormatUtil } from '../common/utils/FormatUtil';
import { LogUtil } from '../common/utils/LogUtil';

interface OptionItem<T> {
  label: string;
  value: T;
}

@Component
export struct SettingsPage {
  // 阅读设置
  @State fontSize: number = READER_DEFAULTS.FONT_SIZE;
  @State lineHeight: number = READER_DEFAULTS.LINE_HEIGHT;
  @State flipMode: string = READER_DEFAULTS.FLIP_MODE;
  @State readerTheme: string = READER_DEFAULTS.THEME;
  @State fontFamily: string = READER_DEFAULTS.FONT_FAMILY;
  
  // 朗读设置
  @State ttsSpeed: number = TTS_DEFAULTS.SPEED;
  @State ttsAutoNext: boolean = TTS_DEFAULTS.AUTO_NEXT_CHAPTER;
  @State ttsHighlight: boolean = TTS_DEFAULTS.HIGHLIGHT_ENABLED;
  
  // 通用
  @State storageUsed: string = '计算中...';
  
  // 行距选项
  private lineHeights: OptionItem<number>[] = [
    { label: '紧凑', value: 1.5 },
    { label: '适中', value: 1.9 },
    { label: '宽松', value: 2.2 },
  ];
  
  // 翻页模式
  private flipModes: OptionItem<string>[] = [
    { label: '点击翻页', value: 'click' },
    { label: '滑动翻页', value: 'slide' },
  ];
  
  // 字体选项
  private fontFamilies: OptionItem<string>[] = [
    { label: '宋体', value: 'serif' },
    { label: '黑体', value: 'sans' },
    { label: '楷体', value: 'kai' },
  ];
  
  // 语速选项
  private speeds: number[] = [0.75, 1.0, 1.25, 1.5, 2.0];
  
  aboutToAppear(): void {
    this.loadSettings();
    this.calculateStorage();
  }
  
  private async loadSettings(): Promise<void> {
    const prefService = AppStorageV2.connect(PreferencesService, 'prefService') as PreferencesService;
    if (!prefService) return;
    
    try {
      const readerSettings = await prefService.getReaderSettings();
      this.fontSize = readerSettings.fontSize;
      this.lineHeight = readerSettings.lineHeight;
      this.flipMode = readerSettings.flipMode;
      this.readerTheme = readerSettings.theme;
      this.fontFamily = readerSettings.fontFamily;
      
      const ttsSettings = await prefService.getTtsSettings();
      this.ttsSpeed = ttsSettings.speed;
      this.ttsAutoNext = ttsSettings.autoNextChapter;
      this.ttsHighlight = ttsSettings.highlightEnabled;
    } catch (err) {
      LogUtil.error(`Failed to load settings: ${JSON.stringify(err)}`);
    }
  }
  
  private async saveReaderSettings(): Promise<void> {
    const prefService = AppStorageV2.connect(PreferencesService, 'prefService') as PreferencesService;
    if (!prefService) return;
    
    const settings: ReaderSettings = {
      fontSize: this.fontSize,
      lineHeight: this.lineHeight,
      letterSpacing: 0.02,
      flipMode: this.flipMode as 'click' | 'slide',
      theme: this.readerTheme as 'warm' | 'white' | 'night',
      fontFamily: this.fontFamily as 'serif' | 'sans' | 'kai',
    };
    await prefService.saveReaderSettings(settings);
    // 通知阅读器刷新（通过 AppStorage）
    AppStorage.setOrCreate('readerSettingsChanged', Date.now());
  }
  
  private async saveTtsSettings(): Promise<void> {
    const prefService = AppStorageV2.connect(PreferencesService, 'prefService') as PreferencesService;
    if (!prefService) return;
    
    const settings: TtsSettings = {
      speed: this.ttsSpeed,
      autoNextChapter: this.ttsAutoNext,
      highlightEnabled: this.ttsHighlight,
    };
    await prefService.saveTtsSettings(settings);
  }
  
  private calculateStorage(): void {
    // 简单占位，实际项目中遍历 filesDir/books 和 filesDir/covers 计算总大小
    this.storageUsed = '128 MB / 可用 3.8 GB';
  }

  private getThemeByKey(key: string): ReaderTheme | null {
    if (key === 'warm') return READER_THEMES.warm;
    if (key === 'white') return READER_THEMES.white;
    if (key === 'night') return READER_THEMES.night;
    return null;
  }
  
  build() {
    Column() {
      Row().height(48).width('100%').backgroundColor(AppTheme.surfacePage);
      
      Text('设置')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.textPrimary)
        .margin({ left: 20, right: 20, bottom: 16 })
      
      Scroll() {
        Column({ space: 16 }) {
          // ── 阅读设置卡片 ──
          Column() {
            Text('阅读设置')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textPrimary)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 16 })
            
            // 字号
            Row() {
              Text('字号')
                .fontSize(14)
                .fontColor(AppTheme.textSecondary)
                .layoutWeight(1)
              Row({ space: 12 }) {
                Text('A-')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.fontSize > 12 ? AppTheme.textPrimary : AppTheme.textTertiary)
                  .onClick(() => {
                    if (this.fontSize > 12) { this.fontSize--; this.saveReaderSettings(); }
                  })
                Text('中')
                  .fontSize(14)
                  .fontColor(AppTheme.primary)
                Text('A+')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.fontSize < 28 ? AppTheme.textPrimary : AppTheme.textTertiary)
                  .onClick(() => {
                    if (this.fontSize < 28) { this.fontSize++; this.saveReaderSettings(); }
                  })
              }
            }
            .width('100%')
            .padding({ bottom: 16 })
            
            // 分割线
            Divider().color(AppTheme.borderDefault)
            
            // 行距
            Row() {
              Text('行距')
                .fontSize(14)
                .fontColor(AppTheme.textSecondary)
                .layoutWeight(1)
              Row({ space: 8 }) {
                ForEach(this.lineHeights, (item: OptionItem<number>) => {
                  Text(item.label)
                    .fontSize(13)
                    .fontColor(this.lineHeight === item.value ? Color.White : AppTheme.textSecondary)
                    .backgroundColor(this.lineHeight === item.value ? AppTheme.primary : AppTheme.surfaceInset)
                    .borderRadius(14)
                    .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                    .onClick(() => {
                      this.lineHeight = item.value;
                      this.saveReaderSettings();
                    })
                })
              }
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            
            Divider().color(AppTheme.borderDefault)
            
            // 翻页方式
            Row() {
              Text('翻页方式')
                .fontSize(14)
                .fontColor(AppTheme.textSecondary)
                .layoutWeight(1)
              Row({ space: 8 }) {
                ForEach(this.flipModes, (item: OptionItem<string>) => {
                  Text(item.label)
                    .fontSize(13)
                    .fontColor(this.flipMode === item.value ? Color.White : AppTheme.textSecondary)
                    .backgroundColor(this.flipMode === item.value ? AppTheme.primary : AppTheme.surfaceInset)
                    .borderRadius(14)
                    .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                    .onClick(() => {
                      this.flipMode = item.value;
                      this.saveReaderSettings();
                    })
                })
              }
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            
            Divider().color(AppTheme.borderDefault)
            
            // 阅读主题
            Row() {
              Text('阅读主题')
                .fontSize(14)
                .fontColor(AppTheme.textSecondary)
                .layoutWeight(1)
              Row({ space: 12 }) {
                ForEach(Object.keys(READER_THEMES), (key: string) => {
                  const theme: ReaderTheme | null = this.getThemeByKey(key);
                  Column({ space: 4 }) {
                    Stack() {
                      Column()
                        .width(40)
                        .height(40)
                        .borderRadius(8)
                        .backgroundColor(theme ? theme.backgroundColor : AppTheme.surfaceInset)
                        .border(this.readerTheme === key ?
                          { width: 2, color: AppTheme.primary } :
                          { width: 1, color: AppTheme.borderDefault }
                        )
                      if (this.readerTheme === key) {
                        Image($r('app.media.ic_check'))
                          .width(16).height(16).fillColor(AppTheme.primary)
                      }
                    }
                    Text(theme ? theme.name : '')
                      .fontSize(11)
                      .fontColor(this.readerTheme === key ? AppTheme.primary : AppTheme.textTertiary)
                  }
                  .alignItems(HorizontalAlign.Center)
                  .onClick(() => {
                    this.readerTheme = key;
                    this.saveReaderSettings();
                  })
                })
              }
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            
            Divider().color(AppTheme.borderDefault)
            
            // 字体
            Row() {
              Text('字体')
                .fontSize(14)
                .fontColor(AppTheme.textSecondary)
                .layoutWeight(1)
              Row({ space: 8 }) {
                ForEach(this.fontFamilies, (item: OptionItem<string>) => {
                  Text(item.label)
                    .fontSize(13)
                    .fontColor(this.fontFamily === item.value ? Color.White : AppTheme.textSecondary)
                    .backgroundColor(this.fontFamily === item.value ? AppTheme.primary : AppTheme.surfaceInset)
                    .borderRadius(14)
                    .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                    .onClick(() => {
                      this.fontFamily = item.value;
                      this.saveReaderSettings();
                    })
                })
              }
            }
            .width('100%')
            .padding({ top: 16 })
          }
          .width('100%')
          .padding(20)
          .backgroundColor(AppTheme.surfaceCard)
          .borderRadius(12)
          .shadow({ radius: 4, color: 'rgba(61,53,42,0.04)', offsetY: 1 })
          
          // ── 朗读设置卡片 ──
          Column() {
            Text('朗读设置')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textPrimary)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 16 })
            
            // 语音选择
            Row() {
              Text('语音')
                .fontSize(14)
                .fontColor(AppTheme.textSecondary)
                .layoutWeight(1)
              Row() {
                Text('普通话女声')
                  .fontSize(14)
                  .fontColor(AppTheme.textPrimary)
                Image($r('app.media.ic_arrow_right'))
                  .width(16).height(16).fillColor(AppTheme.textTertiary)
                  .margin({ left: 8 })
              }
            }
            .width('100%')
            .padding({ bottom: 16 })
            
            Divider().color(AppTheme.borderDefault)
            
            // 语速
            Row() {
              Text('语速')
                .fontSize(14)
                .fontColor(AppTheme.textSecondary)
                .layoutWeight(1)
              Row({ space: 8 }) {
                ForEach(this.speeds, (speed: number) => {
                  Text(`${speed}x`)
                    .fontSize(13)
                    .fontColor(this.ttsSpeed === speed ? Color.White : AppTheme.textSecondary)
                    .backgroundColor(this.ttsSpeed === speed ? AppTheme.primary : AppTheme.surfaceInset)
                    .borderRadius(14)
                    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                    .onClick(() => {
                      this.ttsSpeed = speed;
                      this.saveTtsSettings();
                    })
                })
              }
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            
            Divider().color(AppTheme.borderDefault)
            
            // 自动播放下一章
            Row() {
              Text('自动播放下一章')
                .fontSize(14)
                .fontColor(AppTheme.textSecondary)
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.ttsAutoNext })
                .onChange((isOn: boolean) => {
                  this.ttsAutoNext = isOn;
                  this.saveTtsSettings();
                })
                .selectedColor(AppTheme.primary)
            }
            .width('100%')
            .padding({ top: 4, bottom: 16 })
            
            Divider().color(AppTheme.borderDefault)
            
            // 朗读高亮
            Row() {
              Text('朗读时高亮当前文字')
                .fontSize(14)
                .fontColor(AppTheme.textSecondary)
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.ttsHighlight })
                .onChange((isOn: boolean) => {
                  this.ttsHighlight = isOn;
                  this.saveTtsSettings();
                })
                .selectedColor(AppTheme.primary)
            }
            .width('100%')
            .padding({ top: 4 })
          }
          .width('100%')
          .padding(20)
          .backgroundColor(AppTheme.surfaceCard)
          .borderRadius(12)
          .shadow({ radius: 4, color: 'rgba(61,53,42,0.04)', offsetY: 1 })
          
          // ── 通用设置卡片 ──
          Column() {
            Text('通用')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textPrimary)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 16 })
            
            // 语言
            Row() {
              Text('语言')
                .fontSize(14)
                .fontColor(AppTheme.textSecondary)
                .layoutWeight(1)
              Row() {
                Text('简体中文')
                  .fontSize(14)
                  .fontColor(AppTheme.textPrimary)
                Image($r('app.media.ic_arrow_right'))
                  .width(16).height(16).fillColor(AppTheme.textTertiary)
                  .margin({ left: 8 })
              }
            }
            .width('100%')
            .padding({ bottom: 16 })
            
            Divider().color(AppTheme.borderDefault)
            
            // 存储空间
            Row() {
              Text('存储空间')
                .fontSize(14)
                .fontColor(AppTheme.textSecondary)
                .layoutWeight(1)
              Text(this.storageUsed)
                .fontSize(12)
                .fontColor(AppTheme.textTertiary)
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            
            Divider().color(AppTheme.borderDefault)
            
            // 清除缓存
            Row() {
              Text('清除缓存')
                .fontSize(14)
                .fontColor(AppTheme.textSecondary)
                .layoutWeight(1)
              Text('23 MB')
                .fontSize(13)
                .fontColor(AppTheme.error)
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            
            Divider().color(AppTheme.borderDefault)
            
            // 关于
            Row() {
              Text('关于')
                .fontSize(14)
                .fontColor(AppTheme.textSecondary)
                .layoutWeight(1)
              Row() {
                Text('书声 v1.0.0')
                  .fontSize(14)
                  .fontColor(AppTheme.textPrimary)
                Image($r('app.media.ic_arrow_right'))
                  .width(16).height(16).fillColor(AppTheme.textTertiary)
                  .margin({ left: 8 })
              }
            }
            .width('100%')
            .padding({ top: 16 })
          }
          .width('100%')
          .padding(20)
          .backgroundColor(AppTheme.surfaceCard)
          .borderRadius(12)
          .shadow({ radius: 4, color: 'rgba(61,53,42,0.04)', offsetY: 1 })
          
          // 底部间距
          Row().height(40)
        }
        .width('100%')
        .padding({ top: 8 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.surfacePage)
  }
}
