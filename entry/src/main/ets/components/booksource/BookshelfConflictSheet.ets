// 加入书架时「疑似重复」的处理面板。
//
// 对齐上游 `ui/widget/components/conflict/BookshelfConflictSheet.kt`（246 行）与
// `domain/model/BookshelfConflict.kt`：
// - 卡片点击 → 打开书架已有作品的详情页；
// - 多个候选时用单选决定「对哪一本」执行操作，默认选中第一本（上游按最近阅读时间倒序排好）；
// - 底部「共存 / 迁移」复用换源的携带数据选项，右上角齿轮单独打开选项面板。
//
// 选项面板直接复用 `ChangeSourceMigrationOptionsSheet`：上游 `BookshelfConflictSheet.kt:182` 调的就是
// 那个公共 composable（`title = bookshelf_conflict_options_title`「要携带的数据」、`showDeleteDownloaded = false`，
// 因为共存场景两本书都留在书架，删缓存没有意义）。
import { Book } from '../../model/Book';
import { ChangeSourceMigrationOptions, defaultMigrationOptions } from '../../bookSource/ChangeSourceCoordinator';
import { ChangeSourceMigrationOptionsSheet } from './ChangeSourceMigrationOptionsSheet';
import { BookCover } from '../BookCover';
import { AppGlyph } from '../AppGlyph';
import {
  BODY_SMALL,
  LABEL_LARGE,
  LABEL_MEDIUM,
  LABEL_SMALL_EMPHASIZED,
  TITLE_SMALL
} from '../typography/TypographyTokens';
import { SPACE_12, SPACE_16, SPACE_4, SPACE_8 } from '../UiTokens';

/** 冲突面板里展示的一本书，对齐上游 `ConflictBookSummary`。 */
export class ConflictBookSummary {
  bookUrl: string = '';
  name: string = '';
  author: string = '';
  coverUrl: string = '';
  customCoverUrl: string = '';
  origin: string = '';
  sourceName: string = '';
  totalChapterNum: number = 0;
  latestChapterTitle: string = '';

  /** 上游 `displayCover`：自定义封面优先，空串回落原始封面。 */
  displayCover(): string {
    if (this.customCoverUrl.length > 0) { return this.customCoverUrl; }
    return this.coverUrl;
  }

  /** 从本地书架条目构造（书架里已有的那一本）。 */
  static fromBook(book: Book): ConflictBookSummary {
    const summary = new ConflictBookSummary();
    summary.bookUrl = book.contentPath !== undefined && book.contentPath.length > 0 ? book.contentPath : book.id;
    summary.name = book.title;
    summary.author = book.author;
    summary.coverUrl = book.coverUri !== undefined ? book.coverUri : '';
    summary.customCoverUrl = book.customCoverUri !== undefined ? book.customCoverUri : '';
    summary.origin = book.origin !== undefined ? book.origin : '';
    summary.sourceName = book.originName !== undefined ? book.originName : '';
    const chapterCount = book.chapterCount !== undefined ? Number.parseInt(book.chapterCount, 10) : 0;
    summary.totalChapterNum = Number.isNaN(chapterCount) ? 0 : chapterCount;
    summary.latestChapterTitle = book.latestChapterTitle !== undefined ? book.latestChapterTitle : '';
    return summary;
  }
}

/** 一次冲突：待加入的书 + 书架里疑似同一作品的已有书（对齐上游 `BookshelfConflict`）。 */
export class BookshelfConflict {
  incoming: ConflictBookSummary = new ConflictBookSummary();
  candidates: ConflictBookSummary[] = [];
}

/** 「书架里已有的同作品」卡片，对齐上游 `ConflictBookCard`。 */
@Component
export struct ConflictBookCard {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  /** 面板内卡片底色。上游 `onSheetContent` 派生自 `surface`（`ThemeColorSchemeOverride.kt:78`）。 */
  @StorageProp('themeColorOnSheetContent') themeColorOnSheetContent: string = '#F5F6F8';

  @Prop summary: ConflictBookSummary = new ConflictBookSummary();

  onOpenBook: (summary: ConflictBookSummary) => void = () => {};

  /** 上游 `all_chapter_num`「共 %1$d 章」。 */
  private chapterLabel(): string {
    return `共 ${this.summary.totalChapterNum} 章`;
  }

  build() {
    Row() {
      if (this.summary.displayCover().length > 0) {
        Image(this.summary.displayCover())
          .width(52)
          .aspectRatio(5 / 7)
          .borderRadius(4)
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.transparent_pixel'))
      } else {
        Column() {
          AppGlyph({ name: 'book', glyphSize: 20, tint: this.themeColorAccent })
        }
        .width(52)
        .aspectRatio(5 / 7)
        .borderRadius(4)
        .backgroundColor(this.themeColorOnSheetContent)
        .justifyContent(FlexAlign.Center)
      }
      Column() {
        Text(this.summary.name)
          .fontSize(TITLE_SMALL)
          .fontColor(this.themeColorTextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.summary.author.length > 0) {
          Text(this.summary.author)
            .fontSize(LABEL_LARGE)
            .fontColor(this.themeColorTextPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 2 })
        }
        Text(this.summary.sourceName)
          .fontSize(LABEL_MEDIUM)
          .fontColor(this.themeColorAccent)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 2 })
        Text(this.chapterLabel())
          .fontSize(LABEL_SMALL_EMPHASIZED)
          .fontColor(this.themeColorTextSecondary)
          .maxLines(1)
          .width('100%')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: SPACE_12 })
    }
    .width('100%')
    .padding(SPACE_12)
    .backgroundColor(this.themeColorOnSheetContent)
    .borderRadius(12)
    .onClick(() => { this.onOpenBook(this.summary); })
  }
}

/** 单选圆点（本地没有 `AppRadioButton`，按 M3 单选钮的尺寸自绘：外圈 20、内点 10）。 */
@Component
struct ConflictRadio {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorOutlineVariant') themeColorOutlineVariant: string = '#C6C7D0';

  @Prop selected: boolean = false;

  onPick: () => void = () => {};

  build() {
    Column() {
      if (this.selected) {
        Column()
          .width(10)
          .height(10)
          .borderRadius(5)
          .backgroundColor(this.themeColorAccent)
      }
    }
    .width(20)
    .height(20)
    .borderRadius(10)
    .border({ width: 2, color: this.selected ? this.themeColorAccent : this.themeColorOutlineVariant })
    .justifyContent(FlexAlign.Center)
    .accessibilityText(this.selected ? '已选中' : '未选中')
    .onClick(() => { this.onPick(); })
  }
}

@Component
export struct BookshelfConflictSheet {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorOnPrimary') themeColorOnPrimary: string = '#FFFFFF';

  /** 空对象表示没有冲突（面板不出现）。 */
  @Prop conflict: BookshelfConflict = new BookshelfConflict();
  @Prop isResolving: boolean = false;

  onDismissRequest: () => void = () => {};
  onOpenExistingBook: (summary: ConflictBookSummary) => void = () => {};
  onCoexist: (existingBookUrl: string, options: ChangeSourceMigrationOptions) => void =
    (_url: string, _options: ChangeSourceMigrationOptions) => {};
  onMigrate: (existingBookUrl: string, options: ChangeSourceMigrationOptions) => void =
    (_url: string, _options: ChangeSourceMigrationOptions) => {};

  @State private options: ChangeSourceMigrationOptions = defaultMigrationOptions();
  @State private showOptions: boolean = false;
  @State private selectedBookUrl: string = '';

  /** 上游 `target = candidates.firstOrNull { it.bookUrl == selectedBookUrl } ?: candidates.first()`。 */
  private target(): ConflictBookSummary {
    const candidates = this.conflict.candidates;
    if (candidates.length === 0) { return new ConflictBookSummary(); }
    for (const candidate of candidates) {
      if (candidate.bookUrl === this.selectedBookUrl) { return candidate; }
    }
    return candidates[0];
  }

  private hasConflict(): boolean {
    return this.conflict.candidates.length > 0;
  }

  /**
   * 选项面板。
   *
   * 对齐上游 `BookshelfConflictSheet.kt:182-188`：
   * `ChangeSourceMigrationOptionsSheet(show = showOptions && conflict != null,
   *   title = stringResource(R.string.bookshelf_conflict_options_title),
   *   initialOptions = options, showDeleteDownloaded = false, onConfirm = { options = it; showOptions = false })`。
   * `showDeleteDownloaded = false` 的理由见上游注释：「共存场景两本书都留在书架，删缓存没有意义」。
   */
  @Builder
  OptionsPanel() {
    ChangeSourceMigrationOptionsSheet({
      title: '要携带的数据',
      subtitle: '',
      showDeleteDownloaded: false,
      initialOptions: this.options,
      onDismissRequest: () => { this.showOptions = false; },
      onConfirm: (options: ChangeSourceMigrationOptions) => {
        this.options = options;
        this.showOptions = false;
      }
    })
  }

  build() {
    Column() {
      Row() {
        Text('检测到可能重复的作品')
          .fontSize(TITLE_SMALL)
          .fontColor(this.themeColorTextPrimary)
          .layoutWeight(1)
        Row() {
          AppGlyph({ name: 'settings', glyphSize: 20, tint: this.themeColorTextSecondary })
        }
        .padding({ left: SPACE_12, right: SPACE_4 })
        .accessibilityText('设置')
        .onClick(() => { this.showOptions = true; })
      }
      .width('100%')
      .margin({ bottom: SPACE_8 })

      if (this.hasConflict()) {
        Text('书架中已有的作品')
          .fontSize(TITLE_SMALL)
          .fontColor(this.themeColorTextPrimary)
          .width('100%')
        Text('点击卡片查看该作品详情')
          .fontSize(BODY_SMALL)
          .fontColor(this.themeColorTextTertiary)
          .width('100%')

        List() {
          ForEach(this.conflict.candidates, (candidate: ConflictBookSummary) => {
            ListItem() {
              Row() {
                if (this.conflict.candidates.length > 1) {
                  ConflictRadio({
                    selected: candidate.bookUrl === this.target().bookUrl,
                    onPick: () => { this.selectedBookUrl = candidate.bookUrl; }
                  })
                  .margin({ right: SPACE_4 })
                }
                Column() {
                  ConflictBookCard({
                    summary: candidate,
                    onOpenBook: (summary: ConflictBookSummary) => {
                      this.onOpenExistingBook(summary);
                    }
                  })
                }
                .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .margin({ bottom: SPACE_8 })
            }
          }, (candidate: ConflictBookSummary) => candidate.bookUrl)
        }
        .width('100%')
        .constraintSize({ maxHeight: 320 })
        .scrollBar(BarState.Off)
        .margin({ top: SPACE_8 })

        Text('共存：把勾选的数据从已有作品复制到新加入的书。迁移：用勾选的数据以新书替换已有作品。')
          .fontSize(BODY_SMALL)
          .fontColor(this.themeColorTextTertiary)
          .width('100%')
          .margin({ top: SPACE_12 })

        if (this.isResolving) {
          Row() {
            LoadingProgress().width(28).height(28).color(this.themeColorAccent)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: SPACE_8 })
        } else {
          Row() {
            Text('共存')
              .fontSize(LABEL_LARGE)
              .fontColor(this.themeColorTextPrimary)
              .textAlign(TextAlign.Center)
              .constraintSize({ minWidth: 88 })
              .padding({ left: SPACE_16, right: SPACE_16, top: 10, bottom: 10 })
              .backgroundColor(this.themeColorSurfaceTertiary)
              .borderRadius(10)
              .onClick(() => { this.onCoexist(this.target().bookUrl, this.options); })
            Text('迁移')
              .fontSize(LABEL_LARGE)
              .fontColor(this.themeColorOnPrimary)
              .textAlign(TextAlign.Center)
              .constraintSize({ minWidth: 88 })
              .padding({ left: SPACE_16, right: SPACE_16, top: 10, bottom: 10 })
              .backgroundColor(this.themeColorAccent)
              .borderRadius(10)
              .margin({ left: SPACE_12 })
              .onClick(() => { this.onMigrate(this.target().bookUrl, this.options); })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .margin({ top: SPACE_8 })
        }
      }
    }
    .width('100%')
    .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_16, bottom: SPACE_12 })
    .alignItems(HorizontalAlign.Start)
    .bindSheet(this.showOptions && this.hasConflict(), this.OptionsPanel(), {
      backgroundColor: this.themeColorSurfaceTertiary,
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: false,
      onDisappear: () => { this.showOptions = false; }
    })
  }
}
