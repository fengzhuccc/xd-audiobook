import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { COVERS_DIR } from '../common/constants/AppConstants';
import { BookInfo } from '../common/model/BookInfo';
import { BookDatabase } from './BookDatabase';
import { FileImportService } from './FileImportService';
import { LogUtil } from '../common/utils/LogUtil';
import { BookParserFactory, IBookParserHandler } from './BookParser';

export class BookParseService {
  private bookDb: BookDatabase;

  constructor(bookDb: BookDatabase) {
    this.bookDb = bookDb;
  }

  /**
   * 解析电子书文件并入库
   * @param context UIAbilityContext
   * @param filePath 沙箱内文件路径
   * @returns 书籍信息，失败返回 null
   */
  async parseAndImportBook(context: common.UIAbilityContext, filePath: string): Promise<BookInfo | null> {
    let handler: IBookParserHandler | null = null;
    try {
      // 检查是否已导入
      const existingBook = await this.bookDb.getBookByFilePath(filePath);
      if (existingBook) {
        LogUtil.info(`Book already imported: ${filePath}`);
        return existingBook;
      }

      // 确保封面目录存在
      const coversDir = `${context.filesDir}/${COVERS_DIR}`;
      if (!fileIo.accessSync(coversDir)) {
        fileIo.mkdirSync(coversDir);
      }

      // 使用自建解析器解析书籍
      handler = await BookParserFactory.createHandler(filePath, context.tempDir);

      // 获取书籍信息
      const bookInfoData = handler.getBookInfo();

      // 获取书脊列表（总章节数）
      const spineList = handler.getSpineList();

      // 构建书籍模型
      const fileName = filePath.split('/').pop() || 'unknown';
      const fileFormat = FileImportService.getFormatFromFileName(fileName);
      const fileSize = FileImportService.getFileSize(filePath);

      const book: BookInfo = {
        title: bookInfoData.bookTitle || fileName.replace(/\.[^.]+$/, ''),
        author: bookInfoData.bookCreator || '未知作者',
        filePath: filePath,
        fileName: fileName,
        fileFormat: fileFormat,
        fileSize: fileSize,
        language: bookInfoData.bookLanguage,
        totalSpines: spineList.length,
        addTime: Date.now(),
        lastReadTime: 0,
      };

      // 写入数据库
      const id = await this.bookDb.insertBook(book);
      if (id <= 0) {
        LogUtil.error(`Failed to insert book into database, id=${id}`);
        return null;
      }
      book.id = id;

      LogUtil.info(`Book imported: [${id}] ${book.title} by ${book.author}`);
      return book;
    } catch (err) {
      LogUtil.error(`Failed to parse book: ${JSON.stringify(err)}`);
      return null;
    } finally {
      // 释放解析器资源
      if (handler) {
        try {
          handler.release();
        } catch (e) {
          LogUtil.warn(`Failed to release parser: ${JSON.stringify(e)}`);
        }
      }
    }
  }
}
