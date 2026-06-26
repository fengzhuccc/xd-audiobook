import { router, AppStorageV2 } from '@kit.ArkUI';
import { AppTheme } from '../common/theme/AppTheme';
import { BookInfo } from '../common/model/BookInfo';
import { BookProgress } from '../common/model/BookProgress';
import { BookDatabase } from '../service/BookDatabase';
import { LogUtil } from '../common/utils/LogUtil';

@Component
export struct BookshelfPage {
  @State books: BookInfo[] = [];
  @State recentBook: BookInfo | null = null;
  @State recentProgress: BookProgress | null = null;
  @State searchQuery: string = '';
  @State isSearching: boolean = false;
  // 书库变更计数：LibraryPage 导入/删除后会自增，通过 @Watch 触发书架刷新
  @StorageLink('bookshelfRefreshFlag') @Watch('onShelfChanged') refreshFlag: number = 0;

  aboutToAppear(): void {
    this.loadBooks();
  }

  /**
   * 监听书库变更：当 LibraryPage 导入/删除书籍后自增 refreshFlag，触发书架重新加载。
   */
  onShelfChanged(): void {
    this.loadBooks();
  }

  private loadBooks(): void {
    const bookDb = AppStorageV2.connect(BookDatabase, 'bookDb') as BookDatabase;
    if (!bookDb) return;

    bookDb.getAllBooks().then((list: BookInfo[]) => {
      this.books = list;
      // 找到最近阅读的书
      if (list.length > 0) {
        const bookWithProgress = list.find((b: BookInfo) => b.lastReadTime && b.lastReadTime > 0);
        if (bookWithProgress) {
          this.recentBook = bookWithProgress;
          bookDb.getProgressByBookId(bookWithProgress.id!).then((progress: BookProgress | null) => {
            this.recentProgress = progress;
          }).catch((err: Error) => {
            LogUtil.error(`Failed to load progress: ${err.message}`);
          });
        }
      }
    }).catch((err: Error) => {
      LogUtil.error(`Failed to load books: ${err.message}`);
    });
  }

  private filteredBooks(): BookInfo[] {
    if (!this.searchQuery.trim()) return this.books;
    const query = this.searchQuery.trim().toLowerCase();
    return this.books.filter((b: BookInfo) =>
      b.title.toLowerCase().includes(query) || b.author.toLowerCase().includes(query)
    );
  }

  private openBook(book: BookInfo): void {
    router.pushUrl({
      url: 'pages/ReaderPage',
      params: { bookId: book.id, filePath: book.filePath }
    });
  }

  build() {
    Column() {
      // 状态栏占位
      Row().height(48).width('100%').backgroundColor(AppTheme.surfacePage);

      // 标题
      Text('书架')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.textPrimary)
        .margin({ left: 20, right: 20, bottom: 16 })

      // 搜索栏
      Row() {
        Image($r('app.media.ic_search'))
          .width(18)
          .height(18)
          .margin({ left: 12 })
          .fillColor(AppTheme.textTertiary)
        TextInput({ placeholder: '搜索书名或作者...', text: this.searchQuery })
          .layoutWeight(1)
          .height(40)
          .backgroundColor(Color.Transparent)
          .padding({ left: 8, right: 12 })
          .onChange((value: string) => {
            this.searchQuery = value;
          })
          .onFocus(() => { this.isSearching = true })
          .onBlur(() => { this.isSearching = false })
      }
      .height(44)
      .backgroundColor(AppTheme.surfaceInset)
      .borderRadius(12)
      .margin({ left: 20, right: 20, bottom: 20 })
      .clip(true)

      Scroll() {
        Column() {
          // 继续阅读区域
          if (this.recentBook) {
            Column() {
              Text('继续阅读')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.textPrimary)
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 12 })

              // 继续阅读卡片
              Row() {
                // 封面（使用带渐变的占位）
                Stack() {
                  Column()
                    .width('100%')
                    .height('100%')
                    .borderRadius(6)
                    .linearGradient({
                      angle: 135,
                      colors: [[AppTheme.primaryLight, 0], [AppTheme.primary, 1]]
                    })
                  Text((this.recentBook as BookInfo).title.charAt(0))
                    .fontSize(24)
                    .fontColor(Color.White)
                    .fontWeight(FontWeight.Bold)
                }
                .width(64)
                .height(88)

                Column() {
                  Text(this.recentBook.title)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.textPrimary)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.recentBook.author)
                    .fontSize(13)
                    .fontColor(AppTheme.textSecondary)
                    .margin({ top: 4 })

                  // 进度条
                  Stack({ alignContent: Alignment.Start }) {
                    Row()
                      .height(4)
                      .borderRadius(2)
                      .backgroundColor(AppTheme.primaryLight)
                      .width('100%')
                    Row()
                      .height(4)
                      .borderRadius(2)
                      .backgroundColor(AppTheme.primary)
                      .width(this.recentProgress ?
                        `${Math.min(100, (this.recentProgress.spineIndex / Math.max((this.recentBook as BookInfo).totalSpines || 1, 1)) * 100)}%`
                        : '0%')
                  }
                  .width('100%')
                  .margin({ top: 12 })

                  Row() {
                    Text(this.recentProgress ?
                      `已读 ${this.recentProgress.spineIndex} / ${this.recentBook.totalSpines || '?'} 章` :
                      '开始阅读')
                      .fontSize(12)
                      .fontColor(AppTheme.textTertiary)

                    Text('继续')
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.primary)
                      .margin({ left: 'auto' })
                  }
                  .width('100%')
                  .margin({ top: 6 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 14 })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(AppTheme.surfaceCard)
              .borderRadius(12)
              .shadow({ radius: 8, color: 'rgba(61,53,42,0.05)', offsetY: 2 })
              .onClick(() => { this.openBook(this.recentBook as BookInfo) })
            }
            .width('100%')
            .padding({ left: 20, right: 20 })
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: 28 })
          }

          // 我的书架
          Row() {
            Text('我的书架')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textPrimary)
            Text(`共 ${this.filteredBooks().length} 本`)
              .fontSize(13)
              .fontColor(AppTheme.textTertiary)
              .margin({ left: 8 })
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
          .margin({ bottom: 16 })

          // 书架网格
          if (this.filteredBooks().length === 0) {
            Column() {
              Text('书架空空如也')
                .fontSize(15)
                .fontColor(AppTheme.textTertiary)
                .margin({ top: 60 })
              Text('去「书库」导入你的第一本书吧')
                .fontSize(13)
                .fontColor(AppTheme.textTertiary)
                .margin({ top: 8 })
            }
            .width('100%')
            .height(200)
            .justifyContent(FlexAlign.Center)
          } else {
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(this.filteredBooks(), (book: BookInfo) => {
                Column() {
                  // 封面
                  Stack() {
                    Column()
                      .width('100%')
                      .aspectRatio(5 / 7)
                      .borderRadius(6)
                      .linearGradient({
                        angle: 135,
                        colors: this.getGradientForBook(book)
                      })
                      .justifyContent(FlexAlign.Center)
                    Text(book.title.charAt(0))
                      .fontSize(28)
                      .fontColor(Color.White)
                      .fontWeight(FontWeight.Bold)
                  }
                  .width('100%')
                  .shadow({ radius: 4, color: 'rgba(61,53,42,0.04)', offsetY: 2 })

                  Text(book.title)
                    .fontSize(13)
                    .fontColor(AppTheme.textPrimary)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 8 })

                  Text(book.author)
                    .fontSize(11)
                    .fontColor(AppTheme.textTertiary)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 2 })
                }
                .width('46%')
                .margin({ left: '2%', right: '2%', bottom: 16 })
                .onClick(() => { this.openBook(book) })
              }, (book: BookInfo) => `${book.id}_${book.filePath}`)
            }
            .width('100%')
            .padding({ left: 8, right: 8 })
          }
        }
        .width('100%')
        .padding({ bottom: 20 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.surfacePage)
  }

  /**
   * 根据书名生成渐变色（用于无封面占位）
   */
  private getGradientForBook(book: BookInfo): [ResourceColor, number][] {
    const hash = book.title.split('').reduce((acc, c) => acc + c.charCodeAt(0), 0);
    const palettes: [ResourceColor, number][][] = [
      [[AppTheme.primary, 0], [AppTheme.primaryLight, 1]],       // 金棕
      [['#6E614C', 0], ['#A89678', 1]],                            // 暖灰
      [['#4A7B9D', 0], ['#7BAFC9', 1]],                            // 青蓝
      [['#5B8C3E', 0], ['#8DB86B', 1]],                            // 绿色
      [['#8B6914', 0], ['#C49A2A', 1]],                            // 琥珀
      [['#6B4F0E', 0], ['#8B6914', 1]],                            // 深棕
    ];
    return palettes[hash % palettes.length];
  }
}
