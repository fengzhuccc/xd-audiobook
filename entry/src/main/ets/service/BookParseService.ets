import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { COVERS_DIR } from '../common/constants/AppConstants';
import { BookInfo } from '../common/model/BookInfo';
import { BookDatabase } from './BookDatabase';
import { FileImportService } from './FileImportService';
import { LogUtil } from '../common/utils/LogUtil';

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

      // 动态导入 ReaderKit，避免模块加载阶段就依赖 ReaderKit HSP
      const readerKit = await import('@kit.ReaderKit');
      const handler = await readerKit.bookParser.getDefaultHandler(filePath);

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

      // 尝试提取封面
      if (bookInfoData.bookCoverImage) {
        try {
          // bookCoverImage 是书籍内的相对路径，需要从解析器提取
          // 注意：实际封面提取需要通过 getResourceContent 或自定义逻辑
          // 这里暂留占位，后续根据实际 API 实现
          LogUtil.info(`Cover image path in book: ${bookInfoData.bookCoverImage}`);
        } catch (err) {
          LogUtil.warn(`Failed to extract cover: ${JSON.stringify(err)}`);
        }
      }

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
    }
  }
}
