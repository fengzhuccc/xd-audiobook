// 应用级常量
export const APP_NAME = '书声';
export const DB_NAME = 'EbookReader.db';
export const DB_VERSION = 1;
export const PREF_NAME = 'ebook_reader_preferences';
export const BOOKS_DIR = 'books';
export const COVERS_DIR = 'covers';
export const SUPPORTED_FORMATS = ['epub', 'txt', 'mobi', 'azw', 'azw3'];

// Tab 索引
export const TAB_INDEX = {
  BOOKSHELF: 0,
  LIBRARY: 1,
  SETTINGS: 2
} as const;
