import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import {
  IBookParserHandler,
  ParsedBookInfo,
  ParsedSpineItem,
  ParsedCatalogItem,
} from './BookParser';
import { LogUtil } from '../common/utils/LogUtil';

interface ChapterInfo {
  title: string;
  start: number;
  end: number;
}

export class TxtParser implements IBookParserHandler {
  private filePath: string;
  private bookInfo: ParsedBookInfo;
  private spineItems: ParsedSpineItem[];
  private catalogItems: ParsedCatalogItem[];
  private fullText: string;
  private chapters: ChapterInfo[];

  private constructor(
    filePath: string,
    bookInfo: ParsedBookInfo,
    spineItems: ParsedSpineItem[],
    catalogItems: ParsedCatalogItem[],
    fullText: string,
    chapters: ChapterInfo[],
  ) {
    this.filePath = filePath;
    this.bookInfo = bookInfo;
    this.spineItems = spineItems;
    this.catalogItems = catalogItems;
    this.fullText = fullText;
    this.chapters = chapters;
  }

  static async create(filePath: string): Promise<TxtParser> {
    // 读取文件并检测编码
    const fullText = TxtParser.readWithEncodingDetection(filePath);
    const fileName = filePath.split('/').pop() || '未知书名';
    const baseName = fileName.replace(/\.[^.]+$/, '');

    // 按章节标题分章
    const chapters = TxtParser.splitChapters(fullText);

    let spineItems: ParsedSpineItem[];
    let catalogItems: ParsedCatalogItem[];

    if (chapters.length > 1) {
      spineItems = chapters.map((ch: ChapterInfo, i: number) => {
        return { href: `chapter_${i}.txt`, index: i } as ParsedSpineItem;
      });
      catalogItems = chapters.map((ch: ChapterInfo, i: number) => {
        return { href: `chapter_${i}.txt`, title: ch.title, level: 0 } as ParsedCatalogItem;
      });
    } else {
      // 无章节标记，按大小分章（每 8000 字符）
      const chunkSize = 8000;
      const chunkCount = Math.ceil(fullText.length / chunkSize);
      const chunkChapters: ChapterInfo[] = [];
      for (let i = 0; i < chunkCount; i++) {
        const start = i * chunkSize;
        const end = Math.min(start + chunkSize, fullText.length);
        chunkChapters.push({
          title: `第 ${i + 1} 部分`,
          start: start,
          end: end,
        });
      }
      spineItems = chunkChapters.map((ch: ChapterInfo, i: number) => {
        return { href: `part_${i}.txt`, index: i } as ParsedSpineItem;
      });
      catalogItems = chunkChapters.map((ch: ChapterInfo, i: number) => {
        return { href: `part_${i}.txt`, title: ch.title, level: 0 } as ParsedCatalogItem;
      });

      const bookInfo: ParsedBookInfo = {
        bookTitle: baseName,
        bookCreator: '未知作者',
        bookLanguage: 'zh',
        bookCoverPath: '',
      };
      return new TxtParser(filePath, bookInfo, spineItems, catalogItems, fullText, chunkChapters);
    }

    const bookInfo: ParsedBookInfo = {
      bookTitle: baseName,
      bookCreator: '未知作者',
      bookLanguage: 'zh',
      bookCoverPath: '',
    };

    LogUtil.info(`TXT parsed: title="${baseName}", chapters=${spineItems.length}`);
    return new TxtParser(filePath, bookInfo, spineItems, catalogItems, fullText, chapters);
  }

  /** 读取文件并检测编码（UTF-8 / GBK） */
  private static readWithEncodingDetection(filePath: string): string {
    const stat = fileIo.statSync(filePath);
    const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
    try {
      const buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      const bytes = new Uint8Array(buffer);

      // 检查 UTF-8 BOM
      if (bytes.length >= 3 && bytes[0] === 0xEF && bytes[1] === 0xBB && bytes[2] === 0xBF) {
        const decoder = util.TextDecoder.create('utf-8');
        return decoder.decodeWithStream(bytes.subarray(3));
      }

      // 尝试 UTF-8 解码
      try {
        const utf8Decoder = util.TextDecoder.create('utf-8', { fatal: true });
        return utf8Decoder.decodeWithStream(bytes);
      } catch (e) {
        // UTF-8 失败，尝试 GBK
        LogUtil.info('UTF-8 decode failed, trying GBK encoding');
      }

      try {
        const gbkDecoder = util.TextDecoder.create('gbk');
        return gbkDecoder.decodeWithStream(bytes);
      } catch (e2) {
        LogUtil.warn('GBK decode also failed, falling back to UTF-8 (non-fatal)');
        const fallbackDecoder = util.TextDecoder.create('utf-8');
        return fallbackDecoder.decodeWithStream(bytes);
      }
    } finally {
      fileIo.closeSync(file);
    }
  }

  /** 按章节标题分章 */
  private static splitChapters(text: string): ChapterInfo[] {
    // 匹配中文章节标题：第X章/节/回/卷
    const chapterRegex = /^[ \t]*第[零一二三四五六七八九十百千0-9]+[章节回卷][^\n\r]*$/gm;
    // 匹配英文章节标题：Chapter X
    const engChapterRegex = /^[ \t]*Chapter\s+\d+[^\n\r]*$/gim;

    const chapters: ChapterInfo[] = [];
    const matches: RegExpExecArray[] = [];

    let m: RegExpExecArray | null;
    while ((m = chapterRegex.exec(text)) !== null) {
      matches.push(m);
    }
    while ((m = engChapterRegex.exec(text)) !== null) {
      matches.push(m);
    }

    if (matches.length === 0) return [];

    // 按位置排序
    matches.sort((a: RegExpExecArray, b: RegExpExecArray) => a.index - b.index);

    for (let i = 0; i < matches.length; i++) {
      const title = matches[i][0].trim();
      const start = matches[i].index;
      const end = i + 1 < matches.length ? matches[i + 1].index : text.length;
      chapters.push({ title, start, end });
    }

    // 如果第一章标题不在开头，加上标题前的内容作为"序言"
    if (matches[0].index > 0) {
      const prefaceText = text.substring(0, matches[0].index).trim();
      if (prefaceText.length > 50) {
        chapters.unshift({
          title: '序言',
          start: 0,
          end: matches[0].index,
        });
      }
    }

    return chapters;
  }

  getBookInfo(): ParsedBookInfo {
    return this.bookInfo;
  }

  getSpineList(): ParsedSpineItem[] {
    return this.spineItems;
  }

  getCatalogList(): ParsedCatalogItem[] {
    return this.catalogItems;
  }

  async getSpineItemContent(index: number): Promise<string> {
    if (index < 0 || index >= this.chapters.length) {
      return '';
    }
    const ch = this.chapters[index];
    return this.fullText.substring(ch.start, ch.end);
  }

  release(): void {
    // TXT 解析器无需清理
  }
}
