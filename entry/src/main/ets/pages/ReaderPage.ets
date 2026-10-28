import { Book } from '../model/Book';
import { ReaderBookmark } from '../model/ReaderBookmark';
import { ReaderMarking, ReaderMarkingEffect } from '../model/ReaderMarking';
import { ReplaceRule } from '../model/ReplaceRule';
import { ReplaceRuleRepository } from '../data/ReplaceRuleRepository';
import { BookRepository } from '../data/BookRepository';
import { BookContentProcessRepository } from '../data/BookContentProcessRepository';
import { BookContentProcess } from '../model/BookContentProcess';
import { LocalSemanticDocument, LocalTextSemantics } from '../data/LocalTextSemantics';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { BookCover } from '../components/BookCover';
import { ReaderTextProcessingSheet } from './ReaderTextProcessingSheet';
import image from '@ohos.multimedia.image';
import { batteryInfo, settings } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { Action, inputConsumer, KeyCode, KeyEvent } from '@kit.InputKit';
import { LocalReaderLine, LocalReaderLineItem, LocalReaderPage, LocalReaderPaginator } from './LocalReaderPaginator';
import {
  ReaderBottomActionConfig, ReaderControlKind, READER_ACTION_OPTIONS, READER_LOCAL_BOTTOM_ACTION_DEFAULTS,
  READER_LOCAL_TOP_ACTION_DEFAULTS, ReaderActionOption, isReaderActionApplicable,
  ReaderInfoSettings, DEFAULT_READER_INFO_SETTINGS, ReaderPaddingSettings, DEFAULT_READER_PADDING_SETTINGS
} from '../data/ReaderSettingsRepository';
import {
  ReaderMoreActionConfig, READER_MORE_ACTION_DEFAULTS
} from '../data/ReaderMoreActionsRepository';

interface ReaderMoreAction {
  id: string;
  label: string;
  glyph: AppGlyphName;
  scopeLabel: string;
  migrated: boolean;
}

interface ReaderImageStyleOption {
  id: string;
  label: string;
}

const READER_IMAGE_STYLE_OPTIONS: ReaderImageStyleOption[] = [
  { id: 'DEFAULT', label: '默认' },
  { id: 'FULL', label: '全屏' },
  { id: 'TEXT', label: '文字嵌入' },
  { id: 'SINGLE', label: '单页' }
];

const READER_MORE_ACTIONS: ReaderMoreAction[] = [
  { id: 'source_custom_button', label: '书源自定义按钮', glyph: 'profileSource', scopeLabel: '仅支持该按钮的网络书', migrated: false },
  { id: 'change_source', label: '换源', glyph: 'swap', scopeLabel: '仅网络书', migrated: false },
  { id: 'refresh', label: '刷新', glyph: 'profileRefresh', scopeLabel: '仅网络书', migrated: false },
  { id: 'download', label: '离线缓存', glyph: 'cloudDownload', scopeLabel: '仅网络书', migrated: false },
  { id: 'audio_download', label: '听书下载', glyph: 'download', scopeLabel: '', migrated: false },
  { id: 'edit_content', label: '编辑内容', glyph: 'edit', scopeLabel: '', migrated: true },
  { id: 'add_bookmark', label: '添加书签', glyph: 'bookmark', scopeLabel: '', migrated: true },
  { id: 'text_processing', label: '文本处理', glyph: 'profileFindReplace', scopeLabel: '', migrated: true },
  { id: 'reverse_content', label: '反转内容', glyph: 'swap', scopeLabel: '', migrated: true },
  { id: 're_segment', label: '重新分段', glyph: 'list', scopeLabel: '', migrated: true },
  { id: 'del_ruby', label: '删除ruby标签', glyph: 'delete', scopeLabel: '仅EPUB', migrated: false },
  { id: 'del_h', label: '删除h标签', glyph: 'delete', scopeLabel: '仅EPUB', migrated: false },
  { id: 'toc_rule', label: 'TXT目录规则', glyph: 'profileRule', scopeLabel: '仅本地TXT', migrated: true },
  { id: 'charset', label: '设置编码', glyph: 'info', scopeLabel: '仅本地书', migrated: true },
  { id: 'image_style', label: '图片样式', glyph: 'book', scopeLabel: '', migrated: true },
  { id: 'page_anim', label: '翻页动画', glyph: 'profileSettings', scopeLabel: '', migrated: false },
  { id: 'simulated_reading', label: '模拟阅读', glyph: 'book', scopeLabel: '', migrated: false },
  { id: 'get_progress', label: '获取阅读进度', glyph: 'profileHistory', scopeLabel: '需配置阅读进度同步', migrated: false },
  { id: 'cover_progress', label: '覆盖阅读进度', glyph: 'profileHistory', scopeLabel: '需配置阅读进度同步', migrated: false },
  { id: 'highlight_rule', label: '高亮规则', glyph: 'profileRule', scopeLabel: '', migrated: true },
  { id: 'read_style', label: '阅读设置', glyph: 'profileSettings', scopeLabel: '', migrated: true },
  { id: 'bottom_button_config', label: '底栏按钮配置', glyph: 'profileSettings', scopeLabel: '', migrated: true },
  { id: 'log', label: '日志', glyph: 'info', scopeLabel: '', migrated: false }
];
const MORE_ACTION_CONFIG_ENTRY: ReaderMoreAction = {
  id: 'configure_more_actions', label: '配置更多操作', glyph: 'settings', scopeLabel: '', migrated: true
};
const READER_CHARSETS: string[] = ['UTF-8', 'GB2312', 'GB18030', 'GBK', 'Unicode', 'UTF-16', 'UTF-16LE', 'UTF-16BE', 'ASCII'];

interface ReaderContentSegment {
  kind: 'text' | 'image';
  value: string;
}

interface ReaderIntrinsicImageSize {
  width: number;
  height: number;
}

interface ReaderBookmarkPageRange {
  start: number;
  end: number;
  text: string;
}

interface ReaderTextSelectionPart {
  value: string;
  positions: number[];
}

interface ReaderMarkingRange {
  start: number;
  end: number;
}

@Component
export struct ReaderPage {
  @Prop @Watch('onStartAtChapterBeginningChanged') startAtChapterBeginning: boolean = false;
  @Prop @Watch('onBookChanged') book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0,
    coverColor: '#000000', coverMark: '书', isLocal: true
  };
  @Prop @Watch('onChapterTitleChanged') chapterTitle: string = '';
  @State @Watch('onDisplayChapterTitleChanged') displayChapterTitle: string = '';
  @Prop @Watch('onReplaceRulesChanged') replaceRules: ReplaceRule[] = [];
  @Prop @Watch('onReaderContentChanged') content: string = '';
  @Prop @Watch('onPaginationInputsChanged') fontSize: number = 19;
  @Prop @Watch('onProgressBehaviorChanged') progressBehavior: string = 'page';
  @Prop @Watch('onScreenOrientationChanged') screenOrientation: string = '0';
  @Prop @Watch('onKeepLightChanged') keepLight: string = '0';
  @Prop @Watch('onVolumeKeyPageChanged') volumeKeyPage: boolean = true;
  @Prop @Watch('onVolumeKeyPageChanged') keyPageOnLongPress: boolean = false;
  @Prop noAnimScrollPage: boolean = false;
  @Prop readingAnchorEnabled: boolean = true;
  @Prop swipeToAddBookmark: boolean = false;
  @Prop bookmarks: ReaderBookmark[] = [];
  @Prop markings: ReaderMarking[] = [];
  @Prop readingAnchorAvailable: boolean = false;
  @Prop clickImageBehavior: string = '2';
  @Prop clickRegionActions: string[] = [];
  @Prop @Watch('onSystemBarSettingsChanged') hideStatusBar: boolean = false;
  @Prop @Watch('onSystemBarSettingsChanged') hideNavigationBar: boolean = false;
  @Prop @Watch('onImagePreviewCloseRevisionChanged') imagePreviewCloseRevision: number = 0;
  @Prop @Watch('onPageAnimationChanged') pageAnimation: number = 0;
  @Prop animationSpeed: number = 2;
  @Prop @Watch('onPaginationInputsChanged') infoSettings: ReaderInfoSettings = DEFAULT_READER_INFO_SETTINGS;
  @Prop @Watch('onPaginationInputsChanged') paddingSettings: ReaderPaddingSettings = DEFAULT_READER_PADDING_SETTINGS;
  @Prop @Watch('onImageStyleChanged') imageStyle: string = 'DEFAULT';
  @Prop replaceEnabled: boolean = true;
  @Prop replaceUsesDefault: boolean = true;
  @State contentProcesses: BookContentProcess[] = [];
  @State effectiveReplaceRuleIds: number[] = [];
  @Prop @Watch('onBookmarkTargetChanged') bookmarkTargetPosition: number = -1;
  @Prop @Watch('onBookmarkTargetChanged') bookmarkTargetRevision: number = 0;
  onBookmarkTargetConsumed: () => void = () => {};
  @Prop paperColor: string = '#000000';
  @Prop showQuickActions: boolean = false;
  @Prop showControlsOnAppear: boolean = false;
  @Prop showBottomActionText: boolean = true;
  @Prop bottomIconStyle: number = 1;
  @Prop bottomItemsPerRow: number = 5;
  @Prop bottomRowCount: number = 1;
  @Prop bottomActions: ReaderBottomActionConfig[] = READER_LOCAL_BOTTOM_ACTION_DEFAULTS;
  @Prop topActions: ReaderBottomActionConfig[] = READER_LOCAL_TOP_ACTION_DEFAULTS;
  @Prop moreActions: ReaderMoreActionConfig[] = READER_MORE_ACTION_DEFAULTS;
  @State @Watch('onControlsVisibilityChanged') controlsVisible: boolean = false;
  @State imagePreviewVisible: boolean = false;
  @State imagePreviewUri: string = '';
  @State overflowVisible: boolean = false;
  @State imageStyleMenuVisible: boolean = false;
  @State moreActionConfigVisible: boolean = false;
  @State moreActionShellVisible: boolean = false;
  @State moreActionShellTitle: string = '';
  @State draftMoreActions: ReaderMoreActionConfig[] = READER_MORE_ACTION_DEFAULTS.map(
    (item: ReaderMoreActionConfig): ReaderMoreActionConfig => ({ id: item.id, enabled: item.enabled })
  );
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
  @State startPositionPending: boolean = false;
  @State localReaderPages: LocalReaderPage[] = [];
  @State fullBookPageCounts: number[] = [];
  @State fullBookPaginationReady: boolean = false;
  @State localSemanticContent: string = '';
  private localSemanticDocument: LocalSemanticDocument = {
    paragraphs: [], content: '', sourceLength: 0, sourcePositionMap: [0]
  };
  @State currentPageIndex: number = 0;
  @State pageTurnOffsetX: number = 0;
  @State pageTurnOffsetY: number = 0;
  @State pageTurnOpacity: number = 1;
  @State pageTurnAnimating: boolean = false;
  @State bookmarkPullOffset: number = 0;
  @State bookmarkPullArmed: boolean = false;
  @State bookmarkWillRemove: boolean = false;
  private pageTurnTimer: number = -1;
  private fullBookPaginationGeneration: number = 0;
  private fullBookPaginationKey: string = '';
  private pendingMarkingStart: number = -1;
  private pendingMarkingEnd: number = -1;
  private pendingMarkingText: string = '';
  private pendingMarkingRanges: Map<number, ReaderMarkingRange> = new Map<number, ReaderMarkingRange>();
  private lastReaderTapTimestamp: number = 0;
  @State pendingBookmarkTargetPosition: number = -1;
  @State autoPageActive: boolean = false;
  @State autoPageSettingsVisible: boolean = false;
  @State autoPageSecondsRemaining: number = 10;
  @State autoPageWaitingForChapter: boolean = false;
  @State contentEditVisible: boolean = false;
  @State contentEditTitle: string = '';
  @State contentEditBody: string = '';
  @State textProcessingVisible: boolean = false;
  @State currentBottomActionPage: number = 0;
  @Prop autoReadSpeedSeconds: number = 10;
  private autoPageTimer: number = -1;
  private titleGeneration: number = 0;
  private readerScroller: Scroller = new Scroller();
  private readerSystemBarRequestId: number = 0;
  private readerOrientationRequestId: number = 0;
  private originalReaderOrientation: window.Orientation = window.Orientation.UNSPECIFIED;
  private originalReaderOrientationCaptured: boolean = false;
  private keepLightTimer: number = -1;
  private keepLightRequestId: number = 0;
  private readerWindowActive: boolean = false;
  private volumeKeysSubscribed: boolean = false;
  private subscribedVolumeKeyLongPress: boolean | undefined = undefined;
  private volumeUpHandler: (event: KeyEvent) => void = (event: KeyEvent): void => {
    if (event.action === Action.DOWN && this.readerWindowActive && !this.controlsVisible) { this.turnReaderPage(-1); }
  };
  private volumeDownHandler: (event: KeyEvent) => void = (event: KeyEvent): void => {
    if (event.action === Action.DOWN && this.readerWindowActive && !this.controlsVisible) { this.turnReaderPage(1); }
  };
  onBack: () => void = () => {};
  onOpenCatalog: () => void = () => {};
  onRestoreReadingAnchor: () => void = () => {};
  onKeepReadingAnchor: () => void = () => {};
  onToggleCurrentPageBookmark: (start: number, end: number, pageText: string) => void =
    (_start: number, _end: number, _pageText: string) => {};

  onOpenSettings: () => void = () => {};
  onCharsetChange: (charset: string) => void = (_charset: string) => {};
  onOpenSearchContent: () => void = () => {};
  onOpenReadAloud: () => void = () => {};
  onOpenImagePreview: (uri: string) => void = (_uri: string) => {};
  onCloseImagePreview: () => void = () => {};
  onControlsShown: () => void = () => {};
  onOpenTocRule: () => void = () => {};
  onToggleNightMode: () => void = () => {};
  @Prop eyeProtectionActive: boolean = false;
  onToggleEyeProtection: () => void = () => {};
  onMoreActionsChange: (actions: ReaderMoreActionConfig[]) => void = (_actions: ReaderMoreActionConfig[]) => {};
  onOpenHighlightRules: () => void = () => {};
  onOpenBottomActionConfig: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  onImageStyleChange: (imageStyle: string) => void = (_imageStyle: string) => {};
  onProgressChange: (bookId: string, chapterIndex: number, progress: number,
    chapterPosition: number, androidCoordinate: boolean) => void = () => {};
  onAddBookmark: (chapterPosition: number, pageText: string) => void = (_position: number, _pageText: string) => {};
  onCreateMarking: (chapterPosition: number, endPosition: number, selectedText: string) => void =
    (_position: number, _endPosition: number, _selectedText: string) => {};
  onSaveChapterContent: (chapterIndex: number, title: string, body: string) => void =
    (_chapterIndex: number, _title: string, _body: string) => {};
  onToggleReSegment: (enabled: boolean) => void = (_enabled: boolean) => {};
  onOpenReplaceRules: () => void = () => {};
  onReplaceRulesRefresh: () => void = () => {};
  onReplaceEnabledChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onReplaceResetToDefault: () => void = () => {};
  onRuleEnabledChange: (id: number, enabled: boolean) => void = (_id: number, _enabled: boolean) => {};
  onContentProcessToggle: (id: string, enabled: boolean) => void = (_id: string, _enabled: boolean) => {};
  onContentProcessDelete: (id: string) => void = (_id: string) => {};
  onSelectChapterIndex: (chapterIndex: number) => void = () => {};
  onTurnChapterBoundary: (delta: number) => void = (_delta: number) => {};
  onAutoReadSpeedChange: (seconds: number) => void = (_seconds: number) => {};
  onReadSessionStart: () => void = () => {};
  onReadSessionPulse: () => void = () => {};
  onReadSessionStop: () => void = () => {};
  private readSessionTimer: number = -1;
  onStartAtChapterBeginningResolved: () => void = () => {};

  aboutToAppear(): void {
    this.readerWindowActive = true;
    this.startPositionPending = this.startAtChapterBeginning;
    if (this.bookmarkTargetPosition >= 0) { this.pendingBookmarkTargetPosition = this.bookmarkTargetPosition; }
    this.resetPageTurnTransition();
    if (this.showControlsOnAppear) {
      this.controlsVisible = true;
      this.onControlsShown();
    }
    this.onReadSessionStart();
    this.readSessionTimer = setInterval(() => this.onReadSessionPulse(), 30000);
    this.activeImageStyle = this.imageStyle;
    this.readerProgress = this.startPositionPending ? 0 : (this.book.chapterProgress ?? 0);
    this.lastReportedProgress = this.readerProgress;
    this.sliderProgressIndex = this.startPositionPending ? 0 : this.getChapterIndex();
    if (this.startPositionPending) {
      this.restoredProgressPosition = false;
      this.scrollOffset = 0;
      try {
        this.readerScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
      } catch (_) {
      }
      this.rebuildReaderPages();
    }
    this.loadContentImageSizes();
    this.autoPageSecondsRemaining = this.autoReadSpeedSeconds;
    this.refreshDisplayChapterTitle();
    this.refreshContentProcesses();
    this.syncReaderSystemBars();
    this.applyReaderOrientation(this.screenOrientation, true);
    this.applyKeepLight();
    this.syncVolumeKeyPage();
  }

  aboutToDisappear(): void {
    this.readerWindowActive = false;
    this.clearKeepLight();
    this.releaseVolumeKeys();
    this.syncReaderSystemBars(true);
    this.restoreReaderOrientation();
    this.fullBookPaginationGeneration++;
    this.stopAutoPageTimer();
    this.resetPageTurnTransition();
    if (this.readSessionTimer >= 0) {
      clearInterval(this.readSessionTimer);
      this.readSessionTimer = -1;
    }
    this.onReadSessionStop();
  }

  onControlsVisibilityChanged(): void {
    this.syncReaderSystemBars();
    this.syncVolumeKeyPage();
  }

  onVolumeKeyPageChanged(): void {
    this.syncVolumeKeyPage();
  }

  onStartAtChapterBeginningChanged(): void {
    if (!this.startAtChapterBeginning) {
      this.startPositionPending = false;
      return;
    }
    this.startPositionPending = true;
    this.readerProgress = 0;
    this.lastReportedProgress = 0;
    this.sliderProgressIndex = 0;
    this.restoredProgressPosition = false;
    this.scrollOffset = 0;
    try {
      this.readerScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
    } catch (_) {
    }
    this.rebuildReaderPages();
  }

  private resolveStartPosition(): void {
    if (!this.startPositionPending) { return; }
    this.startPositionPending = false;
    this.onStartAtChapterBeginningResolved();
  }

  private syncVolumeKeyPage(): void {
    if (!this.readerWindowActive || !this.volumeKeyPage || this.controlsVisible) {
      this.releaseVolumeKeys();
      return;
    }
    if (this.volumeKeysSubscribed && this.subscribedVolumeKeyLongPress === this.keyPageOnLongPress) { return; }
    if (this.volumeKeysSubscribed) { this.releaseVolumeKeys(); }
    try {
      inputConsumer.on('keyPressed', {
        key: KeyCode.KEYCODE_VOLUME_UP, action: 1, isRepeat: this.keyPageOnLongPress
      }, this.volumeUpHandler);
      inputConsumer.on('keyPressed', {
        key: KeyCode.KEYCODE_VOLUME_DOWN, action: 1, isRepeat: this.keyPageOnLongPress
      }, this.volumeDownHandler);
      this.volumeKeysSubscribed = true;
      this.subscribedVolumeKeyLongPress = this.keyPageOnLongPress;
    } catch (_) {
      this.releaseVolumeKeys();
    }
  }

  private releaseVolumeKeys(): void {
    try { inputConsumer.off('keyPressed'); } catch (_) {}
    this.volumeKeysSubscribed = false;
    this.subscribedVolumeKeyLongPress = undefined;
  }

  onSystemBarSettingsChanged(): void {
    this.syncReaderSystemBars();
  }

  onScreenOrientationChanged(): void {
    this.applyReaderOrientation(this.screenOrientation);
  }

  onKeepLightChanged(): void {
    if (this.readerWindowActive) { this.applyKeepLight(); }
  }

  private clearKeepLight(): void {
    if (this.keepLightTimer >= 0) {
      clearTimeout(this.keepLightTimer);
      this.keepLightTimer = -1;
    }
    const requestId = ++this.keepLightRequestId;
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      if (requestId === this.keepLightRequestId) { targetWindow.setWindowKeepScreenOn(false).catch(() => {}); }
    }).catch(() => {});
  }

  private renewKeepLightTimeout(): void {
    if (this.readerWindowActive) { this.applyKeepLight(); }
  }

  private applyKeepLight(): void {
    if (this.keepLightTimer >= 0) {
      clearTimeout(this.keepLightTimer);
      this.keepLightTimer = -1;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const seconds = Number.parseInt(this.keepLight, 10);
    let systemTimeout = 60000;
    try {
      systemTimeout = Number.parseInt(settings.getValueSync(context, settings.display.SCREEN_OFF_TIMEOUT, '60000'), 10);
    } catch (_) {}
    const shouldKeepOn = this.readerWindowActive && (seconds < 0 || (seconds > 0 &&
      seconds * 1000 > (Number.isFinite(systemTimeout) ? systemTimeout : 60000)));
    const requestId = ++this.keepLightRequestId;
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      if (requestId === this.keepLightRequestId) { targetWindow.setWindowKeepScreenOn(shouldKeepOn).catch(() => {}); }
    }).catch(() => {});
    if (shouldKeepOn && seconds > 0) {
      this.keepLightTimer = setTimeout(() => this.clearKeepLight(), seconds * 1000);
    }
  }

  private applyReaderOrientation(value: string, captureOriginal: boolean = false): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const requestId = ++this.readerOrientationRequestId;
    let orientation: window.Orientation = window.Orientation.UNSPECIFIED;
    if (value === '1') { orientation = window.Orientation.PORTRAIT; }
    else if (value === '2') { orientation = window.Orientation.LANDSCAPE; }
    else if (value === '3') { orientation = window.Orientation.AUTO_ROTATION; }
    else if (value === '4') { orientation = window.Orientation.PORTRAIT_INVERTED; }
    else if (value === '5') { orientation = window.Orientation.LANDSCAPE_INVERTED; }
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      if (requestId !== this.readerOrientationRequestId) { return; }
      if (captureOriginal && !this.originalReaderOrientationCaptured) {
        this.originalReaderOrientation = targetWindow.getPreferredOrientation();
        this.originalReaderOrientationCaptured = true;
      }
      targetWindow.setPreferredOrientation(orientation).catch(() => {});
    }).catch(() => {});
  }

  private restoreReaderOrientation(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const requestId = ++this.readerOrientationRequestId;
    const orientation = this.originalReaderOrientationCaptured
      ? this.originalReaderOrientation : window.Orientation.UNSPECIFIED;
    this.originalReaderOrientationCaptured = false;
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      if (requestId !== this.readerOrientationRequestId) { return; }
      targetWindow.setPreferredOrientation(orientation).catch(() => {});
    }).catch(() => {});
  }

  private syncReaderSystemBars(forceVisible: boolean = false): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const requestId = ++this.readerSystemBarRequestId;
    const showStatusBar = forceVisible || this.controlsVisible || !this.hideStatusBar;
    const showNavigationBar = forceVisible || this.controlsVisible || !this.hideNavigationBar;
    window.getLastWindow(context).then((targetWindow: window.Window) => {
      if (requestId !== this.readerSystemBarRequestId) { return; }
      Promise.all([
        targetWindow.setSpecificSystemBarEnabled('status', showStatusBar, false),
        targetWindow.setSpecificSystemBarEnabled('navigation', showNavigationBar, false),
        targetWindow.setSpecificSystemBarEnabled('navigationIndicator', showNavigationBar, false)
      ]).catch(() => {});
    }).catch(() => {});
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

  onBookmarkTargetChanged(): void {
    if (this.bookmarkTargetPosition < 0) { return; }
    this.resolveStartPosition();
    this.pendingBookmarkTargetPosition = this.bookmarkTargetPosition;
    this.rebuildReaderPages(true);
  }

  onChapterTitleChanged(): void {
    this.resetPageTurnTransition();
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
    this.refreshDisplayChapterTitle();
    this.refreshContentProcesses();
  }

  onBookChanged(): void {
    this.onReadSessionStart();
    this.refreshDisplayChapterTitle();
    this.refreshContentProcesses();
  }

  onReplaceRulesChanged(): void {
    this.refreshDisplayChapterTitle();
    this.refreshContentProcesses();
  }

  private async refreshDisplayChapterTitle(): Promise<void> {
    const generation = ++this.titleGeneration;
    const title = this.chapterTitle;
    const bookId = this.book.id;
    const displayTitle = await ReplaceRuleRepository.applyTitle(this.book, title);
    this.onReplaceRulesRefresh();
    if (generation === this.titleGeneration && bookId === this.book.id && title === this.chapterTitle) {
      this.displayChapterTitle = displayTitle;
    }
  }

  private async refreshContentProcesses(): Promise<void> {
    const bookId = this.book.id;
    const chapterIndex = this.getChapterIndex();
    await BookContentProcessRepository.waitUntilLoaded();
    if (bookId === this.book.id && chapterIndex === this.getChapterIndex()) {
      this.contentProcesses = BookContentProcessRepository.getForChapter(bookId, chapterIndex);
      this.effectiveReplaceRuleIds = BookRepository.getEffectiveReplaceRuleIds(bookId, chapterIndex);
    }
  }
  onDisplayChapterTitleChanged(): void {
    this.rebuildReaderPages();
  }

  onReaderContentChanged(): void {
    this.resetPageTurnTransition();
    this.refreshContentProcesses();
    this.readerContentRevision++;
    this.imageSizes = new Map<string, ReaderIntrinsicImageSize>();
    this.contentHeight = 0;
    this.estimatedContentHeight = 0;
    this.scrollOffset = 0;
    this.restoredProgressPosition = false;
    this.currentPageIndex = 0;
    this.localReaderPages = [];
    this.localSemanticContent = '';
    this.localSemanticDocument = { paragraphs: [], content: '', sourceLength: 0, sourcePositionMap: [0] };
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
    this.sliderProgressIndex = this.pageAnimation === 3
      ? this.readerProgress
      : (this.progressBehavior === 'page' && this.localReaderPages.length > 0
        ? this.currentPageIndex : this.getChapterIndex());
  }

  private openReaderImage(uri: string): void {
    if (this.clickImageBehavior !== '1' || uri.length === 0) { return; }
    this.imagePreviewUri = uri;
    this.imagePreviewVisible = true;
    this.onOpenImagePreview(uri);
  }

  private closeReaderImagePreview(): void {
    if (!this.imagePreviewVisible) { return; }
    this.imagePreviewVisible = false;
    this.imagePreviewUri = '';
    this.onCloseImagePreview();
  }

  onImagePreviewCloseRevisionChanged(): void {
    this.closeReaderImagePreview();
  }

  onPageAnimationChanged(): void {
    this.resetPageTurnTransition();
    this.restoredProgressPosition = false;
    if (this.pageAnimation === 3) {
      this.scrollOffset = 0;
      this.contentHeight = 0;
      this.estimatedContentHeight = 0;
    } else {
      this.rebuildReaderPages();
    }
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

  private reverseContentByCodePoint(content: string): string {
    const characters: string[] = [];
    for (let index = 0; index < content.length; index++) {
      const firstUnit = content.charCodeAt(index);
      if (firstUnit >= 0xD800 && firstUnit <= 0xDBFF && index + 1 < content.length) {
        const secondUnit = content.charCodeAt(index + 1);
        if (secondUnit >= 0xDC00 && secondUnit <= 0xDFFF) {
          characters.push(content.substring(index, index + 2));
          index++;
          continue;
        }
      }
      characters.push(content.charAt(index));
    }
    let reversed: string = '';
    for (let index = characters.length - 1; index >= 0; index--) {
      reversed += characters[index] ?? '';
    }
    return reversed;
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

  private rebuildReaderPages(forceProgressCommit: boolean = false): void {
    if ((this.book.format !== 'txt' && this.book.format !== 'epub') ||
      this.readerContentWidth <= 0 || this.viewportHeight <= 0) {
      this.localReaderPages = [];
      return;
    }
    const context = this.getUIContext();
    const measureUtils = context.getMeasureUtils();
    const fontSize = this.fontSize * 1.05;
    const width = this.getBodyContentWidth();
    const lineHeight = this.fontSize * 1.25;
    const infoHeaderReserve = this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0;
    const infoFooterReserve = this.isReaderFooterVisible() ? this.getReaderInfoReserve(false) : 0;
    const pageHeight = Math.max(lineHeight, this.getBodyContentHeight(infoHeaderReserve, infoFooterReserve));
    // 当前 Android 书籍配置 paragraphSpacing=6，原版按行高的十分之六计算段距。
    const paragraphSpacing = lineHeight * 0.6;
    const document = LocalTextSemantics.parse(this.content);
    this.localSemanticContent = document.content;
    this.localSemanticDocument = document;
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
      textContent: this.displayChapterTitle,
      fontSize: this.fontSize + 4
    });
    const titleWidth = context.px2vp(this.toDimension(titleMetrics.width ?? 0));
    const titleLines = this.displayChapterTitle.length > 0 ? Math.max(1, Math.ceil(titleWidth / width)) : 0;
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
    const nextPages: LocalReaderPage[] = [];
    const titlePageInserted = this.activeImageStyle === 'SINGLE' && this.displayChapterTitle.length > 0;
    if (titlePageInserted) {
      nextPages.push({ lines: [], startPosition: 0, endPosition: 0, titleOnly: true });
    }
    for (let pageIndex = 0; pageIndex < paginatedPages.length; pageIndex++) {
      const page = paginatedPages[pageIndex];
      if (page !== undefined) { nextPages.push(page); }
    }
    const percentPosition = Math.round(this.localSemanticContent.length * (this.book.chapterProgress ?? 0) / 100);
    let targetPosition = percentPosition;
    if (this.pendingBookmarkTargetPosition >= 0) {
      targetPosition = this.pendingBookmarkTargetPosition;
    } else if (this.startPositionPending) {
      targetPosition = 0;
    } else {
      const savedPosition = Math.max(0, this.book.androidCharacterPosition ?? 0);
      if (this.book.readerPositionVersion === 2 && savedPosition > 0) {
        targetPosition = LocalTextSemantics.toRenderPosition(this.localSemanticDocument, savedPosition);
      } else if (this.book.readerPositionVersion === 1 && savedPosition > 0) {
        // 旧 HOS 版本保存的是包含显示缩进的渲染坐标，按原值恢复以保住已有进度。
        targetPosition = savedPosition;
      }
    }
    let pageIndex = 0;
    if (!(titlePageInserted && targetPosition === 0)) {
      for (let index = 0; index < nextPages.length; index++) {
        const page = nextPages[index];
        if (page === undefined || page.titleOnly) { continue; }
        if (page.startPosition > targetPosition) { break; }
        pageIndex = index;
      }
    }
    this.localReaderPages = nextPages;
    this.currentPageIndex = pageIndex;
    const consumedBookmarkTarget = this.pendingBookmarkTargetPosition >= 0;
    this.pendingBookmarkTargetPosition = -1;
    if (this.pageAnimation !== 3 && forceProgressCommit) {
      this.reportReaderPageProgress();
    } else if (this.pageAnimation !== 3) {
      this.sliderProgressIndex = this.progressBehavior === 'page'
        ? this.currentPageIndex : this.getChapterIndex();
    }
    this.requestFullBookPagination();
    if (consumedBookmarkTarget) { this.onBookmarkTargetConsumed(); }
  }

  private reportReaderPageProgress(): void {
    const page = this.localReaderPages[this.currentPageIndex];
    if (page === undefined) { return; }
    this.resolveStartPosition();
    this.sliderProgressIndex = this.progressBehavior === 'page'
      ? this.currentPageIndex : this.getChapterIndex();
    const renderPosition = Math.max(0, Math.min(this.localSemanticContent.length, page.startPosition));
    const position = LocalTextSemantics.toSourcePosition(this.localSemanticDocument, renderPosition);
    const progress = this.localSemanticDocument.sourceLength > 0
      ? position / this.localSemanticDocument.sourceLength * 100 : 0;
    this.readerProgress = progress;
    this.lastReportedProgress = Math.round(progress);
    this.emitReaderProgress(progress, position, true);
  }

  private emitReaderProgress(progress: number, chapterPosition: number, androidCoordinate: boolean): void {
    this.onProgressChange(this.book.id, this.getChapterIndex(), progress, chapterPosition, androidCoordinate);
  }

  private getCurrentPageBookmarkRange(): ReaderBookmarkPageRange | undefined {
    const page = this.localReaderPages[this.currentPageIndex];
    if (page === undefined || page.titleOnly) { return undefined; }
    const renderStart = Math.max(0, Math.min(this.localSemanticContent.length, page.startPosition));
    const renderEnd = Math.max(renderStart, Math.min(this.localSemanticContent.length, page.endPosition));
    if (renderEnd <= renderStart) { return undefined; }
    const start = LocalTextSemantics.toSourcePosition(this.localSemanticDocument, renderStart);
    const end = LocalTextSemantics.toSourcePosition(this.localSemanticDocument, renderEnd);
    if (end <= start) { return undefined; }
    return { start: start, end: end, text: this.localSemanticContent.substring(renderStart, renderEnd).trim() };
  }

  private hasBookmarkOnCurrentPage(): boolean {
    const pageRange = this.getCurrentPageBookmarkRange();
    if (pageRange === undefined) { return false; }
    const chapterIndex = this.getChapterIndex();
    for (let index = 0; index < this.bookmarks.length; index++) {
      const bookmark = this.bookmarks[index];
      if (bookmark !== undefined && bookmark.bookId === this.book.id &&
        bookmark.chapterIndex === chapterIndex && bookmark.chapterPosition >= pageRange.start &&
        bookmark.chapterPosition < pageRange.end) { return true; }
    }
    return false;
  }

  private updateBookmarkPull(event: GestureEvent): void {
    if (!this.swipeToAddBookmark || !this.book.isLocal || this.pageAnimation === 3 ||
      event.offsetY <= 0 || event.offsetY <= Math.abs(event.offsetX) * 1.5) {
      this.bookmarkPullOffset = 0;
      this.bookmarkPullArmed = false;
      return;
    }
    this.bookmarkPullOffset = Math.min(event.offsetY, Math.max(0, this.viewportHeight * 0.6));
    this.bookmarkPullArmed = event.offsetY >= 80;
  }

  private finishBookmarkPull(event: GestureEvent): void {
    this.updateBookmarkPull(event);
    const shouldToggle = this.bookmarkPullArmed;
    const pageRange = shouldToggle ? this.getCurrentPageBookmarkRange() : undefined;
    this.bookmarkPullOffset = 0;
    this.bookmarkPullArmed = false;
    if (pageRange !== undefined) {
      this.onToggleCurrentPageBookmark(pageRange.start, pageRange.end, pageRange.text);
    }
  }

  private turnReaderPage(delta: number): void {
    if (this.pageTurnAnimating) { return; }
    if (this.usesLocalPagination() && this.localReaderPages.length === 0) { return; }
    if (this.pageAnimation === 3) {
      let totalScrollHeight = Math.max(0, this.contentHeight - this.viewportHeight);
      try {
        totalScrollHeight = Math.max(totalScrollHeight,
          this.toDimension(this.readerScroller.contentSize().height) - this.viewportHeight);
      } catch (_) {
      }
      if ((delta < 0 && this.scrollOffset <= 1) || (delta > 0 && this.scrollOffset >= totalScrollHeight - 1)) {
        this.onTurnChapterBoundary(delta);
        return;
      }
      this.scrollOffset = Math.max(0, Math.min(totalScrollHeight, this.scrollOffset + delta * this.viewportHeight));
      try {
        this.readerScroller.scrollTo({
          xOffset: 0, yOffset: this.scrollOffset, animation: !this.noAnimScrollPage
        });
      } catch (_) {
      }
      this.updateProgress();
      return;
    }
    const nextPageIndex = this.currentPageIndex + delta;
    this.resolveStartPosition();
    if (nextPageIndex < 0 || nextPageIndex >= this.localReaderPages.length) {
      this.onTurnChapterBoundary(delta);
      return;
    }
    if (this.pageAnimation === 5) {
      this.currentPageIndex = nextPageIndex;
      this.reportReaderPageProgress();
      return;
    }
    const durationBySpeed: number[] = [240, 300, 360, 540];
    const duration = durationBySpeed[this.animationSpeed] ?? 360;
    const direction: number = delta > 0 ? -1 : 1;
    const reverseDirection: number = delta > 0 ? 1 : -1;
    const pageWidth = Math.max(1, this.readerContentWidth);
    const pageHeight = Math.max(1, this.viewportHeight);
    const horizontalTravel = this.pageAnimation === 0 ? pageWidth :
      this.pageAnimation === 1 ? Math.min(140, pageWidth * 0.18) :
      this.pageAnimation === 2 ? Math.min(72, pageWidth * 0.07) : 0;
    const verticalTravel = this.pageAnimation === 3 ? Math.min(180, pageHeight * 0.18) : 0;
    const fade = this.pageAnimation === 2 || this.pageAnimation === 4;
    this.pageTurnAnimating = true;
    animateTo({ duration: duration / 2, curve: Curve.EaseIn }, () => {
      this.pageTurnOffsetX = direction * horizontalTravel;
      this.pageTurnOffsetY = direction * verticalTravel;
      this.pageTurnOpacity = fade ? 0 : 1;
    });
    this.pageTurnTimer = setTimeout(() => {
      this.currentPageIndex = nextPageIndex;
      this.reportReaderPageProgress();
      this.pageTurnOffsetX = reverseDirection * horizontalTravel;
      this.pageTurnOffsetY = reverseDirection * verticalTravel;
      this.pageTurnOpacity = fade ? 0 : 1;
      animateTo({ duration: duration / 2, curve: Curve.EaseOut }, () => {
        this.pageTurnOffsetX = 0;
        this.pageTurnOffsetY = 0;
        this.pageTurnOpacity = 1;
      });
      this.pageTurnAnimating = false;
      this.pageTurnTimer = -1;
    }, duration / 2);
  }

  private resetPageTurnTransition(): void {
    if (this.pageTurnTimer >= 0) {
      clearTimeout(this.pageTurnTimer);
      this.pageTurnTimer = -1;
    }
    this.pageTurnOffsetX = 0;
    this.pageTurnOffsetY = 0;
    this.pageTurnOpacity = 1;
    this.pageTurnAnimating = false;
  }

  private turnReaderChapter(delta: number): void {
    this.onSelectChapterIndex(this.getChapterIndex() + delta);
  }

  private handleReaderTap(event: ClickEvent): void {
    this.handleReaderTapAt(event.x, event.y);
  }

  private handleReaderTapAt(x: number, y: number): void {
    const now = Date.now();
    if (now - this.lastReaderTapTimestamp < 90) { return; }
    this.lastReaderTapTimestamp = now;
    if (this.readerContentWidth <= 0 || this.viewportHeight <= 0) { return; }
    const column = Math.max(0, Math.min(2, Math.floor(x / this.readerContentWidth * 3)));
    const row = Math.max(0, Math.min(2, Math.floor(y / this.viewportHeight * 3)));
    this.performReaderTapAction(row * 3 + column);
  }

  private performReaderTapAction(index: number): void {
    const action = this.clickRegionActions[index] ?? '无操作';
    if (action === '无操作') { return; }
    if (action === '菜单') {
      setTimeout(() => {
        this.controlsVisible = !this.controlsVisible;
      }, 100);
      return;
    }
    if (action === '下一页') { this.turnReaderPage(1); return; }
    if (action === '上一页') { this.turnReaderPage(-1); return; }
    if (action === '下一章') { this.turnReaderChapter(1); return; }
    if (action === '上一章') { this.turnReaderChapter(-1); return; }
    if (action === '添加书签') { this.addCurrentPageBookmark(); return; }
    if (action === '编辑内容') {
      this.contentEditTitle = this.chapterTitle;
      this.contentEditBody = this.content;
      this.contentEditVisible = true;
      return;
    }
    if (action === '替换(启用/禁用)') { this.onReplaceEnabledChange(!this.replaceEnabled); return; }
    if (action === '目录') { this.onOpenCatalog(); return; }
    if (action === '全文搜索') { this.onOpenSearchContent(); return; }
    if (action === '同步阅读进度') { this.reportReaderPageProgress(); return; }
    this.onUnavailableAction(`${action}功能尚未迁移`);
  }

  private isPageProgressMode(): boolean {
    return this.pageAnimation !== 3 && this.progressBehavior === 'page' && this.localReaderPages.length > 0;
  }

  private getProgressSliderMaximum(): number {
    if (this.pageAnimation === 3) { return 100; }
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
    const actions: ReaderControlKind[] = [];
    this.bottomActions.forEach((item: ReaderBottomActionConfig) => {
      const option = READER_ACTION_OPTIONS.find((action: ReaderActionOption) => action.id === item.id);
      if (item.enabled && option !== undefined &&
        isReaderActionApplicable(option.id, this.book.isLocal, this.book.format)) {
        actions.push(option.id);
      }
    });
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
    const actions: ReaderBottomActionConfig[] = this.topActions.filter((item: ReaderBottomActionConfig) => {
      const option = READER_ACTION_OPTIONS.find((candidate: ReaderActionOption) => candidate.id === item.id);
      return item.enabled && option !== undefined &&
        isReaderActionApplicable(option.id, this.book.isLocal, this.book.format);
    });
    if (actions.length > 0) {
      // ArkUI 顶栏 Row 中后插入的配置项靠左，因此反转数据以保持视觉顺序与配置列表一致。
      return actions.reverse();
    }
    return [{ id: 'more_actions', enabled: true }];
  }

  private getTopActionKind(id: string): ReaderControlKind {
    const option = READER_ACTION_OPTIONS.find((candidate: ReaderActionOption) => candidate.id === id);
    return option?.id ?? 'more_actions';
  }

  @Builder
  private TopActionOverflowMenu() {
    Menu() {
      ForEach(this.getVisibleTopActions().slice(2), (action: ReaderBottomActionConfig) => {
        MenuItem({ content: this.getBottomActionLabel(action.id) })
          .onClick(() => this.selectBottomAction(this.getTopActionKind(action.id)))
      }, (action: ReaderBottomActionConfig) => action.id)
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(18)
  }

  @Builder
  private topActionButton(action: ReaderBottomActionConfig) {
    Stack({ alignContent: Alignment.Center }) {
      ReaderControlGlyph({ kind: this.getTopActionKind(action.id), glyphSize: 20 })
    }.width(40).height(40).margin({ left: 6 }).onClick(() => {
      this.selectBottomAction(this.getTopActionKind(action.id));
    })
  }

  private getBottomActionPageIndex(): number {
    return Math.max(0, Math.min(this.currentBottomActionPage, this.getBottomActionPages().length - 1));
  }

  private getBottomActionLabel(kind: string): string {
    const option = READER_ACTION_OPTIONS.find((item: ReaderActionOption) => item.id === kind);
    return option?.label ?? kind;
  }

  private selectBottomAction(kind: ReaderControlKind): void {
    if (kind === 'catalog') { this.onOpenCatalog(); }
    else if (kind === 'search') { this.onOpenSearchContent(); }
    else if (kind === 'autoPage') { this.toggleAutoPage(); }
    else if (kind === 'voice') { this.onUnavailableAction('朗读播放尚未迁移'); }
    else if (kind === 'settings') { this.onOpenSettings(); }
    else if (kind === 'addBookmark') { this.addCurrentPageBookmark(); }
    else if (kind === 'theme') { this.onToggleNightMode(); }
    else if (kind === 'eye_protection') { this.onToggleEyeProtection(); }
    else if (kind === 'prev_chapter') { this.onTurnChapterBoundary(-1); }
    else if (kind === 'next_chapter') { this.onTurnChapterBoundary(1); }
    else if (kind === 'replace') { this.textProcessingVisible = true; }
    else if (kind === 'more_actions') { this.overflowVisible = true; }
    else if (kind === 'charset') { this.openCharsetDialog(); }
    else if (kind === 'toc_rule') { this.onOpenTocRule(); }
    else { this.onUnavailableAction(this.getBottomActionLabel(kind) + '功能尚未迁移'); }
  }

  private addCurrentPageBookmark(): void {
    const page = this.localReaderPages[this.currentPageIndex];
    if (page === undefined) {
      this.onUnavailableAction('当前页尚未完成分页，暂时无法添加书签');
      return;
    }
    const start = Math.max(0, Math.min(this.localSemanticContent.length, page.startPosition));
    const end = Math.max(start, Math.min(this.localSemanticContent.length, page.endPosition));
    this.onAddBookmark(start, this.localSemanticContent.substring(start, end).trim());
  }

  private longSelectBottomAction(kind: ReaderControlKind): void {
    if (kind === 'voice') { this.onOpenReadAloud(); }
  }

  private isMoreActionApplicable(id: string): boolean {
    if (id === 'source_custom_button') { return false; }
    if (id === 'change_source' || id === 'refresh' || id === 'download') { return !this.book.isLocal; }
    if (id === 'toc_rule') { return this.book.isLocal && this.book.format === 'txt'; }
    if (id === 'charset') { return this.book.isLocal; }
    if (id === 'del_ruby' || id === 'del_h') { return this.book.isLocal && this.book.format === 'epub'; }
    if (id === 'get_progress' || id === 'cover_progress') { return false; }
    return true;
  }

  private getVisibleMoreActions(): ReaderMoreAction[] {
    const actions: ReaderMoreAction[] = [];
    this.moreActions.forEach((config: ReaderMoreActionConfig) => {
      const action = READER_MORE_ACTIONS.find((item: ReaderMoreAction) => item.id === config.id);
      if (config.enabled && action !== undefined && this.isMoreActionApplicable(action.id)) {
        actions.push(action);
      }
    });
    return [...actions, MORE_ACTION_CONFIG_ENTRY];
  }

  private getMoreAction(id: string): ReaderMoreAction | undefined {
    return READER_MORE_ACTIONS.find((item: ReaderMoreAction) => item.id === id);
  }

  private openMoreActionConfig(): void {
    this.draftMoreActions = this.moreActions.map((item: ReaderMoreActionConfig): ReaderMoreActionConfig => ({
      id: item.id,
      enabled: item.enabled
    }));
    this.moreActionConfigVisible = true;
  }

  private toggleMoreAction(id: string): void {
    this.draftMoreActions = this.draftMoreActions.map((item: ReaderMoreActionConfig): ReaderMoreActionConfig => ({
      id: item.id,
      enabled: item.id === id ? !item.enabled : item.enabled
    }));
  }

  private moveMoreAction(index: number, delta: number): void {
    const target = index + delta;
    if (target < 0 || target >= this.draftMoreActions.length) { return; }
    const updated = this.draftMoreActions.map((item: ReaderMoreActionConfig): ReaderMoreActionConfig => ({
      id: item.id,
      enabled: item.enabled
    }));
    const current = updated[index];
    const neighbor = updated[target];
    if (current === undefined || neighbor === undefined) { return; }
    updated[index] = neighbor;
    updated[target] = current;
    this.draftMoreActions = updated;
  }

  @Builder
  private moreActionConfigRow(config: ReaderMoreActionConfig, index: number) {
    Row() {
      AppGlyph({ name: this.getMoreAction(config.id)?.glyph ?? 'more', glyphSize: 20,
        tint: config.enabled ? '#D5C2C6' : '#777984' }).margin({ right: 12 })
      Column() {
        Text(this.getMoreAction(config.id)?.label ?? config.id).fontSize(14)
          .fontColor(config.enabled ? '#E5E6EB' : '#777984')
        if ((this.getMoreAction(config.id)?.scopeLabel ?? '').length > 0) {
          Text(this.getMoreAction(config.id)?.scopeLabel ?? '')
            .fontSize(10).fontColor('#92949E').margin({ top: 2 })
        }
        if (this.getMoreAction(config.id)?.migrated === false) {
          Text('未迁移').fontSize(10).fontColor('#92949E').margin({ top: 2 })
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Stack({ alignContent: Alignment.Center }) {
        Image(config.enabled ? $r('app.media.app_visibility') : $r('app.media.reader_visibility_off'))
          .width(20).height(20).fillColor(config.enabled ? '#D5C2C6' : '#777984')
      }.width(36).height(36).borderRadius(18).backgroundColor('#292A31')
        .onClick(() => this.toggleMoreAction(config.id))
      Column() {
        Image($r('app.media.reader_reorder_up')).width(16).height(16)
          .fillColor(index === 0 ? '#555761' : '#B9BBC4')
          .onClick(() => this.moveMoreAction(index, -1))
        Image($r('app.media.reader_reorder_down')).width(16).height(16)
          .fillColor(index === this.draftMoreActions.length - 1 ? '#555761' : '#B9BBC4')
          .onClick(() => this.moveMoreAction(index, 1))
      }.width(24).height(36).justifyContent(FlexAlign.SpaceBetween).margin({ left: 4 })
      Image($r('app.media.reader_drag_handle')).width(20).height(20).fillColor('#B9BBC4')
        .width(32).height(36)
    }.width('100%').padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor('#202127').borderRadius(12).margin({ bottom: 8 })
  }

  private selectMoreAction(action: ReaderMoreAction): void {
    this.overflowVisible = false;
    if (action.id === 'configure_more_actions') {
      this.openMoreActionConfig();
    } else if (action.id === 'add_bookmark') {
      this.addCurrentPageBookmark();
    } else if (action.id === 'edit_content') {
      this.contentEditTitle = this.chapterTitle;
      this.contentEditBody = this.content;
      this.contentEditVisible = true;
    } else if (action.id === 'reverse_content') {
      const page = this.localReaderPages[this.currentPageIndex];
      this.pendingBookmarkTargetPosition = page?.startPosition ?? 0;
      this.onSaveChapterContent(this.getChapterIndex(), this.chapterTitle,
        this.reverseContentByCodePoint(this.content));
    } else if (action.id === 're_segment') {
      const page = this.localReaderPages[this.currentPageIndex];
      this.pendingBookmarkTargetPosition = page?.startPosition ?? 0;
      this.onToggleReSegment(this.book.reSegment !== true);
    } else if (action.id === 'text_processing') {
      this.textProcessingVisible = true;
    } else if (action.id === 'charset') {
      this.openCharsetDialog();
    } else if (action.id === 'toc_rule') {
      this.onOpenTocRule();
    } else if (action.id === 'image_style') {
      this.imageStyleMenuVisible = true;
    } else if (action.id === 'read_style') {
      this.onOpenSettings();
    } else if (action.id === 'highlight_rule') {
      this.onOpenHighlightRules();
    } else if (action.id === 'bottom_button_config') {
      this.onOpenBottomActionConfig();
    } else {
      const option = this.getMoreAction(action.id);
      this.moreActionShellTitle = option?.label ?? action.label;
      this.moreActionShellVisible = true;
    }
  }

  @Builder
  private moreActionUnavailableSheet() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#99000000')
        .onClick(() => this.moreActionShellVisible = false)
      Column() {
        Row() {
          Text(this.moreActionShellTitle).fontSize(18).fontWeight(FontWeight.Medium).fontColor('#E5E6EB')
            .layoutWeight(1)
          Text('关闭').fontSize(13).fontColor('#C7C9D1').onClick(() => this.moreActionShellVisible = false)
        }.width('100%').padding({ bottom: 14 })
        Text('此操作尚未迁移，当前不会执行。')
          .fontSize(14).fontColor('#B7B8C1').width('100%')
        Row() {
          Text('知道了').fontSize(14).fontColor('#101116')
            .padding({ left: 22, right: 22, top: 10, bottom: 10 })
            .backgroundColor('#B9C6FF').borderRadius(18)
            .onClick(() => this.moreActionShellVisible = false)
        }.width('100%').justifyContent(FlexAlign.End).margin({ top: 20 })
      }.width('86%').padding(18).backgroundColor('#1A1B21').borderRadius(20)
    }.width('100%').height('100%')
  }

  @Builder
  private moreActionConfigurationSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor('#99000000')
        .onClick(() => this.moreActionConfigVisible = false)
      Column() {
        Row().width(32).height(4).backgroundColor('#C5C6CD').borderRadius(4).margin({ top: 10, bottom: 14 })
        Row() {
          Text('更多操作配置').fontSize(17).fontColor('#E5E6EB').layoutWeight(1)
          Text('取消').fontSize(13).fontColor('#C7C9D1').margin({ right: 18 })
            .onClick(() => this.moreActionConfigVisible = false)
          Text('保存').fontSize(13).fontColor('#C6D3FF')
            .onClick(() => {
              this.onMoreActionsChange(this.draftMoreActions.map(
                (item: ReaderMoreActionConfig): ReaderMoreActionConfig => ({ id: item.id, enabled: item.enabled })
              ));
              this.moreActionConfigVisible = false;
            })
        }.width('100%').padding({ left: 18, right: 18, bottom: 12 })
        Scroll() {
          Column() {
            ForEach(this.draftMoreActions, (config: ReaderMoreActionConfig, index: number) => {
              this.moreActionConfigRow(config, index)
            }, (config: ReaderMoreActionConfig) => config.id)
          }.width('100%').padding({ left: 14, right: 14, bottom: 12 })
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
      }.width('100%').height('62%').backgroundColor('#D91A1B21')
        .borderRadius({ topLeft: 24, topRight: 24 })
    }.width('100%').height('100%')
  }

  private getWholeBookProgress(): number {
    const chapterCount = this.getChapterCount();
    const chapterIndex = this.getChapterIndex();
    if (this.pageAnimation !== 3) {
      const pageCount = this.localReaderPages.length;
      if (pageCount === 0 && chapterIndex === 0) { return 0; }
      const chapterProgress = pageCount > 0 ? (this.currentPageIndex + 1) / pageCount : 1;
      let progress = (chapterIndex + chapterProgress) / chapterCount * 100;
      if (progress >= 100 && (chapterIndex + 1 !== chapterCount || this.currentPageIndex + 1 !== pageCount)) {
        progress = 99.9;
      }
      return Math.max(0, Math.min(100, progress));
    }
    return Math.max(0, Math.min(100,
      (chapterIndex + this.readerProgress / 100) / chapterCount * 100));
  }

  private needsFullBookPageData(): boolean {
    const values: number[] = [
      this.infoSettings.tipHeaderLeft, this.infoSettings.tipHeaderMiddle, this.infoSettings.tipHeaderRight,
      this.infoSettings.tipFooterLeft, this.infoSettings.tipFooterMiddle, this.infoSettings.tipFooterRight
    ];
    const templates: string[] = [
      this.infoSettings.customTipHeaderLeft, this.infoSettings.customTipHeaderMiddle,
      this.infoSettings.customTipHeaderRight, this.infoSettings.customTipFooterLeft,
      this.infoSettings.customTipFooterMiddle, this.infoSettings.customTipFooterRight
    ];
    for (let index = 0; index < values.length; index++) {
      const value = values[index] ?? 0;
      const template = templates[index] ?? '';
      if (value === 19 || value === 20 || (value === 18 &&
        (template.includes('{FullPageIndex}') || template.includes('{FullPageSize}')))) {
        return true;
      }
    }
    return false;
  }

  private getFullBookPaginationLayoutKey(): string {
    const replaceKey = JSON.stringify([
      ReplaceRuleRepository.isBookEnabled(this.book),
      this.replaceRules.map((rule: ReplaceRule) => [
        rule.id, rule.name, rule.pattern, rule.replacement, rule.scope,
        rule.scopeTitle, rule.scopeContent, rule.excludeScope, rule.isEnabled,
        rule.isRegex, rule.timeoutMillisecond, rule.order
      ])
    ]);
    const processKey = JSON.stringify(BookContentProcessRepository.getAll()
      .filter((process: BookContentProcess) => process.bookUrl === this.book.id)
      .sort((left: BookContentProcess, right: BookContentProcess) =>
        left.id < right.id ? -1 : left.id > right.id ? 1 : 0)
      .map((process: BookContentProcess) => [
        process.id, process.chapterIndex, process.kind, process.stage, process.target,
        process.anchorJson, process.actionJson, process.styleJson, process.sourceContentHash,
        process.enabled, process.sortOrder, process.status, process.schemaVersion, process.updatedAt
      ]));
    const chapterKey = JSON.stringify([
      this.book.chapterTitles ?? [],
      this.book.chapterOffsets ?? []
    ]);
    return [
      this.book.id, this.book.contentPath ?? '', this.readerContentRevision, this.fontSize,
      this.readerContentWidth, this.viewportHeight, this.activeImageStyle,
      JSON.stringify(this.paddingSettings),
      this.infoSettings.headerMode, this.infoSettings.footerMode,
      this.infoSettings.headerFontSize, this.infoSettings.footerFontSize, this.infoSettings.applyHeaderStyle,
      chapterKey, replaceKey, processKey
    ].join('|');
  }

  private requestFullBookPagination(): void {
    if (!this.needsFullBookPageData() || !this.book.isLocal || this.book.contentPath === undefined) {
      if (this.fullBookPaginationKey !== '' || this.fullBookPageCounts.length > 0) {
        this.fullBookPaginationGeneration++;
        this.fullBookPaginationKey = '';
        this.fullBookPageCounts = [];
        this.fullBookPaginationReady = false;
      }
      return;
    }
    if (this.readerContentWidth <= 0 || this.viewportHeight <= 0) { return; }
    const key = this.getFullBookPaginationLayoutKey();
    if (this.fullBookPaginationKey === key) { return; }
    this.fullBookPaginationKey = key;
    this.fullBookPaginationReady = false;
    this.fullBookPageCounts = [];
    const generation = ++this.fullBookPaginationGeneration;
    this.paginateFullBookPages(key, generation).catch(() => {
      if (generation === this.fullBookPaginationGeneration) {
        this.fullBookPaginationKey = '';
        this.fullBookPageCounts = [];
        this.fullBookPaginationReady = false;
      }
    });
  }

  private async paginateFullBookPages(key: string, generation: number): Promise<void> {
    const context = this.getUIContext();
    const measureUtils = context.getMeasureUtils();
    const fontSize = this.fontSize * 1.05;
    const width = this.getBodyContentWidth();
    const lineHeight = this.fontSize * 1.25;
    const infoHeaderReserve = this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0;
    const infoFooterReserve = this.isReaderFooterVisible() ? this.getReaderInfoReserve(false) : 0;
    const pageHeight = Math.max(lineHeight, this.getBodyContentHeight(infoHeaderReserve, infoFooterReserve));
    const paragraphSpacing = lineHeight * 0.6;
    const imageSizes = new Map<string, ReaderIntrinsicImageSize>(this.imageSizes);
    const glyphWidths = new Map<string, number>();
    let scannedGlyphCount = 0;
    let measuredGlyphCount = 0;
    const yieldToUi = async (): Promise<void> => {
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 0));
    };
    const cacheGlyphWidths = async (text: string): Promise<void> => {
      let cursor = 0;
      while (cursor < text.length) {
        const codePoint = text.codePointAt(cursor);
        const nextCursor = cursor + (codePoint !== undefined && codePoint > 0xFFFF ? 2 : 1);
        const glyph = text.substring(cursor, nextCursor);
        if (!glyphWidths.has(glyph)) {
          const metrics = measureUtils.measureTextSize({ textContent: glyph, fontSize: fontSize });
          glyphWidths.set(glyph, context.px2vp(this.toDimension(metrics.width ?? 0)));
          measuredGlyphCount++;
          if (measuredGlyphCount % 8 === 0) { await yieldToUi(); }
        }
        cursor = nextCursor;
        scannedGlyphCount++;
        if (scannedGlyphCount % 512 === 0) { await yieldToUi(); }
      }
    };
    const cacheDocumentGlyphWidths = async (document: LocalSemanticDocument): Promise<void> => {
      for (let paragraphIndex = 0; paragraphIndex < document.paragraphs.length; paragraphIndex++) {
        const paragraph = document.paragraphs[paragraphIndex];
        if (paragraph === undefined) { continue; }
        for (let partIndex = 0; partIndex < paragraph.parts.length; partIndex++) {
          const part = paragraph.parts[partIndex];
          if (part?.kind === 'text') { await cacheGlyphWidths(part.value); }
        }
        if (paragraphIndex % 8 === 7) { await yieldToUi(); }
      }
    };
    const measureFromGlyphCache = (text: string): number => {
      let totalWidth = 0;
      let cursor = 0;
      while (cursor < text.length) {
        const codePoint = text.codePointAt(cursor);
        const nextCursor = cursor + (codePoint !== undefined && codePoint > 0xFFFF ? 2 : 1);
        totalWidth += glyphWidths.get(text.substring(cursor, nextCursor)) ?? 0;
        cursor = nextCursor;
      }
      return totalWidth;
    };
    const inlineImageWidth = context.px2vp(this.toDimension(
      measureUtils.measureTextSize({ textContent: '袮', fontSize: fontSize }).width ?? 0
    ));
    const pageCounts: number[] = [];
    await BookRepository.forEachChapter(this.book, async (
      chapterContent: string,
      chapterIndex: number
    ): Promise<boolean> => {
      if (generation !== this.fullBookPaginationGeneration || key !== this.getFullBookPaginationLayoutKey()) {
        return false;
      }
      const rawTitle = this.book.chapterTitles?.[chapterIndex] ??
        (chapterIndex === this.getChapterIndex() ? this.chapterTitle : '');
      const displayTitle = await ReplaceRuleRepository.applyTitle(this.book, rawTitle);
      const document = LocalTextSemantics.parse(chapterContent);
      await cacheGlyphWidths(displayTitle);
      await cacheDocumentGlyphWidths(document);
      await this.loadImageSizesForDocument(document, imageSizes);
      const titleWidth = measureFromGlyphCache(displayTitle) * (this.fontSize + 4) / fontSize;
      const titleLines = displayTitle.length > 0 ? Math.max(1, Math.ceil(titleWidth / width)) : 0;
      const titleReservedLines = Math.ceil((titleLines * (this.fontSize + 4) * 1.25 + 12) / lineHeight);
      const pageCount = chapterIndex === this.getChapterIndex() && this.localReaderPages.length > 0
        ? this.localReaderPages.length
        : await LocalReaderPaginator.countPagesIncrementally(
          document,
          width,
          pageHeight,
          lineHeight,
          paragraphSpacing,
          (text: string): number => measureFromGlyphCache(text),
          imageSizes,
          this.activeImageStyle,
          context.px2vp(80),
          inlineImageWidth,
          this.activeImageStyle === 'SINGLE' ? 0 : titleReservedLines
        );
      const titlePageCount = this.activeImageStyle === 'SINGLE' && displayTitle.length > 0 ? 1 : 0;
      pageCounts.push(pageCount + titlePageCount);
      return true;
    });
    const expectedChapterCount = this.book.chapterTitles !== undefined && this.book.chapterTitles.length > 0
      ? this.book.chapterTitles.length : 1;
    if (generation === this.fullBookPaginationGeneration && key === this.getFullBookPaginationLayoutKey() &&
      pageCounts.length === expectedChapterCount) {
      this.fullBookPageCounts = pageCounts;
      this.fullBookPaginationReady = true;
    }
  }

  private async loadImageSizesForDocument(
    document: LocalSemanticDocument,
    sizes: Map<string, ReaderIntrinsicImageSize>
  ): Promise<void> {
    for (let paragraphIndex = 0; paragraphIndex < document.paragraphs.length; paragraphIndex++) {
      const paragraph = document.paragraphs[paragraphIndex];
      if (paragraph === undefined) { continue; }
      for (let partIndex = 0; partIndex < paragraph.parts.length; partIndex++) {
        const part = paragraph.parts[partIndex];
        if (part?.kind !== 'image' || sizes.has(part.value)) { continue; }
        let source: image.ImageSource | undefined = undefined;
        try {
          source = image.createImageSource(part.value);
          const info = await source.getImageInfo();
          if (info.size.width > 0 && info.size.height > 0) {
            const density = info.density > 0 ? info.density / 160 : 1;
            const context = this.getUIContext();
            sizes.set(part.value, {
              width: context.px2vp(info.size.width / density),
              height: context.px2vp(info.size.height / density)
            });
          }
        } catch (_) {
        } finally {
          if (source !== undefined) {
            try { await source.release(); } catch (_) {}
          }
        }
      }
    }
  }

  private getWholeBookPageIndex(): number {
    if (!this.fullBookPaginationReady || this.pageAnimation === 3) { return -1; }
    const chapterIndex = this.getChapterIndex();
    if (chapterIndex < 0 || chapterIndex >= this.fullBookPageCounts.length) { return -1; }
    let pageIndex = this.currentPageIndex + 1;
    for (let index = 0; index < chapterIndex; index++) {
      pageIndex += this.fullBookPageCounts[index] ?? 0;
    }
    return pageIndex;
  }

  private getWholeBookPageCount(): number {
    if (!this.fullBookPaginationReady || this.pageAnimation === 3) { return -1; }
    let total = 0;
    for (let index = 0; index < this.fullBookPageCounts.length; index++) {
      total += this.fullBookPageCounts[index] ?? 0;
    }
    return total;
  }

  private getWholeBookPageText(): string {
    const index = this.getWholeBookPageIndex();
    const count = this.getWholeBookPageCount();
    return index < 0 || count < 0 ? '全文 - / -' : `${index}/${count}`;
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

  private getBodyContentWidth(): number {
    return Math.max(1, this.readerContentWidth - this.paddingSettings.paddingLeft - this.paddingSettings.paddingRight);
  }

  private getBodyContentHeight(headerReserve: number, footerReserve: number): number {
    return Math.max(1, this.viewportHeight - this.paddingSettings.paddingTop -
      this.paddingSettings.paddingBottom - headerReserve - footerReserve);
  }

  private getReaderInfoReserve(isHeader: boolean): number {
    const top = isHeader ? this.paddingSettings.headerPaddingTop : this.paddingSettings.footerPaddingTop;
    const bottom = isHeader ? this.paddingSettings.headerPaddingBottom : this.paddingSettings.footerPaddingBottom;
    return 22 + top + bottom;
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

  private getCurrentPageSelectionParts(): ReaderTextSelectionPart[] {
    const parts: ReaderTextSelectionPart[] = [];
    const lines = this.localReaderPages[this.currentPageIndex]?.lines ?? [];
    if (!this.currentPageContainsImages()) {
      const joinedPart = this.createJoinedPageSelectionPart();
      if (joinedPart.value.length > 0) { parts.push(joinedPart); }
      return parts;
    }
    for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      const line = lines[lineIndex];
      if (line === undefined) { continue; }
      if (this.readerLineContainsImage(line)) {
        for (let itemIndex = 0; itemIndex < line.items.length; itemIndex++) {
          const item = line.items[itemIndex];
          if (item !== undefined && item.kind === 'text') {
            parts.push(this.createReaderTextSelectionPart([item]));
          }
        }
      } else {
        parts.push(this.createReaderTextSelectionPart(line.items));
      }
    }
    return parts;
  }

  private currentPageContainsImages(): boolean {
    const lines = this.localReaderPages[this.currentPageIndex]?.lines ?? [];
    for (let index = 0; index < lines.length; index++) {
      const line = lines[index];
      if (line !== undefined && this.readerLineContainsImage(line)) { return true; }
    }
    return false;
  }

  private createJoinedPageSelectionPart(): ReaderTextSelectionPart {
    const lines = this.localReaderPages[this.currentPageIndex]?.lines ?? [];
    let value: string = '';
    const positions: number[] = [];
    for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      const line = lines[lineIndex];
      if (line === undefined) { continue; }
      const linePart = this.createReaderTextSelectionPart(line.items);
      if (linePart.value.length === 0) { continue; }
      if (positions.length === 0) {
        positions.push(linePart.positions[0] ?? line.startPosition);
      } else {
        value += '\n';
        positions.push(linePart.positions[0] ?? line.startPosition);
      }
      value += linePart.value;
      for (let offset = 1; offset < linePart.positions.length; offset++) {
        positions.push(linePart.positions[offset] ?? line.endPosition);
      }
    }
    if (positions.length === 0) { positions.push(0); }
    return { value: value, positions: positions };
  }

  private readerLineContainsImage(line: LocalReaderLine): boolean {
    for (let index = 0; index < line.items.length; index++) {
      if (line.items[index]?.kind === 'image') { return true; }
    }
    return false;
  }

  private createReaderTextSelectionPart(items: LocalReaderLineItem[]): ReaderTextSelectionPart {
    let value: string = '';
    const positions: number[] = [];
    for (let itemIndex = 0; itemIndex < items.length; itemIndex++) {
      const item = items[itemIndex];
      if (item === undefined || item.kind !== 'text') { continue; }
      if (positions.length === 0) { positions.push(item.startPosition); }
      else { positions[positions.length - 1] = item.startPosition; }
      value += item.value;
      for (let offset = 0; offset < item.value.length; offset++) {
        positions.push(item.startPosition + offset + 1);
      }
    }
    if (positions.length === 0) { positions.push(0); }
    return { value: value, positions: positions };
  }

  private getReaderSelectionPartIndex(lineIndex: number, itemIndex: number = -1): number {
    if (!this.currentPageContainsImages()) { return 0; }
    const lines = this.localReaderPages[this.currentPageIndex]?.lines ?? [];
    let partIndex: number = 0;
    for (let index = 0; index < Math.min(lineIndex, lines.length); index++) {
      const line = lines[index];
      if (line === undefined) { continue; }
      if (this.readerLineContainsImage(line)) {
        for (let item = 0; item < line.items.length; item++) {
          if (line.items[item]?.kind === 'text') { partIndex++; }
        }
      } else if (line.items.some((item: LocalReaderLineItem) => item.kind === 'text')) {
        partIndex++;
      }
    }
    const currentLine = lines[lineIndex];
    if (currentLine !== undefined && this.readerLineContainsImage(currentLine)) {
      for (let item = 0; item < Math.max(0, itemIndex); item++) {
        if (currentLine.items[item]?.kind === 'text') { partIndex++; }
      }
    }
    return partIndex;
  }

  private updatePendingLineSelection(partIndex: number, selectionStart: number, selectionEnd: number): void {
    const parts = this.getCurrentPageSelectionParts();
    const part = parts[partIndex];
    if (part === undefined) { return; }
    const start = Math.max(0, Math.min(part.value.length, Math.trunc(Math.min(selectionStart, selectionEnd))));
    const end = Math.max(start, Math.min(part.value.length, Math.trunc(Math.max(selectionStart, selectionEnd))));
    if (end <= start) {
      this.pendingMarkingRanges.delete(partIndex);
    } else {
      const range: ReaderMarkingRange = { start: start, end: end };
      this.pendingMarkingRanges.set(partIndex, range);
    }
    this.rebuildPendingMarkingRange();
  }

  private rebuildPendingMarkingRange(): void {
    const parts = this.getCurrentPageSelectionParts();
    const ranges = Array.from(this.pendingMarkingRanges.entries()).sort((first, second) => first[0] - second[0]);
    if (ranges.length === 0) {
      this.pendingMarkingStart = -1;
      this.pendingMarkingEnd = -1;
      this.pendingMarkingText = '';
      return;
    }
    const firstPart = parts[ranges[0]?.[0] ?? -1];
    const firstRange = ranges[0]?.[1];
    const lastPair = ranges[ranges.length - 1];
    const lastPart = parts[lastPair?.[0] ?? -1];
    if (firstPart === undefined || firstRange === undefined || lastPart === undefined || lastPair === undefined) { return; }
    const start = firstPart.positions[firstRange.start] ?? 0;
    const end = lastPart.positions[lastPair[1].end] ?? start;
    if (end <= start) {
      this.pendingMarkingStart = -1;
      this.pendingMarkingEnd = -1;
      this.pendingMarkingText = '';
      return;
    }
    const rawText = this.localSemanticContent.substring(start, end);
    const leftTrim = rawText.length - rawText.trimStart().length;
    const selectedText = rawText.trim();
    this.pendingMarkingStart = start + leftTrim;
    this.pendingMarkingEnd = this.pendingMarkingStart + selectedText.length;
    this.pendingMarkingText = selectedText;
  }

  private createMarkingFromCurrentSelection(): void {
    const start = this.pendingMarkingStart;
    const end = this.pendingMarkingEnd;
    const selectedText = this.pendingMarkingText;
    this.pendingMarkingStart = -1;
    this.pendingMarkingEnd = -1;
    this.pendingMarkingText = '';
    if (!this.book.isLocal || this.book.bodyMissing === true) {
      this.onUnavailableAction('划线与笔记仅支持已有本地正文的书籍');
      return;
    }
    if (start < 0 || end <= start || selectedText.length === 0) {
      this.onUnavailableAction('没有取得有效的正文选区，请重新选择文字');
      return;
    }
    this.onCreateMarking(start, end, selectedText);
  }

  private getMarkingForTextRange(start: number, end: number): ReaderMarking | undefined {
    const chapterIndex = this.getChapterIndex();
    for (let index = this.markings.length - 1; index >= 0; index--) {
      const marking = this.markings[index];
      if (marking !== undefined && marking.enabled && marking.chapterIndex === chapterIndex &&
        marking.chapterPosition < end && marking.endPosition > start) {
        return marking;
      }
    }
    return undefined;
  }

  private getMarkingBackground(marking: ReaderMarking | undefined): string {
    if (marking === undefined || (marking.effect !== 'highlight' && marking.effect !== 'background')) {
      return 'transparent';
    }
    return marking.color.startsWith('#') && marking.color.length === 7
      ? `#44${marking.color.substring(1)}` : marking.color;
  }

  private getMarkingDecorationType(marking: ReaderMarking | undefined): TextDecorationType {
    if (marking === undefined) { return TextDecorationType.None; }
    if (marking.effect === 'strike') { return TextDecorationType.LineThrough; }
    if (marking.effect === 'solid' || marking.effect === 'double' || marking.effect === 'dashed' ||
      marking.effect === 'wave') { return TextDecorationType.Underline; }
    return TextDecorationType.None;
  }

  private getMarkingDecorationStyle(marking: ReaderMarking | undefined): TextDecorationStyle {
    if (marking?.effect === 'double') { return TextDecorationStyle.DOUBLE; }
    if (marking?.effect === 'dashed') { return TextDecorationStyle.DASHED; }
    if (marking?.effect === 'wave') { return TextDecorationStyle.WAVY; }
    return TextDecorationStyle.SOLID;
  }

  private getReaderGlyphStartPosition(value: string, basePosition: number, glyphIndex: number): number {
    let position = basePosition;
    const glyphs = this.getReaderTextGlyphs(value);
    for (let index = 0; index < glyphIndex; index++) {
      position += glyphs[index]?.length ?? 0;
    }
    return position;
  }

  @Builder
  private readerMarkingSelectionMenu() {
    Row() {
      Text('划线 / 笔记').fontSize(14).fontColor('#E5E6EB')
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .onClick(() => this.createMarkingFromCurrentSelection())
    }.backgroundColor('#242127').borderRadius(12)
  }

  @Builder
  private ReaderGlyphSpan(glyph: string, start: number, end: number, gapAfter: number) {
    Span(glyph)
      .fontSize(this.fontSize * 1.05)
      .fontColor(this.getMarkingForTextRange(start, end)?.effect === 'text'
        ? this.getMarkingForTextRange(start, end)?.color ?? this.getReadingTextColor()
        : this.getReadingTextColor())
      .backgroundColor(this.getMarkingBackground(this.getMarkingForTextRange(start, end)))
      .decoration({
        type: this.getMarkingDecorationType(this.getMarkingForTextRange(start, end)),
        color: this.getMarkingForTextRange(start, end)?.color ?? this.getReadingTextColor(),
        style: this.getMarkingDecorationStyle(this.getMarkingForTextRange(start, end)),
        thicknessScale: 1
      })
      .letterSpacing(gapAfter)
  }

  @Builder
  private ReaderPageTextJoined() {
    Text() {
      ForEach(this.localReaderPages[this.currentPageIndex]?.lines ?? [],
        (line: LocalReaderLine, lineIndex: number) => {
          if (lineIndex > 0) {
            Span('\n').fontSize(this.fontSize * 1.05).fontColor(this.getReadingTextColor())
          }
          ForEach(line.items, (item: LocalReaderLineItem, itemIndex: number) => {
            if (item.kind === 'text') {
              if (item.leadingIndent) {
                Span(item.value).fontSize(this.fontSize * 1.05).fontColor(this.getReadingTextColor())
              } else {
                ForEach(this.getReaderTextGlyphs(item.value), (glyph: string, glyphIndex: number) => {
                  this.ReaderGlyphSpan(
                    glyph,
                    this.getReaderGlyphStartPosition(item.value, item.startPosition, glyphIndex),
                    this.getReaderGlyphStartPosition(item.value, item.startPosition, glyphIndex) + glyph.length,
                    this.getReaderGlyphGapAfter(line, itemIndex, glyphIndex,
                      this.getReaderTextGlyphCount(item.value), item)
                  )
                }, (glyph: string, glyphIndex: number) =>
                  `${this.readerContentRevision}-joined-${lineIndex}-${itemIndex}-${glyphIndex}-${glyph}`)
              }
            }
          }, (item: LocalReaderLineItem, itemIndex: number) =>
            `${this.readerContentRevision}-joined-${lineIndex}-${itemIndex}`)
        }, (line: LocalReaderLine, lineIndex: number) =>
          `${this.readerContentRevision}-joined-${this.currentPageIndex}-${lineIndex}`)
    }
    .fontSize(this.fontSize * 1.05)
    .lineHeight(this.fontSize * 1.25)
    .width('100%')
    .textAlign(TextAlign.Start)
    .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
    .copyOption(CopyOptions.InApp)
    .onClick((event: ClickEvent) => this.handleReaderTapAt(event.windowX, event.windowY))
    .onTextSelectionChange((start: number, end: number) =>
      this.updatePendingLineSelection(0, start, end))
    .bindSelectionMenu(TextSpanType.TEXT, this.readerMarkingSelectionMenu(), TextResponseType.LONG_PRESS, {
      onMenuShow: (start: number, end: number) => this.updatePendingLineSelection(0, start, end)
    })
  }

  @Builder
  private ReaderPageTextLines() {
    ForEach(this.localReaderPages[this.currentPageIndex]?.lines ?? [],
      (line: LocalReaderLine, lineIndex: number) => this.ReaderPageTextLine(line, lineIndex),
      (line: LocalReaderLine, lineIndex: number) =>
        `${this.readerContentRevision}-${this.currentPageIndex}-${lineIndex}`)
  }

  @Builder
  private ReaderPageTextLine(line: LocalReaderLine, lineIndex: number) {
    if (this.readerLineContainsImage(line)) {
      Row() {
        ForEach(line.items, (item: LocalReaderLineItem, itemIndex: number) => {
          if (item.kind === 'image') {
            Image(item.value)
              .width(item.width)
              .height(item.height)
              .objectFit(ImageFit.Contain)
              .alignSelf(ItemAlign.Center)
              .margin({ right: this.getReaderLineGapAfter(line, itemIndex, item) })
              .onClick(() => this.openReaderImage(item.value))
          } else {
            Text(item.value)
              .fontSize(this.fontSize * 1.05)
              .fontColor(this.getReadingTextColor())
              .maxLines(1)
              .height(line.height)
              .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
              .copyOption(CopyOptions.InApp)
              .onClick((event: ClickEvent) => this.handleReaderTapAt(event.windowX, event.windowY))
              .onTextSelectionChange((start: number, end: number) =>
                this.updatePendingLineSelection(this.getReaderSelectionPartIndex(lineIndex, itemIndex), start, end))
              .bindSelectionMenu(TextSpanType.TEXT, this.readerMarkingSelectionMenu(), TextResponseType.LONG_PRESS, {
                onMenuShow: (start: number, end: number) =>
                  this.updatePendingLineSelection(this.getReaderSelectionPartIndex(lineIndex, itemIndex), start, end)
              })
          }
        }, (item: LocalReaderLineItem, itemIndex: number) =>
          `${this.readerContentRevision}-${lineIndex}-${itemIndex}-${item.kind}`)
      }
      .width('100%')
      .height(line.height)
      .justifyContent(line.imageOnly ? FlexAlign.Center : FlexAlign.Start)
      .margin({ top: line.verticalSpaceBefore, bottom: line.paragraphSpacingAfter })
    } else {
      Text() {
        ForEach(line.items, (item: LocalReaderLineItem, itemIndex: number) => {
          if (item.leadingIndent) {
            Span(item.value).fontSize(this.fontSize * 1.05).fontColor(this.getReadingTextColor())
          } else {
            ForEach(this.getReaderTextGlyphs(item.value), (glyph: string, glyphIndex: number) => {
              this.ReaderGlyphSpan(
                glyph,
                this.getReaderGlyphStartPosition(item.value, item.startPosition, glyphIndex),
                this.getReaderGlyphStartPosition(item.value, item.startPosition, glyphIndex) + glyph.length,
                this.getReaderGlyphGapAfter(line, itemIndex, glyphIndex,
                  this.getReaderTextGlyphCount(item.value), item)
              )
            }, (glyph: string, glyphIndex: number) =>
              `${this.readerContentRevision}-${lineIndex}-${itemIndex}-${glyphIndex}-${glyph}`)
          }
        }, (item: LocalReaderLineItem, itemIndex: number) =>
          `${this.readerContentRevision}-${lineIndex}-${itemIndex}-${item.kind}`)
      }
      .fontSize(this.fontSize * 1.05)
      .lineHeight(line.height)
      .width('100%')
      .height(line.height)
      .maxLines(1)
      .textAlign(line.justifyGap > 0 ? TextAlign.JUSTIFY : TextAlign.Start)
      .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
      .copyOption(CopyOptions.InApp)
      .onClick((event: ClickEvent) => this.handleReaderTapAt(event.windowX, event.windowY))
      .onTextSelectionChange((start: number, end: number) =>
        this.updatePendingLineSelection(this.getReaderSelectionPartIndex(lineIndex), start, end))
      .bindSelectionMenu(TextSpanType.TEXT, this.readerMarkingSelectionMenu(), TextResponseType.LONG_PRESS, {
        onMenuShow: (start: number, end: number) =>
          this.updatePendingLineSelection(this.getReaderSelectionPartIndex(lineIndex), start, end)
      })
      .margin({ top: line.verticalSpaceBefore, bottom: line.paragraphSpacingAfter })
    }
  }

  private usesLocalPagination(): boolean {
    return (this.book.format === 'txt' || this.book.format === 'epub') && this.pageAnimation !== 3;
  }

  private updateProgress(): void {
    if (this.usesLocalPagination()) { return; }
    if (this.startPositionPending) { return; }
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
    if (this.pageAnimation === 3) { this.sliderProgressIndex = progress; }
    if (progress !== this.lastReportedProgress) {
      this.lastReportedProgress = progress;
      this.emitReaderProgress(progress, Math.round(this.content.length * progress / 100), false);
    }
  }

  private restoreProgressPosition(): void {
    if (this.usesLocalPagination()) { return; }
    if (this.startPositionPending) { return; }
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
    this.sliderProgressIndex = chapterProgress;
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
    this.resolveStartPosition();
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
    this.emitReaderProgress(nextProgress, Math.round(this.content.length * nextProgress / 100), false);
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
    const headerReserve = this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0;
    const footerReserve = this.isReaderFooterVisible() ? this.getReaderInfoReserve(false) : 0;
    const scale = Math.min(1,
      this.readerContentWidth > 0 ? this.getBodyContentWidth() / size.width : 1,
      this.viewportHeight > 0 ? this.getBodyContentHeight(headerReserve, footerReserve) / size.height : 1);
    return size.width * scale;
  }

  private getReaderImageHeight(uri: string): number {
    const size = this.imageSizes.get(uri);
    if (size === undefined || size.width <= 0 || size.height <= 0) { return 1; }
    const headerReserve = this.isReaderHeaderVisible() ? this.getReaderInfoReserve(true) : 0;
    const footerReserve = this.isReaderFooterVisible() ? this.getReaderInfoReserve(false) : 0;
    const scale = Math.min(1,
      this.readerContentWidth > 0 ? this.getBodyContentWidth() / size.width : 1,
      this.viewportHeight > 0 ? this.getBodyContentHeight(headerReserve, footerReserve) / size.height : 1);
    return size.height * scale;
  }

  private estimateContentHeight(): number {
    const availableWidth = this.getBodyContentWidth();
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
    if (this.usesLocalPagination()) { return; }
    this.refreshEstimatedContentHeight();
    this.restoreProgressPosition();
    this.updateProgress();
  }

  private getReadingTextColor(): string {
    return this.paperColor === '#000000' || this.paperColor === '#343832' || this.paperColor === '#3C3F43'
      ? '#D8D8DC' : '#38383B';
  }

  private isReaderHeaderVisible(): boolean {
    // HOS 目前保留系统状态栏；Android 模式0在状态栏显示时隐藏页眉。
    return this.infoSettings.headerMode === 1;
  }

  private isReaderFooterVisible(): boolean {
    return this.infoSettings.footerMode !== 1;
  }

  private getReaderInfoFontSize(isHeader: boolean): number {
    const size = isHeader || this.infoSettings.applyHeaderStyle
      ? this.infoSettings.headerFontSize : this.infoSettings.footerFontSize;
    return size > 0 ? size : 12;
  }

  private getReaderInfoColor(isHeader: boolean): string {
    const useHeaderStyle = isHeader || this.infoSettings.applyHeaderStyle;
    const isNightPaper = this.paperColor === '#000000' || this.paperColor === '#343832' || this.paperColor === '#3C3F43';
    const configuredColor = useHeaderStyle
      ? (isNightPaper ? this.infoSettings.tipHeaderColorNight : this.infoSettings.tipHeaderColor)
      : (isNightPaper ? this.infoSettings.tipFooterColorNight : this.infoSettings.tipFooterColor);
    if (configuredColor === 0) { return this.getReadingTextColor(); }
    const unsignedColor = configuredColor < 0 ? configuredColor + 4294967296 : configuredColor;
    const hexColor = unsignedColor.toString(16).padStart(8, '0');
    return `#${hexColor.substring(2)}`;
  }

  private getReaderInfoDividerColor(): string {
    if (this.infoSettings.tipDividerColor === -1) { return '#66666A'; }
    if (this.infoSettings.tipDividerColor === 0) { return this.getReadingTextColor(); }
    const unsignedColor = this.infoSettings.tipDividerColor < 0
      ? this.infoSettings.tipDividerColor + 4294967296 : this.infoSettings.tipDividerColor;
    const hexColor = unsignedColor.toString(16).padStart(8, '0');
    return `#${hexColor.substring(2)}`;
  }

  private getReaderInfoValue(type: number, customTemplate: string): string {
    const currentPage = this.localReaderPages[this.currentPageIndex];
    const chapterCount = this.getChapterCount();
    const pageCount = this.localReaderPages.length;
    const chapterTitle = this.displayChapterTitle;
    const time = new Date();
    const timeText = `${time.getHours().toString().padStart(2, '0')}:${time.getMinutes().toString().padStart(2, '0')}`;
    const batteryPercent = Math.max(0, Math.min(100, batteryInfo.batterySOC));
    const progressText = `${this.getWholeBookProgress().toFixed(1)}%`;
    const fullPageIndex = this.getWholeBookPageIndex();
    const fullPageCount = this.getWholeBookPageCount();
    // Android 的自定义占位符在整本页数暂不可用时回退到本章页码和页数。
    const customFullPageIndex = fullPageIndex > 0 ? `${fullPageIndex}` : `${this.currentPageIndex + 1}`;
    const customFullPageCount = fullPageCount > 0 ? `${fullPageCount}` : `${Math.max(1, pageCount)}`;
    let value = '';
    if (type === 1) { value = chapterTitle; }
    else if (type === 2) { value = timeText; }
    else if (type === 3 || type === 10 || type === 13 || type === 14 || type === 15) { value = `${batteryPercent}%`; }
    else if (type === 4) { value = `${this.currentPageIndex + 1}/${pageCount > 0 ? pageCount : '-'}`; }
    else if (type === 5) { value = progressText; }
    else if (type === 6) { value = `${this.currentPageIndex + 1}/${pageCount > 0 ? pageCount : '-' }  ${progressText}`; }
    else if (type === 7) { value = this.book.title; }
    else if (type === 8 || type === 9 || type === 16) { value = `${timeText} ${batteryPercent}%`; }
    else if (type === 11) { value = `${this.getChapterIndex() + 1}/${chapterCount}`; }
    else if (type === 12 || type === 17) { value = `${chapterTitle} ›`; }
    else if (type === 18) {
      value = customTemplate
        .replaceAll('{BookName}', this.book.title)
        .replaceAll('{ChapterTitle}', chapterTitle)
        .replaceAll('{Time}', timeText)
        .replaceAll('{BatteryPercent}', `${batteryPercent}%`)
        .replaceAll('{ChapterIndex}', `${this.getChapterIndex() + 1}`)
        .replaceAll('{ChapterSize}', `${chapterCount}`)
        .replaceAll('{PageIndex}', `${this.currentPageIndex + 1}`)
        .replaceAll('{PageSize}', `${pageCount > 0 ? pageCount : '-'}`)
        .replaceAll('{PageRemaining}', `${pageCount > 0 ? Math.max(0, pageCount - this.currentPageIndex - 1) : '-'}`)
        .replaceAll('{ReadProgress}', progressText)
        .replaceAll('{FullPageIndex}', customFullPageIndex)
        .replaceAll('{FullPageSize}', customFullPageCount);
    } else if (type === 19) { value = this.getWholeBookPageText(); }
    else if (type === 20) { value = `${this.getWholeBookPageText()}  ${progressText}`; }
    if (currentPage === undefined && type === 4) { return '-'; }
    return value;
  }

  private getReaderInfoType(isHeader: boolean, position: number): number {
    if (isHeader) {
      if (position === 0) { return this.infoSettings.tipHeaderLeft; }
      if (position === 1) { return this.infoSettings.tipHeaderMiddle; }
      return this.infoSettings.tipHeaderRight;
    }
    if (position === 0) { return this.infoSettings.tipFooterLeft; }
    if (position === 1) { return this.infoSettings.tipFooterMiddle; }
    return this.infoSettings.tipFooterRight;
  }

  private getReaderInfoTemplate(isHeader: boolean, position: number): string {
    if (isHeader) {
      if (position === 0) { return this.infoSettings.customTipHeaderLeft; }
      if (position === 1) { return this.infoSettings.customTipHeaderMiddle; }
      return this.infoSettings.customTipHeaderRight;
    }
    if (position === 0) { return this.infoSettings.customTipFooterLeft; }
    if (position === 1) { return this.infoSettings.customTipFooterMiddle; }
    return this.infoSettings.customTipFooterRight;
  }

  @Builder
  private ReaderInfoRow(isHeader: boolean) {
    Column() {
      Row() {
        Text(this.getReaderInfoValue(this.getReaderInfoType(isHeader, 0), this.getReaderInfoTemplate(isHeader, 0)))
          .fontSize(this.getReaderInfoFontSize(isHeader)).fontColor(this.getReaderInfoColor(isHeader))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        Text(this.getReaderInfoValue(this.getReaderInfoType(isHeader, 1), this.getReaderInfoTemplate(isHeader, 1)))
          .fontSize(this.getReaderInfoFontSize(isHeader)).fontColor(this.getReaderInfoColor(isHeader))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center).layoutWeight(1)
        Text(this.getReaderInfoValue(this.getReaderInfoType(isHeader, 2), this.getReaderInfoTemplate(isHeader, 2)))
          .fontSize(this.getReaderInfoFontSize(isHeader)).fontColor(this.getReaderInfoColor(isHeader))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.End).layoutWeight(1)
      }.width('100%').height(18)
      if ((isHeader && this.infoSettings.showHeaderLine) || (!isHeader && this.infoSettings.showFooterLine)) {
        Column().width('100%').height(1).backgroundColor(this.getReaderInfoDividerColor())
      }
    }.width('100%').padding({
      left: isHeader ? this.paddingSettings.headerPaddingLeft : this.paddingSettings.footerPaddingLeft,
      right: isHeader ? this.paddingSettings.headerPaddingRight : this.paddingSettings.footerPaddingRight,
      top: 2 + (isHeader ? this.paddingSettings.headerPaddingTop : this.paddingSettings.footerPaddingTop),
      bottom: 2 + (isHeader ? this.paddingSettings.headerPaddingBottom : this.paddingSettings.footerPaddingBottom)
    })
  }

  build() {
    Stack() {
      if ((this.book.format === 'txt' || this.book.format === 'epub') && this.localReaderPages.length > 0 && this.pageAnimation !== 3) {
        Stack() {
          Column() {
            if (this.isReaderHeaderVisible()) { this.ReaderInfoRow(true) }
            if (this.localReaderPages[this.currentPageIndex]?.titleOnly === true) {
              Blank().layoutWeight(1)
              Text(this.displayChapterTitle)
                .fontSize(this.fontSize + 4)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getReadingTextColor())
                .width('100%')
                .textAlign(TextAlign.Center)
              Blank().layoutWeight(1)
            } else if (this.currentPageIndex === 0) {
              Text(this.displayChapterTitle)
                .fontSize(this.fontSize + 4)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getReadingTextColor())
                .width('100%')
                .margin({ bottom: 24 })
            }
            if (this.currentPageContainsImages()) {
              this.ReaderPageTextLines()
            } else {
              this.ReaderPageTextJoined()
            }
            Blank().layoutWeight(1)
            if (this.isReaderFooterVisible()) { this.ReaderInfoRow(false) }
          }
          .width('100%')
          .height('100%')
          .padding({
            left: this.paddingSettings.paddingLeft,
            right: this.paddingSettings.paddingRight,
            top: this.paddingSettings.paddingTop,
            bottom: this.paddingSettings.paddingBottom
          })
          .translate({ x: this.pageTurnOffsetX, y: this.pageTurnOffsetY + this.bookmarkPullOffset })
          .opacity(this.pageTurnOpacity)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.paperColor)
        .onAreaChange((oldArea: Area, newArea: Area) => {
          this.readerContentWidth = this.toDimension(newArea.width);
          this.viewportHeight = this.toDimension(newArea.height);
          this.rebuildReaderPages();
        })
        .gesture(GestureGroup(GestureMode.Parallel,
          TapGesture().onAction((event: GestureEvent) => {
            const finger = event.fingerList[0];
            if (finger !== undefined) { this.handleReaderTapAt(finger.localX, finger.localY); }
          }),
          PanGesture({ direction: PanDirection.Horizontal })
            .onActionEnd((event: GestureEvent) => {
              if (event.offsetX < -36) { this.turnReaderPage(1); }
              else if (event.offsetX > 36) { this.turnReaderPage(-1); }
            }),
          PanGesture({ direction: this.swipeToAddBookmark && this.book.isLocal && this.pageAnimation !== 3
            ? PanDirection.Vertical : PanDirection.None })
            .onActionStart(() => {
              this.bookmarkWillRemove = this.hasBookmarkOnCurrentPage();
              this.bookmarkPullOffset = 0;
              this.bookmarkPullArmed = false;
            })
            .onActionUpdate((event: GestureEvent) => this.updateBookmarkPull(event))
            .onActionEnd((event: GestureEvent) => this.finishBookmarkPull(event))
        ))
      } else {
      Scroll(this.readerScroller) {
        Column() {
          if (this.isReaderHeaderVisible()) { this.ReaderInfoRow(true) }
          Text(this.displayChapterTitle)
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
                  .onClick(() => this.openReaderImage(segment.value))
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
          if (this.isReaderFooterVisible()) { this.ReaderInfoRow(false) }
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .padding({
          left: this.paddingSettings.paddingLeft,
          right: this.paddingSettings.paddingRight,
          top: this.paddingSettings.paddingTop,
          bottom: this.paddingSettings.paddingBottom
        })
        .onClick((event: ClickEvent) => this.handleReaderTap(event))
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
        if (this.usesLocalPagination()) { return; }
        const nextOffset = Math.max(0, this.scrollOffset + yOffset);
        if (this.startPositionPending && Math.abs(nextOffset - this.scrollOffset) > 1) {
          this.resolveStartPosition();
        }
        this.scrollOffset = nextOffset;
        this.updateProgress();
      })
      .onAreaChange((oldArea: Area, newArea: Area) => {
        this.viewportHeight = this.toDimension(newArea.height);
        this.rebuildReaderPages();
          if (this.usesLocalPagination()) { return; }
        this.restoreProgressPosition();
        this.updateProgress();
      })
      }

      if (this.bookmarkPullArmed && !this.controlsVisible) {
        Row() {
          Text(this.bookmarkWillRemove ? '松手以取消书签' : '松手以添加书签')
            .fontSize(14).fontColor('#FFFFFF')
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor('#A0000000')
        .borderRadius(24)
        .margin({ top: 72 })
        .alignSelf(ItemAlign.Center)
        .zIndex(10)
      }
      if (this.controlsVisible) {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#01000000')
            .onClick(() => {
              this.controlsVisible = false;
              this.overflowVisible = false;
              this.imageStyleMenuVisible = false;
            })
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
              if (this.getVisibleTopActions().length > 2) {
                Stack({ alignContent: Alignment.Center }) {
                  AppGlyph({ name: 'more', glyphSize: 18, tint: '#D5C2C6' })
                }.width(40).height(40).margin({ left: 6 })
                  .bindMenu(this.TopActionOverflowMenu, { placement: Placement.Bottom })
              }
            }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 4 })
            Text(this.book.title).fontSize(16).fontColor('#D5C2C6').maxLines(1)
              .width('100%').padding({ left: 16, right: 16, top: 4, bottom: 4 })
            Text(this.displayChapterTitle).fontSize(12).fontColor('#D5C2C6').maxLines(1)
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
                    if (this.pageAnimation === 3) {
                      if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                        this.seekToProgress(index);
                      }
                    } else if (this.isPageProgressMode()) {
                      this.currentPageIndex = index;
                      this.reportReaderPageProgress();
                    } else if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                      this.onSelectChapterIndex(index);
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
                          active: (kind === 'autoPage' && this.autoPageActive) ||
                            (kind === 'eye_protection' && this.eyeProtectionActive),
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
        .width('100%')
        .height('100%')
      }

      if (this.readingAnchorAvailable && this.readingAnchorEnabled && !this.controlsVisible &&
        !this.imagePreviewVisible && !this.overflowVisible) {
        Stack({ alignContent: Alignment.Bottom }) {
          Row() {
            Row() {
              AppGlyph({ name: 'profileHistory', glyphSize: 18, tint: '#DDE1F0' }).margin({ right: 8 })
              Text('返回原阅读位置').fontSize(14).fontColor('#ECEEF4')
            }.layoutWeight(1).onClick(() => this.onRestoreReadingAnchor())
            Text('关闭').fontSize(13).fontColor('#BFC2CD').padding({ left: 12, right: 6 })
              .onClick(() => this.onKeepReadingAnchor())
          }
          .width('88%')
          .padding({ left: 16, right: 14, top: 12, bottom: 12 })
          .backgroundColor('#D92B2D35')
          .borderRadius(24)
          .margin({ bottom: 96 })
          .alignSelf(ItemAlign.Center)
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
                Text(this.displayChapterTitle).fontSize(11).fontColor('#B7B8C1').maxLines(1)
                  .margin({ top: 4 })
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Text(`${this.getChapterIndex() + 1} / ${this.getChapterCount()}`)
                .fontSize(11).fontColor('#E5E6EB').padding({ left: 10, right: 10, top: 7, bottom: 7 })
                .backgroundColor('#111217').borderRadius(16)
            }.width('100%').padding({ left: 16, right: 16, bottom: 14 })
            Grid() {
              ForEach(this.getVisibleMoreActions(), (action: ReaderMoreAction) => {
                GridItem() {
                  Column() {
                    AppGlyph({ name: action.glyph,
                      tint: action.id === 're_segment' && this.book.reSegment === true ? '#FFB1C8' : '#D5C2C6',
                      glyphSize: 22 }).margin({ bottom: 8 })
                    Text(action.id === 're_segment' && this.book.reSegment === true
                      ? '重新分段（已启用）' : action.label)
                      .fontSize(11).fontColor('#E1DADD').textAlign(TextAlign.Center)
                      .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (!action.migrated) {
                      Text('未迁移').fontSize(9).fontColor('#92949E').margin({ top: 2 })
                    }
                  }.width('100%').height(100).justifyContent(FlexAlign.Center)
                    .backgroundColor('#202127').borderRadius(16)
                    .onClick(() => this.selectMoreAction(action))
                }
              }, (action: ReaderMoreAction) => action.id)
            }.columnsTemplate('1fr 1fr 1fr 1fr').rowsGap(8).columnsGap(8)
              .width('100%').padding({ left: 16, right: 16, bottom: 16 }).layoutWeight(1)
              .scrollBar(BarState.Off)
          }
          .width('100%').height('52%').backgroundColor('#1A1B21')
          .borderRadius({ topLeft: 26, topRight: 26 })
        }
        .width('100%')
        .height('100%')
      }

      if (this.imageStyleMenuVisible) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#88000000')
            .onClick(() => this.imageStyleMenuVisible = false)
          Column() {
            Row() {
              Text('图片样式').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#E5E6EB')
              Blank()
              Text('关闭').fontSize(13).fontColor('#C7C9D1').onClick(() => this.imageStyleMenuVisible = false)
            }.width('100%').padding({ bottom: 12 })
            ForEach(READER_IMAGE_STYLE_OPTIONS, (style: ReaderImageStyleOption) => {
              Row() {
                Text(style.label).fontSize(14).fontColor('#E5E6EB').layoutWeight(1)
                if (this.activeImageStyle === style.id) {
                  AppGlyph({ name: 'profileCheck', glyphSize: 18, tint: '#B9C6FF' })
                }
              }.width('100%').padding({ left: 12, right: 12, top: 12, bottom: 12 })
                .backgroundColor('#202127').borderRadius(12).margin({ bottom: 6 })
                .onClick(() => this.chooseImageStyle(style.id))
            }, (style: ReaderImageStyleOption) => style.id)
          }.width('86%').padding(16).backgroundColor('#1A1B21').borderRadius(20)
        }.width('100%').height('100%')
      }

      if (this.moreActionConfigVisible) {
        this.moreActionConfigurationSheet()
      }

      if (this.moreActionShellVisible) {
        this.moreActionUnavailableSheet()
      }

      if (this.contentEditVisible) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#99000000')
            .onClick(() => this.contentEditVisible = false)
          Column() {
            Row() {
              Text('编辑内容').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#ECEEF2')
              Blank()
              Text('取消').fontSize(14).fontColor('#C8C9D0').onClick(() => this.contentEditVisible = false)
            }.width('100%').padding({ bottom: 14 })
            TextInput({ text: this.contentEditTitle, placeholder: '章节名称' })
              .width('100%').height(48).fontSize(15).fontColor('#ECEEF2')
              .backgroundColor('#292A31').borderRadius(10).padding({ left: 12, right: 12 })
              .onChange((value: string) => this.contentEditTitle = value)
            TextArea({ text: this.contentEditBody, placeholder: '章节正文' })
              .width('100%').layoutWeight(1).margin({ top: 10 })
              .fontSize(15).fontColor('#ECEEF2').backgroundColor('#292A31')
              .borderRadius(10).padding(12)
              .onChange((value: string) => this.contentEditBody = value)
            Row() {
              Text('还原').fontSize(14).fontColor('#D8D9E0').layoutWeight(1).textAlign(TextAlign.Center)
                .onClick(() => {
                  this.contentEditTitle = this.chapterTitle;
                  this.contentEditBody = this.content;
                })
              Text('保存').fontSize(14).fontColor('#101116').textAlign(TextAlign.Center)
                .width(84).padding({ top: 10, bottom: 10 }).backgroundColor('#B9C6FF').borderRadius(18)
                .onClick(() => {
                  const currentPage = this.localReaderPages[this.currentPageIndex];
                  this.pendingBookmarkTargetPosition = currentPage?.startPosition ?? 0;
                  this.onSaveChapterContent(this.getChapterIndex(), this.contentEditTitle, this.contentEditBody);
                  this.contentEditVisible = false;
                })
            }.width('100%').padding({ top: 14 })
          }
          .width('92%').height('76%').padding(18).backgroundColor('#1A1B21').borderRadius(22)
          .onClick(() => {})
        }.width('100%').height('100%')
      }

      if (this.textProcessingVisible) {
        ReaderTextProcessingSheet({
          book: this.book,
          chapterTitle: this.displayChapterTitle,
          replaceEnabled: this.replaceEnabled,
          replaceUsesDefault: this.replaceUsesDefault,
          rules: this.replaceRules,
          contentProcesses: this.contentProcesses,
          effectiveRuleIds: this.effectiveReplaceRuleIds,
          onReplaceEnabledChange: (enabled: boolean) => this.onReplaceEnabledChange(enabled),
          onReplaceResetToDefault: () => this.onReplaceResetToDefault(),
          onRuleEnabledChange: (id: number, enabled: boolean) => this.onRuleEnabledChange(id, enabled),
          onContentProcessToggle: (id: string, enabled: boolean) => this.onContentProcessToggle(id, enabled),
          onContentProcessDelete: (id: string) => this.onContentProcessDelete(id),
          onClose: () => this.textProcessingVisible = false,
          onOpenReplaceRules: () => this.onOpenReplaceRules(),
          onUnavailableAction: (message: string) => this.onUnavailableAction(message)
        })
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

      if (this.imagePreviewVisible) {
        Column() {
          Row() {
            Text('图片预览').fontSize(16).fontColor('#ECEEF2').layoutWeight(1)
            Image($r('app.media.profile_close')).width(22).height(22).fillColor('#ECEEF2')
              .padding(8).onClick(() => this.closeReaderImagePreview())
          }.width('100%').height(48).padding({ left: 16, right: 16 })
          Image(this.imagePreviewUri)
            .width('100%').layoutWeight(1).objectFit(ImageFit.Contain)
            .onClick(() => {})
        }
        .width('100%').height('100%')
        .padding({ top: 28, bottom: 20 })
        .backgroundColor('#FF000000')
        .onClick(() => {})
        .zIndex(1000)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.paperColor)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) { this.renewKeepLightTimeout(); }
    })
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
    } else if (this.kind === 'addBookmark') {
      Image($r('app.media.app_bookmark')).width(this.glyphSize).height(this.glyphSize).fillColor('#D5C2C6')
    } else if (this.kind === 'theme') {
      Image($r('app.media.app_daynight')).width(this.glyphSize).height(this.glyphSize).fillColor('#D5C2C6')
    } else if (this.kind === 'prev_chapter') {
      Image($r('app.media.app_previous')).width(this.glyphSize).height(this.glyphSize).fillColor('#D5C2C6')
    } else if (this.kind === 'next_chapter') {
      Image($r('app.media.reader_arrow_forward')).width(this.glyphSize).height(this.glyphSize).fillColor('#D5C2C6')
    } else if (this.kind === 'replace' || this.kind === 'replace_badge') {
      Image($r('app.media.profile_find_replace')).width(this.glyphSize).height(this.glyphSize).fillColor('#D5C2C6')
    } else if (this.kind === 'charset' || this.kind === 'translate') {
      Image($r('app.media.reader_translate')).width(this.glyphSize).height(this.glyphSize).fillColor('#D5C2C6')
    } else if (this.kind === 'more_actions' || this.kind === 'source_custom_button') {
      Image($r('app.media.reader_more')).width(this.glyphSize).height(this.glyphSize).fillColor('#D5C2C6')
    } else if (this.kind === 'download' || this.kind === 'audio_download') {
      Image($r('app.media.app_download')).width(this.glyphSize).height(this.glyphSize).fillColor('#D5C2C6')
    } else if (this.kind === 'refresh' || this.kind === 'refresh_current') {
      Image($r('app.media.app_refresh')).width(this.glyphSize).height(this.glyphSize).fillColor('#D5C2C6')
    } else if (this.kind === 'change_source') {
      Image($r('app.media.app_swap')).width(this.glyphSize).height(this.glyphSize).fillColor('#D5C2C6')
    } else if (this.kind === 'toc_rule') {
      Image($r('app.media.profile_rule')).width(this.glyphSize).height(this.glyphSize).fillColor('#D5C2C6')
    } else if (this.kind === 'ai_summary' || this.kind === 'ai_cast') {
      Image($r('app.media.profile_auto_awesome')).width(this.glyphSize).height(this.glyphSize).fillColor('#D5C2C6')
    } else if (this.kind === 'ai_rewrite') {
      Image($r('app.media.app_edit')).width(this.glyphSize).height(this.glyphSize).fillColor('#D5C2C6')
    } else if (this.kind === 'multi_role_read' || this.kind === 'multi_role_cast') {
      Image($r('app.media.app_group')).width(this.glyphSize).height(this.glyphSize).fillColor('#D5C2C6')
    } else if (this.kind === 'cast_table') {
      Image($r('app.media.app_list')).width(this.glyphSize).height(this.glyphSize).fillColor('#D5C2C6')
    } else if (this.kind === 'eye_protection') {
      Image($r('app.media.app_visibility')).width(this.glyphSize).height(this.glyphSize).fillColor('#D5C2C6')
    } else {
      Image($r('app.media.reader_voice')).width(this.glyphSize).height(this.glyphSize).fillColor(this.active ? '#FFB1C8' : '#D5C2C6')
    }
  }
}




