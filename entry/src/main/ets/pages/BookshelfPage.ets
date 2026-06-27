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

  /** 继续阅读卡片的阅读进度百分比（0-100） */
  private getRecentProgressPercent(): number {
    if (!this.recentProgress || !this.recentBook) return 0;
    const total = (this.recentBook as BookInfo).totalSpines || 1;
    if (total <= 0) return 0;
    const pct = (this.recentProgress.spineIndex / total) * 100;
    return Math.min(100, Math.max(0, Math.round(pct)));
  }

  /** 书架网格中某本书的阅读进度百分比（0-100），仅最近阅读的书有进度数据 */
  private getBookProgressPercent(book: BookInfo): number {
    if (this.recentBook && this.recentProgress && book.id === (this.recentBook as BookInfo).id) {
      const total = (this.recentBook as BookInfo).totalSpines || 1;
      if (total <= 0) return 0;
      const pct = (this.recentProgress.spineIndex / total) * 100;
      return Math.min(100, Math.max(0, Math.round(pct)));
    }
    return 0;
  }

  build() {
    Column() {
      // 状态栏占位
      Row().height(48).width('100%').backgroundColor(AppTheme.surfacePage);

      // 标题
      Text('书架')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.textPrimary)
        .padding({ left: 20 })
        .margin({ top: 4, bottom: 16 })

      Scroll() {
        Column() {
          // 搜索栏
          Row() {
            Image($r('app.media.ic_search'))
              .width(18)
              .height(18)
              .margin({ left: 14 })
              .fillColor(AppTheme.textTertiary)
            TextInput({ placeholder: '搜索书名或作者...', text: this.searchQuery })
              .layoutWeight(1)
              .height(44)
              .fontSize(14)
              .fontColor(AppTheme.textPrimary)
              .backgroundColor(Color.Transparent)
              .padding({ left: 8, right: 12 })
              .onChange((value: string) => {
                this.searchQuery = value;
              })
              .onFocus(() => { this.isSearching = true })
              .onBlur(() => { this.isSearching = false })
          }
          .height(44)
          .width('100%')
          .backgroundColor(AppTheme.surfaceInset)
          .borderRadius(12)
          .border({ width: 1, color: AppTheme.borderDefault })
          .margin({ bottom: 20 })
          .clip(true)

          // 继续阅读区域
          if (this.recentBook) {
            Column() {
              Text('继续阅读')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.textSecondary)
                .letterSpacing(0.5)
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 12 })

              // 继续阅读卡片
              Row() {
                // 封面
                Stack({ alignContent: Alignment.End }) {
                  Column()
                    .width('100%')
                    .height('100%')
                    .linearGradient({
                      angle: 135,
                      colors: [[AppTheme.primaryLight, 0], [AppTheme.primary, 1]]
                    })
                  Column() {
                    Text((this.recentBook as BookInfo).title.charAt(0))
                      .fontSize(24)
                      .fontColor(Color.White)
                      .fontWeight(FontWeight.Bold)
                      .fontFamily('serif')
                  }
                  .width('100%')
                  .height('100%')
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)

                  // 琥珀色"金色时光"叠层
                  Column()
                    .width('100%')
                    .height('100%')
                    .linearGradient({
                      angle: 90,
                      colors: [['rgba(196,154,42,0.15)', 0], ['rgba(196,154,42,0.35)', 1]]
                    })

                  // 右侧渐变过渡，融入卡片
                  Column()
                    .width(16)
                    .height('100%')
                    .linearGradient({
                      angle: 90,
                      colors: [['rgba(255,255,255,0)', 0], [AppTheme.surfaceCard, 1]]
                    })
                }
                .width(100)
                .height(140)
                .borderRadius(8)
                .clip(true)

                // 右侧信息
                Column() {
                  Text((this.recentBook as BookInfo).title)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.textPrimary)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text((this.recentBook as BookInfo).author)
                    .fontSize(12)
                    .fontColor(AppTheme.textTertiary)
                    .margin({ top: 2 })

                  // 进度行
                  Row() {
                    Text('阅读进度')
                      .fontSize(12)
                      .fontColor(AppTheme.textTertiary)
                    Text(`${this.getRecentProgressPercent()}%`)
                      .fontSize(12)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppTheme.primary)
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.SpaceBetween)
                  .margin({ top: 12 })

                  // 进度条
                  Stack({ alignContent: Alignment.Start }) {
                    Row()
                      .width('100%')
                      .height(6)
                      .borderRadius(3)
                      .backgroundColor(AppTheme.borderDefault)
                    Row()
                      .height(6)
                      .borderRadius(3)
                      .linearGradient({
                        angle: 90,
                        colors: [[AppTheme.primaryLight, 0], [AppTheme.primary, 1]]
                      })
                      .width(`${this.getRecentProgressPercent()}%`)
                  }
                  .width('100%')
                  .height(6)
                  .margin({ top: 6 })

                  // 继续按钮
                  Text('继续')
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.textInverse)
                    .backgroundColor(AppTheme.primary)
                    .padding({ left: 20, right: 20, top: 6, bottom: 6 })
                    .borderRadius(999)
                    .alignSelf(ItemAlign.Start)
                    .margin({ top: 14 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 14 })
              }
              .width('100%')
              .padding(12)
              .backgroundColor(AppTheme.surfaceCard)
              .borderRadius(8)
              .shadow({ radius: 8, color: 'rgba(61,53,42,0.05)', offsetY: 2 })
              .onClick(() => { this.openBook(this.recentBook as BookInfo) })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: 24 })
          }

          // 我的书架标题
          Row() {
            Text('我的书架')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.textSecondary)
              .letterSpacing(0.5)
            Text(`共 ${this.filteredBooks().length} 本`)
              .fontSize(12)
              .fontColor(AppTheme.textTertiary)
              .margin({ left: 8 })
          }
          .width('100%')
          .margin({ bottom: 12 })

          // 书架网格 / 空状态
          if (this.filteredBooks().length === 0) {
            Column() {
              Text('书架空空如也')
                .fontSize(15)
                .fontColor(AppTheme.textTertiary)
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
                  Stack({ alignContent: Alignment.Bottom }) {
                    Column()
                      .width('100%')
                      .height('100%')
                      .linearGradient({
                        angle: 135,
                        colors: this.getGradientForBook(book)
                      })
                    Column() {
                      Text(book.title.charAt(0))
                        .fontSize(28)
                        .fontColor(Color.White)
                        .fontWeight(FontWeight.Bold)
                        .fontFamily('serif')
                    }
                    .width('100%')
                    .height('100%')
                    .justifyContent(FlexAlign.Center)
                    .alignItems(HorizontalAlign.Center)
                    // 封面底部进度条
                    Stack({ alignContent: Alignment.Start }) {
                      Row()
                        .width('100%')
                        .height(4)
                        .backgroundColor('rgba(0,0,0,0.15)')
                      Row()
                        .height(4)
                        .backgroundColor(AppTheme.primary)
                        .width(`${this.getBookProgressPercent(book)}%`)
                    }
                    .width('100%')
                    .height(4)
                  }
                  .width('100%')
                  .aspectRatio(0.715)
                  .borderRadius(8)
                  .shadow({ radius: 4, color: 'rgba(61,53,42,0.04)', offsetY: 1 })
                  .clip(true)

                  Text(book.title)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.textPrimary)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 8 })
                    .textAlign(TextAlign.Center)
                    .width('100%')
                }
                .width('46%')
                .margin({ left: '2%', right: '2%', bottom: 16 })
                .onClick(() => { this.openBook(book) })
              }, (book: BookInfo) => `${book.id}_${book.filePath}`)
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 112 })
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
    // 仅使用设计稿中的暖色系渐变，保持"温暖书卷风"视觉一致
    const palettes: [ResourceColor, number][][] = [
      [[AppTheme.primary, 0], [AppTheme.primaryLight, 1], [AppTheme.primaryLighter, 1]],       // 金棕
      [['#6E614C', 0], ['#A89678', 0.5], ['#DDD3BF', 1]],                                      // 暖灰
      [['#554A3A', 0], ['#8A7A60', 0.5], ['#C4B69A', 1]],                                      // 棕褐
      [['#6B4F0E', 0], [AppTheme.primary, 0.5], [AppTheme.primaryLight, 1]],                   // 深棕
    ];
    return palettes[hash % palettes.length];
  }
}
