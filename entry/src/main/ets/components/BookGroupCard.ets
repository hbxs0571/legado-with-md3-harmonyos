import { Book } from '../model/Book';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../data/CoverSettingsRepository';
import { BookCover } from './BookCover';
import { AppGlyph } from './AppGlyph';
import {
  BODY_SMALL,
  LABEL_SMALL_EMPHASIZED,
  TITLE_MEDIUM_EMPHASIZED,
  TITLE_SMALL
} from './typography/TypographyTokens';

/**
 * 分组卡片：书架「文件夹」样式根层每个分组一张卡。
 *
 * 三形态逐条对齐上游 BookItem.kt 的三个 composable：
 * - listStyle == 0 → BookGroupItemGrid（:451-488）：封面 2×2 在上、组名在下，数量是封面左下角角标；
 * - listStyle == 1 → BookGroupItemList（:490-554）：列表行，封面左、标题 / 数量 /「最近阅读：第一本」右；
 * - listStyle == 2 → BookGroupItemHorizontalCovers（:556-670）：圆角 12 的卡片，标题行在上、横排封面在下。
 *
 * 封面本体统一走 BookGroupCover（:326-449）的口径：固定 2×2 四宫格（不是按数量横排）、5:7、
 * 圆角 4、每格 1dp 内距；coverShadow 打开时给四宫格铺一层 surface 底色（上游是 background(surface)，
 * 不是投影）；数量角标是 TextCard 样式（圆角 4、水平内距 4、垂直内距 0）。
 */
@Component
export struct BookGroupCard {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  /** 四宫格的 surface 底色（BookItem.kt:349-354 `background(surface)`）。 */
  @StorageProp('themeColorSurface') themeColorSurface: string = '#F7F8FA';
  /** NormalCard 的默认容器色（GlassCard / NormalCard 用 cardContainer）。 */
  @StorageProp('themeColorCardContainer') themeColorCardContainer: string = '#F1F2F6';
  /** 数量角标 TextCard 的默认字色（TextCard.kt:44 `onSurface`）。 */
  @StorageProp('themeColorOnSurface') themeColorOnSurface: string = '#1B1C22';
  /** 角标与副标题的次级文字色。 */
  @StorageProp('themeColorOnSurfaceVariant') themeColorOnSurfaceVariant: string = '#2E3038';
  @Prop groupName: string = '';
  @Prop books: Book[] = [];
  /** 横排封面数量（bookshelfGroupCoverCount），只用于 listStyle == 2 的横排分支。 */
  @Prop coverCount: number = 4;
  /** 0 网格 / 1 紧凑列表 / 2 横排封面（bookshelfGroupListStyle）。 */
  @Prop listStyle: number = 0;
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  @Prop isNight: boolean = false;
  /** 列表封面宽度，来自书架布局 bookshelfListCoverWidth。 */
  @Prop listCoverWidth: number = 84;
  /** 是否显示书籍计数（书架布局 showBookCount）。 */
  @Prop showCount: boolean = true;
  /**
   * 封面阴影（书架布局 bookshelfCoverShadow）。上游 BookItem.kt:349-354 在四宫格外层
   * `background(LegadoTheme.colorScheme.surface)`，不是投影——四格之间的缝由这层底色透出来。
   */
  @Prop coverShadow: boolean = false;
  /** 私密锁定：不画预览、不显示计数、组名旁加锁图标。 */
  @Prop locked: boolean = false;
  /** 卡片底部分隔线（书架布局 bookshelfShowDivider，上游 BookItem.kt:663-668）。 */
  @Prop showDivider: boolean = true;
  onOpen: () => void = () => {};
  /** 长按分组卡直接进该分组的编辑面板（上游 GroupEditSheet 入口）。 */
  onLongPress: (groupName: string) => void = (_groupName: string) => {};

  /**
   * 四宫格取书：上游 `books.getOrNull(0..3)` 固定四格，与 coverCount 无关。
   * 锁定时一格都不给——从缩略图认出是哪本书等于没锁。
   */
  private gridBooks(): Book[] {
    if (this.locked) { return []; }
    return this.books.slice(0, 4);
  }

  /** 横排分支取书：上游 `previewBooks.take(coverCount)`。 */
  private horizontalBooks(): Book[] {
    if (this.locked) { return []; }
    const count = Math.max(0, Math.round(this.coverCount));
    return this.books.slice(0, count);
  }

  /** 横排分支右侧留空位：上游 `repeat(maxOf(0, coverCount - previewBooks.size)) { Spacer }`。 */
  private emptySlots(): number[] {
    const count = Math.max(0, Math.round(this.coverCount) - this.horizontalBooks().length);
    const slots: number[] = [];
    for (let index = 0; index < count; index += 1) { slots.push(index); }
    return slots;
  }

  /** 列表分支的「最近阅读：」书名（上游 descAnnotated 取 previewBooks 第一本的书名）。 */
  private firstBookName(): string {
    const books = this.gridBooks();
    return books.length > 0 ? books[0].title : '';
  }

  /** 数量文案（上游 `stringResource(R.string.book_count, count)` → 「%1$d 本」）。 */
  private countText(): string {
    return `${this.books.length} 本`;
  }

  /** 四宫格的一格：有书就画封面，没书就留空；每格 1dp 内距（BookItem.kt:366/383/402/419）。 */
  @Builder
  private CoverCell(index: number) {
    Column() {
      if (index < this.gridBooks().length) {
        BookCover({
          book: this.gridBooks()[index],
          compact: true,
          fillWidth: true,
          cornerRadius: 4,
          coverSettings: this.coverSettings,
          isNight: this.isNight
        })
      }
    }
    .layoutWeight(1)
    .height('100%')
    .padding(1)
    .clip(true)
    .borderRadius(4)
  }

  /**
   * 2×2 四宫格封面（BookGroupCover :326-449）。
   * 外层 5:7 + 圆角 4；coverShadow 时铺 surface 底色，缝隙透出来就是上游那层「框」。
   */
  @Builder
  private GroupCoverGrid() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Column() {
        Row() {
          this.CoverCell(0)
          this.CoverCell(1)
        }.width('100%').layoutWeight(1)
        Row() {
          this.CoverCell(2)
          this.CoverCell(3)
        }.width('100%').layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      // 上游 `Column(Modifier.fillMaxSize().padding(horizontal = 1.dp))`：左右各 1dp。
      .padding({ left: 1, right: 1 })
      .backgroundColor(this.coverShadow ? this.themeColorSurface : Color.Transparent)

      // 左下角数量角标（BookItem.kt:437-446 TextCard：圆角 4、水平内距 4、垂直内距 0）。
      if (this.showCount && !this.locked) {
        Text(this.countText())
          .fontSize(LABEL_SMALL_EMPHASIZED)
          .fontColor(this.themeColorOnSurface)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 4, right: 4, top: 0, bottom: 0 })
          .backgroundColor(this.themeColorSurface)
          .borderRadius(4)
          .margin(2)
      }
    }
    .width('100%')
    .aspectRatio(5 / 7)
    .clip(true)
    .borderRadius(4)
  }

  build() {
    if (this.listStyle === 2) {
      // ---- BookGroupItemHorizontalCovers（:556-670）----
      Column() {
        Column({ space: 8 }) {
          // 标题行：组名 + 计数 + 右箭头（:593-620）。
          Row() {
            Text(this.groupName)
              .fontSize(TITLE_MEDIUM_EMPHASIZED)
              .fontColor(this.themeColorTextSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            if (this.showCount && !this.locked) {
              Text(this.countText())
                .fontSize(LABEL_SMALL_EMPHASIZED)
                .fontColor(this.themeColorOnSurfaceVariant)
                .maxLines(1)
                .margin({ left: 4 })
            }
            AppGlyph({ name: 'arrowForward', glyphSize: 16, tint: this.themeColorOnSurfaceVariant })
              .margin({ left: 4 })
          }
          .width('100%')
          .padding({ left: 4, right: 4, top: 4, bottom: 4 })
          .alignItems(VerticalAlign.Center)

          // 横排封面行：每本一格，等宽 5:7、圆角 4，不足补空位（:621-660）。
          Row({ space: 4 }) {
            ForEach(this.horizontalBooks(), (book: Book) => {
              Column() {
                BookCover({
                  book: book,
                  compact: true,
                  fillWidth: true,
                  cornerRadius: 4,
                  coverSettings: this.coverSettings,
                  isNight: this.isNight
                })
              }
              .layoutWeight(1)
              .aspectRatio(5 / 7)
              .clip(true)
              .borderRadius(4)
            }, (book: Book) => `hcover_${book.id}`)
            ForEach(this.emptySlots(), (index: number) => {
              Row().layoutWeight(1)
            }, (index: number) => `hempty_${index}`)
          }
          .width('100%')
          .padding({ left: 4, right: 4 })
        }
        .width('100%')
        // 上游 `Column(Modifier.padding(vertical = 8.dp, horizontal = 4.dp), spacedBy(8.dp))`
        .padding({ left: 4, right: 4, top: 8, bottom: 8 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      // 上游 NormalCard(padding(all = 4.dp), cornerRadius = 12.dp, containerColor = cardContainer)
      .padding(4)
      .backgroundColor(this.themeColorCardContainer)
      .borderRadius(12)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
      .onClick(() => { this.onOpen(); })
      .gesture(LongPressGesture({ duration: 500 }).onAction(() => { this.onLongPress(this.groupName); }))
      if (this.showDivider) {
        Divider()
          .strokeWidth(0.5)
          .color(this.themeColorTextTertiary)
          .opacity(0.5)
          .width('100%')
          .padding({ left: 16, right: 16 })
      }
    } else {
      // ---- BookGroupItemList（:490-554）/ BookGroupItemGrid（:451-488）----
      Column() {
        if (this.listStyle === 0) {
          // 网格形态：封面在上、组名在下（BookshelfGridItem，数量走封面左下角角标）。
          Column() {
            this.GroupCoverGrid()
            Text(this.groupName)
              .fontSize(TITLE_SMALL)
              .fontColor(this.themeColorTextSecondary)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ left: 4, right: 4, top: 4, bottom: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        } else {
          // 紧凑列表形态：封面左、右列标题 + 计数 +「最近阅读：第一本」。
          Row() {
            Column() {
              this.GroupCoverGrid()
            }
            .width(this.listCoverWidth)

            Column() {
              Text(this.groupName)
                .fontSize(TITLE_MEDIUM_EMPHASIZED)
                .fontColor(this.themeColorTextSecondary)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
              if (this.showCount && !this.locked) {
                Text(this.countText())
                  .fontSize(BODY_SMALL)
                  .fontColor(this.themeColorOnSurfaceVariant)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 2 })
              }
              if (this.firstBookName().length > 0) {
                // 上游 descAnnotated：`最近阅读：` + 书名（书名用 Medium 加重）。
                Text(`最近阅读：${this.firstBookName()}`)
                  .fontSize(LABEL_SMALL_EMPHASIZED)
                  .fontColor(this.themeColorTextTertiary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 2 })
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            // 上游 `Column(Modifier.weight(1f).padding(top = 4.dp, bottom = 4.dp, end = 8.dp, start = 4.dp))`
            .padding({ left: 4, right: 8, top: 4, bottom: 4 })
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
      }
      .width('100%')
      // 上游 NormalCard(cornerRadius = 8.dp, containerColor = cardContainer, padding(vertical = 4.dp))
      .padding({ left: 0, right: 0, top: 4, bottom: 4 })
      .backgroundColor(this.themeColorCardContainer)
      .borderRadius(8)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
      .onClick(() => { this.onOpen(); })
      .gesture(LongPressGesture({ duration: 500 }).onAction(() => { this.onLongPress(this.groupName); }))
      if (this.showDivider) {
        Divider()
          .strokeWidth(0.5)
          .color(this.themeColorTextTertiary)
          .opacity(0.5)
          .width('100%')
          .padding({ left: 16, right: 16 })
      }
    }
  }
}
