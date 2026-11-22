import { SearchBookItem } from '../../bookSource/SourceModels';
import { BookCover } from '../BookCover';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../../data/CoverSettingsRepository';
import { formatDisplayText } from '../../lib/HtmlFormatter';
import { BookShelfState, SearchBookTagChip, searchBookKindList, searchBookToBook } from './SearchBookItems';
import {
  BODY_LARGE,
  BODY_LARGE_LINE_HEIGHT,
  BODY_SMALL,
  BODY_SMALL_LINE_HEIGHT,
  HEADLINE_SMALL,
  HEADLINE_SMALL_LINE_HEIGHT,
  LABEL_LARGE,
  LABEL_MEDIUM,
  LABEL_MEDIUM_EMPHASIZED,
  LABEL_MEDIUM_EMPHASIZED_LINE_HEIGHT
} from '../typography/TypographyTokens';
import { SPACE_12, SPACE_16, SPACE_4, SPACE_8 } from '../UiTokens';

/**
 * 长按在线书弹出的预览面板，对齐上游
 * `ui/widget/components/book/SearchBookPreviewSheet.kt`（187 行）。
 *
 * 上游结构（`AppModalBottomSheet` 里一整列，底部留 24dp）：
 *   Row（封面 120dp 宽 5:7 ｜ 右列垂直居中：书名 headlineSmall Bold 三行、作者 bodyLarge、
 *        来源名 labelMedium primary、最新章节 bodySmall、保存时间 bodySmall alpha 0.7）
 *   标签 chip 横滚（kinds 非空时）
 *   简介（formatDisplayText，最多 160dp 高、可滚）
 *   确认/取消按钮行：`book_info`（去详情）｜`add_to_bookshelf` 或 `already_in_bookshelf`（在架时禁用）
 *
 * 与上游的一处能力差别（记入 `tmp/appearance-impl-report.md` 待办账本）：
 * 上游最后一行「保存时间」用的是 `SearchBook.time`（存进 searchBooks 表那一刻的时间戳，
 * `SearchBook.kt:41 var time: Long = System.currentTimeMillis()`）。本地
 * `bookSource/SourceModels.ets:5-18 SearchBookItem` 没有这个字段 —— 本地的搜索结果
 * 不落库、没有「保存时刻」这个概念，所以这一行不画。
 * `updateTime` 不能顶替：它是书源给的「最新章节更新时间」字符串，与保存时间无关。
 */
@Component
export struct SearchBookPreviewSheet {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#4A4C55';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @Prop item: SearchBookItem = {
    bookUrl: '', origin: '', originName: '', name: '', author: '', kind: '',
    coverUrl: '', intro: '', lastChapter: '', wordCount: '', updateTime: '', tocUrl: ''
  };
  @Prop shelfState: BookShelfState = BookShelfState.NOT_IN_SHELF;
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  @Prop isNight: boolean = false;
  /** 共享元素键；由调用方按上游 `bookCoverSharedElementKey` 拼好传入。 */
  @Prop sharedKey: string = '';
  /** 点「书籍信息」：上游 `onOpenDetail(book, sharedCoverKey)`。 */
  onOpenDetail: () => void = () => {};
  /** 点「放入书架」：上游 `onAddToShelf(book)`。 */
  onAddToShelf: () => void = () => {};

  /** 上游 `isInShelf = shelfState == BookShelfState.IN_SHELF`。 */
  private isInShelf(): boolean {
    return this.shelfState === BookShelfState.IN_SHELF;
  }

  /** 上游 `HtmlFormatter.formatDisplayText(book.intro)`（详情预览用 display 那一层，不是 summary）。 */
  private introText(): string {
    return formatDisplayText(this.item.intro);
  }

  private a11yLabel(): string {
    return this.item.author.trim().length === 0 ? this.item.name : `${this.item.name}, ${this.item.author}`;
  }

  build() {
    Column() {
      Row() {
        BookCover({
          book: searchBookToBook(this.item),
          displayWidth: 120,
          displayHeight: Math.round(120 / (5 / 7)),
          cornerRadius: 4,
          coverSettings: this.coverSettings,
          isNight: this.isNight,
          a11yText: this.a11yLabel(),
          sharedKey: this.sharedKey
        })

        Column() {
          Text(this.item.name)
            .fontSize(HEADLINE_SMALL)
            .lineHeight(HEADLINE_SMALL_LINE_HEIGHT)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColorTextPrimary)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          if (this.item.author.trim().length > 0) {
            Text(this.item.author)
              .fontSize(BODY_LARGE)
              .lineHeight(BODY_LARGE_LINE_HEIGHT)
              .fontColor(this.themeColorTextSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: SPACE_4 })
              .width('100%')
          }
          if (this.item.originName.trim().length > 0) {
            Text(this.item.originName)
              .fontSize(LABEL_MEDIUM)
              .lineHeight(LABEL_MEDIUM)
              .fontColor(this.themeColorAccent)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: SPACE_4 })
              .width('100%')
          }
          if (this.item.lastChapter.trim().length > 0) {
            Text(this.item.lastChapter)
              .fontSize(BODY_SMALL)
              .lineHeight(BODY_SMALL_LINE_HEIGHT)
              .fontColor(this.themeColorTextSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: SPACE_4 })
              .width('100%')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .margin({ left: SPACE_16 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (searchBookKindList(this.item).length > 0) {
        Scroll() {
          Row() {
            ForEach(searchBookKindList(this.item), (kind: string, index: number) => {
              SearchBookTagChip({ text: kind }).margin({ right: 6 })
            }, (kind: string, index: number) => `${kind}:${index}`)
          }
          .align(Alignment.Start)
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .align(Alignment.Start)
        .margin({ top: SPACE_12 })
      }

      if (this.introText().length > 0) {
        Scroll() {
          Text(this.introText())
            .fontSize(LABEL_MEDIUM_EMPHASIZED)
            .lineHeight(LABEL_MEDIUM_EMPHASIZED_LINE_HEIGHT)
            .fontColor(this.themeColorTextSecondary)
            .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: 160 })
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off)
        .align(Alignment.TopStart)
        .margin({ top: SPACE_12 })
      }

      Row() {
        Text('书籍信息')
          .fontSize(LABEL_LARGE)
          .fontColor(this.themeColorTextTertiary)
          .constraintSize({ minWidth: 88 })
          .textAlign(TextAlign.Center)
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .onClick(() => this.onOpenDetail())
        Text(this.isInShelf() ? '已在书架' : '放入书架')
          .fontSize(LABEL_LARGE)
          .fontColor(this.isInShelf() ? this.themeColorTextTertiary : '#FFFFFF')
          .backgroundColor(this.isInShelf() ? this.themeColorSurfaceElevated : this.themeColorAccent)
          .borderRadius(10)
          .constraintSize({ minWidth: 88 })
          .textAlign(TextAlign.Center)
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .enabled(!this.isInShelf())
          .onClick(() => {
            if (!this.isInShelf()) { this.onAddToShelf(); }
          })
      }
      .width('100%')
      // 上游 M3 分支是 `Arrangement.spacedBy(12.dp, Alignment.End)`：两个按钮靠右、间距 12。
      .justifyContent(FlexAlign.End)
      .margin({ top: SPACE_16 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    // 上游 `Column(...).padding(bottom = 24.dp)`；左右内边距由宿主 sheet 提供。
    .padding({ bottom: 24 })
  }
}
