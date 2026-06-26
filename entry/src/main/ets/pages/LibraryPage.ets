import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppTheme } from '../common/theme/AppTheme';
import { BookInfo } from '../common/model/BookInfo';
import { SUPPORTED_FORMATS } from '../common/constants/AppConstants';
import { FormatUtil } from '../common/utils/FormatUtil';
import { FileImportService } from '../service/FileImportService';
import { BookParseService } from '../service/BookParseService';
import { BookDatabase } from '../service/BookDatabase';
import { LogUtil } from '../common/utils/LogUtil';
import { common } from '@kit.AbilityKit';

@Component
export struct LibraryPage {
  @State books: BookInfo[] = [];
  @State isImporting: boolean = false;
  @State activeFilter: string = '全部';
  private filters: string[] = ['全部', 'EPUB', 'TXT', 'MOBI', 'AZW', 'AZW3'];

  aboutToAppear(): void {
    this.loadBooks();
  }

  private loadBooks(): void {
    const bookDb = AppStorageV2.connect(BookDatabase, 'bookDb') as BookDatabase;
    if (!bookDb) return;
    bookDb.getAllBooks().then((list: BookInfo[]) => {
      this.books = list;
    });
  }

  private async importBook(): Promise<void> {
    this.isImporting = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const importService = new FileImportService();
      const filePath = await importService.selectAndImport(context);
      if (!filePath) {
        this.isImporting = false;
        return;
      }

      const bookDb = AppStorageV2.connect(BookDatabase, 'bookDb') as BookDatabase;
      if (!bookDb) {
        this.isImporting = false;
        return;
      }

      const parseService = new BookParseService(bookDb);
      const book = await parseService.parseAndImportBook(context, filePath);
      if (book) {
        promptAction.showToast({ message: `《${book.title}》导入成功` });
        this.loadBooks();
      } else {
        promptAction.showToast({ message: '导入失败，请检查文件格式' });
      }
    } catch (err) {
      LogUtil.error(`Import error: ${JSON.stringify(err)}`);
      promptAction.showToast({ message: '导入失败' });
    } finally {
      this.isImporting = false;
    }
  }

  private async deleteBook(book: BookInfo): Promise<void> {
    const bookDb = AppStorageV2.connect(BookDatabase, 'bookDb') as BookDatabase;
    if (!bookDb) return;

    try {
      // 先删除沙箱文件，再删数据库，避免孤儿文件
      FileImportService.deleteBookFile(book.filePath);
      const deleted = await bookDb.deleteBook(book.id!);
      if (deleted > 0) {
        promptAction.showToast({ message: `《${book.title}》已删除` });
      } else {
        promptAction.showToast({ message: '删除失败，书籍未找到' });
      }
      this.loadBooks();
    } catch (err) {
      LogUtil.error(`Delete error: ${JSON.stringify(err)}`);
      promptAction.showToast({ message: '删除失败' });
    }
  }

  private filteredBooks(): BookInfo[] {
    if (this.activeFilter === '全部') return this.books;
    return this.books.filter((b) => b.fileFormat && b.fileFormat.toUpperCase() === this.activeFilter);
  }

  private getFormatBadgeColor(format: string): string {
    switch (format.toUpperCase()) {
      case 'EPUB': return AppTheme.success;
      case 'TXT': return AppTheme.info;
      case 'PDF': return AppTheme.error;
      case 'MOBI': return '#8B5CF6';
      default: return AppTheme.textTertiary;
    }
  }

  build() {
    Column() {
      Row().height(48).width('100%').backgroundColor(AppTheme.surfacePage);

      Text('书库')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.textPrimary)
        .margin({ left: 20, right: 20, bottom: 16 })

      // 导入按钮区域
      Column() {
        Row() {
          Column() {
            Image($r('app.media.ic_upload'))
              .width(24)
              .height(24)
              .fillColor(AppTheme.primary)
          }
          .width(48)
          .height(48)
          .borderRadius(24)
          .backgroundColor(AppTheme.primaryLightest)
          .justifyContent(FlexAlign.Center)

          Text('导入书籍')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.primary)
            .margin({ left: 12 })

          Text(this.isImporting ? '导入中...' : `支持 ${SUPPORTED_FORMATS.join('、').toUpperCase()} 格式`)
            .fontSize(12)
            .fontColor(AppTheme.textTertiary)
            .margin({ left: 'auto' })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppTheme.surfaceCard)
        .borderRadius(12)
        .border({ width: 2, color: AppTheme.primaryLighter, style: BorderStyle.Dashed })
        .onClick(() => { this.importBook() })
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
      .margin({ bottom: 16 })

      // 格式筛选
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.filters, (filter: string) => {
            Text(filter)
              .fontSize(13)
              .fontColor(this.activeFilter === filter ? Color.White : AppTheme.textSecondary)
              .backgroundColor(this.activeFilter === filter ? AppTheme.primary : AppTheme.surfaceInset)
              .borderRadius(16)
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .onClick(() => {
                this.activeFilter = filter;
              })
          })
        }
        .padding({ left: 20, right: 20 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .margin({ bottom: 12 })

      // 统计栏
      Text(`共 ${this.filteredBooks().length} 本 · 已读 ${this.books.filter(b => b.lastReadTime && b.lastReadTime > 0).length} 本`)
        .fontSize(12)
        .fontColor(AppTheme.textTertiary)
        .padding({ left: 20 })
        .margin({ bottom: 12 })

      // 文件列表
      List({ space: 8 }) {
        ForEach(this.filteredBooks(), (book: BookInfo) => {
          ListItem() {
            Row() {
              // 格式标签
              Text(book.fileFormat.toUpperCase())
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .backgroundColor(this.getFormatBadgeColor(book.fileFormat))
                .borderRadius(4)
                .padding({ left: 6, right: 6, top: 3, bottom: 3 })

              Column() {
                Text(book.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.textPrimary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${FormatUtil.formatFileSize(book.fileSize)} · ${FormatUtil.formatDate(book.addTime)}`)
                  .fontSize(12)
                  .fontColor(AppTheme.textTertiary)
                  .margin({ top: 3 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 12 })

              // 删除按钮
              Image($r('app.media.ic_delete'))
                .width(20)
                .height(20)
                .fillColor(AppTheme.textTertiary)
                .onClick(() => {
                  this.deleteBook(book);
                })
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppTheme.surfaceCard)
            .borderRadius(10)
            .shadow({ radius: 4, color: 'rgba(61,53,42,0.04)', offsetY: 1 })
          }
        }, (book: BookInfo) => `${book.id}_${book.filePath}`)
      }
      .layoutWeight(1)
      .padding({ left: 20, right: 20 })
      .scrollBar(BarState.Off)
      .margin({ bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.surfacePage)
  }
}
