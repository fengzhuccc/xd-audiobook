import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { DB_NAME, DB_VERSION } from '../common/constants/AppConstants';
import { BookInfo } from '../common/model/BookInfo';
import { BookProgress } from '../common/model/BookProgress';
import { Bookmark } from '../common/model/Bookmark';
import { LogUtil } from '../common/utils/LogUtil';

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: DB_NAME,
  securityLevel: relationalStore.SecurityLevel.S1,
};

export class BookDatabase {
  private store: relationalStore.RdbStore | null = null;

  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.store = await relationalStore.getRdbStore(context, STORE_CONFIG);
      await this.createTables();
      LogUtil.info('BookDatabase initialized');
    } catch (err) {
      LogUtil.error(`Failed to init database: ${JSON.stringify(err)}`);
    }
  }

  private async createTables(): Promise<void> {
    if (!this.store) return;

    // books 表
    const createBooksSql = `
      CREATE TABLE IF NOT EXISTS books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT DEFAULT '',
        file_path TEXT NOT NULL UNIQUE,
        file_name TEXT NOT NULL,
        file_format TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        cover_path TEXT DEFAULT '',
        language TEXT DEFAULT '',
        total_spines INTEGER DEFAULT 0,
        add_time INTEGER NOT NULL,
        last_read_time INTEGER DEFAULT 0
      )
    `;
    await this.store.executeSql(createBooksSql);

    // reading_progress 表
    const createProgressSql = `
      CREATE TABLE IF NOT EXISTS reading_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        spine_index INTEGER NOT NULL DEFAULT 0,
        dom_pos TEXT DEFAULT '',
        update_time INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    `;
    await this.store.executeSql(createProgressSql);

    // bookmarks 表
    const createBookmarksSql = `
      CREATE TABLE IF NOT EXISTS bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        spine_index INTEGER NOT NULL,
        dom_pos TEXT NOT NULL,
        chapter_title TEXT DEFAULT '',
        note TEXT DEFAULT '',
        create_time INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    `;
    await this.store.executeSql(createBookmarksSql);

    LogUtil.info('Database tables created');
  }

  // ── Books CRUD ──

  async insertBook(book: BookInfo): Promise<number> {
    if (!this.store) return -1;
    const valueBucket: relationalStore.ValuesBucket = {
      title: book.title,
      author: book.author,
      file_path: book.filePath,
      file_name: book.fileName,
      file_format: book.fileFormat,
      file_size: book.fileSize,
      cover_path: book.coverPath || '',
      language: book.language || '',
      total_spines: book.totalSpines || 0,
      add_time: book.addTime,
      last_read_time: book.lastReadTime || 0,
    };
    return await this.store.insert('books', valueBucket);
  }

  async getAllBooks(): Promise<BookInfo[]> {
    if (!this.store) return [];
    const predicates = new relationalStore.RdbPredicates('books');
    predicates.orderByDesc('last_read_time');
    const resultSet = await this.store.query(predicates, [
      'id', 'title', 'author', 'file_path', 'file_name', 'file_format',
      'file_size', 'cover_path', 'language', 'total_spines', 'add_time', 'last_read_time'
    ]);
    const books: BookInfo[] = [];
    while (resultSet.goToNextRow()) {
      books.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        title: resultSet.getString(resultSet.getColumnIndex('title')),
        author: resultSet.getString(resultSet.getColumnIndex('author')),
        filePath: resultSet.getString(resultSet.getColumnIndex('file_path')),
        fileName: resultSet.getString(resultSet.getColumnIndex('file_name')),
        fileFormat: resultSet.getString(resultSet.getColumnIndex('file_format')),
        fileSize: resultSet.getLong(resultSet.getColumnIndex('file_size')),
        coverPath: resultSet.getString(resultSet.getColumnIndex('cover_path')) || undefined,
        language: resultSet.getString(resultSet.getColumnIndex('language')) || undefined,
        totalSpines: resultSet.getLong(resultSet.getColumnIndex('total_spines')),
        addTime: resultSet.getLong(resultSet.getColumnIndex('add_time')),
        lastReadTime: resultSet.getLong(resultSet.getColumnIndex('last_read_time')),
      });
    }
    resultSet.close();
    return books;
  }

  async getBookById(id: number): Promise<BookInfo | null> {
    if (!this.store) return null;
    const predicates = new relationalStore.RdbPredicates('books');
    predicates.equalTo('id', id);
    const resultSet = await this.store.query(predicates, [
      'id', 'title', 'author', 'file_path', 'file_name', 'file_format',
      'file_size', 'cover_path', 'language', 'total_spines', 'add_time', 'last_read_time'
    ]);
    let book: BookInfo | null = null;
    if (resultSet.goToFirstRow()) {
      book = {
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        title: resultSet.getString(resultSet.getColumnIndex('title')),
        author: resultSet.getString(resultSet.getColumnIndex('author')),
        filePath: resultSet.getString(resultSet.getColumnIndex('file_path')),
        fileName: resultSet.getString(resultSet.getColumnIndex('file_name')),
        fileFormat: resultSet.getString(resultSet.getColumnIndex('file_format')),
        fileSize: resultSet.getLong(resultSet.getColumnIndex('file_size')),
        coverPath: resultSet.getString(resultSet.getColumnIndex('cover_path')) || undefined,
        language: resultSet.getString(resultSet.getColumnIndex('language')) || undefined,
        totalSpines: resultSet.getLong(resultSet.getColumnIndex('total_spines')),
        addTime: resultSet.getLong(resultSet.getColumnIndex('add_time')),
        lastReadTime: resultSet.getLong(resultSet.getColumnIndex('last_read_time')),
      };
    }
    resultSet.close();
    return book;
  }

  async deleteBook(id: number): Promise<number> {
    if (!this.store) return 0;
    const predicates = new relationalStore.RdbPredicates('books');
    predicates.equalTo('id', id);
    return await this.store.delete(predicates);
  }

  async getBookByFilePath(filePath: string): Promise<BookInfo | null> {
    if (!this.store) return null;
    const predicates = new relationalStore.RdbPredicates('books');
    predicates.equalTo('file_path', filePath);
    const resultSet = await this.store.query(predicates, [
      'id', 'title', 'author', 'file_path', 'file_name', 'file_format',
      'file_size', 'cover_path', 'language', 'total_spines', 'add_time', 'last_read_time'
    ]);
    let book: BookInfo | null = null;
    if (resultSet.goToFirstRow()) {
      book = {
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        title: resultSet.getString(resultSet.getColumnIndex('title')),
        author: resultSet.getString(resultSet.getColumnIndex('author')),
        filePath: resultSet.getString(resultSet.getColumnIndex('file_path')),
        fileName: resultSet.getString(resultSet.getColumnIndex('file_name')),
        fileFormat: resultSet.getString(resultSet.getColumnIndex('file_format')),
        fileSize: resultSet.getLong(resultSet.getColumnIndex('file_size')),
        coverPath: resultSet.getString(resultSet.getColumnIndex('cover_path')) || undefined,
        language: resultSet.getString(resultSet.getColumnIndex('language')) || undefined,
        totalSpines: resultSet.getLong(resultSet.getColumnIndex('total_spines')),
        addTime: resultSet.getLong(resultSet.getColumnIndex('add_time')),
        lastReadTime: resultSet.getLong(resultSet.getColumnIndex('last_read_time')),
      };
    }
    resultSet.close();
    return book;
  }

  async updateLastReadTime(bookId: number): Promise<void> {
    if (!this.store) return;
    const valueBucket: relationalStore.ValuesBucket = {
      last_read_time: Date.now(),
    };
    const predicates = new relationalStore.RdbPredicates('books');
    predicates.equalTo('id', bookId);
    await this.store.update(valueBucket, predicates);
  }

  // ── Progress CRUD ──

  async saveOrUpdateProgress(progress: BookProgress): Promise<void> {
    if (!this.store) return;
    // Check if progress exists for this book
    const predicates = new relationalStore.RdbPredicates('reading_progress');
    predicates.equalTo('book_id', progress.bookId);
    const resultSet = await this.store.query(predicates, ['id']);
    if (resultSet.goToFirstRow()) {
      // Update existing
      const existingId = resultSet.getLong(resultSet.getColumnIndex('id'));
      const valueBucket: relationalStore.ValuesBucket = {
        spine_index: progress.spineIndex,
        dom_pos: progress.domPos,
        update_time: progress.updateTime,
      };
      const updatePred = new relationalStore.RdbPredicates('reading_progress');
      updatePred.equalTo('id', existingId);
      await this.store.update(valueBucket, updatePred);
    } else {
      // Insert new
      const valueBucket: relationalStore.ValuesBucket = {
        book_id: progress.bookId,
        spine_index: progress.spineIndex,
        dom_pos: progress.domPos,
        update_time: progress.updateTime,
      };
      await this.store.insert('reading_progress', valueBucket);
    }
    resultSet.close();
  }

  async getProgressByBookId(bookId: number): Promise<BookProgress | null> {
    if (!this.store) return null;
    const predicates = new relationalStore.RdbPredicates('reading_progress');
    predicates.equalTo('book_id', bookId);
    const resultSet = await this.store.query(predicates, ['id', 'book_id', 'spine_index', 'dom_pos', 'update_time']);
    let progress: BookProgress | null = null;
    if (resultSet.goToFirstRow()) {
      progress = {
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        bookId: resultSet.getLong(resultSet.getColumnIndex('book_id')),
        spineIndex: resultSet.getLong(resultSet.getColumnIndex('spine_index')),
        domPos: resultSet.getString(resultSet.getColumnIndex('dom_pos')),
        updateTime: resultSet.getLong(resultSet.getColumnIndex('update_time')),
      };
    }
    resultSet.close();
    return progress;
  }

  // ── Bookmarks CRUD ──

  async addBookmark(bookmark: Bookmark): Promise<number> {
    if (!this.store) return -1;
    const valueBucket: relationalStore.ValuesBucket = {
      book_id: bookmark.bookId,
      spine_index: bookmark.spineIndex,
      dom_pos: bookmark.domPos,
      chapter_title: bookmark.chapterTitle,
      note: bookmark.note || '',
      create_time: bookmark.createTime,
    };
    return await this.store.insert('bookmarks', valueBucket);
  }

  async getBookmarksByBookId(bookId: number): Promise<Bookmark[]> {
    if (!this.store) return [];
    const predicates = new relationalStore.RdbPredicates('bookmarks');
    predicates.equalTo('book_id', bookId).orderByDesc('create_time');
    const resultSet = await this.store.query(predicates, ['id', 'book_id', 'spine_index', 'dom_pos', 'chapter_title', 'note', 'create_time']);
    const bookmarks: Bookmark[] = [];
    while (resultSet.goToNextRow()) {
      bookmarks.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        bookId: resultSet.getLong(resultSet.getColumnIndex('book_id')),
        spineIndex: resultSet.getLong(resultSet.getColumnIndex('spine_index')),
        domPos: resultSet.getString(resultSet.getColumnIndex('dom_pos')),
        chapterTitle: resultSet.getString(resultSet.getColumnIndex('chapter_title')),
        note: resultSet.getString(resultSet.getColumnIndex('note')) || undefined,
        createTime: resultSet.getLong(resultSet.getColumnIndex('create_time')),
      });
    }
    resultSet.close();
    return bookmarks;
  }

  async deleteBookmark(id: number): Promise<number> {
    if (!this.store) return 0;
    const predicates = new relationalStore.RdbPredicates('bookmarks');
    predicates.equalTo('id', id);
    return await this.store.delete(predicates);
  }
}
