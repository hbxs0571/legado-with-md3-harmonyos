import { Book, bookCoverColor, bookCoverMark } from '../model/Book';
import { BookRepository } from '../data/BookRepository';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../data/CoverSettingsRepository';
import { buildCoverTextLayout } from './CoverTextLayout';
import { AppGlyph } from './AppGlyph';
import { CoverAlbumRepository } from '../data/CoverAlbumRepository';
import { ImageSeedColorExtractor } from '../data/ImageSeedColorExtractor';

/** 无封面文字的绘制上下文；每个 BookCover 各持一份，避免多本共享导致互相覆盖。 */
const COVER_TEXT_CANVAS_SETTINGS: RenderingContextSettings = new RenderingContextSettings(true);

@Component
export struct BookCover {
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0, isLocal: true
  };
  @Prop compact: boolean = false;
  @Prop mini: boolean = false;
  @Prop displayWidth: number = 0;
  @Prop displayHeight: number = 0;
  @Prop cornerRadius: number = 7;
  @Prop showChapterBadge: boolean = false;
  /** 书封阴影，对应上游 bookshelfCoverShadow。 */
  @Prop shadowEnabled: boolean = false;
  /**
   * 宽度铺满父容器。
   *
   * 对应上游 BookItem.kt:269-273 的 fillMaxWidth().aspectRatio(5f / 7f)：
   * 书架网格里封面宽度由格子决定，高度按 5:7 推导，不再用固定 px。
   * 其他调用点（列表、详情页、目录页）保持固定尺寸，不传即沿用旧行为。
   */
  @Prop fillWidth: boolean = false;
  /**
   * 铺满模式下的宽度上限（vp），0 表示不设上限。
   *
   * 对应上游 bookshelfGridCoverWidth：用户可调小让封面变窄，
   * 但格子更宽时封面不该继续放大，所以取「格子宽 - 内边距」与它的小值。
   */
  @Prop maxWidth: number = 0;
  /**
   * 封面文字设置。
   *
   * 由页面把 CoverSettingsRepository.get() 的结果传下来；不传时用默认值，
   * 保证详情页、目录页这些次要调用点不用改也能正常显示书名。
   */
  @Prop @Watch('onCoverSourceChanged') coverSettings: CoverSettings = DEFAULT_COVER_SETTINGS;
  /** 当前是否夜间，决定用哪一套文字色与显示开关。 */
  @Prop isNight: boolean = false;
  /**
   * 是否按 A8「限制封面比例」推导高度。
   *
   * 上游只在搜索/发现/书籍详情页生效（CoverSettings.kt:6-10 的注释），书架网格恒固定 5:7，
   * 所以只有那几处调用点传 true，书架页不传、沿用默认值 false。
   */
  @Prop applyAspectRatio: boolean = false;
  @State imageFailed: boolean = false;
  /** 封面原图宽高比（width / height）；异步读图后回填，0 表示读不到或不需要。 */
  @State coverAspectRatio: number = 0;
  /** 无封面文字的绘制上下文。 */
  private coverTextContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(COVER_TEXT_CANVAS_SETTINGS);

  aboutToAppear(): void {
    this.refreshCoverAspectRatio();
  }

  /** coverSettings 变化（例如刚在设置页关掉 A8）或异步恢复完成后重算一次比例。 */
  private onCoverSourceChanged(): void {
    this.refreshCoverAspectRatio();
  }

  /** A8 关闭且调用点受该开关约束时，异步读原图宽高比；读不到就回落固定 5:7。 */
  private refreshCoverAspectRatio(): void {
    if (!this.applyAspectRatio || this.coverSettings.restrictCoverRatio) {
      this.coverAspectRatio = 0;
      return;
    }
    const uri = this.effectiveCoverUri();
    if (uri.length === 0) {
      this.coverAspectRatio = 0;
      return;
    }
    ImageSeedColorExtractor.coverAspectRatio(uri).then((ratio: number) => {
      this.coverAspectRatio = ratio;
    });
  }

  /**
   * 实际要显示的封面图路径。
   *
   * A3「使用默认封面」打开时改取选中相册的默认图（对齐 model/BookCover.kt:125 的
   * useDefaultCover 分支），没有相册图就返回空串、走文字占位；关闭时用书籍自带图。
   */
  private effectiveCoverUri(): string {
    if (this.coverSettings.useDefaultCover) {
      return CoverAlbumRepository.defaultCoverPath(this.isNight);
    }
    const uri = this.book.coverUri;
    return uri === undefined ? '' : uri;
  }

  private hasCoverImage(): boolean {
    return this.effectiveCoverUri().length > 0 && !this.imageFailed;
  }

  // 夜间书名/作者开关由 CoverTextLayout.buildCoverTextLayout 按 isNight 取 *Dark 一组判断。

  /**
   * 无封面文字的颜色。
   *
   * 对应上游 CoilBookCover.kt:526-532：useDefaultColor 时用主题 secondary 色，
   * 否则用日间/夜间各自的 textColor。本地没有 secondary 语义色，
   * 默认色取封面底色上对比度稳定的浅色。
   */
  private coverTextColor(): string {
    if (this.coverSettings.useDefaultColor) { return '#F1F2F6'; }
    return this.isNight ? this.coverSettings.textColorDark : this.coverSettings.textColor;
  }

  private coverShadowColor(): string {
    return this.isNight ? this.coverSettings.shadowColorDark : this.coverSettings.shadowColor;
  }

  /**
   * 无封面时居中书本图标的边长。
   *
   * 上游 CoilBookCover.kt:213-217 用 fillMaxSize(0.35f) 取封面的 35%。
   * 这里封面尺寸可能是 '100%'（由父容器决定），所以按已知宽高算，
   * 拿不到时按常规书架封面宽度 92vp 估算。
   */
  private coverIconSize(): number {
    const width = this.displayWidth > 0
      ? this.displayWidth
      : this.maxWidth > 0 ? this.maxWidth : this.compact ? 70 : 92;
    return Math.max(16, Math.round(width * 0.35));
  }

  /**
   * 画无封面时的书名与作者。
   *
   * 上游用 Canvas 逐字绘制（CoilBookCover.kt:512-700），本地同样走 Canvas：
   * 在 ArkUI 里堆几十个 Text 拼竖排会让书架滚动明显掉帧。
   *
   * 画布坐标与 context.width/height 都是 vp，但 font 字符串里的 px 是物理像素，
   * 两者差一个 density（本机 3.47 倍）。排版按 vp 算，写 font 时再经 vp2px() 换算。
   */
  private paintCoverText(): void {
    const widthVp = this.coverTextContext.width;
    const heightVp = this.coverTextContext.height;
    if (widthVp <= 0 || heightVp <= 0) { return; }
    const context = this.coverTextContext;
    context.clearRect(0, 0, widthVp, heightVp);
    if (this.hasCoverImage()) { return; }
    const layout = buildCoverTextLayout(
      widthVp, heightVp, this.book.title, this.book.author, this.coverSettings, 1.2, this.isNight);
    if (layout.glyphs.length === 0) { return; }
    const fillColor = this.coverTextColor();
    context.textAlign = 'center';
    context.textBaseline = 'alphabetic';
    for (const glyph of layout.glyphs) {
      // 排版坐标是 vp，font 的 px 是物理像素，这里换算一次
      const fontSizePx = Math.max(1, Math.round(vp2px(glyph.fontSize)));
      context.font = glyph.bold
        ? `bold ${fontSizePx}px sans-serif`
        : `${fontSizePx}px sans-serif`;
      // 上游 showStroke 默认 true：先描白边再填字，深色底上更清晰。
      // 描边宽度与坐标同为 vp 量纲，所以用 glyph.fontSize（vp）而不是换算后的像素值，
      // 否则描边会粗一个 density 倍，字糊成一团。
      if (this.coverSettings.showStroke) {
        context.strokeStyle = '#FFFFFF';
        context.lineWidth = Math.max(1, glyph.fontSize / 10);
        context.strokeText(glyph.text, glyph.x, glyph.y);
      }
      // 上游 showShadow 默认 false：开启时给填充加一层阴影
      if (this.coverSettings.showShadow) {
        context.shadowBlur = 4;
        context.shadowOffsetX = 2;
        context.shadowOffsetY = 2;
        context.shadowColor = this.coverShadowColor();
      } else {
        context.shadowBlur = 0;
        context.shadowOffsetX = 0;
        context.shadowOffsetY = 0;
      }
      context.fillStyle = fillColor;
      context.fillText(glyph.text, glyph.x, glyph.y);
    }
    // 阴影是「粘性」的，画完要复位，否则后续重绘会带上上一次的阴影
    context.shadowBlur = 0;
    context.shadowOffsetX = 0;
    context.shadowOffsetY = 0;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.hasCoverImage()) {
        Image(this.effectiveCoverUri())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .borderRadius(this.cornerRadius)
          .onError(() => this.imageFailed = true)
      }
      if (!this.hasCoverImage()) {
        // 文字封面铺满整张封面：竖排/横排坐标由 buildCoverTextLayout 按画布宽高算，
        // 放进下面的 Column 会被 padding 与 SpaceBetween 压缩，所以单独挂一层。
        Canvas(this.coverTextContext)
          .width('100%')
          .height('100%')
          .onReady(() => {
            // 画布尺寸只有 onReady 之后才确定，这时 context.width/height 就是像素值
            this.paintCoverText();
          })
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            // 书架切列数/改封面宽度时画布尺寸会变，需要按新尺寸重画。
            // 这里只当触发信号用：Area 是 vp，真正的像素尺寸仍从 context 取。
            const width = parseFloat(String(newArea.width));
            const height = parseFloat(String(newArea.height));
            if (!Number.isFinite(width) || !Number.isFinite(height)) { return; }
            this.paintCoverText();
          })
        // 上游 CoilBookCover.kt:210-218：没有封面图时居中叠一个书本图标，
        // 占封面 35% 大小，色取主题 secondary（本地用固定的浅灰）。
        AppGlyph({ name: 'book', tint: '#8B90A0', glyphSize: this.coverIconSize() })
      }
      Column() {
        if (this.showChapterBadge || BookRepository.isBodyMissing(this.book)) {
          Row() {
            if (BookRepository.isBodyMissing(this.book)) {
              Text('缺正文').fontSize(8).fontColor('#FFE0DC')
                .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                .backgroundColor('#8B3A3A').borderRadius(5)
            }
            Blank()
            if (this.showChapterBadge && this.book.chapterCount !== undefined) {
              Text(this.book.chapterCount)
                .fontSize(8)
                .fontColor('#E6E7EC')
                .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                .backgroundColor('#15161BCC')
                .borderRadius(5)
            }
          }.width('100%').height(14)
        }
        // 上下两个 Blank 把书签图标压到底部，与上游 SpaceBetween 的效果一致
        Blank()
        Blank()
        if (this.showChapterBadge) {
          Row() {
            AppGlyph({ name: 'bookmark', tint: '#C4C9D7', glyphSize: 16 })
            Blank()
          }.width('100%').height(16)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 5, right: 5, top: 5, bottom: 5 })
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width(this.coverWidth())
    .height(this.coverHeight())
    .backgroundColor(bookCoverColor(this.book))
    .borderRadius(this.cornerRadius)
    .shadow(this.shadowEnabled
      ? { radius: 6, color: '#66000000', offsetX: 0, offsetY: 2 }
      : { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 })
  }

  /**
   * 封面宽度。
   *
   * 铺满模式返回 '100%' 交给父容器（书架格子），有上限时改用 maxWidth 数值；
   * 其余调用点沿用原来的固定尺寸，避免连带改动列表与详情页。
   */
  private coverWidth(): Length {
    if (!this.fillWidth) {
      return this.displayWidth > 0 ? this.displayWidth : this.mini ? 48 : this.compact ? 70 : 92;
    }
    return this.maxWidth > 0 ? this.maxWidth : '100%';
  }

  /**
   * 封面高度。
   *
   * 铺满模式按上游 BookItem.kt:271 的 aspectRatio(5f / 7f) 由宽度推导高度：
   * 宽度受限时直接算像素高度，宽度交给父容器时返回 '100%'，
   * 由外层 aspectRatio 兜住比例。
   */
  private coverHeight(): Length {
    // A8「限制封面比例」关闭时，搜索/详情/发现页按原图宽高比推导高度。
    // 读不到原图比例（coverAspectRatio === 0）时回落到下面的固定 5:7，与上游读图失败一致。
    if (this.applyAspectRatio && !this.coverSettings.restrictCoverRatio && this.coverAspectRatio > 0) {
      const width = this.coverWidth();
      if (typeof width === 'number') {
        return Math.round(width / this.coverAspectRatio);
      }
    }
    if (!this.fillWidth) {
      return this.displayHeight > 0 ? this.displayHeight : this.mini ? 68 : this.compact ? 100 : 128;
    }
    return this.maxWidth > 0 ? Math.round(this.maxWidth * 7 / 5) : '100%';
  }
}
