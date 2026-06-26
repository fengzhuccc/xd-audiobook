import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { LogUtil } from '../common/utils/LogUtil';
import { FileImportService } from './FileImportService';

/** 书籍基本信息 */
export interface ParsedBookInfo {
  bookTitle: string;
  bookCreator: string;
  bookLanguage: string;
  bookCoverPath: string;
}

/** 书脊项（章节） */
export interface ParsedSpineItem {
  href: string;
  index: number;
}

/** 目录项 */
export interface ParsedCatalogItem {
  href: string;
  title: string;
  level: number;
}

/** 解析器接口：与 ReaderKit 的 BookParserHandler 保持兼容 */
export interface IBookParserHandler {
  getBookInfo(): ParsedBookInfo;
  getSpineList(): ParsedSpineItem[];
  getCatalogList(): ParsedCatalogItem[];
  getSpineItemContent(index: number): Promise<string>;
  release(): void;
}

/** HTML 转纯文本 */
export function htmlToPlainText(html: string): string {
  return html
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n')
    .replace(/<\/div>/gi, '\n')
    .replace(/<h[1-6][^>]*>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&ldquo;/g, '\u201C')
    .replace(/&rdquo;/g, '\u201D')
    .replace(/&hellip;/g, '\u2026')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/** 读取文本文件（UTF-8） */
export function readTextFile(filePath: string): string {
  const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
  try {
    const stat = fileIo.statSync(filePath);
    const buffer = new ArrayBuffer(stat.size);
    fileIo.readSync(file.fd, buffer);
    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeWithStream(new Uint8Array(buffer));
  } finally {
    fileIo.closeSync(file);
  }
}

/** 读取二进制文件 */
export function readBinaryFile(filePath: string): ArrayBuffer {
  const stat = fileIo.statSync(filePath);
  const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
  try {
    const buffer = new ArrayBuffer(stat.size);
    fileIo.readSync(file.fd, buffer);
    return buffer;
  } finally {
    fileIo.closeSync(file);
  }
}

/** 规范化路径（处理 ../ 和 ./） */
export function normalizePath(path: string): string {
  const parts = path.split('/');
  const result: string[] = [];
  for (const part of parts) {
    if (part === '..') {
      result.pop();
    } else if (part !== '.' && part.length > 0) {
      result.push(part);
    }
  }
  return result.join('/');
}

/** 解析路径所在目录 */
export function getDirName(path: string): string {
  const idx = path.lastIndexOf('/');
  return idx >= 0 ? path.substring(0, idx) : '';
}

/** 工厂：根据文件扩展名创建对应的解析器 */
export class BookParserFactory {
  static async createHandler(filePath: string, workDir: string): Promise<IBookParserHandler> {
    const ext = FileImportService.getFormatFromFileName(filePath);
    LogUtil.info(`BookParserFactory: creating parser for ${ext} file: ${filePath}`);
    if (ext === 'epub') {
      return await EpubParser.create(filePath, workDir);
    } else if (ext === 'txt') {
      return await TxtParser.create(filePath);
    } else if (ext === 'mobi' || ext === 'azw' || ext === 'azw3') {
      return await MobiParser.create(filePath);
    }
    throw new Error(`不支持的格式: ${ext}`);
  }
}

// 导入各格式解析器
import { EpubParser } from './EpubParser';
import { TxtParser } from './TxtParser';
import { MobiParser } from './MobiParser';
