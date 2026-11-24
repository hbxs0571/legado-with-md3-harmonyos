import { Book } from '../../model/Book';
import { BookCover } from '../BookCover';
import { AppGlyph } from '../AppGlyph';
import { SearchBookItem } from '../../bookSource/SourceModels';
import { BookRepository } from '../../data/BookRepository';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../../data/CoverSettingsRepository';
import { formatSummaryText } from '../../lib/HtmlFormatter';
import {
  BODY_SMALL,
  BODY_SMALL_LINE_HEIGHT,
  LABEL_SMALL,
  LABEL_SMALL_LINE_HEIGHT,
  TITLE_SMALL,
  TITLE_SMALL_LINE_HEIGHT
} from '../typography/TypographyTokens';
import { SPACE_12, SPACE_16, SPACE_2, SPACE_4, SPACE_8 } from '../UiTokens';

/**
 * 在线书条目（列表 / 网格 / 标签 chip），对齐上游
 * `ui/widget/components/book/SearchBookItem.kt`（375 行）的三个导出：
 * `SearchBookListItem`、`SearchBookGridItem`、`SearchBookTagChip`。
 *
 * 上游这三个组件同时被「发现」「探索结果」「作者其它作品」等页面复用；
 * 本地此前只有 `pages/DiscoverPage.ets` 里内联的 `ExploreBookCard`
 * （52×72 封面 + 名称/作者/最新章节/来源），字段与排版都与上游不同。
 * 探索结果页（`ExploreShowPage`）要用上游那一套，所以按上游口径新建，
 * 不改 `DiscoverPage`（它已经在用，改动会牵动发现页的现有视觉）。
 */

/** 上游 `DEFAULT_SEARCH_BOOK_COVER_ASPECT_RATIO = 5f / 7f`。 */
const COVER_ASPECT_RATIO: number = 5 / 7;
/** 上游 `SEARCH_BOOK_COVER_WIDTH_DP = 72f`。 */
const COVER_WIDTH: number = 72;
/** 上游 `MIN_SEARCH_BOOK_COVER_HEIGHT_DP = 80f`。 */
const MIN_COVER_HEIGHT: number = 80;
/** 上游 `MAX_SEARCH_BOOK_COVER_HEIGHT_DP = 140f`。 */
const MAX_COVER_HEIGHT: number = 140;
/** 上游 `CoilBookCover` 的默认 `radius: Dp = 4.dp`。 */
const COVER_RADIUS: number = 4;
/** 上游 `Modifier.blur(8.dp)`：质量屏蔽时封面模糊半径。 */
const QUALITY_MASK_BLUR: number = 8;
/** 上游 `SearchBookListItem` 封面与文字的间距 `Spacer(Modifier.width(8.dp))`。 */
const COVER_GAP: number = 8;
/** 上游 `TextCard` 默认 `cornerRadius = 8.dp`，但三处角标都显式传 `4.dp`。 */
const BADGE_RADIUS: number = 4;
/** 上游 `TextCard` 默认 `iconSize = 14.dp`。 */
const BADGE_ICON_SIZE: number = 14;

/** 书架状态，对齐上游 `domain/model/BookShelfState.kt:3-7`。 */
export enum BookShelfState {
  IN_SHELF = 0,
  SAME_NAME_AUTHOR = 1,
  NOT_IN_SHELF = 2
}

/**
 * 上游 `BaseBook.kt:42-52 getKindList()`：
 * 字数（非空才加）在前，然后 `kind` 按逗号或换行拆开逐条加入。
 */
export function searchBookKindList(item: SearchBookItem): string[] {
  const kinds: string[] = [];
  if (item.wordCount.trim().length > 0) { kinds.push(item.wordCount); }
  if (item.kind.length > 0) {
    for (const part of item.kind.split(/[,\n]/)) {
      const trimmed = part.trim();
      if (trimmed.length > 0) { kinds.push(trimmed); }
    }
  }
  return kinds;
}

/**
 * 把在线书条目转成本地 `Book`，只为复用 `BookCover` 的封面渲染
 * （与 `components/RelatedBooksBanner.ets` 的 `toBook` 同一口径）。
 */
export function searchBookToBook(item: SearchBookItem): Book {
  return {
    id: BookRepository.bookIdFromUrl(item.bookUrl),
    title: item.name,
    author: item.author,
    category: item.kind ?? '',
    lastChapter: item.lastChapter,
    progress: 0,
    coverUri: item.coverUrl.length > 0 ? item.coverUrl : undefined,
    contentPath: item.bookUrl,
    isLocal: false
  };
}

/** 上游 `searchBookCoverHeightDp(aspectRatio)`：`72 / ratio` 夹在 80..140。 */
function coverHeightFor(aspectRatio: number): number {
  const safe = Number.isFinite(aspectRatio) && aspectRatio > 0 ? aspectRatio : COVER_ASPECT_RATIO;
  return Math.min(Math.max(COVER_WIDTH / safe, MIN_COVER_HEIGHT), MAX_COVER_HEIGHT);
}

/** 书架状态对应的角标图标，对齐上游 `shelfIcon` 的 when 分支。 */
function shelfGlyph(state: BookShelfState): string {
  if (state === BookShelfState.IN_SHELF) { return 'profileCheck'; }
  if (state === BookShelfState.SAME_NAME_AUTHOR) { return 'shuffle'; }
  return '';
}

/**
 * 标签 chip。上游 `SearchBookItem.kt:357-375 SearchBookTagChip`：
 * `GlassCard(containerColor = surfaceContainerHigh, cornerRadius = 4.dp)` 里一段
 * `labelSmallEmphasized`、字色 `onCardContainer`、内边距 4/2 的文字。
 *
 * 容器 `themeColorSurfaceElevated`（= surfaceContainerHigh）对齐上游默认值；
 * 字色 `themeColorOnCardContainer`（派生自 primary，见 `data/ThemePalette.ets` 的 `publishPaletteColors`）。
 */
@Component
export struct SearchBookTagChip {
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorOnCardContainer') themeColorOnCardContainer: string = '#4C662B';
  @Prop text: string = '';

  build() {
    Text(this.text)
      .fontSize(LABEL_SMALL)
      .lineHeight(LABEL_SMALL_LINE_HEIGHT)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.themeColorOnCardContainer)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: 4, right: 4, top: 2, bottom: 2 })
      .backgroundColor(this.themeColorSurfaceElevated)
      .borderRadius(BADGE_RADIUS)
  }
}

/**
 * 列表条目。对齐上游 `SearchBookItem.kt:76-262 SearchBookListItem`：
 * - `Row`，封面宽 72dp（默认 5:7；开启自适应且未限制比例时按原图比例算高，夹在 80..140）；
 * - 封面右上角书架状态角标（在架 → 勾、同名同作者 → 交换箭头，其余不画）；
 * - 右侧 `Column` 垂直居中：书名 `titleSmall` 单行 +（可选）来源数角标；
 *   作者 `bodySmall` +「 • 最新: 章节名」；简介 `labelSmall` 两行；
 *   标签 chip 横向可滚。
 *
 * 上游的 `qualityMasked`（内容质量检测排除）与 `sourceCount` 角标在探索结果页都不传，
 * 但 `SearchBookListItem` 是通用组件，这里把两个参数都保留下来。
 */
@Component
export struct SearchBookListItem {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#4A4C55';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#858792';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorScrim') themeColorScrim: string = '#000000';
  @Prop item: SearchBookItem = {
    bookUrl: '', origin: '', originName: '', name: '', author: '', kind: '',
    coverUrl: '', intro: '', lastChapter: '', wordCount: '', updateTime: '', tocUrl: ''
  };
  @Prop shelfState: BookShelfState = BookShelfState.NOT_IN_SHELF;
  /** 是否画左右内边距；上游 `showPadding = true` 时加 `adaptiveHorizontalPadding(vertical = 8.dp)`。 */
  @Prop showPadding: boolean = true;
  /** 来源数角标；上游 `sourceCount: Int?`，0 或不传时不画。 */
  @Prop sourceCount: number = 0;
  /** 内容质量检测已排除：封面上叠一层 scrim + 一行说明。 */
  @Prop qualityMasked: boolean = false;
  /** 是否按原图比例推导封面高度（上游 `adaptCoverAspectRatio`，探索结果页传 true）。 */
  @Prop adaptCoverAspectRatio: boolean = false;
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  @Prop isNight: boolean = false;
  /** 共享元素键，由调用方按上游 `bookCoverSharedElementKey` 拼好传入。 */
  @Prop sharedKey: string = '';
  onSelect: () => void = () => {};
  onLongPress: () => void = () => {};

  /**
   * 是否允许封面高度跟随原图比例。
   * 上游 `allowCoverRatioAdapt = adaptCoverAspectRatio && !cover.restrictCoverRatio`。
   */
  private allowCoverRatioAdapt(): boolean {
    return this.adaptCoverAspectRatio && !this.coverSettings.restrictCoverRatio;
  }

  /** 简介摘要：上游 `HtmlFormatter.formatSummaryText(book.intro)`。 */
  private introSummary(): string {
    return formatSummaryText(this.item.intro);
  }

  /** 无障碍文案：上游 `BannerModule` 同款「书名, 作者」口径。 */
  private a11yLabel(): string {
    return this.item.author.trim().length === 0 ? this.item.name : `${this.item.name}, ${this.item.author}`;
  }

  build() {
    Row() {
      Stack({ alignContent: Alignment.TopEnd }) {
        BookCover({
          book: searchBookToBook(this.item),
          displayWidth: COVER_WIDTH,
          displayHeight: this.allowCoverRatioAdapt() ? coverHeightFor(COVER_ASPECT_RATIO) : 0,
          cornerRadius: COVER_RADIUS,
          coverSettings: this.coverSettings,
          isNight: this.isNight,
          applyAspectRatio: this.allowCoverRatioAdapt(),
          a11yText: this.a11yLabel(),
          sharedKey: this.sharedKey
        })
        // 上游 `:126`：`if (qualityMasked) Modifier.blur(8.dp) else Modifier`，封面先糊再盖 scrim。
        .blur(this.qualityMasked ? QUALITY_MASK_BLUR : 0)
        if (this.qualityMasked) {
          // 上游：`scrim.copy(alpha = 0.58f)` 铺满封面 + 居中 `content_quality_excluded`。
          Column() {
            Text('内容质量检测已排除')
              .fontSize(LABEL_SMALL)
              .lineHeight(LABEL_SMALL_LINE_HEIGHT)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeColorTextPrimary)
              .textAlign(TextAlign.Center)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: 2, right: 2 })
          }
          .width(COVER_WIDTH)
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.themeColorScrim)
          .opacity(0.58)
          .borderRadius(COVER_RADIUS)
        }
        if (shelfGlyph(this.shelfState).length > 0) {
          Row() {
            AppGlyph({
              name: shelfGlyph(this.shelfState) === 'profileCheck' ? 'profileCheck' : 'shuffle',
              glyphSize: BADGE_ICON_SIZE,
              tint: this.themeColorTextPrimary
            })
          }
          .padding({ left: 2, right: 2, top: 2, bottom: 2 })
          .backgroundColor(this.themeColorSurfaceElevated)
          .borderRadius(BADGE_RADIUS)
          .margin({ top: 2, right: 2 })
        }
      }
      .width(COVER_WIDTH)
      // 上游封面 Box 的宽度固定 72dp，高度由 aspectRatio 或自适应高度决定；
      // Stack 不传高度时按最高子节点撑开，这里显式给高度避免 BookCover 的 0 高度塌陷。
      .height(this.allowCoverRatioAdapt()
        ? coverHeightFor(COVER_ASPECT_RATIO)
        : Math.round(COVER_WIDTH / COVER_ASPECT_RATIO))

      Column() {
        Row() {
          Text(this.item.name)
            .fontSize(TITLE_SMALL)
            .lineHeight(TITLE_SMALL_LINE_HEIGHT)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColorTextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.sourceCount > 0) {
            Text(`${this.sourceCount}`)
              .fontSize(LABEL_SMALL)
              .lineHeight(LABEL_SMALL_LINE_HEIGHT)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeColorTextPrimary)
              .padding({ left: 4, right: 4, top: 2, bottom: 2 })
              .backgroundColor(this.themeColorSurfaceElevated)
              .borderRadius(BADGE_RADIUS)
              .margin({ left: COVER_GAP })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row() {
          Text(this.item.author)
            .fontSize(BODY_SMALL)
            .lineHeight(BODY_SMALL_LINE_HEIGHT)
            .fontColor(this.themeColorTextPrimary)
            .maxLines(1)
          if (this.item.lastChapter.length > 0) {
            Text(' • ')
              .fontSize(BODY_SMALL)
              .lineHeight(BODY_SMALL_LINE_HEIGHT)
              .fontColor(this.themeColorTextSecondary)
              .maxLines(1)
            Text(`最新: ${this.item.lastChapter}`)
              .fontSize(BODY_SMALL)
              .lineHeight(BODY_SMALL_LINE_HEIGHT)
              .fontColor(this.themeColorTextSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
        }
        .width('100%')

        if (this.introSummary().length > 0) {
          Text(this.introSummary())
            .fontSize(LABEL_SMALL)
            .lineHeight(LABEL_SMALL_LINE_HEIGHT)
            .fontColor(this.themeColorTextSecondary)
            .maxLines(2)
            .minLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: SPACE_4 })
            .width('100%')
        }

        if (searchBookKindList(this.item).length > 0) {
          Scroll() {
            Row() {
              ForEach(searchBookKindList(this.item), (kind: string, index: number) => {
                SearchBookTagChip({ text: kind }).margin({ right: 6 })
              }, (kind: string, index: number) => `${kind}:${index}`)
            }
            // Scroll 的内容默认居中，必须显式左对齐（同 RelatedBooksBanner 的教训）。
            .align(Alignment.Start)
          }
          .width('100%')
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .align(Alignment.Start)
          .margin({ top: SPACE_4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .margin({ left: COVER_GAP })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      left: this.showPadding ? SPACE_16 : 0,
      right: this.showPadding ? SPACE_16 : 0,
      top: this.showPadding ? SPACE_8 : 0,
      bottom: this.showPadding ? SPACE_8 : 0
    })
    .onClick(() => this.onSelect())
    // 上游是 combinedClickable(onClick, onLongClick)；ArkUI 的 gesture(LongPress) 与 onClick
    // 可以共存，长按不触发点击。
    .gesture(LongPressGesture().onAction(() => this.onLongPress()))
  }
}

/**
 * 网格条目。对齐上游 `SearchBookItem.kt:264-352 SearchBookGridItem`：
 * - `Column` 圆角 4 裁切；
 * - 封面 `fillMaxWidth + aspectRatio(5:7)`，右上角书架状态角标；
 * - 封面下 `padding(horizontal 4dp, vertical 4dp)` 里两行书名（`bodySmall` Bold，
 *   `maxLines = 2, minLines = 2`）。
 */
@Component
export struct SearchBookGridItem {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorScrim') themeColorScrim: string = '#000000';
  @Prop item: SearchBookItem = {
    bookUrl: '', origin: '', originName: '', name: '', author: '', kind: '',
    coverUrl: '', intro: '', lastChapter: '', wordCount: '', updateTime: '', tocUrl: ''
  };
  @Prop shelfState: BookShelfState = BookShelfState.NOT_IN_SHELF;
  @Prop qualityMasked: boolean = false;
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  @Prop isNight: boolean = false;
  @Prop sharedKey: string = '';
  onSelect: () => void = () => {};
  onLongPress: () => void = () => {};

  private a11yLabel(): string {
    return this.item.author.trim().length === 0 ? this.item.name : `${this.item.name}, ${this.item.author}`;
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        BookCover({
          book: searchBookToBook(this.item),
          fillWidth: true,
          cornerRadius: COVER_RADIUS,
          coverSettings: this.coverSettings,
          isNight: this.isNight,
          a11yText: this.a11yLabel(),
          sharedKey: this.sharedKey
        })
        // 上游 `:296`：网格项同样 `if (qualityMasked) Modifier.blur(8.dp) else Modifier`。
        .blur(this.qualityMasked ? QUALITY_MASK_BLUR : 0)
        if (this.qualityMasked) {
          Column() {
            Text('内容质量检测已排除')
              .fontSize(LABEL_SMALL)
              .lineHeight(LABEL_SMALL_LINE_HEIGHT)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeColorTextPrimary)
              .textAlign(TextAlign.Center)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: 2, right: 2 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.themeColorScrim)
          .opacity(0.58)
          .borderRadius(COVER_RADIUS)
        }
        if (shelfGlyph(this.shelfState).length > 0) {
          Row() {
            AppGlyph({
              name: shelfGlyph(this.shelfState) === 'profileCheck' ? 'profileCheck' : 'shuffle',
              glyphSize: BADGE_ICON_SIZE,
              tint: this.themeColorTextPrimary
            })
          }
          .padding({ left: 2, right: 2, top: 2, bottom: 2 })
          .backgroundColor(this.themeColorSurfaceElevated)
          .borderRadius(BADGE_RADIUS)
          .margin({ top: 2, right: 2 })
        }
      }
      .width('100%')
      // 上游 `aspectRatio(5f / 7f)`：宽度由格子决定，高度按比例推导。
      .aspectRatio(COVER_ASPECT_RATIO)

      Column() {
        Text(this.item.name)
          .fontSize(BODY_SMALL)
          .lineHeight(BODY_SMALL_LINE_HEIGHT)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColorTextPrimary)
          .maxLines(2)
          .minLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 4, right: 4, top: 4, bottom: 4 })
    }
    .width('100%')
    .clip(true)
    .borderRadius(COVER_RADIUS)
    .onClick(() => this.onSelect())
    .gesture(LongPressGesture().onAction(() => this.onLongPress()))
  }
}
