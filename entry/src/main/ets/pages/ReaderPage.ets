import { Book } from '../model/Book';
import { LocalTextSemantics } from '../data/LocalTextSemantics';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { BookCover } from '../components/BookCover';
import image from '@ohos.multimedia.image';
import { LocalReaderLine, LocalReaderLineItem, LocalReaderPage, LocalReaderPaginator } from './LocalReaderPaginator';
import {
  ReaderBottomActionConfig, READER_LOCAL_BOTTOM_ACTION_DEFAULTS, READER_LOCAL_TOP_ACTION_DEFAULTS
} from '../data/ReaderSettingsRepository';

type ReaderControlKind = 'search' | 'autoPage' | 'catalog' | 'voice' | 'settings';
interface ReaderMoreAction {
  id: string;
  label: string;
  glyph: AppGlyphName;
}

const READER_LOCAL_MORE_ACTIONS: ReaderMoreAction[] = [
  { id: 'audioDownload', label: '听书下载', glyph: 'download' },
  { id: 'editContent', label: '编辑内容', glyph: 'edit' },
  { id: 'bookmark', label: '添加书签', glyph: 'bookmark' },
  { id: 'textProcessing', label: '文本处理', glyph: 'profileFindReplace' },
  { id: 'reverse', label: '反转内容', glyph: 'swap' },
  { id: 'reSegment', label: '重新分段', glyph: 'list' },
  { id: 'deleteRuby', label: '删除ruby标签', glyph: 'delete' },
  { id: 'deleteHeading', label: '删除h标签', glyph: 'delete' }
];
const READER_CHARSETS: string[] = ['UTF-8', 'GB2312', 'GB18030', 'GBK', 'Unicode', 'UTF-16', 'UTF-16LE', 'UTF-16BE', 'ASCII'];

interface ReaderContentSegment {
  kind: 'text' | 'image';
  value: string;
}

interface ReaderIntrinsicImageSize {
  width: number;
  height: number;
}

@Component
export struct ReaderPage {
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0,
    coverColor: '#000000', coverMark: '书', isLocal: true
  };
  @Prop @Watch('onChapterTitleChanged') chapterTitle: string = '';
  @Prop @Watch('onReaderContentChanged') content: string = '';
  @Prop @Watch('onPaginationInputsChanged') fontSize: number = 19;
  @Prop @Watch('onProgressBehaviorChanged') progressBehavior: string = 'page';
  @Prop @Watch('onImageStyleChanged') imageStyle: string = 'DEFAULT';
  @Prop paperColor: string = '#000000';
  @Prop showQuickActions: boolean = false;
  @Prop showBottomActionText: boolean = true;
  @Prop bottomIconStyle: number = 1;
  @Prop bottomItemsPerRow: number = 5;
  @Prop bottomRowCount: number = 1;
  @Prop bottomActions: ReaderBottomActionConfig[] = READER_LOCAL_BOTTOM_ACTION_DEFAULTS;
  @Prop topActions: ReaderBottomActionConfig[] = READER_LOCAL_TOP_ACTION_DEFAULTS;
  @State controlsVisible: boolean = false;
  @State overflowVisible: boolean = false;
  @State imageStyleMenuVisible: boolean = false;
  @State charsetDialogVisible: boolean = false;
  @State charsetOptionsExpanded: boolean = false;
  @State charsetInput: string = 'UTF-8';
  @State activeImageStyle: string = 'DEFAULT';
  @State readerProgress: number = 0;
  @State sliderProgressIndex: number = 0;
  @State contentHeight: number = 0;
  @State estimatedContentHeight: number = 0;
  @State viewportHeight: number = 0;
  @State readerContentWidth: number = 0;
  @State readerContentRevision: number = 0;
  @State imageSizes: Map<string, ReaderIntrinsicImageSize> = new Map<string, ReaderIntrinsicImageSize>();
  @State scrollOffset: number = 0;
  @State lastReportedProgress: number = -1;
  @State restoredProgressPosition: boolean = false;
  @State localReaderPages: LocalReaderPage[] = [];
  @State localSemanticContent: string = '';
  @State currentPageIndex: number = 0;
  @State autoPageActive: boolean = false;
  @State autoPageSettingsVisible: boolean = false;
  @State autoPageSecondsRemaining: number = 10;
  @State autoPageWaitingForChapter: boolean = false;
  @State currentBottomActionPage: number = 0;
  @Prop autoReadSpeedSeconds: number = 10;
  private autoPageTimer: number = -1;
  private readerScroller: Scroller = new Scroller();
  onBack: () => void = () => {};
  onOpenCatalog: () => void = () => {};
  onOpenSettings: () => void = () => {};
  onCharsetChange: (charset: string) => void = (_charset: string) => {};
  onOpenSearchContent: () => void = () => {};
  onOpenReadAloud: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  onImageStyleChange: (imageStyle: string) => void = (_imageStyle: string) => {};
  onProgressChange: (progress: number, chapterPosition: number) => void = () => {};
  onSelectChapterIndex: (chapterIndex: number) => void = () => {};
  onTurnChapterBoundary: (delta: number) => void = (_delta: number) => {};
  onAutoReadSpeedChange: (seconds: number) => void = (_seconds: number) => {};

  aboutToAppear(): void {
    this.activeImageStyle = this.imageStyle;
    this.readerProgress = this.book.chapterProgress ?? 0;
    this.lastReportedProgress = this.readerProgress;
    this.sliderProgressIndex = this.getChapterIndex();
    this.loadContentImageSizes();
    this.autoPageSecondsRemaining = this.autoReadSpeedSeconds;
  }

  aboutToDisappear(): void {
    this.stopAutoPageTimer();
  }

  private stopAutoPageTimer(): void {
    if (this.autoPageTimer >= 0) {
      clearInterval(this.autoPageTimer);
      this.autoPageTimer = -1;
    }
  }

  private toggleAutoPage(): void {
    if (this.autoPageActive) {
      this.autoPageSettingsVisible = true;
      return;
    }
    this.autoPageActive = true;
    this.autoPageSecondsRemaining = this.autoReadSpeedSeconds;
    this.stopAutoPageTimer();
    this.autoPageTimer = setInterval(() => {
      if (!this.autoPageActive || this.controlsVisible || this.autoPageSettingsVisible ||
        this.autoPageWaitingForChapter) { return; }
      this.autoPageSecondsRemaining = Math.max(0, this.autoPageSecondsRemaining - 1);
      if (this.autoPageSecondsRemaining <= 0) {
        if (this.localReaderPages.length > 0 && this.currentPageIndex < this.localReaderPages.length - 1) {
          this.turnReaderPage(1);
        } else if (this.getChapterIndex() < this.getChapterCount() - 1) {
          this.autoPageWaitingForChapter = true;
          this.onTurnChapterBoundary(1);
        } else {
          this.autoPageActive = false;
        }
        this.autoPageSecondsRemaining = this.autoReadSpeedSeconds;
      }
    }, 1000);
  }

  private setAutoPageSpeed(seconds: number): void {
    const value = Math.max(1, Math.min(120, Math.round(seconds)));
    this.autoPageSecondsRemaining = value;
    this.onAutoReadSpeedChange(value);
  }

  onChapterTitleChanged(): void {
    this.autoPageWaitingForChapter = false;
    this.readerProgress = this.book.chapterProgress ?? 0;
    this.lastReportedProgress = this.readerProgress;
    this.sliderProgressIndex = this.getChapterIndex();
    this.restoredProgressPosition = false;
    this.contentHeight = 0;
    this.estimatedContentHeight = 0;
    this.scrollOffset = 0;
    try {
      this.readerScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
    } catch (_) {
    }
    this.rebuildReaderPages();
  }

  onReaderContentChanged(): void {
    this.readerContentRevision++;
    this.imageSizes = new Map<string, ReaderIntrinsicImageSize>();
    this.contentHeight = 0;
    this.estimatedContentHeight = 0;
    this.scrollOffset = 0;
    this.restoredProgressPosition = false;
    this.currentPageIndex = 0;
    this.localReaderPages = [];
    this.localSemanticContent = '';
    this.refreshEstimatedContentHeight();
    this.loadContentImageSizes();
    this.rebuildReaderPages();
    try {
      this.readerScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
    } catch (_) {
    }
  }

  onPaginationInputsChanged(): void {
    this.rebuildReaderPages();
  }

  onProgressBehaviorChanged(): void {
    this.sliderProgressIndex = this.progressBehavior === 'page' && this.localReaderPages.length > 0
      ? this.currentPageIndex : this.getChapterIndex();
  }

  onImageStyleChanged(): void {
    this.activeImageStyle = this.imageStyle;
    this.readerContentRevision++;
    this.rebuildReaderPages();
  }

  private imageStyleLabel(style: string): string {
    if (style === 'FULL') { return '全屏'; }
    if (style === 'TEXT') { return '文字嵌入'; }
    if (style === 'SINGLE') { return '单页'; }
    return '默认';
  }

  private chooseImageStyle(style: string): void {
    this.activeImageStyle = style;
    this.readerContentRevision++;
    this.rebuildReaderPages();
    this.onImageStyleChange(style);
    this.imageStyleMenuVisible = false;
    this.overflowVisible = false;
  }

  private openCharsetDialog(): void {
    this.charsetInput = this.book.charset ?? 'UTF-8';
    this.charsetOptionsExpanded = false;
    this.charsetDialogVisible = true;
  }

  private applyCharset(): void {
    this.charsetDialogVisible = false;
    this.charsetOptionsExpanded = false;
    this.onCharsetChange(this.charsetInput);
  }

  private rebuildReaderPages(): void {
    if ((this.book.format !== 'txt' && this.book.format !== 'epub') ||
      this.readerContentWidth <= 0 || this.viewportHeight <= 0) {
      this.localReaderPages = [];
      return;
    }
    const context = this.getUIContext();
    const measureUtils = context.getMeasureUtils();
    const fontSize = this.fontSize * 1.05;
    const width = Math.max(1, this.readerContentWidth - 40);
    const lineHeight = this.fontSize * 1.25;
    const pageHeight = Math.max(lineHeight, this.viewportHeight - 11);
    // 当前 Android 书籍配置 paragraphSpacing=6，原版按行高的十分之六计算段距。
    const paragraphSpacing = lineHeight * 0.6;
    const document = LocalTextSemantics.parse(this.content);
    this.localSemanticContent = document.content;
    for (let paragraphIndex = 0; paragraphIndex < document.paragraphs.length; paragraphIndex++) {
      const paragraph = document.paragraphs[paragraphIndex];
      if (paragraph === undefined) { continue; }
      for (let partIndex = 0; partIndex < paragraph.parts.length; partIndex++) {
        const part = paragraph.parts[partIndex];
        if (part?.kind === 'image' && !this.imageSizes.has(part.value)) {
          this.localReaderPages = [];
          return;
        }
      }
    }
    const titleMetrics = measureUtils.measureTextSize({
      textContent: this.chapterTitle,
      fontSize: this.fontSize + 4
    });
    const titleWidth = context.px2vp(this.toDimension(titleMetrics.width ?? 0));
    const titleLines = this.chapterTitle.length > 0 ? Math.max(1, Math.ceil(titleWidth / width)) : 0;
    const titleReservedLines = Math.ceil((titleLines * (this.fontSize + 4) * 1.25 + 12) / lineHeight);
    const paginatedPages = LocalReaderPaginator.paginate(
      document,
      width,
      pageHeight,
      lineHeight,
      paragraphSpacing,
      (text: string): number => {
        const measured = measureUtils.measureTextSize({ textContent: text, fontSize: fontSize });
        return context.px2vp(this.toDimension(measured.width ?? 0));
      },
      this.imageSizes,
      this.activeImageStyle,
      context.px2vp(80),
      context.px2vp(this.toDimension(measureUtils.measureTextSize({ textContent: '袮', fontSize: fontSize }).width ?? 0)),
      this.activeImageStyle === 'SINGLE' ? 0 : titleReservedLines
    );
    this.localReaderPages = [];
    const titlePageInserted = this.activeImageStyle === 'SINGLE' && this.chapterTitle.length > 0;
    if (titlePageInserted) {
      this.localReaderPages.push({ lines: [], startPosition: 0, endPosition: 0, titleOnly: true });
    }
    for (let pageIndex = 0; pageIndex < paginatedPages.length; pageIndex++) {
      const page = paginatedPages[pageIndex];
      if (page !== undefined) { this.localReaderPages.push(page); }
    }
    const savedPosition = Math.max(0, this.book.androidCharacterPosition ?? 0);
    const percentPosition = Math.round(this.localSemanticContent.length * (this.book.chapterProgress ?? 0) / 100);
    const targetPosition = savedPosition > 0 ? savedPosition : percentPosition;
    const pageIndex = titlePageInserted && targetPosition === 0 ? 0 : this.localReaderPages.findIndex((page: LocalReaderPage) =>
      targetPosition >= page.startPosition && targetPosition < page.endPosition);
    this.currentPageIndex = pageIndex >= 0 ? pageIndex : Math.max(0, this.localReaderPages.length - 1);
    this.reportReaderPageProgress();
  }

  private reportReaderPageProgress(): void {
    const page = this.localReaderPages[this.currentPageIndex];
    if (page === undefined) { return; }
    this.sliderProgressIndex = this.progressBehavior === 'page'
      ? this.currentPageIndex : this.getChapterIndex();
    const position = Math.max(0, Math.min(this.localSemanticContent.length, page.startPosition));
    const progress = this.localSemanticContent.length > 0 ? position / this.localSemanticContent.length * 100 : 0;
    this.readerProgress = progress;
    this.lastReportedProgress = Math.round(progress);
    this.onProgressChange(progress, position);
  }

  private turnReaderPage(delta: number): void {
    const nextPageIndex = this.currentPageIndex + delta;
    if (nextPageIndex < 0 || nextPageIndex >= this.localReaderPages.length) {
      const targetChapter = this.getChapterIndex() + delta;
      if (targetChapter >= 0 && targetChapter < this.getChapterCount()) {
        this.onTurnChapterBoundary(delta);
      }
      return;
    }
    this.currentPageIndex = nextPageIndex;
    this.reportReaderPageProgress();
  }

  private turnReaderChapter(delta: number): void {
    const targetChapter = this.getChapterIndex() + delta;
    if (targetChapter >= 0 && targetChapter < this.getChapterCount()) {
      this.onSelectChapterIndex(targetChapter);
    }
  }

  private isPageProgressMode(): boolean {
    return this.progressBehavior === 'page' && this.localReaderPages.length > 0;
  }

  private getProgressSliderMaximum(): number {
    return this.isPageProgressMode() ? this.localReaderPages.length - 1 : this.getChapterCount() - 1;
  }

  private getProgressSliderThumbRatio(): number {
    const maximum = this.getProgressSliderMaximum();
    if (maximum <= 0) { return 0; }
    return Math.max(0, Math.min(1, this.sliderProgressIndex / maximum));
  }

  private getChapterCount(): number {
    const titles = this.book.chapterTitles;
    if (titles !== undefined && titles.length > 0) {
      return titles.length;
    }
    const count = Number(this.book.chapterCount ?? '');
    return Number.isInteger(count) && count > 0 ? count : 1;
  }

  private getChapterIndex(): number {
    const chapterCount = this.getChapterCount();
    if (this.book.chapterIndex !== undefined) {
      return Math.max(0, Math.min(chapterCount - 1, this.book.chapterIndex));
    }
    const titles = this.book.chapterTitles;
    if (titles !== undefined) {
      const index = titles.indexOf(this.chapterTitle);
      if (index >= 0) {
        return index;
      }
    }
    return Math.max(0, Math.min(chapterCount - 1, Math.floor(this.book.progress / 100 * chapterCount)));
  }

  private getBottomActionPages(): ReaderControlKind[][][] {
    const actions = this.bottomActions
      .filter((item: ReaderBottomActionConfig) => item.enabled)
      .map((item: ReaderBottomActionConfig) => item.id as ReaderControlKind);
    if (actions.length === 0) { return []; }
    const itemsPerRow = Math.max(2, Math.min(8, this.bottomItemsPerRow));
    const rowCount = Math.max(1, Math.min(2, this.bottomRowCount));
    const pageSize = itemsPerRow * rowCount;
    const pages: ReaderControlKind[][][] = [];
    for (let pageStart = 0; pageStart < actions.length; pageStart += pageSize) {
      const pageActions = actions.slice(pageStart, pageStart + pageSize);
      const rows: ReaderControlKind[][] = [];
      for (let rowStart = 0; rowStart < pageActions.length; rowStart += itemsPerRow) {
        rows.push(pageActions.slice(rowStart, rowStart + itemsPerRow));
      }
      pages.push(rows);
    }
    return pages.length > 0 ? pages : [[actions]];
  }

  private getVisibleTopActions(): ReaderBottomActionConfig[] {
    const actions = this.topActions.filter((item: ReaderBottomActionConfig) => item.enabled);
    if (actions.length > 0) {
      // ArkUI 顶栏 Row 中后插入的配置项靠左，因此反转数据以保持视觉顺序与配置列表一致。
      return actions.reverse();
    }
    return [{ id: 'moreActions', enabled: true }];
  }

  @Builder
  private topActionButton(action: ReaderBottomActionConfig) {
    Stack({ alignContent: Alignment.Center }) {
      Image(action.id === 'charset' ? $r('app.media.reader_translate') : $r('app.media.reader_more'))
        .width(20).height(20).fillColor('#D5C2C6')
    }.width(40).height(40).margin({ left: 6 }).onClick(() => {
      if (action.id === 'charset') {
        this.openCharsetDialog();
      } else {
        this.overflowVisible = !this.overflowVisible;
        this.imageStyleMenuVisible = false;
      }
    })
  }

  private getBottomActionPageIndex(): number {
    return Math.max(0, Math.min(this.currentBottomActionPage, this.getBottomActionPages().length - 1));
  }

  private getBottomActionLabel(kind: ReaderControlKind): string {
    if (kind === 'catalog') { return '目录'; }
    if (kind === 'search') { return '全文搜索'; }
    if (kind === 'autoPage') { return '自动翻页'; }
    if (kind === 'voice') { return '朗读'; }
    return '设置';
  }

  private selectBottomAction(kind: ReaderControlKind): void {
    if (kind === 'catalog') { this.onOpenCatalog(); }
    else if (kind === 'search') { this.onOpenSearchContent(); }
    else if (kind === 'autoPage') { this.toggleAutoPage(); }
    else if (kind === 'voice') { this.onUnavailableAction('朗读播放尚未迁移'); }
    else { this.onOpenSettings(); }
  }

  private longSelectBottomAction(kind: ReaderControlKind): void {
    if (kind === 'voice') { this.onOpenReadAloud(); }
  }

  private getWholeBookProgress(): number {
    const chapterCount = this.getChapterCount();
    return Math.max(0, Math.min(100,
      (this.getChapterIndex() + this.readerProgress / 100) / chapterCount * 100));
  }

  private getReaderFooterProgress(): string {
    const usesPageProgress = this.isPageProgressMode();
    const current = usesPageProgress ? this.currentPageIndex + 1 : this.getChapterIndex() + 1;
    const total = usesPageProgress ? this.localReaderPages.length : this.getChapterCount();
    return `${current}/${total}  ${this.getWholeBookProgress().toFixed(1)}%`;
  }

  private toDimension(value: Length): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      const parsed = Number.parseFloat(value);
      return Number.isNaN(parsed) ? 0 : parsed;
    }
    return 0;
  }

  private getReaderLineGapAfter(line: LocalReaderLine, itemIndex: number, item: LocalReaderLineItem): number {
    const nextItem = line.items[itemIndex + 1];
    return !item.leadingIndent && nextItem !== undefined && !nextItem.leadingIndent ? line.justifyGap : 0;
  }

  private getReaderTextGlyphs(value: string): string[] {
    const glyphs: string[] = [];
    let cursor = 0;
    while (cursor < value.length) {
      const codePoint = value.codePointAt(cursor);
      const nextCursor = cursor + (codePoint !== undefined && codePoint > 0xFFFF ? 2 : 1);
      glyphs.push(value.substring(cursor, nextCursor));
      cursor = nextCursor;
    }
    return glyphs;
  }

  private getReaderTextGlyphCount(value: string): number {
    let count = 0;
    let cursor = 0;
    while (cursor < value.length) {
      const codePoint = value.codePointAt(cursor);
      cursor += codePoint !== undefined && codePoint > 0xFFFF ? 2 : 1;
      count++;
    }
    return count;
  }

  private getReaderGlyphGapAfter(
    line: LocalReaderLine,
    itemIndex: number,
    glyphIndex: number,
    glyphCount: number,
    item: LocalReaderLineItem
  ): number {
    if (item.leadingIndent) { return 0; }
    if (glyphIndex < glyphCount - 1) { return line.justifyGap; }
    const nextItem = line.items[itemIndex + 1];
    return nextItem !== undefined && !nextItem.leadingIndent ? line.justifyGap : 0;
  }

  private updateProgress(): void {
    if (this.estimatedContentHeight <= 0) {
      this.refreshEstimatedContentHeight();
    }
    try {
      const scrollContentSize = this.readerScroller.contentSize();
      const reportedHeight = this.toDimension(scrollContentSize.height);
      if (reportedHeight > this.contentHeight) {
        this.contentHeight = reportedHeight;
      }
    } catch (_) {
    }
    const totalScrollHeight = this.contentHeight - this.viewportHeight;
    if (totalScrollHeight <= 0) {
      return;
    }
    const progress = Math.max(0, Math.min(100, Math.round(this.scrollOffset / totalScrollHeight * 100)));
    this.readerProgress = progress;
    if (progress !== this.lastReportedProgress) {
      this.lastReportedProgress = progress;
      this.onProgressChange(progress, Math.round(this.content.length * progress / 100));
    }
  }

  private restoreProgressPosition(): void {
    if (this.estimatedContentHeight <= 0) {
      this.refreshEstimatedContentHeight();
    }
    if (this.restoredProgressPosition || this.contentHeight <= this.viewportHeight) {
      return;
    }
    this.restoredProgressPosition = true;
    const totalScrollHeight = this.contentHeight - this.viewportHeight;
    const chapterProgress = this.book.chapterProgress ?? 0;
    this.scrollOffset = totalScrollHeight * chapterProgress / 100;
    this.readerProgress = chapterProgress;
    this.lastReportedProgress = chapterProgress;
    if (chapterProgress > 0) {
      try {
        this.readerScroller.scrollTo({
          xOffset: 0,
          yOffset: this.scrollOffset,
          animation: false
        });
      } catch (_) {
      }
    }
  }

  private seekToProgress(progress: number): void {
    const nextProgress = Math.max(0, Math.min(100, Math.round(progress)));
    const totalScrollHeight = this.contentHeight - this.viewportHeight;
    if (totalScrollHeight <= 0) {
      return;
    }
    this.readerProgress = nextProgress;
    this.lastReportedProgress = nextProgress;
    this.scrollOffset = totalScrollHeight * nextProgress / 100;
    try {
      this.readerScroller.scrollTo({ xOffset: 0, yOffset: this.scrollOffset, animation: false });
    } catch (_) {
    }
    this.onProgressChange(nextProgress, Math.round(this.content.length * nextProgress / 100));
  }

  private getDisplayContent(content: string): string {
    if (this.book.format === 'epub') {
      return content;
    }
    return content.split(/\r?\n/).map((line: string) => line.trim().length > 0 ? '　　' + line : line).join('\n');
  }

  private getReaderContentSegments(): ReaderContentSegment[] {
    const segments: ReaderContentSegment[] = [];
    const imagePattern: RegExp = /\[\[EPUB_IMAGE:([^;\]\r\n]+)(?:;[^\]\r\n]*)?\]\]/g;
    let match: RegExpExecArray | null = imagePattern.exec(this.content);
    let cursor = 0;
    while (match !== null) {
      if (match.index > cursor) {
        const textBeforeImage = this.content.substring(cursor, match.index);
        this.appendParagraphSegments(segments, textBeforeImage);
      }
      const imageUri = match[1] ?? '';
      if (imageUri.length > 0) {
        segments.push({ kind: 'image', value: imageUri });
      }
      cursor = match.index + match[0].length;
      match = imagePattern.exec(this.content);
    }
    if (cursor < this.content.length) {
      const trailingText = this.content.substring(cursor);
      this.appendParagraphSegments(segments, trailingText);
    }
    if (segments.length === 0) {
      segments.push({ kind: 'text', value: this.content.length > 0 ? this.content : '选择一本书开始阅读。' });
    }
    return segments;
  }

  private appendParagraphSegments(segments: ReaderContentSegment[], text: string): void {
    const paragraphs = text.split(/\n\s*\n/);
    for (let index = 0; index < paragraphs.length; index++) {
      const paragraph = paragraphs[index];
      if (paragraph !== undefined && paragraph.trim().length > 0) {
        segments.push({ kind: 'text', value: paragraph });
      }
    }
  }

  private async loadContentImageSizes(): Promise<void> {
    const segments = this.getReaderContentSegments();
    const nextSizes = new Map<string, ReaderIntrinsicImageSize>(this.imageSizes);
    let changed = false;
    for (let index = 0; index < segments.length; index++) {
      const segment = segments[index];
      if (segment === undefined || segment.kind !== 'image' || nextSizes.has(segment.value)) {
        continue;
      }
      let source: image.ImageSource | undefined = undefined;
      try {
        source = image.createImageSource(segment.value);
        const info = await source.getImageInfo();
        if (info.size.width > 0 && info.size.height > 0) {
          const density = info.density > 0 ? info.density / 160 : 1;
          const widthPx = info.size.width / density;
          const heightPx = info.size.height / density;
          const context = this.getUIContext();
          nextSizes.set(segment.value, {
            width: context.px2vp(widthPx),
            height: context.px2vp(heightPx)
          });
          changed = true;
        }
      } catch (_) {
      } finally {
        if (source !== undefined) {
          try {
            await source.release();
          } catch (_) {
          }
        }
      }
    }
    if (changed) {
      this.imageSizes = nextSizes;
      this.refreshEstimatedContentHeight();
      this.rebuildReaderPages();
    }
  }

  private getReaderImageWidth(uri: string): number {
    const size = this.imageSizes.get(uri);
    if (size === undefined || size.width <= 0 || size.height <= 0) { return 1; }
    const scale = Math.min(1,
      this.readerContentWidth > 0 ? Math.max(1, this.readerContentWidth - 40) / size.width : 1,
      this.viewportHeight > 0 ? Math.max(1, this.viewportHeight - 11) / size.height : 1);
    return size.width * scale;
  }

  private getReaderImageHeight(uri: string): number {
    const size = this.imageSizes.get(uri);
    if (size === undefined || size.width <= 0 || size.height <= 0) { return 1; }
    const scale = Math.min(1,
      this.readerContentWidth > 0 ? Math.max(1, this.readerContentWidth - 40) / size.width : 1,
      this.viewportHeight > 0 ? Math.max(1, this.viewportHeight - 11) / size.height : 1);
    return size.height * scale;
  }

  private estimateContentHeight(): number {
    const availableWidth = Math.max(1, this.readerContentWidth - 40);
    const fontSize = this.fontSize * 1.05;
    const lineHeight = this.fontSize * 1.25;
    const charactersPerLine = Math.max(1, availableWidth / fontSize);
    let estimatedHeight = this.fontSize * 4 + 12;
    const segments = this.getReaderContentSegments();
    for (let index = 0; index < segments.length; index++) {
      const segment = segments[index];
      if (segment === undefined) { continue; }
      if (segment.kind === 'image') {
        const size = this.imageSizes.get(segment.value);
        estimatedHeight += (size?.height ?? fontSize * 1.5) + 16;
      } else {
        const lines = segment.value.split(/\r?\n/);
        for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
          const line = lines[lineIndex] ?? '';
          const wrappedLines = Math.max(1, Math.ceil((line.length + 2) / charactersPerLine));
          estimatedHeight += wrappedLines * lineHeight;
        }
        estimatedHeight += this.fontSize;
      }
    }
    return estimatedHeight + 34;
  }

  private refreshEstimatedContentHeight(): void {
    this.estimatedContentHeight = this.estimateContentHeight();
    this.contentHeight = Math.max(this.contentHeight, this.estimatedContentHeight);
  }

  private onReaderContentAreaChanged(oldArea: Area, newArea: Area): void {
    this.contentHeight = this.toDimension(newArea.height);
    this.rebuildReaderPages();
    this.refreshEstimatedContentHeight();
    this.restoreProgressPosition();
    this.updateProgress();
  }

  private getReadingTextColor(): string {
    return this.paperColor === '#000000' || this.paperColor === '#343832' || this.paperColor === '#3C3F43'
      ? '#D8D8DC' : '#38383B';
  }

  build() {
    Stack() {
      if ((this.book.format === 'txt' || this.book.format === 'epub') && this.localReaderPages.length > 0) {
        Stack() {
          Column() {
            if (this.localReaderPages[this.currentPageIndex]?.titleOnly === true) {
              Blank().layoutWeight(1)
              Text(this.chapterTitle)
                .fontSize(this.fontSize + 4)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getReadingTextColor())
                .width('100%')
                .textAlign(TextAlign.Center)
              Blank().layoutWeight(1)
            } else if (this.currentPageIndex === 0) {
              Text(this.chapterTitle)
                .fontSize(this.fontSize + 4)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getReadingTextColor())
                .width('100%')
                .margin({ bottom: 24 })
            }
            ForEach(this.localReaderPages[this.currentPageIndex]?.lines ?? [],
              (line: LocalReaderLine, lineIndex: number) => {
                Row() {
                  ForEach(line.items, (item: LocalReaderLineItem, itemIndex: number) => {
                    if (item.kind === 'image') {
                      Image(item.value)
                        .width(item.width)
                        .height(item.height)
                        .objectFit(ImageFit.Contain)
                        .alignSelf(ItemAlign.Center)
                        .margin({ right: this.getReaderLineGapAfter(line, itemIndex, item) })
                    } else if (item.leadingIndent) {
                      Text(item.value)
                        .fontSize(this.fontSize * 1.05)
                        .fontColor(this.getReadingTextColor())
                        .maxLines(1)
                        .height(line.height)
                    } else {
                      ForEach(this.getReaderTextGlyphs(item.value), (glyph: string, glyphIndex: number) => {
                        Text(glyph)
                          .fontSize(this.fontSize * 1.05)
                          .fontColor(this.getReadingTextColor())
                          .maxLines(1)
                          .height(line.height)
                          .margin({ right: this.getReaderGlyphGapAfter(
                            line, itemIndex, glyphIndex, this.getReaderTextGlyphCount(item.value), item) })
                      }, (glyph: string, glyphIndex: number) =>
                        `${this.readerContentRevision}-${lineIndex}-${itemIndex}-${glyphIndex}-${glyph}`)
                    }
                  }, (item: LocalReaderLineItem, itemIndex: number) =>
                    `${this.readerContentRevision}-${lineIndex}-${itemIndex}-${item.kind}`)
                }
                .width('100%')
                .height(line.height)
                .justifyContent(line.imageOnly ? FlexAlign.Center : FlexAlign.Start)
                .margin({ top: line.verticalSpaceBefore, bottom: line.paragraphSpacingAfter })
              }, (line: LocalReaderLine, lineIndex: number) =>
                `${this.readerContentRevision}-${this.currentPageIndex}-${lineIndex}`)
          }
          .width('100%')
          .height('100%')
          .padding({ left: 20, right: 20, top: 7, bottom: 4 })

          Row() {
            Blank().layoutWeight(1).onClick(() => this.turnReaderPage(-1))
            Blank().layoutWeight(1).onClick(() => this.controlsVisible = !this.controlsVisible)
            Blank().layoutWeight(1).onClick(() => this.turnReaderPage(1))
          }.width('100%').height('100%')
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.paperColor)
        .onAreaChange((oldArea: Area, newArea: Area) => {
          this.readerContentWidth = this.toDimension(newArea.width);
          this.viewportHeight = this.toDimension(newArea.height);
          this.rebuildReaderPages();
        })
        .parallelGesture(PanGesture({ direction: PanDirection.Horizontal })
          .onActionEnd((event: GestureEvent) => {
            if (event.offsetX < -36) { this.turnReaderPage(1); }
            else if (event.offsetX > 36) { this.turnReaderPage(-1); }
          }))
      } else {
      Scroll(this.readerScroller) {
        Column() {
          Text(this.chapterTitle)
            .fontSize(this.fontSize + 4)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getReadingTextColor())
            .width('100%')
            .margin({ bottom: 24 })
          ForEach(this.getReaderContentSegments(), (segment: ReaderContentSegment, index: number) => {
            if (segment.kind === 'image') {
              if (this.imageSizes.has(segment.value)) {
                Image(segment.value)
                  .width(this.getReaderImageWidth(segment.value))
                  .height(this.getReaderImageHeight(segment.value))
                  .objectFit(ImageFit.Contain)
                  .alignSelf(ItemAlign.Center)
                  .margin({ top: 8, bottom: 8 })
              }
            } else {
              Text(this.getDisplayContent(segment.value))
                .fontSize(this.fontSize * 1.05)
                .fontColor(this.getReadingTextColor())
                .lineHeight(this.fontSize * 1.25)
                .textAlign(TextAlign.JUSTIFY)
                .width('100%')
                .margin({ bottom: this.fontSize })
            }
          }, (segment: ReaderContentSegment, index: number) => `${this.readerContentRevision}-${segment.kind}-${index}`)
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .padding({ left: 20, right: 20, top: 7, bottom: 4 })
        .onClick(() => this.controlsVisible = !this.controlsVisible)
        .onAreaChange((oldArea: Area, newArea: Area) => {
          this.readerContentWidth = this.toDimension(newArea.width);
          this.onReaderContentAreaChanged(oldArea, newArea);
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.paperColor)
      .scrollBar(BarState.Off)
      .onDidScroll((xOffset: number, yOffset: number, scrollState: ScrollState) => {
        this.scrollOffset = Math.max(0, this.scrollOffset + yOffset);
        this.updateProgress();
      })
      .onAreaChange((oldArea: Area, newArea: Area) => {
        this.viewportHeight = this.toDimension(newArea.height);
        this.rebuildReaderPages();
        this.restoreProgressPosition();
        this.updateProgress();
      })
      }

      if (!this.controlsVisible) {
        Column() {
          Blank().layoutWeight(1)
          Row() {
            Text(this.book.title).fontSize(10).fontColor('#989AA4').maxLines(1)
            Blank()
            Text(this.getReaderFooterProgress()).fontSize(10).fontColor('#989AA4')
          }.width('100%').padding({ left: 16, right: 16, bottom: 8 })
        }.width('100%').height('100%')
          .hitTestBehavior(HitTestMode.Transparent)
      }

      if (this.controlsVisible) {
        Column() {
          Column() {
            Row() {
              Stack({ alignContent: Alignment.Center }) {
                Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D5C2C6')
              }.width(40).height(40).onClick(() => this.onBack())
              Blank().layoutWeight(1)
              if (this.getVisibleTopActions().length > 0) {
                this.topActionButton(this.getVisibleTopActions()[0] as ReaderBottomActionConfig)
              }
              if (this.getVisibleTopActions().length > 1) {
                this.topActionButton(this.getVisibleTopActions()[1] as ReaderBottomActionConfig)
              }
            }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 4 })
            Text(this.book.title).fontSize(16).fontColor('#D5C2C6').maxLines(1)
              .width('100%').padding({ left: 16, right: 16, top: 4, bottom: 4 })
            Text(this.chapterTitle).fontSize(12).fontColor('#D5C2C6').maxLines(1)
              .width('100%').padding({ left: 16, right: 16, top: 4, bottom: 8 })
          }.width('100%').backgroundColor('#D931282A')

          if (this.showQuickActions) {
            Row() {
              ReaderControl({ kind: 'search', active: false, onSelect: () => this.onOpenSearchContent() })
              ReaderControl({ kind: 'autoPage', active: this.autoPageActive, onSelect: (): void => this.toggleAutoPage() })
              ReaderControl({ kind: 'catalog', active: false, onSelect: () => this.onOpenCatalog() })
              ReaderControl({ kind: 'voice', active: false, onSelect: (): void => { this.onUnavailableAction('朗读播放尚未迁移'); }, onLongSelect: (): void => { this.onOpenReadAloud(); } })
              ReaderControl({ kind: 'settings', active: false, onSelect: () => this.onOpenSettings() })
            }.width('100%').justifyContent(FlexAlign.Start).padding({ left: 18, right: 18, top: 8, bottom: 8 })
          }

          Blank().layoutWeight(1)

          Column() {
            Row() {
              Stack({ alignContent: Alignment.Center }) {
                Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D5C2C6')
              }.width(40).height(40).onClick(() => this.turnReaderChapter(-1))
              Stack({ alignContent: Alignment.Center }) {
                Slider({
                  value: this.sliderProgressIndex,
                  min: 0,
                  max: Math.max(0, this.getProgressSliderMaximum()),
                  step: 1,
                  style: SliderStyle.InSet
                })
                  .width('100%').height(40)
                  .selectedColor('#FFB1C8').trackColor('#5A3F47').blockColor('#00000000')
                  .trackThickness(6)
                  .blockSize({ width: 12, height: 12 })
                  .showSteps(true).stepColor('#FFB1C8').stepSize(3)
                  .onChange((value: number, mode: SliderChangeMode) => {
                    const maximum = this.getProgressSliderMaximum();
                    const index = Math.max(0, Math.min(maximum, Math.round(value)));
                    this.sliderProgressIndex = index;
                    if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                      if (this.isPageProgressMode()) {
                        this.currentPageIndex = index;
                        this.reportReaderPageProgress();
                      } else {
                        this.onSelectChapterIndex(index);
                      }
                    }
                  })
                Row() {
                  Blank().layoutWeight(this.getProgressSliderThumbRatio())
                  Column().width(5).height(40).backgroundColor('#FFB1C8').borderRadius(2.5)
                  Blank().layoutWeight(1 - this.getProgressSliderThumbRatio())
                }.width('100%').height(40).padding({ left: 10, right: 10 })
                  .hitTestBehavior(HitTestMode.Transparent)
              }.layoutWeight(1).height(40)
              Stack({ alignContent: Alignment.Center }) {
                Image($r('app.media.reader_arrow_forward')).width(20).height(20).fillColor('#D5C2C6')
              }.width(40).height(40).onClick(() => this.turnReaderChapter(1))
            }.width('100%').height(40).padding({ left: 8, right: 8 })
            if (this.getBottomActionPages().length > 0) {
            Swiper() {
              ForEach(this.getBottomActionPages(), (rows: ReaderControlKind[][], _pageIndex: number) => {
                Column() {
                  ForEach(rows, (row: ReaderControlKind[], _rowIndex: number) => {
                    Row() {
                      ForEach(row, (kind: ReaderControlKind) => {
                        ReaderBottomAction({
                          kind: kind,
                          label: this.getBottomActionLabel(kind),
                          showLabel: this.showBottomActionText,
                          active: kind === 'autoPage' && this.autoPageActive,
                          iconStyle: this.bottomIconStyle,
                          onSelect: () => this.selectBottomAction(kind),
                          onLongSelect: () => this.longSelectBottomAction(kind)
                        }).width(40)
                      }, (kind: ReaderControlKind) => kind)
                    }.width('100%').justifyContent(FlexAlign.SpaceBetween)
                  }, (_row: ReaderControlKind[], rowIndex: number) => `${_pageIndex}-${rowIndex}`)
                }.width('100%').justifyContent(FlexAlign.Center)
              }, (_rows: ReaderControlKind[][], pageIndex: number) => `${pageIndex}`)
            }
              .width('100%')
              .index(this.getBottomActionPageIndex())
              .height((this.showBottomActionText ? 64 : 48) * Math.max(1, Math.min(2, this.bottomRowCount)) + 21)
              .loop(false)
              .indicator(false)
              .onChange((pageIndex: number) => this.currentBottomActionPage = pageIndex)
              .padding({ left: 8, right: 8, top: 4, bottom: 17 })
            }
          }.width('92%').alignSelf(ItemAlign.Center)
            .padding({ left: 8, right: 8, top: 12, bottom: 0 })
            .backgroundColor('#D931282A')
            .borderRadius(32)
            .margin({ bottom: 16 })

        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
      }

      if (this.autoPageSettingsVisible) {
        Column() {
          Blank().layoutWeight(1)
          Column() {
            Row() {
              Text('自动翻页').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#ECECF0')
              Blank()
              Text('×').fontSize(23).fontColor('#C8C9D0').onClick(() => this.autoPageSettingsVisible = false)
            }.width('100%').padding({ bottom: 18 })
            Row() {
              Text('翻页间隔').fontSize(14).fontColor('#D8D9E0')
              Blank()
              Text(`${this.autoReadSpeedSeconds} 秒`).fontSize(14).fontColor('#D8D9E0')
            }.width('100%')
            Slider({ value: this.autoReadSpeedSeconds, min: 1, max: 120, step: 1, style: SliderStyle.InSet })
              .width('100%').selectedColor('#B9C6FF').trackColor('#565A6B').blockColor('#B9C6FF')
              .onChange((value: number, mode: SliderChangeMode) => {
                if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click || mode === SliderChangeMode.End) {
                  this.setAutoPageSpeed(value);
                }
              })
            Row() {
              Text('目录').fontSize(13).fontColor('#E2E3E8').textAlign(TextAlign.Center).layoutWeight(1)
                .onClick(() => { this.autoPageSettingsVisible = false; this.onOpenCatalog(); })
              Text('停止').fontSize(13).fontColor('#E2E3E8').textAlign(TextAlign.Center).layoutWeight(1)
                .onClick(() => { this.autoPageActive = false; this.autoPageSettingsVisible = false; this.stopAutoPageTimer(); })
              Text('翻页设置').fontSize(13).fontColor('#E2E3E8').textAlign(TextAlign.Center).layoutWeight(1)
                .onClick(() => { this.autoPageSettingsVisible = false; this.onOpenSettings(); })
            }.width('100%').padding({ top: 18, bottom: 10 })
          }.width('100%').padding({ left: 20, right: 20, top: 18, bottom: 22 })
            .backgroundColor('#D931282A').borderRadius({ topLeft: 24, topRight: 24 })
        }.width('100%').height('100%').backgroundColor('#66000000')
          .onClick(() => this.autoPageSettingsVisible = false)
      }

      if (this.controlsVisible && this.overflowVisible) {
        Stack({ alignContent: Alignment.Bottom }) {
          Column().width('100%').height('100%').backgroundColor('#88000000')
            .onClick(() => {
              this.overflowVisible = false;
              this.imageStyleMenuVisible = false;
            })
          Column() {
            Row().width(32).height(4).backgroundColor('#C5C6CD').borderRadius(4)
              .alignSelf(ItemAlign.Center).margin({ top: 10, bottom: 14 })
            Row() {
              BookCover({ book: this.book, mini: true }).margin({ right: 12 })
              Column() {
                Text(this.book.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#E5E6EB')
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.chapterTitle).fontSize(11).fontColor('#B7B8C1').maxLines(1)
                  .margin({ top: 4 })
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Text(`${this.getChapterIndex() + 1} / ${this.getChapterCount()}`)
                .fontSize(11).fontColor('#E5E6EB').padding({ left: 10, right: 10, top: 7, bottom: 7 })
                .backgroundColor('#111217').borderRadius(16)
            }.width('100%').padding({ left: 16, right: 16, bottom: 14 })
            Grid() {
              ForEach(READER_LOCAL_MORE_ACTIONS, (action: ReaderMoreAction) => {
                GridItem() {
                  Column() {
                    AppGlyph({ name: action.glyph, tint: '#D5C2C6', glyphSize: 22 }).margin({ bottom: 8 })
                    Text(action.label).fontSize(11).fontColor('#E1DADD').textAlign(TextAlign.Center)
                      .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }.width('100%').height(92).justifyContent(FlexAlign.Center)
                    .backgroundColor('#202127').borderRadius(16)
                    .onClick(() => {
                      this.overflowVisible = false;
                      this.onUnavailableAction(`${action.label}功能尚未迁移`);
                    })
                }
              }, (action: ReaderMoreAction) => action.id)
            }.columnsTemplate('1fr 1fr 1fr 1fr').rowsGap(8).columnsGap(8)
              .width('100%').padding({ left: 16, right: 16, bottom: 16 }).layoutWeight(1)
          }
          .width('100%').height('52%').backgroundColor('#1A1B21')
          .borderRadius({ topLeft: 26, topRight: 26 })
        }
        .width('100%')
        .height('100%')
      }

      if (this.charsetDialogVisible) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#99000000')
            .onClick(() => {
              this.charsetDialogVisible = false;
              this.charsetOptionsExpanded = false;
            })
          Column() {
            Text('设置编码').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#ECEEF2')
              .width('100%').margin({ bottom: 16 })
            Row() {
              TextInput({ text: this.charsetInput, placeholder: '输入或选择字符集' })
                .layoutWeight(1).height(48).fontSize(14).fontColor('#ECEEF2')
                .backgroundColor('#292A31').borderRadius(10).padding({ left: 12, right: 12 })
                .onChange((value: string) => this.charsetInput = value)
              Text(this.charsetOptionsExpanded ? '⌃' : '⌄').fontSize(22).fontColor('#D9DAE0')
                .width(38).height(48).textAlign(TextAlign.Center)
                .onClick(() => this.charsetOptionsExpanded = !this.charsetOptionsExpanded)
            }.width('100%')
            if (this.charsetOptionsExpanded) {
              Scroll() {
                Column() {
                  ForEach(READER_CHARSETS, (charset: string) => {
                    Row() {
                      Text(charset).fontSize(14).fontColor('#E1E2E7').layoutWeight(1)
                      if (this.charsetInput.trim().toLowerCase() === charset.toLowerCase()) {
                        Text('✓').fontSize(14).fontColor('#C5D0FF')
                      }
                    }.width('100%').padding({ left: 12, right: 12, top: 10, bottom: 10 })
                      .onClick(() => {
                        this.charsetInput = charset;
                        this.charsetOptionsExpanded = false;
                      })
                  }, (charset: string) => charset)
                }.width('100%')
              }.width('100%').height(220).margin({ top: 8 })
                .scrollBar(BarState.Off)
            }
            Row() {
              Blank().layoutWeight(1)
              Text('取消').fontSize(14).fontColor('#B9BBC4').padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .onClick(() => {
                  this.charsetDialogVisible = false;
                  this.charsetOptionsExpanded = false;
                })
              Text('确定').fontSize(14).fontColor('#C5D0FF').padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .onClick(() => this.applyCharset())
            }.width('100%').margin({ top: 12 })
          }
          .width('86%').padding(18).backgroundColor('#1C1D23').borderRadius(20)
        }
        .width('100%').height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.paperColor)
  }
}

@Component
struct ReaderControl {
  @Prop kind: ReaderControlKind = 'catalog';
  @Prop active: boolean = false;
  onSelect: () => void = () => {};
  onLongSelect: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      ReaderControlGlyph({ kind: this.kind, glyphSize: 19, active: this.active })
    }.width(36).height(36).backgroundColor(this.active ? '#454B62' : '#303139').borderRadius(20)
      .parallelGesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => { this.onLongSelect(); }))
      .onClick(() => this.onSelect())
  }
}

@Component
struct ReaderBottomAction {
  @Prop kind: ReaderControlKind = 'catalog';
  @Prop label: string = '';
  @Prop showLabel: boolean = true;
  @Prop active: boolean = false;
  @Prop iconStyle: number = 1;
  onSelect: () => void = () => {};
  onLongSelect: () => void = () => {};

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        ReaderControlGlyph({ kind: this.kind, glyphSize: 20, active: this.active })
      }.width(40).height(40)
        .backgroundColor(this.active ? '#454B62' : (this.iconStyle === 1 ? '#292A31' : '#00000000'))
        .border({ width: this.iconStyle === 2 ? 1 : 0, color: '#8B8E98' })
        .borderRadius(20)
      if (this.showLabel) {
        Text(this.label).fontSize(9).fontColor('#E1E2E7').margin({ top: 3 })
      }
    }.layoutWeight(1).padding({ top: 3, bottom: 3 })
      .parallelGesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => { this.onLongSelect(); }))
      .onClick(() => this.onSelect())
  }
}

@Component
struct ReaderControlGlyph {
  @Prop kind: ReaderControlKind = 'catalog';
  @Prop glyphSize: number = 20;
  @Prop active: boolean = false;

  build() {
    if (this.kind === 'search') {
      Image($r('app.media.reader_search')).width(this.glyphSize).height(this.glyphSize).fillColor(this.active ? '#FFB1C8' : '#D5C2C6')
    } else if (this.kind === 'catalog') {
      Image($r('app.media.reader_toc')).width(this.glyphSize).height(this.glyphSize).fillColor(this.active ? '#FFB1C8' : '#D5C2C6')
    } else if (this.kind === 'settings') {
      Image($r('app.media.reader_settings')).width(this.glyphSize).height(this.glyphSize).fillColor(this.active ? '#FFB1C8' : '#D5C2C6')
    } else if (this.kind === 'autoPage') {
      Image(this.active ? $r('app.media.reader_pause') : $r('app.media.reader_play'))
        .width(this.glyphSize).height(this.glyphSize).fillColor(this.active ? '#FFB1C8' : '#D5C2C6')
    } else {
      Image($r('app.media.reader_voice')).width(this.glyphSize).height(this.glyphSize).fillColor(this.active ? '#FFB1C8' : '#D5C2C6')
    }
  }
}
