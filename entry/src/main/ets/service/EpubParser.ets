import { zlib } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import {
  IBookParserHandler,
  ParsedBookInfo,
  ParsedSpineItem,
  ParsedCatalogItem,
  readTextFile,
  normalizePath,
  getDirName,
} from './BookParser';
import { LogUtil } from '../common/utils/LogUtil';

interface ManifestItem {
  id: string;
  href: string;
  mediaType: string;
}

interface DecompressOptions {
  directory: string;
}

export class EpubParser implements IBookParserHandler {
  private extractDir: string;
  private opfPath: string;
  private bookInfo: ParsedBookInfo;
  private spineItems: ParsedSpineItem[];
  private catalogItems: ParsedCatalogItem[];
  private manifest: Map<string, ManifestItem>;

  private constructor(
    extractDir: string,
    opfPath: string,
    bookInfo: ParsedBookInfo,
    spineItems: ParsedSpineItem[],
    catalogItems: ParsedCatalogItem[],
    manifest: Map<string, ManifestItem>,
  ) {
    this.extractDir = extractDir;
    this.opfPath = opfPath;
    this.bookInfo = bookInfo;
    this.spineItems = spineItems;
    this.catalogItems = catalogItems;
    this.manifest = manifest;
  }

  static async create(filePath: string, workDir: string): Promise<EpubParser> {
    // 解压 EPUB 到临时目录
    const hash = filePath.length + filePath.charCodeAt(filePath.length - 1);
    const extractDir = `${workDir}/epub_${hash}`;
    try {
      // 清理旧目录
      if (fileIo.accessSync(extractDir)) {
        fileIo.rmdirSync(extractDir);
      }
    } catch (e) {
      // 忽略
    }
    fileIo.mkdirSync(extractDir, true);

    // 使用 zlib 解压 EPUB（本质是 ZIP）
    const options: zlib.Options = {
      directory: extractDir,
      flushMode: zlib.FlushMode.FINISH,
      level: zlib.CompressLevel.DEFAULT_COMPRESSION,
      memLevel: zlib.CompressMemLevel.DEFAULT_MEMLEVEL,
      strategy: zlib.CompressStrategy.DEFAULT_STRATEGY,
    };
    await zlib.decompressFile(filePath, options);
    LogUtil.info(`EPUB extracted to: ${extractDir}`);

    // 读取 container.xml 获取 OPF 路径
    const containerPath = `${extractDir}/META-INF/container.xml`;
    let opfPath = 'OEBPS/content.opf';
    try {
      const containerXml = readTextFile(containerPath);
      const match = containerXml.match(/full-path="([^"]+)"/i);
      if (match && match[1]) {
        opfPath = match[1];
      }
    } catch (e) {
      LogUtil.warn(`Failed to read container.xml, trying default OPF path`);
    }

    // 读取 OPF 文件
    const opfFullPath = `${extractDir}/${opfPath}`;
    const opfContent = readTextFile(opfFullPath);

    // 解析元数据
    const bookInfo = EpubParser.parseMetadata(opfContent, filePath);

    // 解析 manifest
    const manifest = EpubParser.parseManifest(opfContent);

    // 解析 spine
    const spineItems = EpubParser.parseSpine(opfContent, manifest, opfPath);

    // 解析目录（NCX 或 nav）
    const catalogItems = EpubParser.parseCatalog(extractDir, opfPath, manifest, spineItems);

    LogUtil.info(`EPUB parsed: title="${bookInfo.bookTitle}", spine=${spineItems.length}, catalog=${catalogItems.length}`);

    return new EpubParser(extractDir, opfPath, bookInfo, spineItems, catalogItems, manifest);
  }

  private static parseMetadata(opfContent: string, filePath: string): ParsedBookInfo {
    const titleMatch = opfContent.match(/<dc:title[^>]*>([^<]+)<\/dc:title>/i);
    const authorMatch = opfContent.match(/<dc:creator[^>]*>([^<]+)<\/dc:creator>/i);
    const langMatch = opfContent.match(/<dc:language[^>]*>([^<]+)<\/dc:language>/i);
    const coverMatch = opfContent.match(/<meta[^>]*name="cover"[^>]*content="([^"]+)"/i);

    const fileName = filePath.split('/').pop() || '未知书名';
    return {
      bookTitle: titleMatch && titleMatch[1] ? titleMatch[1].trim() : fileName.replace(/\.[^.]+$/, ''),
      bookCreator: authorMatch && authorMatch[1] ? authorMatch[1].trim() : '未知作者',
      bookLanguage: langMatch && langMatch[1] ? langMatch[1].trim() : 'zh',
      bookCoverPath: coverMatch && coverMatch[1] ? coverMatch[1] : '',
    };
  }

  private static parseManifest(opfContent: string): Map<string, ManifestItem> {
    const manifest = new Map<string, ManifestItem>();
    const itemRegex = /<item\b[^>]*>/gi;
    let match: RegExpExecArray | null;
    while ((match = itemRegex.exec(opfContent)) !== null) {
      const tag = match[0];
      const idMatch = tag.match(/id="([^"]+)"/i);
      const hrefMatch = tag.match(/href="([^"]+)"/i);
      const typeMatch = tag.match(/media-type="([^"]+)"/i);
      if (idMatch && hrefMatch) {
        const item: ManifestItem = {
          id: idMatch[1],
          href: hrefMatch[1],
          mediaType: typeMatch && typeMatch[1] ? typeMatch[1] : '',
        };
        manifest.set(item.id, item);
      }
    }
    return manifest;
  }

  private static parseSpine(opfContent: string, manifest: Map<string, ManifestItem>, opfPath: string): ParsedSpineItem[] {
    const spineItems: ParsedSpineItem[] = [];
    const spineRegex = /<itemref\b[^>]*idref="([^"]+)"[^>]*/gi;
    let match: RegExpExecArray | null;
    let index = 0;
    while ((match = spineRegex.exec(opfContent)) !== null) {
      const idref = match[1];
      const item = manifest.get(idref);
      if (item) {
        spineItems.push({
          href: normalizePath(`${getDirName(opfPath)}/${item.href}`),
          index: index,
        });
        index++;
      }
    }
    return spineItems;
  }

  private static parseCatalog(
    extractDir: string,
    opfPath: string,
    manifest: Map<string, ManifestItem>,
    spineItems: ParsedSpineItem[],
  ): ParsedCatalogItem[] {
    // 尝试从 NCX 解析目录
    for (const item of manifest.values()) {
      if (item.mediaType === 'application/x-dtbncx+xml' || item.href.endsWith('.ncx')) {
        const ncxPath = `${extractDir}/${normalizePath(`${getDirName(opfPath)}/${item.href}`)}`;
        try {
          const ncxContent = readTextFile(ncxPath);
          const catalog = EpubParser.parseNcx(ncxContent);
          if (catalog.length > 0) return catalog;
        } catch (e) {
          LogUtil.warn(`Failed to parse NCX: ${item.href}`);
        }
      }
    }

    // 尝试从 nav (EPUB3) 解析
    for (const item of manifest.values()) {
      if (item.href.endsWith('.xhtml') || item.href.endsWith('.html')) {
        const navPath = `${extractDir}/${normalizePath(`${getDirName(opfPath)}/${item.href}`)}`;
        try {
          const navContent = readTextFile(navPath);
          if (navContent.includes('epub:type="toc"') || navContent.includes('epub:type=\'toc\'')) {
            const catalog = EpubParser.parseNav(navContent);
            if (catalog.length > 0) return catalog;
          }
        } catch (e) {
          // 忽略
        }
      }
    }

    // 回退：用 spine 生成目录
    return spineItems.map((s: ParsedSpineItem) => {
      const name = s.href.split('/').pop()?.replace(/\.\w+$/, '') || `第${s.index + 1}章`;
      return { href: s.href, title: name, level: 0 } as ParsedCatalogItem;
    });
  }

  private static parseNcx(ncxContent: string): ParsedCatalogItem[] {
    const catalog: ParsedCatalogItem[] = [];
    const pointRegex = /<navPoint\b[^>]*>([\s\S]*?)<\/navPoint>/gi;
    let match: RegExpExecArray | null;
    while ((match = pointRegex.exec(ncxContent)) !== null) {
      const block = match[1];
      const textMatch = block.match(/<text>([^<]+)<\/text>/i);
      const srcMatch = block.match(/<content\s+src="([^"]+)"/i);
      const levelMatch = block.match(/playOrder="(\d+)"/i);
      if (textMatch && srcMatch) {
        catalog.push({
          href: srcMatch[1].split('#')[0],
          title: textMatch[1].trim(),
          level: levelMatch && levelMatch[1] ? parseInt(levelMatch[1], 10) - 1 : 0,
        });
      }
    }
    return catalog;
  }

  private static parseNav(navContent: string): ParsedCatalogItem[] {
    const catalog: ParsedCatalogItem[] = [];
    const linkRegex = /<a\b[^>]*href="([^"]+)"[^>]*>([^<]+)<\/a>/gi;
    let match: RegExpExecArray | null;
    let level = 0;
    while ((match = linkRegex.exec(navContent)) !== null) {
      catalog.push({
        href: match[1].split('#')[0],
        title: match[2].trim(),
        level: level,
      });
    }
    return catalog;
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
    if (index < 0 || index >= this.spineItems.length) {
      return '';
    }
    const href = this.spineItems[index].href;
    const fullPath = `${this.extractDir}/${href}`;
    try {
      return readTextFile(fullPath);
    } catch (e) {
      LogUtil.error(`Failed to read spine item ${index}: ${fullPath}`);
      return '';
    }
  }

  release(): void {
    // 清理解压目录
    try {
      if (fileIo.accessSync(this.extractDir)) {
        fileIo.rmdirSync(this.extractDir);
      }
    } catch (e) {
      LogUtil.warn(`Failed to clean extract dir: ${this.extractDir}`);
    }
  }
}
