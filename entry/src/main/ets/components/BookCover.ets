import { Book, bookCoverColor, bookCoverMark } from '../model/Book';
import { BookRepository } from '../data/BookRepository';
import { CoverSettings, DEFAULT_COVER_SETTINGS } from '../data/CoverSettingsRepository';
import { buildCoverTextLayout } from './CoverTextLayout';
import { AppGlyph } from './AppGlyph';
import { BUILTIN_DEFAULT_COVER, CoverAlbumRepository } from '../data/CoverAlbumRepository';
import { ImageSeedColorExtractor } from '../data/ImageSeedColorExtractor';
import { NetworkProbe } from '../lib/NetworkProbe';
import { LABEL_SMALL } from './typography/TypographyTokens';

/** 无封面文字的绘制上下文；每个 BookCover 各持一份，避免多本共享导致互相覆盖。 */
const COVER_TEXT_CANVAS_SETTINGS: RenderingContextSettings = new RenderingContextSettings(true);

/**
 * 锁定态封面的模糊深度。
 *
 * 上游 `PrivateLockedContent.kt:54` `val PrivateLockedCoverBlurRadius: Dp = 20.dp`，
 * 书架卡片锁定态与详情页脱敏态共用这一个值——`:48-53` 的注释说明两端糊得不一样的话，
 * 共享元素转场飞到一半会看到一次「糊度跳变」。
 */
const LOCKED_COVER_BLUR_RADIUS: number = 20;
/** 上游 `BookItem.kt:703` `animateDpAsState(..., tween(320))`：模糊半径的过渡时长。 */
const LOCKED_BLUR_DURATION: number = 320;
/** 上游 `BookItem.kt:706-711` `animateFloatAsState(..., tween(260))`：遮罩淡入时长。 */
const LOCKED_OVERLAY_DURATION: number = 260;

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
  /** 未读章节数角标文字（网格卡专属，:118）。 */
  @Prop badgeText: string = '';
  /** 更新小红点（:119）。 */
  @Prop showBadgeDot: boolean = false;
  /**
   * 正在更新目录（上游 BookshelfCover.kt:123-136 的 `isUpdating`）。
   *
   * 为真时在封面底部画一条高 3vp 的不确定进度线：水平内边距 4、垂直 6、贴底居中。
   * 上游调用点传 `isUpdating && !locked`（BookItem.kt:781），锁定态不显示进度。
   */
  @Prop isUpdating: boolean = false;
  /**
   * 封面左下角的小字标签。
   *
   * 对应上游 BookshelfCover.kt:104-121 的 `leftBottomText`：`Alignment.BottomStart` +
   * `padding(2.dp)` + 圆角 4 + 内边距 4/2。上游调用点传 `matchedSourceLabel ?: bookTypeLabel`
   * （BookItem.kt:794），本地没有「搜索命中书源」这一态，只传书籍类型标签。
   */
  @Prop leftBottomText: string = '';
  // 角标与左下标签的配色，两处口径不同（上游 TextCard.kt:43-47）：
  // · 未读角标（BookshelfCover.kt:85-102）不传 backgroundColor/contentColor → 走 TextCard 默认值
  //   surfaceContainer / onSurface；
  // · 左下标签（BookshelfCover.kt:104-121）显式传 cardContainer / onCardContainer。
  // 本地 ThemePalette.ets:1158/1145/1163/1164 四档都写进了 AppStorage，所以按上游原值订阅，不再降级。
  @StorageProp('themeColorSurfaceContainer') themeColorSurfaceContainer: string = '#F1F2F6';
  @StorageProp('themeColorOnSurface') themeColorOnSurface: string = '#1B1C22';
  @StorageProp('themeColorCardContainer') themeColorCardContainer: string = '#F1F2F6';
  @StorageProp('themeColorOnCardContainer') themeColorOnCardContainer: string = '#3B4A7A';
  /** 更新进度线的前景色（上游 LinearProgressIndicator 用 M3 primary）。 */
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3B4A7A';
  /**
   * 私密锁定（:325）：为真时在封面上叠一层「锁 + 已加密」蒙层，遮住封面本身。
   * 判定（单本标记 ∪ 所属私密分组）留在调用方，组件只负责画：
   * 书架、详情页、目录页都在用这个组件，判定逻辑只能有一处。
   */
  /**
   * 私密书锁定态。
   *
   * F-6：上游 `BookItem.kt:702-711` 在锁定切换时给封面模糊与遮罩各做一条过渡动画
   * （模糊 320ms、遮罩 260ms），所以这里用 `@Watch` 监听，在回调里用 `animateTo` 复现。
   */
  @Prop @Watch('onLockedChanged') locked: boolean = false;
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
  /**
   * 是否按详情页口径夹取比例高度。
   *
   * 上游 `BookInfoCoverSizing.kt:17-19` 用 72dp 参考宽度把搜索列表的 80~140dp
   * 上下限等比换算到 112dp 宽（124.44~217.78dp），保证共享元素转场不形变。
   * 这里同样按当前宽度等比换算，不写死 112，其他宽度的调用点也能用。
   */
  @Prop clampAspectHeight: boolean = false;
  /** 无障碍朗读文本（：114）。不传时空串，读屏不播报这张封面。 */
  @Prop a11yText: string = '';
  /**
   * 共享元素键。非空时把这张封面登记为 `geometryTransition` 的一端。
   *
   * 对齐上游 `ui/main/BookCoverSharedElement.kt:17-20 bookCoverSharedElementKey`：
   * 键由 `data/BookCoverSharedElement.ets` 统一拼装，书架卡片与阅读页两端必须用同一个
   * 函数算，不能各写一遍字面量。空串表示这张封面不参与共享元素转场。
   *
   * ArkUI 的约束是「一个 id 只能绑定两个组件」（`common.d.ts:21406`），所以同一个键
   * 只允许出现在书架那一格与阅读页面板上；同一本书在多个分组页里键不同（键里带来源
   * 标识），不会互相抢锚点。
   */
  @Prop sharedKey: string = '';
  /**
   * 调用方指定的封面地址，非空时优先于书籍自身的显示封面。
   *
   * 第九表 B-4：上游编辑页画的是 `CoilBookCover(path = uiState.coverUrl, ...)`，
   * 即**编辑中的草稿值**而不是书籍当前落库值——换封面面板选完、或手工改「封面链接」后，
   * 预览要立刻跟着变。本地 `BookCover` 只读 `book`，草稿值进不去，故加这一层覆盖。
   * 空串表示不覆盖，仍按 `customCoverUri → coverUri` 的显示封面口径取。
   */
  @Prop @Watch('onCoverSourceChanged') overrideCoverUri: string = '';
  @State imageFailed: boolean = false;
  /** 封面原图宽高比（width / height）；异步读图后回填，0 表示读不到或不需要。 */
  @State coverAspectRatio: number = 0;
  /** 封面模糊半径：锁定态 20、解锁态 0，切换按 320ms 过渡（F-6）。 */
  @State lockedBlur: number = 0;
  /** 锁定遮罩不透明度：锁定态 1、解锁态 0，切换按 260ms 过渡（F-6）。 */
  @State lockOverlayAlpha: number = 0;
  /** 无封面文字的绘制上下文。 */
  private coverTextContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(COVER_TEXT_CANVAS_SETTINGS);

  aboutToAppear(): void {
    // F-6：首帧直接取终值，避免「本来就锁着」的卡片入屏时多播一次淡入。
    this.lockedBlur = this.locked ? LOCKED_COVER_BLUR_RADIUS : 0;
    this.lockOverlayAlpha = this.locked ? 1 : 0;
    this.refreshCoverAspectRatio();
  }

  /** coverSettings 变化（例如刚在设置页关掉 A8）或异步恢复完成后重算一次比例。 */
  /**
   * F-6：锁定态切换时补两条过渡动画。
   *
   * 上游是两个独立的 `animateDpAsState` / `animateFloatAsState`，时长不同（320 / 260），
   * 所以这里也分两次 `animateTo`，而不是塞进同一个动画块——否则两条会一起被拉成同一时长。
   */
  private onLockedChanged(): void {
    animateTo({ duration: LOCKED_BLUR_DURATION, curve: Curve.EaseInOut }, () => {
      this.lockedBlur = this.locked ? LOCKED_COVER_BLUR_RADIUS : 0;
    });
    animateTo({ duration: LOCKED_OVERLAY_DURATION, curve: Curve.EaseInOut }, () => {
      this.lockOverlayAlpha = this.locked ? 1 : 0;
    });
  }

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
   * A3「使用默认封面」打开时改取选中相册按 seed 选中的那张（对齐
   * `CoilBookCover.kt:144-150 getRandomDefaultPath(seed = name ?: author ?: path ?: "")`），
   * 相册没有可用图时返回空串、走「书本图标 + 书名」占位；关闭时用书籍自带图。
   */
  private effectiveCoverUri(): string {
    // 第九表 I-4 / J-6：先取「显示封面」，对齐上游 `Book.kt:183`
    // `getDisplayCover() = if (customCoverUrl.isNullOrEmpty()) coverUrl else customCoverUrl`。
    // 本地 `customCoverUri` 是用户自选的封面（编辑页改封面写这里），`coverUri` 是书源自带的原值；
    // 用户没改过时 customCoverUri 为空，自然回落到 coverUri。
    const customCover = this.book.customCoverUri;
    const displayUri: string | undefined = customCover !== undefined && customCover.length > 0
      ? customCover : this.book.coverUri;
    // 第九表 B-4：调用方给了草稿地址就用草稿（上游 `CoilBookCover(path = uiState.coverUrl)`），
    // 换封面面板选完立刻能在预览里看到，不必先保存。
    const draftUri: string = this.overrideCoverUri;
    const resolvedUri: string | undefined = draftUri.length > 0 ? draftUri : displayUri;
    // H2-1：`coverUri` 存的是上游的 `use_default_cover` 哨兵时（换封面面板选「默认封面」），
    // 与「设置里勾了使用默认封面」同口径，直接走内置封面图，不去加载这个假地址。
    if (resolvedUri === BUILTIN_DEFAULT_COVER) {
      const seed = this.book.title.length > 0
        ? this.book.title
        : this.book.author.length > 0 ? this.book.author : this.book.contentPath ?? '';
      return CoverAlbumRepository.defaultCoverPath(this.isNight, seed);
    }
    if (this.coverSettings.useDefaultCover) {
      // seed 口径照上游：书名优先，其次作者，最后封面路径（三者都空时是空串）。
      const seed = this.book.title.length > 0
        ? this.book.title
        : this.book.author.length > 0 ? this.book.author : (resolvedUri ?? '');
      return CoverAlbumRepository.defaultCoverPath(this.isNight, seed);
    }
    const uri = resolvedUri;
    if (uri === undefined) { return ''; }
    // 批3（r359）：「仅 WiFi 加载封面」（上游 CoverFetcher.kt:136
    // `if (loadOnlyWifi && !appCtx.isWifiConnect) throw IOException(...)` 同款判定）。
    // 开关打开且当前不在 WiFi 上时，不把网络封面交给 Image —— 回落默认封面或文字占位，
    // 与上游抛异常让 Coil 走错误兜底是同一个可见结果。
    // 本地图（沙箱路径、file://）不受开关影响，那是用户自己导入的封面。
    if (this.coverSettings.loadOnlyOnWifi && BookCover.isRemoteUri(uri) && !NetworkProbe.isOnWifi()) {
      return '';
    }
    return uri;
  }

  private static isRemoteUri(uri: string): boolean {
    return uri.startsWith('http://') || uri.startsWith('https://');
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
          // F-6：锁定态模糊真实封面（上游 `PrivateLockedContent.kt:165-169`
          // `Modifier.blur(blurRadius, BlurredEdgeTreatment.Unbounded)` 作用在封面图上），
          // 半径由 lockedBlur 带动画。
          .blur(this.lockedBlur)
          .onError(() => this.imageFailed = true)
      }
      if (!this.hasCoverImage()) {
        // 文字封面铺满整张封面：竖排/横排坐标由 buildCoverTextLayout 按画布宽高算，
        // 放进下面的 Column 会被 padding 与 SpaceBetween 压缩，所以单独挂一层。
        Canvas(this.coverTextContext)
          .width('100%')
          .height('100%')
          // F-6：文字封面也属于「封面图」，锁定态一并模糊。
          .blur(this.lockedBlur)
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
          .blur(this.lockedBlur)
      }
      Column() {
        if (this.showChapterBadge || BookRepository.isBodyMissing(this.book)
          || (this.badgeText.length === 0 && this.book.chapterCount !== undefined)) {
          Row() {
            if (BookRepository.isBodyMissing(this.book)) {
              Text('缺正文').fontSize(LABEL_SMALL).fontColor('#FFE0DC')
                .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                .backgroundColor('#8B3A3A').borderRadius(5)
            }
            Blank()
            if (this.badgeText.length === 0 && this.showChapterBadge && this.book.chapterCount !== undefined) {
              Text(this.book.chapterCount)
                .fontSize(LABEL_SMALL)
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
          }.width('100%').height(16)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 5, right: 5, top: 5, bottom: 5 })
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.SpaceBetween)
      // 未读角标：上游 BookshelfCover.kt:85-102 是 TextCard(text = 未读数, icon = 更新图标,
      // iconSize 12, align = TopEnd, padding 2, cornerRadius 4, hPadding 4, vPadding 2)，
      // 底色 surfaceContainer、字色 onSurface、字号 labelSmallEmphasized = 11sp Medium
      // （TextCard.kt:39-44 + Typography.kt:121/:38）。
      // 改前这里是暗红小胶囊（#C0504D / 8 号字 / 圆角 5），且「更新红点」是底部一个独立 8×8 圆点。
      // 现在按上游口径：数字在右上角，showBadgeDot 只决定数字左边加不加更新图标。
      //
      // 定位方式：外层 Stack 的 alignContent 只对「全尺寸子节点」生效，直接给角标挂 .align()
      // 是设置元素内容自身的对齐、不是父容器里的位置（实测角标落在封面正中）。所以套一层
      // 铺满封面的 Stack，由它的 alignContent 把角标推到右上角。
      if (this.badgeText.length > 0) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Row({ space: 4 }) {
            if (this.showBadgeDot) {
              AppGlyph({ name: 'profileRefresh', glyphSize: 12, tint: this.themeColorOnSurface })
            }
            Text(this.badgeText)
              .fontSize(LABEL_SMALL)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeColorOnSurface)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .padding({ left: 4, right: 4, top: 2, bottom: 2 })
          .backgroundColor(this.themeColorSurfaceContainer)
          .borderRadius(4)
        }
        .width('100%')
        .height('100%')
        // 角标只负责显示，点按要穿透到封面（书架格子靠外层 onClick 打开书籍）。
        .hitTestBehavior(HitTestMode.Transparent)
        // margin 2 对应上游的 `padding(2.dp)`。
        .padding({ top: 2, right: 2 })
      }
      // 左下角小标签：上游 BookshelfCover.kt:104-121 的 leftBottomText，形态与上面的角标同源
      // （TextCard、圆角 4、内边距 4/2），底色 cardContainer、字色 onCardContainer。
      if (this.leftBottomText.length > 0) {
        Stack({ alignContent: Alignment.BottomStart }) {
          Text(this.leftBottomText)
            .fontSize(LABEL_SMALL)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColorOnCardContainer)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 4, right: 4, top: 2, bottom: 2 })
            .backgroundColor(this.themeColorCardContainer)
            .borderRadius(4)
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
        .padding({ bottom: 2, left: 2 })
      }
      // 更新目录进度线：上游 BookshelfCover.kt:123-136 是
      // `AppLinearProgressIndicator(align(BottomCenter).fillMaxWidth().padding(horizontal 4, vertical 6).height(3))`，
      // 未传 progress 即「不确定态」（AppLinearProgressIndicator.kt:21-30 走无参 LinearProgressIndicator）。
      // ArkUI 的 Progress 没有 indeterminate 形态，用 `enableScanEffect` 的扫描效果等效：
      // 固定 value 只决定扫描带的基准位置，视觉上是一条来回扫的 3vp 高细线。
      if (this.isUpdating) {
        Row() {
          Progress({ value: 30, total: 100, type: ProgressType.Linear })
            .width('100%')
            .height(3)
            .color(this.themeColorAccent)
            .backgroundColor('#1F000000')
            .style({ strokeWidth: 3, enableScanEffect: true, enableSmoothEffect: true })
        }
        .width('100%')
        .height(15)
        .padding({ left: 4, right: 4, top: 6, bottom: 6 })
        .hitTestBehavior(HitTestMode.Transparent)
        // 贴底居中：外层 Stack 的 alignContent 是 Center，这里单独指定位置。
        .align(Alignment.Bottom)
      }
      // 私密遮罩盖在封面与角标之上（:325）：锁图标 +「已加密」，不是单纯压暗。
      // F-6：上游 `BookItem.kt:706-711` 的 `lockOverlayAlpha` 是常驻渲染 + 透明度动画，
      // 所以这里不再用 `if (this.locked)` 硬切，而是始终挂载、由 lockOverlayAlpha 控制可见度
      // （锁定淡入、解锁淡出，都是 260ms）。
      Column() {
        AppGlyph({ name: 'lock', glyphSize: 20, tint: '#E6E7EC' })
        Text('已加密').fontSize(LABEL_SMALL).fontColor('#C4C9D7').margin({ top: 3 })
      }.width('100%').height('100%')
      .backgroundColor('#D915161B')
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .opacity(this.lockOverlayAlpha)
      // 完全透明时不参与命中测试，避免解锁后的卡片被这层吃掉点击。
      .hitTestBehavior(this.lockOverlayAlpha > 0 ? HitTestMode.Default : HitTestMode.None)
    }
    .width(this.coverWidth())
    .height(this.coverHeight())
    .backgroundColor(bookCoverColor(this.book))
    .borderRadius(this.cornerRadius)
    // 半径 4 对齐上游 `CoilBookCover.kt:388` 的 `Modifier.shadow(4.dp, shape)`：
    // 上游封面阴影只有一个 4.dp 值，没有第二档。
    .shadow(this.shadowEnabled
      ? { radius: 4, color: '#66000000', offsetX: 0, offsetY: 2 }
      : { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 })
    // 共享元素源端：空串按 `common.d.ts:21406` 的文档语义解除绑定，所以不需要 if 包裹。
    .geometryTransition(this.sharedKey)
    .accessibilityText(this.a11yText)
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
        const derived = width / this.coverAspectRatio;
        if (this.clampAspectHeight) {
          // 上游 80/72 ~ 140/72 的换算比，按当前宽度等比缩放。
          return Math.round(Math.max(width * 80 / 72, Math.min(width * 140 / 72, derived)));
        }
        return Math.round(derived);
      }
    }
    if (!this.fillWidth) {
      if (this.displayHeight > 0) {
        return this.displayHeight;
      }
      const fallbackWidth = this.coverWidth();
      if (this.clampAspectHeight && typeof fallbackWidth === 'number') {
        // 读不到原图比例时上游用默认 5:7（112dp 宽 → 156.8dp），不再写死 157。
        return Math.round(fallbackWidth * 7 / 5);
      }
      return this.mini ? 68 : this.compact ? 100 : 128;
    }
    return this.maxWidth > 0 ? Math.round(this.maxWidth * 7 / 5) : '100%';
  }
}
