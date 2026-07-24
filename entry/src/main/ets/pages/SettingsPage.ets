import { AppStorageV2 } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppTheme } from '../common/theme/AppTheme';
import { READER_THEMES, READER_DEFAULTS, TTS_DEFAULTS, ReaderTheme } from '../common/constants/ReaderConstants';
import { ReaderSettings } from '../common/model/ReaderSettings';
import { TtsSettings } from '../common/model/TtsSettings';
import { PreferencesService } from '../service/PreferencesService';
import { TtsService, VoiceOption, TtsEngineType } from '../service/TtsService';
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
  @State ttsVoicePerson: number = TTS_DEFAULTS.VOICE_PERSON;
  @State ttsEngineType: TtsEngineType = TTS_DEFAULTS.ENGINE_TYPE;
  @State voiceOptions: VoiceOption[] = [];
  @State voicePickerVisible: boolean = false;
  @State voicePickerLoading: boolean = false;

  // 引擎选项
  private engineOptions: OptionItem<TtsEngineType>[] = [
    { label: '系统语音', value: 'system' },
    { label: 'Qwen 本地语音', value: 'qwen' },
  ];

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
    this.loadVoiceOptions();
    this.calculateStorage();
  }

  private async loadVoiceOptions(): Promise<void> {
    if (this.ttsEngineType === 'qwen') {
      this.voiceOptions = TtsService.getQwenVoiceOptions();
      return;
    }

    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const voices = await TtsService.getAvailableVoices(context);
      this.voiceOptions = voices.length > 0 ? voices : this.getFallbackVoiceOptions();
    } catch (err) {
      LogUtil.error(`Failed to load voice options: ${JSON.stringify(err)}`);
      this.voiceOptions = this.getFallbackVoiceOptions();
    }
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
      this.ttsVoicePerson = ttsSettings.voicePerson;
      this.ttsEngineType = ttsSettings.engineType;
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
      voicePerson: this.ttsVoicePerson,
      engineType: this.ttsEngineType,
    };
    await prefService.saveTtsSettings(settings);
  }

  private getSelectedVoiceName(): string {
    const option = this.voiceOptions.find((item) => item.person === this.ttsVoicePerson);
    return option?.name || '默认音色';
  }

  private async openVoicePicker(): Promise<void> {
    this.voicePickerVisible = true;
    if (this.ttsEngineType === 'qwen') {
      this.voiceOptions = TtsService.getQwenVoiceOptions();
      return;
    }
    if (this.voiceOptions.length > 0) {
      return;
    }
    this.voicePickerLoading = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const voices = await TtsService.getAvailableVoices(context);
      this.voiceOptions = voices.length > 0 ? voices : this.getFallbackVoiceOptions();
    } catch (err) {
      LogUtil.error(`Failed to load voices: ${JSON.stringify(err)}`);
      this.voiceOptions = this.getFallbackVoiceOptions();
    } finally {
      this.voicePickerLoading = false;
    }
  }

  private getFallbackVoiceOptions(): VoiceOption[] {
    return [
      { person: 0, name: '默认女声', description: '系统默认女声' } as VoiceOption
    ];
  }

  private selectVoice(person: number): void {
    this.ttsVoicePerson = person;
    this.saveTtsSettings();
    this.voicePickerVisible = false;
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

            // TTS 引擎选择
            Column() {
              Text('朗读引擎')
                .fontSize(14)
                .fontColor(AppTheme.textPrimary)
                .width('100%')
                .margin({ bottom: 8 })
              Row({ space: 8 }) {
                ForEach(this.engineOptions, (item: OptionItem<TtsEngineType>) => {
                  Text(item.label)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.ttsEngineType === item.value ? AppTheme.primary : AppTheme.textTertiary)
                    .backgroundColor(this.ttsEngineType === item.value ? AppTheme.primaryLightest : AppTheme.surfaceInset)
                    .border(this.ttsEngineType === item.value ?
                      { width: 1.5, color: AppTheme.primary } :
                      { width: 1, color: AppTheme.borderDefault })
                    .borderRadius(4)
                    .padding({ top: 6, bottom: 6 })
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                    .onClick(() => {
                      this.ttsEngineType = item.value;
                      // 切换引擎后重置音色，避免用系统音色编号匹配 Qwen 音色
                      if (item.value === 'qwen') {
                        this.ttsVoicePerson = TtsService.getQwenVoiceOptions()[0]?.person ?? 0;
                      } else {
                        this.ttsVoicePerson = TTS_DEFAULTS.VOICE_PERSON;
                      }
                      this.loadVoiceOptions();
                      this.saveTtsSettings();
                    })
                }, (item: OptionItem<TtsEngineType>) => item.value)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)

            Divider().color(AppTheme.borderSubtle).strokeWidth(1)

            // 语音
            Row() {
              Text('语音')
                .fontSize(14)
                .fontColor(AppTheme.textPrimary)
                .layoutWeight(1)
              Row() {
                Text(this.getSelectedVoiceName())
                  .fontSize(14)
                  .fontColor(AppTheme.textSecondary)
                Image($r('app.media.ic_arrow_right'))
                  .width(16)
                  .height(16)
                  .fillColor(AppTheme.textTertiary)
                  .margin({ left: 4 })
              }
              .alignItems(VerticalAlign.Center)
              .onClick(() => { this.openVoicePicker() })
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

      // 音色选择弹窗
      if (this.voicePickerVisible) {
        Stack({ alignContent: Alignment.Bottom }) {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0,0,0,0.4)')
            .onClick(() => { this.voicePickerVisible = false })

          Column() {
            Row()
              .width(40)
              .height(4)
              .borderRadius(2)
              .backgroundColor(AppTheme.borderDefault)
              .margin({ top: 12, bottom: 12 })

            Text('选择语音')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textPrimary)
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 12 })

            if (this.voicePickerLoading) {
              Row() {
                Text('正在加载可用音色...')
                  .fontSize(14)
                  .fontColor(AppTheme.textSecondary)
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding({ top: 32, bottom: 32 })
            } else {
              Scroll() {
                Column({ space: 4 }) {
                  ForEach(this.voiceOptions, (voice: VoiceOption) => {
                    Row() {
                      Column() {
                        Text(voice.name)
                          .fontSize(14)
                          .fontColor(this.ttsVoicePerson === voice.person ? AppTheme.primary : AppTheme.textPrimary)
                          .fontWeight(this.ttsVoicePerson === voice.person ? FontWeight.Medium : FontWeight.Normal)
                        if (voice.description.length > 0 && voice.description !== voice.name) {
                          Text(voice.description)
                            .fontSize(12)
                            .fontColor(AppTheme.textTertiary)
                            .margin({ top: 2 })
                        }
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)

                      if (this.ttsVoicePerson === voice.person) {
                        Image($r('app.media.ic_check'))
                          .width(18)
                          .height(18)
                          .fillColor(AppTheme.primary)
                      }
                    }
                    .width('100%')
                    .padding(16)
                    .backgroundColor(this.ttsVoicePerson === voice.person ? AppTheme.primaryLightest : Color.Transparent)
                    .borderRadius(8)
                    .onClick(() => { this.selectVoice(voice.person) })
                  }, (voice: VoiceOption) => `${voice.person}`)
                }
                .width('100%')
                .padding({ left: 12, right: 12 })
              }
              .width('100%')
              .constraintSize({ maxHeight: 360 })
              .scrollBar(BarState.Off)
            }

            Row().height(24)
          }
          .width('100%')
          .backgroundColor(AppTheme.surfaceCard)
          .borderRadius({ topLeft: 16, topRight: 16 })
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.surfacePage)
  }
}
