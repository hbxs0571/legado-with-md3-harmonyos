import { Book } from '../model/Book';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../data/CoverSettingsRepository';
import { BookCover } from './BookCover';
import { AppGlyph } from './AppGlyph';

/**
 * 分组卡片：书架「文件夹」样式根层每个分组一张卡。
 *
 * 对齐上游 BookItem.kt 的 BookGroupItemList / BookGroupItemHorizontalCovers：
 * - bookshelfGroupListStyle == 2 → 横排封面数量，按 coverCount 取前 N 本，不足补空位；
 * - == 1 → 紧凑列表（较小封面）；
 * - == 0 → 普通分组（单张封面 + 分组名 + 书籍数）。
 * 点击整卡回调 onOpen，由书架页进入该分组。
 */
@Component
export struct BookGroupCard {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @Prop groupName: string = '';
  @Prop books: Book[] = [];
  @Prop coverCount: number = 4;
  @Prop listStyle: number = 0;
  @Prop coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  @Prop isNight: boolean = false;
  /** 列表封面宽度，来自书架布局 bookshelfListCoverWidth（:187）。 */
  @Prop listCoverWidth: number = 84;
  /** 是否显示书籍计数（：106）；对应书架布局 showBookCount，关闭后两处「N 本」都不画。 */
  @Prop showCount: boolean = true;
  /**
   * 私密锁定（:257）：锁定时三件事同时做——不画封面预览、不显示计数、组名旁加锁图标。
   * 上游 countText 的条件正是 `showBookCount && !groupLocked`，所以计数两处都要与它取与。
   */
  @Prop locked: boolean = false;
  onOpen: () => void = () => {};
  /** 长按分组卡直接进该分组的编辑面板（:107，上游 GroupEditSheet 入口）。 */
  onLongPress: (groupName: string) => void = (_groupName: string) => {};

  /** 取前 coverCount 本作预览封面，与上游 previewBooks.take(coverCount) 一致。 */
  private previewBooks(): Book[] {
    // 锁定时一份预览都不给：从封面缩略图上认出是哪本书，等于没锁（:257）。
    if (this.locked) { return []; }
    const count = Math.max(0, Math.round(this.coverCount));
    return this.books.slice(0, count);
  }

  /** 不足 coverCount 时空位个数，上游用 repeat + Spacer 补右侧留空。 */
  private emptySlots(): number[] {
    // 锁定时可见预览为 0，空位也补 0：一排空框本身就宣告了「这个分组有几本书」。
    const visible = this.locked ? 0 : this.books.length;
    const count = Math.max(0, Math.round(this.coverCount) - visible);
    const slots: number[] = [];
    for (let index = 0; index < count; index += 1) { slots.push(index); }
    return slots;
  }

  build() {
    Column() {
      Row() {
        if (this.locked) {
          AppGlyph({ name: 'lock', glyphSize: 13, tint: this.themeColorTextTertiary }).margin({ right: 4 })
        }
        Text(this.groupName).fontSize(14).fontColor(this.themeColorTextSecondary).layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.showCount && !this.locked) {
          Text(`${this.books.length} 本`).fontSize(11).fontColor(this.themeColorTextTertiary)
        }
        Text('›').fontSize(16).fontColor(this.themeColorAccent).margin({ left: 4 })
      }.width('100%').padding({ left: 8, right: 8, top: 8, bottom: 8 })

      if (this.listStyle === 2) {
        // 横排封面数量：先画实际预览封面，再把不足的空位补成等宽占位（右侧留空）。
        Row() {
          ForEach(this.previewBooks(), (book: Book) => {
            Column() {
              BookCover({
                book: book,
                compact: true,
                displayWidth: Math.round(this.listCoverWidth * 44 / 84),
                displayHeight: Math.round(this.listCoverWidth * 62 / 84),
                cornerRadius: 4,
                coverSettings: this.coverSettings,
                isNight: this.isNight
              })
            }.layoutWeight(1).alignItems(HorizontalAlign.Center)
          }, (book: Book) => `cover_${book.id}`)
          ForEach(this.emptySlots(), (index: number) => {
            Row().layoutWeight(1);
          }, (index: number) => `empty_${index}`)
        }.width('100%').padding({ left: 8, right: 8, bottom: 10 })
      } else {
        // 普通分组 / 紧凑列表：单张封面 + 分组样式说明 + 书籍数。
        Row() {
          if (this.books.length > 0 && !this.locked) {
            BookCover({
              book: this.books[0],
              compact: this.listStyle === 1,
              displayWidth: this.listCoverWidth,
              displayHeight: Math.round(this.listCoverWidth * 7 / 5),
              cornerRadius: 5,
              coverSettings: this.coverSettings,
              isNight: this.isNight
            })
          }
          Column() {
            Text(this.listStyle === 1 ? '紧凑列表' : '分组').fontSize(11).fontColor(this.themeColorTextTertiary)
            if (this.showCount && !this.locked) {
              Text(`共 ${this.books.length} 本`).fontSize(11).fontColor(this.themeColorTextTertiary)
            }
          }.alignItems(HorizontalAlign.Start).layoutWeight(1).padding({ left: 10 })
        }.width('100%').alignItems(VerticalAlign.Top).padding({ left: 8, right: 8, bottom: 10 })
      }
    }
    .width('100%')
    .padding(4)
    .backgroundColor(this.themeColorSurfaceElevated)
    .borderRadius(8)
    .onClick(() => { this.onOpen(); })
    .gesture(LongPressGesture({ duration: 500 }).onAction(() => { this.onLongPress(this.groupName); }))
  }
}
