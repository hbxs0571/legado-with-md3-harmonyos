import { Book } from '../model/Book';
import { BookCover } from './BookCover';
import { AppGlyph } from './AppGlyph';
import { SearchBookItem } from '../bookSource/SourceModels';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../data/CoverSettingsRepository';
import { BookRepository } from '../data/BookRepository';
import { LABEL_MEDIUM, TITLE_MEDIUM } from './typography/TypographyTokens';
import { SPACE_8 } from './UiTokens';

/** 关联书籍横向条每本的封面宽度，对齐上游 `BannerModule.kt:73` 的 `width(96.dp)`。 */
const BANNER_COVER_WIDTH: number = 96;
/** 封面圆角，对齐上游 `BannerModule.kt:70` 的 `radius = 12.dp`。 */
const BANNER_COVER_RADIUS: number = 12;
/** 书与书的间距，对齐上游 `BannerModule.kt:57` 的 `Arrangement.spacedBy(12.dp)`。 */
const BANNER_COVER_GAP: number = 12;
/** 封面高宽比 7:5，与 `BookCover` 的默认比例一致。 */
const BANNER_COVER_RATIO: number = 7 / 5;

/**
 * 关联书籍横向条。对齐上游 `ui/book/info/BookInfoScreen.kt:2125-2171 RelatedBooksBanner`
 * 与 `ui/main/homepage/modules/BannerModule.kt:44-96`：
 * - 外层 `Column(fillMaxWidth().padding(bottom = 16.dp))`；
 * - 标题行 `Row(fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), CenterVertically)`，
 *   左 `titleMedium` + Bold 标题，右 `showMore` 时一枚箭头按钮（`contentDescription` 是
 *   `a11y_related_books_more`，`values-zh-rCN/strings.xml:2784` 的「查看更多相关书籍：%1$s」）；
 * - 内容 `LazyRow(spacedBy(12.dp))`，每本只有封面（宽 96dp、圆角 12dp），**没有书名文字行**，
 *   `contentDescription` 是 `"$name, $author"`（作者为空时只有书名）。
 *
 * 本地横向条统一用 `Scroll() { Row() { ForEach } }.scrollable(ScrollDirection.Horizontal)`
 * （与 `pages/HomePage.ets` 的最近阅读条同一写法），不用 `List`。
 */
@Component
export struct RelatedBooksBanner {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop title: string = '';
  @Prop books: SearchBookItem[] = [];
  @Prop showMore: boolean = false;
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  @Prop isNight: boolean = false;
  onSelectBook: (item: SearchBookItem) => void = () => {};
  onMore: () => void = () => {};

  /** 把在线书条目转成本地 `Book`，只为复用 `BookCover` 的封面渲染。 */
  private toBook(item: SearchBookItem): Book {
    return {
      id: BookRepository.bookIdFromUrl(item.bookUrl),
      title: item.name,
      author: item.author,
      category: item.kind ?? '',
      lastChapter: item.lastChapter,
      progress: 0,
      coverUri: item.coverUrl.length > 0 ? item.coverUrl : undefined,
      contentPath: item.bookUrl,
      // 关联书籍都来自在线书源，恒为在线书（对齐上游 SearchBook 只来自网络这一前提）。
      isLocal: false
    };
  }

  /** 无障碍文案：上游 `BannerModule.kt:93-95 bookAccessibilityLabel`。 */
  private accessibilityLabel(item: SearchBookItem): string {
    return item.author.trim().length === 0 ? item.name : `${item.name}, ${item.author}`;
  }

  build() {
    Column() {
      Row() {
        Text(this.title)
          .fontSize(TITLE_MEDIUM)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColorTextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.showMore) {
          Row() {
            AppGlyph({ name: 'arrowForward', tint: this.themeColorAccent, glyphSize: 18 })
          }
          .height(32)
          .padding({ left: SPACE_8, right: SPACE_8 })
          .accessibilityText(`查看更多相关书籍：${this.title}`)
          .onClick(() => this.onMore())
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      Scroll() {
        Row() {
          ForEach(this.books, (item: SearchBookItem, index: number) => {
            BookCover({
              book: this.toBook(item),
              displayWidth: BANNER_COVER_WIDTH,
              displayHeight: Math.round(BANNER_COVER_WIDTH * BANNER_COVER_RATIO),
              cornerRadius: BANNER_COVER_RADIUS,
              coverSettings: this.coverSettings,
              isNight: this.isNight,
              a11yText: this.accessibilityLabel(item)
            })
              .margin({ right: BANNER_COVER_GAP })
              .onClick(() => this.onSelectBook(item))
          }, (item: SearchBookItem, index: number) => `${item.bookUrl}:${index}`)
        }
        // Scroll 的内容默认居中，必须显式左对齐，否则两三条时会飘到整行中间
        // （书架分组栏与详情页标签行都踩过同一条）。
        .align(Alignment.Start)
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .align(Alignment.Start)
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ bottom: 16 })
  }
}
