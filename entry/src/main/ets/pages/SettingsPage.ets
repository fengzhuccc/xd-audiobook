import { AppStorageV2 } from '@kit.ArkUI';
import { AppTheme } from '../common/theme/AppTheme';
import { READER_THEMES, READER_DEFAULTS, TTS_DEFAULTS, ReaderTheme } from '../common/constants/ReaderConstants';
import { ReaderSettings } from '../common/model/ReaderSettings';
import { TtsSettings } from '../common/model/TtsSettings';
import { PreferencesService } from '../service/PreferencesService';
import { LogUtil } from '../common/utils/LogUtil';

interface OptionItem<T> {
  label: string;
  value: T;
}

interface ThemeOption {
  key: string;
  theme: ReaderTheme;
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

  // 主题选项
  private themeOptions: ThemeOption[] = [
    { key: 'warm', theme: READER_THEMES.warm },
    { key: 'white', theme: READER_THEMES.white },
    { key: 'night', theme: READER_THEMES.night },
  ];

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

  build() {
    Column() {
      // ── 状态栏占位 ──
      Row()
        .height(48)
        .width('100%')
        .backgroundColor(AppTheme.surfacePage)

      // ── 标题 ──
      Text('设置')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textPrimary)
        .width('100%')
        .padding({ left: 20, top: 12, bottom: 12 })

      // ── 滚动内容 ──
      Scroll() {
        Column({ space: 12 }) {
          // ===== 阅读设置卡片 =====
          Column() {
            Text('阅读设置')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textSecondary)
              .letterSpacing(0.5)
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 4 })

            // 字号
            Row() {
              Text('字号')
                .fontSize(14)
                .fontColor(AppTheme.textPrimary)
                .layoutWeight(1)
              Row({ space: 12 }) {
                Row() {
                  Text('A-')
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.textSecondary)
                }
                .width(32)
                .height(32)
                .borderRadius(4)
                .border({ width: 1, color: AppTheme.borderDefault })
                .backgroundColor(AppTheme.surfaceInset)
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .onClick(() => {
                  if (this.fontSize > 12) {
                    this.fontSize--;
                    this.saveReaderSettings();
                  }
                })

                Text('中')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.textPrimary)
                  .constraintSize({ minWidth: 28 })
                  .textAlign(TextAlign.Center)

                Row() {
                  Text('A+')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppTheme.textSecondary)
                }
                .width(32)
                .height(32)
                .borderRadius(4)
                .border({ width: 1, color: AppTheme.borderDefault })
                .backgroundColor(AppTheme.surfaceInset)
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .onClick(() => {
                  if (this.fontSize < 28) {
                    this.fontSize++;
                    this.saveReaderSettings();
                  }
                })
              }
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .padding(16)

            Divider().color(AppTheme.borderSubtle).strokeWidth(1)

            // 行距
            Column() {
              Text('行距')
                .fontSize(14)
                .fontColor(AppTheme.textPrimary)
                .width('100%')
                .margin({ bottom: 8 })
              Row({ space: 8 }) {
                ForEach(this.lineHeights, (item: OptionItem<number>) => {
                  Text(item.label)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.lineHeight === item.value ? AppTheme.primary : AppTheme.textTertiary)
                    .backgroundColor(this.lineHeight === item.value ? AppTheme.primaryLightest : AppTheme.surfaceInset)
                    .border(this.lineHeight === item.value ?
                      { width: 1.5, color: AppTheme.primary } :
                      { width: 1, color: AppTheme.borderDefault })
                    .borderRadius(4)
                    .padding({ top: 6, bottom: 6 })
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                    .onClick(() => {
                      this.lineHeight = item.value;
                      this.saveReaderSettings();
                    })
                }, (item: OptionItem<number>) => `${item.value}`)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)

            Divider().color(AppTheme.borderSubtle).strokeWidth(1)

            // 翻页方式
            Column() {
              Text('翻页方式')
                .fontSize(14)
                .fontColor(AppTheme.textPrimary)
                .width('100%')
                .margin({ bottom: 8 })
              Row({ space: 8 }) {
                ForEach(this.flipModes, (item: OptionItem<string>) => {
                  Text(item.label)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.flipMode === item.value ? AppTheme.primary : AppTheme.textTertiary)
                    .backgroundColor(this.flipMode === item.value ? AppTheme.primaryLightest : AppTheme.surfaceInset)
                    .border(this.flipMode === item.value ?
                      { width: 1.5, color: AppTheme.primary } :
                      { width: 1, color: AppTheme.borderDefault })
                    .borderRadius(4)
                    .padding({ top: 6, bottom: 6 })
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                    .onClick(() => {
                      this.flipMode = item.value;
                      this.saveReaderSettings();
                    })
                }, (item: OptionItem<string>) => item.value)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)

            Divider().color(AppTheme.borderSubtle).strokeWidth(1)

            // 阅读主题
            Column() {
              Text('阅读主题')
                .fontSize(14)
                .fontColor(AppTheme.textPrimary)
                .width('100%')
                .margin({ bottom: 10 })
              Row({ space: 12 }) {
                ForEach(this.themeOptions, (item: ThemeOption) => {
                  Column() {
                    Stack({ alignContent: Alignment.TopEnd }) {
                      Column() {
                        Text('在人间')
                          .fontSize(5)
                          .fontFamily('serif')
                          .fontColor(item.theme.fontColor)
                          .opacity(0.9)
                          .lineHeight(8)
                        Text('第一章 童年')
                          .fontSize(5)
                          .fontFamily('serif')
                          .fontColor(item.theme.fontColor)
                          .opacity(0.5)
                          .lineHeight(8)
                          .margin({ top: 2 })
                        Text('在一个幽暗的')
                          .fontSize(5)
                          .fontFamily('serif')
                          .fontColor(item.theme.fontColor)
                          .opacity(0.3)
                          .lineHeight(8)
                          .margin({ top: 2 })
                      }
                      .width('100%')
                      .height('100%')
                      .alignItems(HorizontalAlign.Start)
                      .padding({ left: 6, right: 6, top: 8, bottom: 4 })

                      if (this.readerTheme === item.key) {
                        Row() {
                          Image($r('app.media.ic_check'))
                            .width(8)
                            .height(8)
                            .fillColor(Color.White)
                        }
                        .width(14)
                        .height(14)
                        .borderRadius(7)
                        .backgroundColor(AppTheme.primary)
                        .justifyContent(FlexAlign.Center)
                        .alignItems(VerticalAlign.Center)
                        .margin({ top: 3, right: 3 })
                      }
                    }
                    .width('100%')
                    .aspectRatio(0.75)
                    .borderRadius(4)
                    .backgroundColor(item.theme.backgroundColor)
                    .border(this.readerTheme === item.key ?
                      { width: 2, color: AppTheme.primary } :
                      { width: 1, color: AppTheme.borderDefault })
                    .clip(true)

                    Text(item.theme.name)
                      .fontSize(12)
                      .fontWeight(this.readerTheme === item.key ? FontWeight.Medium : FontWeight.Normal)
                      .fontColor(this.readerTheme === item.key ? AppTheme.primary : AppTheme.textTertiary)
                      .margin({ top: 6 })
                  }
                  .alignItems(HorizontalAlign.Center)
                  .layoutWeight(1)
                  .onClick(() => {
                    this.readerTheme = item.key;
                    this.saveReaderSettings();
                  })
                }, (item: ThemeOption) => item.key)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }
            .width('100%')
            .padding(16)

            Divider().color(AppTheme.borderSubtle).strokeWidth(1)

            // 字体
            Column() {
              Text('字体')
                .fontSize(14)
                .fontColor(AppTheme.textPrimary)
                .width('100%')
                .margin({ bottom: 8 })
              Row({ space: 8 }) {
                ForEach(this.fontFamilies, (item: OptionItem<string>) => {
                  Text(item.label)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.fontFamily === item.value ? AppTheme.primary : AppTheme.textTertiary)
                    .backgroundColor(this.fontFamily === item.value ? AppTheme.primaryLightest : AppTheme.surfaceInset)
                    .border(this.fontFamily === item.value ?
                      { width: 1.5, color: AppTheme.primary } :
                      { width: 1, color: AppTheme.borderDefault })
                    .borderRadius(4)
                    .padding({ top: 6, bottom: 6 })
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                    .onClick(() => {
                      this.fontFamily = item.value;
                      this.saveReaderSettings();
                    })
                }, (item: OptionItem<string>) => item.value)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
          }
          .width('100%')
          .backgroundColor(AppTheme.surfaceCard)
          .border({ width: 1, color: AppTheme.borderDefault })
          .borderRadius(8)
          .shadow({ radius: 2, color: 'rgba(61,53,42,0.04)', offsetX: 0, offsetY: 1 })
          .clip(true)

          // ===== 朗读设置卡片 =====
          Column() {
            Text('朗读设置')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textSecondary)
              .letterSpacing(0.5)
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 4 })

            // 语音
            Row() {
              Text('语音')
                .fontSize(14)
                .fontColor(AppTheme.textPrimary)
                .layoutWeight(1)
              Row() {
                Text('普通话女声')
                  .fontSize(14)
                  .fontColor(AppTheme.textSecondary)
                Image($r('app.media.ic_arrow_right'))
                  .width(16)
                  .height(16)
                  .fillColor(AppTheme.textTertiary)
                  .margin({ left: 4 })
              }
              .alignItems(VerticalAlign.Center)
              .onClick(() => {})
            }
            .width('100%')
            .padding(16)

            Divider().color(AppTheme.borderSubtle).strokeWidth(1)

            // 语速
            Column() {
              Text('语速')
                .fontSize(14)
                .fontColor(AppTheme.textPrimary)
                .width('100%')
                .margin({ bottom: 8 })
              Row({ space: 6 }) {
                ForEach(this.speeds, (speed: number) => {
                  Text(`${speed % 1 === 0 ? speed.toFixed(1) : speed}x`)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.ttsSpeed === speed ? AppTheme.primary : AppTheme.textTertiary)
                    .backgroundColor(this.ttsSpeed === speed ? AppTheme.primaryLightest : AppTheme.surfaceInset)
                    .border(this.ttsSpeed === speed ?
                      { width: 1.5, color: AppTheme.primary } :
                      { width: 1, color: AppTheme.borderDefault })
                    .borderRadius(4)
                    .padding({ top: 6, bottom: 6 })
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                    .onClick(() => {
                      this.ttsSpeed = speed;
                      this.saveTtsSettings();
                    })
                }, (speed: number) => `${speed}`)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)

            Divider().color(AppTheme.borderSubtle).strokeWidth(1)

            // 自动播放下一章
            Row() {
              Text('自动播放下一章')
                .fontSize(14)
                .fontColor(AppTheme.textPrimary)
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.ttsAutoNext })
                .selectedColor(AppTheme.primary)
                .onChange((isOn: boolean) => {
                  this.ttsAutoNext = isOn;
                  this.saveTtsSettings();
                })
            }
            .width('100%')
            .padding(16)

            Divider().color(AppTheme.borderSubtle).strokeWidth(1)

            // 朗读时高亮当前文字
            Row() {
              Text('朗读时高亮当前文字')
                .fontSize(14)
                .fontColor(AppTheme.textPrimary)
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.ttsHighlight })
                .selectedColor(AppTheme.primary)
                .onChange((isOn: boolean) => {
                  this.ttsHighlight = isOn;
                  this.saveTtsSettings();
                })
            }
            .width('100%')
            .padding(16)
          }
          .width('100%')
          .backgroundColor(AppTheme.surfaceCard)
          .border({ width: 1, color: AppTheme.borderDefault })
          .borderRadius(8)
          .shadow({ radius: 2, color: 'rgba(61,53,42,0.04)', offsetX: 0, offsetY: 1 })
          .clip(true)

          // ===== 通用卡片 =====
          Column() {
            Text('通用')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textSecondary)
              .letterSpacing(0.5)
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 4 })

            // 语言
            Row() {
              Text('语言')
                .fontSize(14)
                .fontColor(AppTheme.textPrimary)
                .layoutWeight(1)
              Row() {
                Text('简体中文')
                  .fontSize(14)
                  .fontColor(AppTheme.textSecondary)
                Image($r('app.media.ic_arrow_right'))
                  .width(16)
                  .height(16)
                  .fillColor(AppTheme.textTertiary)
                  .margin({ left: 4 })
              }
              .alignItems(VerticalAlign.Center)
              .onClick(() => {})
            }
            .width('100%')
            .padding(16)

            Divider().color(AppTheme.borderSubtle).strokeWidth(1)

            // 存储
            Column() {
              Text('存储')
                .fontSize(14)
                .fontColor(AppTheme.textPrimary)
                .width('100%')
                .margin({ bottom: 8 })
              Text(`已使用 ${this.storageUsed}`)
                .fontSize(12)
                .fontColor(AppTheme.textTertiary)
                .width('100%')
                .margin({ bottom: 6 })
              Row() {
                Row()
                  .width('3.2%')
                  .height('100%')
                  .backgroundColor(AppTheme.primary)
                  .borderRadius(3)
              }
              .width('100%')
              .height(6)
              .borderRadius(3)
              .backgroundColor(AppTheme.surfaceInset)
              .clip(true)
            }
            .width('100%')
            .padding(16)

            Divider().color(AppTheme.borderSubtle).strokeWidth(1)

            // 清除缓存
            Row() {
              Text('清除缓存')
                .fontSize(14)
                .fontColor(AppTheme.textPrimary)
                .layoutWeight(1)
              Text('清除缓存 (23 MB)')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.textSecondary)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .borderRadius(4)
                .border({ width: 1, color: AppTheme.borderDefault })
                .backgroundColor(AppTheme.surfaceInset)
                .onClick(() => {})
            }
            .width('100%')
            .padding(16)

            Divider().color(AppTheme.borderSubtle).strokeWidth(1)

            // 关于
            Row() {
              Text('关于')
                .fontSize(14)
                .fontColor(AppTheme.textPrimary)
                .layoutWeight(1)
              Row() {
                Text('书声 v1.0.0')
                  .fontSize(14)
                  .fontColor(AppTheme.textTertiary)
                Image($r('app.media.ic_arrow_right'))
                  .width(16)
                  .height(16)
                  .fillColor(AppTheme.textTertiary)
                  .margin({ left: 4 })
              }
              .alignItems(VerticalAlign.Center)
              .onClick(() => {})
            }
            .width('100%')
            .padding(16)
          }
          .width('100%')
          .backgroundColor(AppTheme.surfaceCard)
          .border({ width: 1, color: AppTheme.borderDefault })
          .borderRadius(8)
          .shadow({ radius: 2, color: 'rgba(61,53,42,0.04)', offsetX: 0, offsetY: 1 })
          .clip(true)

          // 底部间距
          Row().height(40)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.surfacePage)
  }
}
