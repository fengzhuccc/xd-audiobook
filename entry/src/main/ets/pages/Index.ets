import { AppTheme } from '../common/theme/AppTheme';
import { BookshelfPage } from './BookshelfPage';
import { LibraryPage } from './LibraryPage';
import { SettingsPage } from './SettingsPage';

@Entry
@Component
struct Index {
  @StorageProp('currentTab') currentTab: number = 0;

  // Tab bar builder
  @Builder
  tabBuilder(title: string, icon: ResourceStr, activeIcon: ResourceStr, index: number) {
    Column() {
      Image(this.currentTab === index ? activeIcon : icon)
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
      Text(title)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTab === index ? AppTheme.primary : AppTheme.textTertiary)
        .margin({ top: 2 })
    }
    .width('33.3%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.currentTab = index;
    })
  }

  build() {
    Column() {
      // 内容区
      Tabs({
        index: this.currentTab,
        barPosition: BarPosition.End,
        controller: null
      }) {
        TabContent() {
          BookshelfPage()
            .width('100%')
            .height('100%')
        }.tabBar(this.tabBuilder('书架', $r('app.media.tab_bookshelf'), $r('app.media.tab_bookshelf_active'), 0))

        TabContent() {
          LibraryPage()
            .width('100%')
            .height('100%')
        }.tabBar(this.tabBuilder('书库', $r('app.media.tab_library'), $r('app.media.tab_library_active'), 1))

        TabContent() {
          SettingsPage()
            .width('100%')
            .height('100%')
        }.tabBar(this.tabBuilder('设置', $r('app.media.tab_settings'), $r('app.media.tab_settings_active'), 2))
      }
      .vertical(false)
      .scrollable(false)
      .barMode(BarMode.Fixed)
      .barOverlap(false)
      .barWidth('100%')
      .barHeight(56)
      .animationDuration(200)
      .onChange((index: number) => {
        this.currentTab = index;
      })
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.surfacePage)
    }
  }
}
