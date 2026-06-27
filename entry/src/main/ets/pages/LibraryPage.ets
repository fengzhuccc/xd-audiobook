import { promptAction, AppStorageV2 } from '@kit.ArkUI';
import { AppTheme } from '../common/theme/AppTheme';
import { BookInfo } from '../common/model/BookInfo';
import { FileImportService } from '../service/FileImportService';
import { BookParseService } from '../service/BookParseService';
import { BookDatabase } from '../service/BookDatabase';
import { FormatUtil } from '../common/utils/FormatUtil';
import { LogUtil } from '../common/utils/LogUtil';
import { common } from '@kit.AbilityKit';

interface FormatBadgeStyle {
  bg: string;
  color: string;
}

@Component
export struct LibraryPage {
  @State books: BookInfo[] = [];
  @State isImporting: boolean = false;
  @State activeFilter: string = '全部';
  // 书库变更计数：导入/删除后自增，通知书架页刷新
  @StorageLink('bookshelfRefreshFlag') refreshFlag: number = 0;
  private filters: string[] = ['全部', 'EPUB', 'TXT', 'PDF', 'MOBI'];

  aboutToAppear(): void {
    this.waitAndLoadBooks();
  }

  onPageShow(): void {
    this.waitAndLoadBooks();
  }

  /** 等待数据库初始化完成后再加载书籍，避免启动时空数据 */
  private waitAndLoadBooks(): void {
    BookDatabase.getInstance().waitForInit().then(() => {
      this.loadBooks();
    });
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
        // 用户取消选择或文件导入失败（错误日志已在 selectAndImport 中输出）
        this.isImporting = false;
        return;
      }

      const bookDb = AppStorageV2.connect(BookDatabase, 'bookDb') as BookDatabase;
      if (!bookDb) {
        promptAction.showToast({ message: '数据库未初始化，请重试' });
        this.isImporting = false;
        return;
      }

      const parseService = new BookParseService(bookDb);
      const book = await parseService.parseAndImportBook(context, filePath);
      if (book) {
        promptAction.showToast({ message: `《${book.title}》导入成功` });
        this.loadBooks();
        // 通知书架页刷新
        this.refreshFlag++;
      } else {
        promptAction.showToast({ message: '导入失败，该设备可能不支持此格式' });
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
        // 通知书架页刷新
        this.refreshFlag++;
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
    return this.books.filter((b: BookInfo) => b.fileFormat.toUpperCase() === this.activeFilter);
  }

  private getFormatBadgeStyle(format: string): FormatBadgeStyle {
    const style: FormatBadgeStyle = { bg: AppTheme.surfaceInset, color: AppTheme.textTertiary };
    switch (format.toUpperCase()) {
      case 'EPUB':
        style.bg = 'rgba(91,140,62,0.12)';
        style.color = AppTheme.success;
        break;
      case 'TXT':
        style.bg = 'rgba(74,123,157,0.12)';
        style.color = AppTheme.info;
        break;
      case 'PDF':
        style.bg = 'rgba(196,77,63,0.12)';
        style.color = AppTheme.error;
        break;
      case 'MOBI':
        style.bg = 'rgba(139,92,246,0.12)';
        style.color = '#8B5CF6';
        break;
      default:
        style.bg = AppTheme.surfaceInset;
        style.color = AppTheme.textTertiary;
        break;
    }
    return style;
  }

  build() {
    Stack() {
      Column() {
        // 状态栏占位
        Row().height(48).width('100%').backgroundColor(AppTheme.surfacePage);

        // 内容区
        Column() {
          // 导入 Hero 区
          Column() {
            // 圆形上传图标
            Row() {
              Image($r('app.media.ic_upload'))
                .width(28)
                .height(28)
                .fillColor(Color.White);
            }
            .width(56)
            .height(56)
            .borderRadius(28)
            .backgroundColor(AppTheme.primary)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .shadow({ radius: 16, color: 'rgba(139,105,20,0.25)', offsetY: 4 });

            // 导入按钮
            Text('导入书籍')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textInverse)
              .padding({ left: 32, right: 32, top: 12, bottom: 12 })
              .borderRadius(24)
              .backgroundColor(AppTheme.primary)
              .shadow({ radius: 12, color: 'rgba(139,105,20,0.3)', offsetY: 2 })
              .margin({ top: 16 })
              .onClick(() => { this.importBook(); });

            // 副标题
            Text('支持 EPUB、TXT、PDF、MOBI 格式')
              .fontSize(13)
              .fontColor(AppTheme.textTertiary)
              .margin({ top: 12 });
          }
          .width('100%')
          .padding({ top: 28, bottom: 28, left: 16, right: 16 })
          .borderRadius(16)
          .border({ width: 2, color: AppTheme.primaryLighter, style: BorderStyle.Dashed })
          .linearGradient({
            angle: 135,
            colors: [[AppTheme.primaryLightest, 0], [AppTheme.surfaceCard, 0.5], [AppTheme.primaryLightest, 1]]
          })
          .alignItems(HorizontalAlign.Center)
          .margin({ left: 16, right: 16, top: 16 });

          // 筛选 chips
          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.filters, (filter: string) => {
                Text(filter)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.activeFilter === filter ? Color.White : AppTheme.textSecondary)
                  .backgroundColor(this.activeFilter === filter ? AppTheme.primary : AppTheme.surfaceInset)
                  .borderRadius(999)
                  .padding({ left: 16, right: 16, top: 6, bottom: 6 })
                  .onClick(() => {
                    this.activeFilter = filter;
                  })
              }, (filter: string) => filter)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .margin({ top: 20, left: 16, right: 16 });

          // 统计栏
          Text(`共 ${this.books.length} 本 · 已读 ${this.books.filter((b: BookInfo) => (b.lastReadTime ?? 0) > 0).length} 本 · 未读 ${this.books.filter((b: BookInfo) => (b.lastReadTime ?? 0) <= 0).length} 本`)
            .fontSize(12)
            .fontColor(AppTheme.textTertiary)
            .margin({ top: 16, left: 16, right: 16 });

          // 文件列表 / 空状态
          if (this.filteredBooks().length === 0) {
            Text('还没有导入任何书籍')
              .fontSize(14)
              .fontColor(AppTheme.textTertiary)
              .margin({ top: 40 })
              .textAlign(TextAlign.Center)
              .width('100%');
          } else {
            Scroll() {
              Column({ space: 8 }) {
                ForEach(this.filteredBooks(), (book: BookInfo) => {
                  Row() {
                    // 格式标签
                    Text(book.fileFormat.toUpperCase())
                      .fontSize(11)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.getFormatBadgeStyle(book.fileFormat).color)
                      .backgroundColor(this.getFormatBadgeStyle(book.fileFormat).bg)
                      .borderRadius(999)
                      .padding({ left: 10, right: 10, top: 4, bottom: 4 });

                    // 文件信息
                    Column() {
                      Text(book.fileName)
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(AppTheme.textPrimary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis });
                      Text(`${FormatUtil.formatFileSize(book.fileSize)} · ${FormatUtil.formatDate(book.addTime)}`)
                        .fontSize(12)
                        .fontColor(AppTheme.textTertiary)
                        .margin({ top: 2 });
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    .margin({ left: 12 });

                    // 操作按钮
                    Row() {
                      Image($r('app.media.ic_more'))
                        .width(18)
                        .height(18)
                        .fillColor(AppTheme.textTertiary);
                    }
                    .width(32)
                    .height(32)
                    .justifyContent(FlexAlign.Center)
                    .alignItems(VerticalAlign.Center)
                    .borderRadius(999)
                    .onClick(() => {
                      promptAction.showDialog({
                        title: '删除书籍',
                        message: `确定要删除《${book.title}》吗？`,
                        buttons: [
                          { text: '取消', color: AppTheme.textTertiary },
                          { text: '删除', color: AppTheme.error }
                        ]
                      }).then((dialogResult) => {
                        if (dialogResult.index === 1) {
                          this.deleteBook(book);
                        }
                      });
                    });
                  }
                  .width('100%')
                  .padding(12)
                  .backgroundColor(AppTheme.surfaceCard)
                  .borderRadius(12)
                  .border({ width: 1, color: AppTheme.borderDefault })
                  .shadow({ radius: 4, color: 'rgba(61,53,42,0.04)', offsetY: 1 });
                }, (book: BookInfo) => `${book.id}`)
              }
              .width('100%')
              .padding({ left: 16, right: 16 });
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .margin({ top: 12 });
          }
        }
        .layoutWeight(1)
        .padding({ bottom: 80 })
        .width('100%');
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.surfacePage);

      // 导入中遮罩
      if (this.isImporting) {
        Column() {
          Text('导入中...')
            .fontSize(16)
            .fontColor(AppTheme.textPrimary);
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('rgba(253,251,247,0.8)');
      }
    }
    .width('100%')
    .height('100%');
  }
}
