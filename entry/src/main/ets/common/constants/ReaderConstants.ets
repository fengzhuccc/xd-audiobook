// 阅读器默认配置
export const READER_DEFAULTS = {
  FONT_SIZE: 17,        // 默认字号 (sp)
  LINE_HEIGHT: 1.9,      // 默认行高
  LETTER_SPACING: 0.02,  // 字间距
  FLIP_MODE: 'slide' as const, // 默认翻页模式
  THEME: 'warm' as const,      // 默认主题
  FONT_FAMILY: 'serif' as const // 默认字体
};

// 阅读主题预设
export const READER_THEMES = {
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
export const TTS_DEFAULTS = {
  SPEED: 1.0,
  AUTO_NEXT_CHAPTER: true,
  HIGHLIGHT_ENABLED: true,
};

// 书架网格
export const BOOKSHELF_COLUMNS = 2;
