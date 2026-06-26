import { util } from '@kit.ArkTS';
import {
  IBookParserHandler,
  ParsedBookInfo,
  ParsedSpineItem,
  ParsedCatalogItem,
  readBinaryFile,
  htmlToPlainText,
} from './BookParser';
import { LogUtil } from '../common/utils/LogUtil';

/** PDB 记录索引项 */
interface PdbRecord {
  offset: number;
  length: number;
}

/** MOBI 章节内容 */
interface MobiChapter {
  title: string;
  content: string;
}

export class MobiParser implements IBookParserHandler {
  private bookInfo: ParsedBookInfo;
  private spineItems: ParsedSpineItem[];
  private catalogItems: ParsedCatalogItem[];
  private chapterTexts: string[];

  private constructor(
    bookInfo: ParsedBookInfo,
    spineItems: ParsedSpineItem[],
    catalogItems: ParsedCatalogItem[],
    chapterTexts: string[],
  ) {
    this.bookInfo = bookInfo;
    this.spineItems = spineItems;
    this.catalogItems = catalogItems;
    this.chapterTexts = chapterTexts;
  }

  static async create(filePath: string): Promise<MobiParser> {
    const buffer = readBinaryFile(filePath);
    const view = new DataView(buffer);

    // 解析 PDB 头
    const nameBytes = new Uint8Array(buffer, 0, 32);
    const pdbName = MobiParser.bytesToString(nameBytes).trim().replace(/\x00+$/, '');

    const numRecords = view.getUint16(76); // 偏移 76: 记录数

    // 读取记录索引
    const records: PdbRecord[] = [];
    for (let i = 0; i < numRecords; i++) {
      const recordOffset = view.getUint32(78 + i * 8);
      const nextOffset = i + 1 < numRecords
        ? view.getUint32(78 + (i + 1) * 8)
        : buffer.byteLength;
      records.push({
        offset: recordOffset,
        length: nextOffset - recordOffset,
      });
    }

    if (records.length < 2) {
      throw new Error('Invalid MOBI file: too few records');
    }

    // 解析记录 0（PalmDOC + MOBI 头）
    const rec0Data = new Uint8Array(buffer, records[0].offset, records[0].length);
    const compression = (rec0Data[0] << 8) | rec0Data[1]; // 1=无压缩, 2=PalmDOC LZ77
    const textLength = view.getUint32(records[0].offset + 4);
    const textRecordCount = (rec0Data[8] << 8) | rec0Data[9];

    // 检查是否有 MOBI 头
    const mobiId = MobiParser.bytesToString(rec0Data.subarray(16, 20));
    let textEncoding = 1252; // 默认 CP1252
    let author = '未知作者';
    let title = pdbName;

    if (mobiId === 'MOBI') {
      const mobiHeaderLen = view.getUint32(records[0].offset + 20);
      textEncoding = view.getUint32(records[0].offset + 28);

      // 尝试从 EXTH 头提取作者
      const exthOffset = records[0].offset + 16 + mobiHeaderLen;
      if (exthOffset + 12 <= buffer.byteLength) {
        const exthId = MobiParser.bytesToString(
          new Uint8Array(buffer, exthOffset, 4));
        if (exthId === 'EXTH') {
          const exthRecCount = view.getUint32(exthOffset + 8);
          let pos = exthOffset + 12;
          for (let i = 0; i < exthRecCount && pos + 8 <= buffer.byteLength; i++) {
            const recType = view.getUint32(pos);
            const recLen = view.getUint32(pos + 4);
            if (recLen < 8 || pos + recLen > buffer.byteLength) break;
            const recData = new Uint8Array(buffer, pos + 8, recLen - 8);
            const recText = MobiParser.bytesToString(recData);
            if (recType === 100) {
              author = recText;
            } else if (recType === 503) {
              title = recText;
            }
            pos += recLen;
          }
        }
      }
    }

    // 读取并解压文本记录（记录 1 到 textRecordCount）
    let fullHtmlBytes: number[] = [];
    for (let i = 0; i < textRecordCount && i + 1 < records.length; i++) {
      const rec = records[i + 1];
      const recData = new Uint8Array(buffer, rec.offset, rec.length);
      let decompressed: number[];
      if (compression === 2) {
        decompressed = MobiParser.palmDocDecompress(recData);
      } else {
        decompressed = Array.from(recData);
      }
      fullHtmlBytes = fullHtmlBytes.concat(decompressed);
    }

    // 转换为字符串
    const htmlText = MobiParser.bytesToText(new Uint8Array(fullHtmlBytes), textEncoding);

    // 按章节分割（HTML heading 标签 或 <mbp:pagebreak/>）
    const chapters = MobiParser.splitMobiChapters(htmlText);

    const spineItems: ParsedSpineItem[] = [];
    const catalogItems: ParsedCatalogItem[] = [];
    const chapterTexts: string[] = [];

    for (let i = 0; i < chapters.length; i++) {
      spineItems.push({ href: `chapter_${i}.html`, index: i });
      catalogItems.push({ href: `chapter_${i}.html`, title: chapters[i].title, level: 0 });
      chapterTexts.push(chapters[i].content);
    }

    const bookInfo: ParsedBookInfo = {
      bookTitle: title || '未知书名',
      bookCreator: author,
      bookLanguage: 'zh',
      bookCoverPath: '',
    };

    LogUtil.info(`MOBI parsed: title="${title}", author="${author}", chapters=${chapters.length}, compression=${compression}, encoding=${textEncoding}`);

    return new MobiParser(bookInfo, spineItems, catalogItems, chapterTexts);
  }

  /** PalmDOC LZ77 解压 */
  private static palmDocDecompress(data: Uint8Array): number[] {
    const output: number[] = [];
    let i = 0;
    while (i < data.length) {
      const b = data[i++];
      if (b === 0x00) {
        // 复制下一个字节
        if (i < data.length) output.push(data[i++]);
      } else if (b <= 0x0A) {
        // 复制 b 个字面字节
        for (let j = 0; j < b && i < data.length; j++) {
          output.push(data[i++]);
        }
      } else if (b <= 0x7F) {
        // 回引：2 字节编码距离和长度
        if (i < data.length) {
          const c = data[i++];
          const value = (b << 8) | c;
          const len = ((value >> 11) & 0x07) + 2;
          const dist = value & 0x07FF;
          const start = output.length - dist;
          for (let j = 0; j < len; j++) {
            if (start + j >= 0 && start + j < output.length) {
              output.push(output[start + j]);
            }
          }
        }
      } else {
        // 0x80-0xFF: 输出空格 + (b & 0x7F)
        output.push(0x20);
        output.push(b & 0x7F);
      }
    }
    return output;
  }

  /** 字节数组转字符串（ASCII / Latin1） */
  private static bytesToString(bytes: Uint8Array): string {
    let result = '';
    for (let i = 0; i < bytes.length; i++) {
      result += String.fromCharCode(bytes[i]);
    }
    return result;
  }

  /** 字节数组转文本（根据编码） */
  private static bytesToText(bytes: Uint8Array, encoding: number): string {
    if (encoding === 65001) {
      // UTF-8
      const decoder = util.TextDecoder.create('utf-8');
      return decoder.decodeWithStream(bytes);
    }
    // CP1252 / Latin1：直接逐字节转换
    return MobiParser.bytesToString(bytes);
  }

  /** 按 HTML 标题标签分割 MOBI 章节 */
  private static splitMobiChapters(html: string): MobiChapter[] {
    // 匹配 <h1>-<h3> 或 <mbp:pagebreak/> 作为章节分隔
    const splitRegex = /<(?:h[1-3][^>]*>|mbp:pagebreak\s*\/?>)/gi;
    const titleRegex = /<h[1-3][^>]*>([^<]+)<\/h[1-3]>/i;

    const chapters: MobiChapter[] = [];
    const positions: number[] = [0];
    let match: RegExpExecArray | null;
    while ((match = splitRegex.exec(html)) !== null) {
      if (match.index > 0) positions.push(match.index);
    }
    positions.push(html.length);

    for (let i = 0; i < positions.length - 1; i++) {
      const chunk = html.substring(positions[i], positions[i + 1]);
      const titleMatch = chunk.match(titleRegex);
      const title = titleMatch && titleMatch[1]
        ? titleMatch[1].trim()
        : `第 ${i + 1} 节`;
      const content = htmlToPlainText(chunk);
      if (content.trim().length > 0) {
        const chapter: MobiChapter = { title, content };
        chapters.push(chapter);
      }
    }

    if (chapters.length === 0) {
      // 无法分章，整体作为一个章节
      const wholeChapter: MobiChapter = { title: '全文', content: htmlToPlainText(html) };
      chapters.push(wholeChapter);
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
    if (index < 0 || index >= this.chapterTexts.length) {
      return '';
    }
    return this.chapterTexts[index];
  }

  release(): void {
    // MOBI 解析器无需清理
  }
}
