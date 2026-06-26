import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { APP_NAME, PREF_NAME } from '../common/constants/AppConstants';
import { READER_DEFAULTS, TTS_DEFAULTS } from '../common/constants/ReaderConstants';
import { ReaderSettings } from '../common/model/ReaderSettings';
import { TtsSettings } from '../common/model/TtsSettings';
import { LogUtil } from '../common/utils/LogUtil';

const PREF_KEYS = {
  FONT_SIZE: 'reader_fontSize',
  LINE_HEIGHT: 'reader_lineHeight',
  LETTER_SPACING: 'reader_letterSpacing',
  FLIP_MODE: 'reader_flipMode',
  READER_THEME: 'reader_theme',
  FONT_FAMILY: 'reader_fontFamily',
  TTS_SPEED: 'tts_speed',
  TTS_AUTO_NEXT: 'tts_autoNextChapter',
  TTS_HIGHLIGHT: 'tts_highlightEnabled',
  LAST_BOOK_ID: 'last_opened_book_id',
};

export class PreferencesService {
  private prefInstance: preferences.Preferences | null = null;

  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.prefInstance = await preferences.getPreferences(context, PREF_NAME);
      LogUtil.info('PreferencesService initialized');
    } catch (err) {
      LogUtil.error(`Failed to init preferences: ${JSON.stringify(err)}`);
    }
  }

  // ── 阅读设置 ──
  async getReaderSettings(): Promise<ReaderSettings> {
    if (!this.prefInstance) return { ...READER_DEFAULTS } as ReaderSettings;
    try {
      const settings: ReaderSettings = {
        fontSize: (await this.prefInstance.get(PREF_KEYS.FONT_SIZE, READER_DEFAULTS.FONT_SIZE)) as number,
        lineHeight: (await this.prefInstance.get(PREF_KEYS.LINE_HEIGHT, READER_DEFAULTS.LINE_HEIGHT)) as number,
        letterSpacing: (await this.prefInstance.get(PREF_KEYS.LETTER_SPACING, READER_DEFAULTS.LETTER_SPACING)) as number,
        flipMode: (await this.prefInstance.get(PREF_KEYS.FLIP_MODE, READER_DEFAULTS.FLIP_MODE)) as 'click' | 'slide',
        theme: (await this.prefInstance.get(PREF_KEYS.READER_THEME, READER_DEFAULTS.THEME)) as 'warm' | 'white' | 'night',
        fontFamily: (await this.prefInstance.get(PREF_KEYS.FONT_FAMILY, READER_DEFAULTS.FONT_FAMILY)) as 'serif' | 'sans' | 'kai',
      };
      return settings;
    } catch (err) {
      LogUtil.error(`Failed to get reader settings: ${JSON.stringify(err)}`);
      return { ...READER_DEFAULTS } as ReaderSettings;
    }
  }

  async saveReaderSettings(settings: ReaderSettings): Promise<void> {
    if (!this.prefInstance) return;
    try {
      await this.prefInstance.put(PREF_KEYS.FONT_SIZE, settings.fontSize);
      await this.prefInstance.put(PREF_KEYS.LINE_HEIGHT, settings.lineHeight);
      await this.prefInstance.put(PREF_KEYS.LETTER_SPACING, settings.letterSpacing);
      await this.prefInstance.put(PREF_KEYS.FLIP_MODE, settings.flipMode);
      await this.prefInstance.put(PREF_KEYS.READER_THEME, settings.theme);
      await this.prefInstance.put(PREF_KEYS.FONT_FAMILY, settings.fontFamily);
      await this.prefInstance.flush();
      LogUtil.info('Reader settings saved');
    } catch (err) {
      LogUtil.error(`Failed to save reader settings: ${JSON.stringify(err)}`);
    }
  }

  // ── 朗读设置 ──
  async getTtsSettings(): Promise<TtsSettings> {
    if (!this.prefInstance) return { ...TTS_DEFAULTS } as TtsSettings;
    try {
      const settings: TtsSettings = {
        speed: (await this.prefInstance.get(PREF_KEYS.TTS_SPEED, TTS_DEFAULTS.SPEED)) as number,
        autoNextChapter: (await this.prefInstance.get(PREF_KEYS.TTS_AUTO_NEXT, TTS_DEFAULTS.AUTO_NEXT_CHAPTER)) as boolean,
        highlightEnabled: (await this.prefInstance.get(PREF_KEYS.TTS_HIGHLIGHT, TTS_DEFAULTS.HIGHLIGHT_ENABLED)) as boolean,
      };
      return settings;
    } catch (err) {
      LogUtil.error(`Failed to get TTS settings: ${JSON.stringify(err)}`);
      return { ...TTS_DEFAULTS } as TtsSettings;
    }
  }

  async saveTtsSettings(settings: TtsSettings): Promise<void> {
    if (!this.prefInstance) return;
    try {
      await this.prefInstance.put(PREF_KEYS.TTS_SPEED, settings.speed);
      await this.prefInstance.put(PREF_KEYS.TTS_AUTO_NEXT, settings.autoNextChapter);
      await this.prefInstance.put(PREF_KEYS.TTS_HIGHLIGHT, settings.highlightEnabled);
      await this.prefInstance.flush();
      LogUtil.info('TTS settings saved');
    } catch (err) {
      LogUtil.error(`Failed to save TTS settings: ${JSON.stringify(err)}`);
    }
  }

  // ── 通用键值操作 ──
  async set(key: string, value: preferences.ValueType): Promise<void> {
    if (!this.prefInstance) return;
    try {
      await this.prefInstance.put(key, value);
      await this.prefInstance.flush();
    } catch (err) {
      LogUtil.error(`Failed to set preference [${key}]: ${JSON.stringify(err)}`);
    }
  }

  async get(key: string, defaultValue: preferences.ValueType): Promise<preferences.ValueType> {
    if (!this.prefInstance) return defaultValue;
    try {
      return await this.prefInstance.get(key, defaultValue);
    } catch (err) {
      LogUtil.error(`Failed to get preference [${key}]: ${JSON.stringify(err)}`);
      return defaultValue;
    }
  }
}
