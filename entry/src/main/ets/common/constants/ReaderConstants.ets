// 阅读器默认配置
export interface ReaderDefaults {
  FONT_SIZE: number;
  LINE_HEIGHT: number;
  LETTER_SPACING: number;
  FLIP_MODE: string;
  THEME: string;
  FONT_FAMILY: string;
}

export const READER_DEFAULTS: ReaderDefaults = {
  FONT_SIZE: 17,        // 默认字号 (sp)
  LINE_HEIGHT: 1.9,      // 默认行高
  LETTER_SPACING: 0.02,  // 字间距
  FLIP_MODE: 'slide', // 默认翻页模式
  THEME: 'warm',      // 默认主题
  FONT_FAMILY: 'serif' // 默认字体
};

// 阅读主题预设
export interface ReaderTheme {
  name: string;
  backgroundColor: string;
  fontColor: string;
}

export interface ReaderThemes {
  warm: ReaderTheme;
  white: ReaderTheme;
  night: ReaderTheme;
}

export const READER_THEMES: ReaderThemes = {
  warm: {
    name: '暖纸',
    backgroundColor: '#FAF6EE',
    fontColor: '#3D352A',
  },
  white: {
    name: '纯白',
    backgroundColor: '#FFFFFF',
    fontColor: '#1A1A1A',
  },
  night: {
    name: '夜间',
    backgroundColor: '#1E1B16',
    fontColor: '#DDD3BF',
  }
};

// 朗读设置默认值
export interface TtsDefaults {
  SPEED: number;
  AUTO_NEXT_CHAPTER: boolean;
  HIGHLIGHT_ENABLED: boolean;
}

export const TTS_DEFAULTS: TtsDefaults = {
  SPEED: 1.0,
  AUTO_NEXT_CHAPTER: true,
  HIGHLIGHT_ENABLED: true,
};

// 书架网格
export const BOOKSHELF_COLUMNS = 2;
