import { DURATION_FADE, HEADER_COLLAPSE_THRESHOLD, HEADER_EXPAND_THRESHOLD } from '../components/UiTokens';
import { UiSwitchControl } from '../components/UiSwitchControl';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import curves from '@ohos.curves';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { ThemeGroupColumn, ThemeGroupItem } from '../components/settings/ThemeGroupColumn';
import { UiDropdown } from '../components/settings/UiDropdown';
import { BackupCategoryOption } from '../data/BackupRepository';
import { WebDavSettings, defaultWebDavSettings, cloneWebDavSettings } from '../lib/WebDavConfig';
import { WebDavSync } from '../lib/WebDavSync';
import { BODY_MEDIUM_EMPHASIZED, BODY_SMALL, BODY_SMALL_EMPHASIZED, HEADLINE_SMALL, LABEL_LARGE, LABEL_MEDIUM, LABEL_MEDIUM_EMPHASIZED, LABEL_SMALL, TITLE_MEDIUM, TITLE_SMALL, TITLE_SMALL_LINE_HEIGHT } from '../components/typography/TypographyTokens';

/** 弹层分支：对应上游 BackupConfigSheet 七项（BackupConfigContract.kt:28-36）。 */
enum BackupSheetKind {
  NONE = 'none',
  CHOOSE_BACKUP_PATH = 'chooseBackupPath',
  CHOOSE_BACKUP_AND_RUN = 'chooseBackupAndRun',
  BACKUP_OPTIONS = 'backupOptions',
  RESTORE_OPTIONS = 'restoreOptions',
  RESTORE_FILES = 'restoreFiles',
  IGNORE_RESTORE_ITEMS = 'ignoreRestoreItems',
  IGNORE_BACKUP_ITEMS = 'ignoreBackupItems'
}

/** 对话框分支：对应上游 BackupConfigDialog 三项（BackupConfigContract.kt:38-47）。 */
enum BackupDialogKind {
  NONE = 'none',
  WEBDAV_AUTH = 'webDavAuth',
  CONFIRM_LOCAL_RESTORE_FALLBACK = 'confirmLocalRestoreFallback',
  LOADING = 'loading'
}

/** 忽略项：对应上游 BackupIgnoreItem 三字段（BackupConfigContract.kt:22-26）。 */
interface BackupIgnoreItem {
  key: string;
  title: string;
  checked: boolean;
}

/** 配置维度九项顺序：照 help/storage/BackupConfig.kt:145-155。 */
const BACKUP_CONFIG_KEYS: string[] = [
  'readConfig', 'themeMode', 'themeConfig', 'coverConfig', 'bookshelfLayout',
  'showRss', 'threadCount', 'localBook', 'mangaConfig'
];

/** 数据库维度十九项顺序：照 help/storage/BackupConfig.kt:96-102。 */
const BACKUP_DB_KEYS: string[] = [
  'bookmark', 'bookGroup', 'bookSource', 'rssSource', 'rssStar', 'replaceRule',
  'readRecord', 'searchHistory', 'sourceSub', 'txtTocRule', 'httpTTS',
  'keyboardAssists', 'dictRule', 'homepageModules', 'homepageCustomSets',
  'highlightRule', 'highlightTagRule', 'tagGroupRule', 'server'
];

/** 配置维度标题：照 help/storage/BackupConfig.kt:158-168 的 strings 真值。 */
const BACKUP_CONFIG_TITLES: string[] = [
  '阅读界面', '深色模式', '主题配置', '封面设置', '书架布局',
  '显示订阅', '线程数', '本地书籍', '漫画设置'
];

/** 数据库维度标题：照 help/storage/BackupConfig.kt:104-124 的 strings 真值。 */
const BACKUP_DB_TITLES: string[] = [
  '书签', '书架分组', '书源', '订阅源', 'RSS 收藏', '替换规则',
  '阅读记录', '搜索历史', '书源订阅', 'TXT 目录规则', 'HTTP TTS',
  '键盘辅助', '字典规则', '首页模块 (JSON)', '首页自定义',
  '高亮规则', '标签规则', '标签分组规则', '服务器配置'
];

/** 本地备份与恢复页面，文件格式与 Android 原项目兼容。 */
@Component
export struct AppBackupSettingsPage {
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop localBookCount: number = 0;
  @Prop categoryOptions: BackupCategoryOption[] = [];
  @Prop backupIgnoreKeys: string[] = [];
  @Prop restoreIgnoreKeys: string[] = [];
  /** 状态消息改走 showToast（对齐上游 Snackbar），不再在页内常驻成条。 */
  @Prop @Watch('syncStatusMessage') statusMessage: string = '';
  @Prop @Watch('syncDialog') busy: boolean = false;
  @Prop webDavSettings: WebDavSettings = defaultWebDavSettings();
  @Prop @Watch('syncDialog') webDavTesting: boolean = false;
  @Prop webDavConfigured: boolean = false;
  onBack: () => void = () => {};
  onCreateBackup: () => void = () => {};
  onSelectRestore: () => void = () => {};
  onToggleBackupIgnore: (key: string, ignored: boolean) => void = (_key: string, _ignored: boolean) => {};
  onToggleRestoreIgnore: (key: string, ignored: boolean) => void = (_key: string, _ignored: boolean) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  onWebDavSettingsChange: (settings: WebDavSettings) => void = () => {};
  onTestWebDav: () => void = () => {};
  onBackupToWebDav: () => void = () => {};
  onRestoreFromWebDav: () => void = () => {};
  /** 同时备份：本地保存后无条件上传，不看 backupSyncMode。 */
  onCreateBackupBoth: () => void = () => {};
  /** 选择本地备份目录（DocumentViewPicker 的 FOLDER 模式 + 持久授权）。 */
  onChooseBackupPath: () => void = () => {};
  /** 直接把应用内 backups 目录设为固定备份目录（目录选择器在部分设备上选不出可写目录时的等价入口）。 */
  onUseDownloadDir: () => void = () => {};
  /** 清掉已记住的备份目录，回到每次弹 picker。 */
  onClearBackupPath: () => void = () => {};
  /** 导入旧版本 myBookShelf.json。 */
  onImportOldShelf: () => void = () => {};
  /** 保存账号密码：宿主写完配置后串一次连接测试，对齐上游 saveWebDavAuth。 */
  onSaveWebDavAuth: (account: string, password: string) => void = (_account: string, _password: string) => {};
  /** 恢复指定的远端备份文件（由 RestoreFiles 弹层选中后触发）。 */
  onRestoreNetwork: (name: string) => void = (_name: string) => {};
  /** 网络恢复失败回退：确认后开本地文件选择器。 */
  onConfirmLocalRestoreFallback: () => void = () => {};
  /** 忽略面板关闭时一次性写盘，side 为 backup 或 restore。 */
  onSaveIgnoreItems: (side: string, keys: string[]) => void = (_side: string, _keys: string[]) => {};
  @State activeSheet: BackupSheetKind = BackupSheetKind.NONE;
  /** 对话框改由 openCustomDialog 承载：独立弹层形态对齐上游 AppAlertDialog。 */
  @State @Watch('syncDialog') activeDialog: BackupDialogKind = BackupDialogKind.NONE;
  @State collapsedHeader: boolean = false;
  /** 顶栏连续折叠进度，对齐上游 TopAppBarState.collapsedFraction。 */
  @State headerFraction: number = 0;
  /** 三个行内输入行的草稿：editingKey 为空表示没有行在编辑。 */
  @State editingKey: string = '';
  @State inputDraft: string = '';
  /** WebDAV 账号密码对话框草稿。 */
  @State accountDraft: string = '';
  @State passwordDraft: string = '';
  @State passwordVisible: boolean = false;
  /** 忽略面板内存态：只在面板内改，关闭时统一提交。 */
  @State ignoreDraft: BackupIgnoreItem[] = [];
  @State ignoreSide: string = 'backup';
  @State ignoreTab: number = 0;
  /** 网络恢复拉到的文件名列表与失败原因。 */
  @State networkNames: string[] = [];
  @State fallbackError: string = '';
  private backupScroller: Scroller = new Scroller();
  /** openCustomDialog 的 builder 需存成成员，且每次重开重建以刷新内部输入态。 */
  private dialogBuilder: CustomBuilder | undefined = undefined;
  private dialogId: number = -1;

  private openSettingInput(key: string, draft: string): void {
    this.editingKey = key;
    this.inputDraft = draft;
  }

  private openWebDavAuth(): void {
    this.accountDraft = this.webDavSettings.account;
    this.passwordDraft = this.webDavSettings.password;
    this.passwordVisible = false;
    this.activeDialog = BackupDialogKind.WEBDAV_AUTH;
  }

  /** 账号行描述固定为 web_dav_account_d（strings.xml:805），账号值只在对话框内呈现。 */
  private webDavAuthDetail(): string {
    return '输入你的 WebDav 账号';
  }

  private describeSyncMode(mode: string): string {
    if (mode === 'local') { return '备份至本地'; }
    if (mode === 'webdav') { return '备份至网络'; }
    return '备份至本地与网络';
  }

  private syncModeLabel(value: string): string {
    return this.describeSyncMode(value);
  }

  /** 关总开关时把增强一起关掉，对齐上游 syncBookProgressPlus = plus && value。 */
  private setSyncBookProgress(value: boolean): void {
    const next: WebDavSettings = cloneWebDavSettings(this.webDavSettings);
    next.syncBookProgress = value;
    if (!value) {
      next.syncBookProgressPlus = false;
    }
    this.onWebDavSettingsChange(next);
  }

  private setWebDavField(field: string, value: string): void {
    const next: WebDavSettings = cloneWebDavSettings(this.webDavSettings);
    if (field === 'url') {
      next.url = value.trim();
    } else if (field === 'dir') {
      next.dir = value.trim();
    } else if (field === 'deviceName') {
      next.deviceName = value.trim();
    }
    this.editingKey = '';
    this.onWebDavSettingsChange(next);
  }

  private setBackupSyncMode(mode: string): void {
    const next: WebDavSettings = cloneWebDavSettings(this.webDavSettings);
    next.backupSyncMode = mode;
    this.onWebDavSettingsChange(next);
  }

  private setOnlyLatestBackup(value: boolean): void {
    const next: WebDavSettings = cloneWebDavSettings(this.webDavSettings);
    next.onlyLatestBackup = value;
    this.onWebDavSettingsChange(next);
  }

  private setAutoCheckNewBackup(value: boolean): void {
    const next: WebDavSettings = cloneWebDavSettings(this.webDavSettings);
    next.autoCheckNewBackup = value;
    this.onWebDavSettingsChange(next);
  }

  private setSyncBookProgressPlus(value: boolean): void {
    const next: WebDavSettings = cloneWebDavSettings(this.webDavSettings);
    next.syncBookProgressPlus = value;
    this.onWebDavSettingsChange(next);
  }

  /** 打开忽略面板时按上游键序构建内存副本，checked 取当前该侧的键集合。 */
  private openIgnoreSheet(sheet: BackupSheetKind): void {
    const side: string = sheet === BackupSheetKind.IGNORE_BACKUP_ITEMS ? 'backup' : 'restore';
    const source: string[] = side === 'backup' ? this.backupIgnoreKeys : this.restoreIgnoreKeys;
    const draft: BackupIgnoreItem[] = [];
    for (let i = 0; i < BACKUP_CONFIG_KEYS.length; i++) {
      draft.push({ key: BACKUP_CONFIG_KEYS[i], title: BACKUP_CONFIG_TITLES[i], checked: source.includes(BACKUP_CONFIG_KEYS[i]) });
    }
    for (let i = 0; i < BACKUP_DB_KEYS.length; i++) {
      draft.push({ key: BACKUP_DB_KEYS[i], title: BACKUP_DB_TITLES[i], checked: source.includes(BACKUP_DB_KEYS[i]) });
    }
    this.ignoreDraft = draft;
    this.ignoreSide = side;
    this.ignoreTab = 0;
    this.activeSheet = sheet;
  }

  private toggleIgnoreItem(key: string, checked: boolean): void {
    this.ignoreDraft = this.ignoreDraft.map((item: BackupIgnoreItem): BackupIgnoreItem => {
      if (item.key === key) {
        return { key: item.key, title: item.title, checked: checked };
      }
      return item;
    });
  }

  private visibleIgnoreItems(): BackupIgnoreItem[] {
    return this.ignoreDraft.filter((item: BackupIgnoreItem, index: number): boolean => {
      return this.ignoreTab === 0 ? index < BACKUP_CONFIG_KEYS.length : index >= BACKUP_CONFIG_KEYS.length;
    });
  }

  /** 关闭即保存：对齐上游 IgnoreItemsSheet 的 onDismissRequest = onConfirm。 */
  private dismissSheet(): void {
    if (this.activeSheet === BackupSheetKind.IGNORE_BACKUP_ITEMS ||
        this.activeSheet === BackupSheetKind.IGNORE_RESTORE_ITEMS) {
      const keys: string[] = this.ignoreDraft
        .filter((item: BackupIgnoreItem): boolean => item.checked)
        .map((item: BackupIgnoreItem): string => item.key);
      this.onSaveIgnoreItems(this.ignoreSide, keys);
    }
    this.activeSheet = BackupSheetKind.NONE;
  }

  /** 从网络恢复：先拉全部文件名，非空弹选择层，空或失败弹回退对话框。 */
  private async requestNetworkRestore(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    this.activeDialog = BackupDialogKind.LOADING;
    try {
      const names: string[] = await WebDavSync.listBackups(context);
      this.activeDialog = BackupDialogKind.NONE;
      if (names.length > 0) {
        this.networkNames = names;
        this.activeSheet = BackupSheetKind.RESTORE_FILES;
      } else {
        this.fallbackError = '没有找到远端备份文件';
        this.activeDialog = BackupDialogKind.CONFIRM_LOCAL_RESTORE_FALLBACK;
      }
    } catch (error) {
      this.activeDialog = BackupDialogKind.CONFIRM_LOCAL_RESTORE_FALLBACK;
      this.fallbackError = error instanceof Error ? error.message : String(error);
    }
  }

  private dialogVisible(): boolean {
    return this.activeDialog !== BackupDialogKind.NONE || this.busy || this.webDavTesting;
  }

  /** 状态变化走 toast，对齐上游 Snackbar 的浮层 + 自动消失。 */
  private syncStatusMessage(): void {
    if (this.statusMessage.length > 0) {
      this.onUnavailableAction(this.statusMessage);
    }
  }

  /**
   * activeDialog / busy / webDavTesting 任一变化时同步独立对话框开合。
   * 用 openCustomDialog 而非 bindContentCover：后者在此 SDK 版本首次 false→true 不重建 Builder，
   * 对话框内容（连最小结构）都不挂载；openCustomDialog 的 builder 在本仓三处页面已验证可用。
   */
  private syncDialog(): void {
    if (!this.dialogVisible()) {
      this.closeDialog();
      return;
    }
    if (this.dialogId < 0) {
      this.dialogBuilder = (): void => { this.dialogContent(); };
      this.getUIContext().getPromptAction().openCustomDialog({
        builder: this.dialogBuilder,
        autoCancel: false,
        alignment: DialogAlignment.Center,
        onWillDismiss: () => {
          this.dialogId = -1;
          this.activeDialog = BackupDialogKind.NONE;
        }
      }).then((id: number) => {
        this.dialogId = id;
      }).catch((error: Error) => {
        console.warn('打开备份对话框失败:', error);
      });
    }
  }

  /** 关闭独立对话框；重复关闭是安全调用。 */
  private closeDialog(): void {
    if (this.dialogId >= 0) {
      this.getUIContext().getPromptAction().closeCustomDialog(this.dialogId);
      this.dialogId = -1;
    }
  }

  aboutToDisappear(): void {
    this.closeDialog();
  }

  private sheetHeight(): number {
    if (this.activeSheet === BackupSheetKind.IGNORE_BACKUP_ITEMS ||
        this.activeSheet === BackupSheetKind.IGNORE_RESTORE_ITEMS) {
      return 560;
    }
    if (this.activeSheet === BackupSheetKind.RESTORE_FILES) {
      return 420;
    }
    return 320;
  }

  private updateHeader(): void {
    const offset = this.backupScroller.currentOffset().yOffset;
    const shouldCollapse = offset > HEADER_COLLAPSE_THRESHOLD ? true : offset < HEADER_EXPAND_THRESHOLD ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
    }
    // 连续折叠进度：滚动过阈值即为 1，与 TopBar.ets 的 collapseFraction 同口径。
    const fraction: number = Math.max(0, Math.min(1, offset / HEADER_COLLAPSE_THRESHOLD));
    if (fraction !== this.headerFraction) {
      this.headerFraction = fraction;
    }
  }

  build() {
    Column() {
      CollapsingSettingsHeader({
        title: '备份与恢复',
        collapsed: this.collapsedHeader,
        collapseFraction: this.headerFraction,
        onBack: () => this.onBack()
      })
      Scroll(this.backupScroller) {
        Column() {
          ThemeGroupColumn({ title: 'WebDav 设置', surfaceFill: false }) {
            ThemeGroupItem({ first: true }) {
              BackupInputRow({ cardSurface: true, title: 'WebDav 服务器地址', detail: '输入你的WebDav服务器地址',
                value: this.webDavSettings.url, defaultValue: '', editing: this.editingKey === 'url',
                draft: this.inputDraft,
                onBegin: () => this.openSettingInput('url', this.webDavSettings.url),
                onDraft: (value: string) => this.inputDraft = value,
                onConfirm: (value: string) => this.setWebDavField('url', value) })
            }
            ThemeGroupItem() {
              BackupActionRow({ cardSurface: true, title: 'WebDav 账号', detail: this.webDavAuthDetail(),
                onSelect: () => this.openWebDavAuth() })
            }
            ThemeGroupItem() {
              BackupInputRow({ cardSurface: true, title: '子文件夹', detail: '',
                value: this.webDavSettings.dir.length > 0 ? this.webDavSettings.dir : 'legado',
                defaultValue: 'legado', editing: this.editingKey === 'dir',
                draft: this.inputDraft,
                onBegin: () => this.openSettingInput('dir', this.webDavSettings.dir.length > 0 ? this.webDavSettings.dir : 'legado'),
                onDraft: (value: string) => this.inputDraft = value,
                onConfirm: (value: string) => this.setWebDavField('dir', value) })
            }
            ThemeGroupItem() {
              BackupInputRow({ cardSurface: true, title: '设备名称', detail: '',
                value: this.webDavSettings.deviceName, defaultValue: '', editing: this.editingKey === 'deviceName',
                draft: this.inputDraft,
                onBegin: () => this.openSettingInput('deviceName', this.webDavSettings.deviceName),
                onDraft: (value: string) => this.inputDraft = value,
                onConfirm: (value: string) => this.setWebDavField('deviceName', value) })
            }
            ThemeGroupItem() {
              BackupActionRow({ cardSurface: true, title: '测试 WebDav 配置', detail: '测试 WebDav 服务工作状态',
                onSelect: () => this.onTestWebDav() })
            }
            ThemeGroupItem() {
              BackupPreviewSwitchRow({ cardSurface: true, title: '同步阅读进度',
                detail: '进入退出阅读界面时同步阅读进度',
                checked: this.webDavSettings.syncBookProgress,
                onChange: (value: boolean) => this.setSyncBookProgress(value) })
            }
            if (this.webDavSettings.syncBookProgress) {
              ThemeGroupItem() {
                BackupPreviewSwitchRow({ cardSurface: true, title: '同步增强',
                  detail: '重新进入页面（息屏、后台返回等）或者网络变为可用时同步云端进度',
                  checked: this.webDavSettings.syncBookProgressPlus,
                  onChange: (value: boolean) => this.setSyncBookProgressPlus(value)
                }).transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE }))
              }
            }
            ThemeGroupItem() {
              BackupPreviewSwitchRow({ cardSurface: true, title: '自动检查新备份',
                detail: '打开软件时检查是否有新备份，有新备份时提示是否更新',
                checked: this.webDavSettings.autoCheckNewBackup,
                onChange: (value: boolean) => this.setAutoCheckNewBackup(value) })
            }
            ThemeGroupItem() {
              UiDropdown({ cardSurface: true, title: '自动备份同步', detail: '选择自动备份时的同步行为',
                option: this.webDavSettings.backupSyncMode,
                options: ['both', 'local', 'webdav'],
                labelOf: (value: string) => this.syncModeLabel(value),
                onSelect: (value: string) => this.setBackupSyncMode(value), showDivider: false })
            }
          }

          ThemeGroupColumn({ title: '备份与恢复', surfaceFill: false }) {
            ThemeGroupItem({ first: true }) {
              BackupActionRow({ cardSurface: true, title: '备份路径',
                detail: this.webDavSettings.backupPath.trim().length === 0 ? '请选择备份路径' : this.webDavSettings.backupPath,
                onSelect: () => this.activeSheet = BackupSheetKind.CHOOSE_BACKUP_PATH })
            }
            ThemeGroupItem() {
              BackupActionRow({ cardSurface: true, title: '备份', detail: '本地和 WebDav 一起备份',
                onSelect: () => this.activeSheet = BackupSheetKind.BACKUP_OPTIONS })
            }
            ThemeGroupItem() {
              BackupActionRow({ cardSurface: true, title: '恢复', detail: '选择从本地或网络恢复备份',
                onSelect: () => this.activeSheet = BackupSheetKind.RESTORE_OPTIONS })
            }
            ThemeGroupItem() {
              BackupActionRow({ cardSurface: true, title: '恢复忽略列表', detail: '选择恢复忽略内容',
                onSelect: () => this.openIgnoreSheet(BackupSheetKind.IGNORE_RESTORE_ITEMS) })
            }
            ThemeGroupItem() {
              BackupActionRow({ cardSurface: true, title: '备份忽略列表', detail: '选择备份忽略内容',
                onSelect: () => this.openIgnoreSheet(BackupSheetKind.IGNORE_BACKUP_ITEMS) })
            }
            ThemeGroupItem() {
              BackupActionRow({ cardSurface: true, title: '导入旧版数据', detail: '选择旧版备份文件夹',
                onSelect: () => this.onImportOldShelf() })
            }
            ThemeGroupItem() {
              BackupPreviewSwitchRow({ cardSurface: true, title: '仅保留最新备份',
                detail: '本地备份仅保留最新备份文件',
                checked: this.webDavSettings.onlyLatestBackup,
                onChange: (value: boolean) => this.setOnlyLatestBackup(value) })
            }
          }
        }.padding({ left: 16, right: 16, top: 16, bottom: 120 })
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.activeSheet !== BackupSheetKind.NONE, this.backupSheetContent(), {
        height: this.sheetHeight(),
        dragBar: true,
        showClose: false,
        backgroundColor: this.themeColorSurfaceTertiary,
        onDisappear: () => {
          if (this.activeSheet !== BackupSheetKind.NONE) {
            this.dismissSheet();
          }
        }
      })
      .onAppear(() => this.syncDialog())
  }

  @Builder
  private backupSheetContent() {
    Column() {
      Row() {
        Text(this.activeSheet === BackupSheetKind.CHOOSE_BACKUP_PATH ? '选择操作' :
          this.activeSheet === BackupSheetKind.BACKUP_OPTIONS ? '备份' :
          this.activeSheet === BackupSheetKind.RESTORE_OPTIONS ? '恢复' :
          this.activeSheet === BackupSheetKind.RESTORE_FILES ? '选择恢复文件' :
          this.activeSheet === BackupSheetKind.IGNORE_BACKUP_ITEMS ? '备份忽略列表' :
          this.activeSheet === BackupSheetKind.IGNORE_RESTORE_ITEMS ? '恢复忽略列表' : '')
          .fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
          .textAlign(TextAlign.Center).maxLines(1).layoutWeight(1)
        if (this.activeSheet === BackupSheetKind.IGNORE_BACKUP_ITEMS ||
            this.activeSheet === BackupSheetKind.IGNORE_RESTORE_ITEMS) {
          AppGlyph({ name: 'profileSave', glyphSize: 22, tint: this.themeColorAccent })
            .accessibilityText('保存')
            .onClick(() => this.dismissSheet())
        }
      }.width('100%').padding({ left: 18, right: 18, top: 12, bottom: 14 })
      if (this.activeSheet === BackupSheetKind.CHOOSE_BACKUP_PATH) {
        Grid() {
          GridItem() {
            BackupOptionCard({ icon: 'folder', title: '系统文件夹选择器',
              onSelect: () => { this.dismissSheet(); this.onChooseBackupPath(); } })
          }
        }.columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12).padding({ left: 16, right: 16 })
      } else if (this.activeSheet === BackupSheetKind.BACKUP_OPTIONS) {
        Grid() {
          GridItem() {
            BackupOptionCard({ icon: 'folder', title: '备份至本地',
              onSelect: () => { this.dismissSheet(); this.onCreateBackup(); } })
          }
          GridItem() {
            BackupOptionCard({ icon: 'cloud', title: '备份至网络',
              onSelect: () => { this.dismissSheet(); this.onBackupToWebDav(); } })
          }
          GridItem() {
            BackupOptionCard({ icon: 'grid', title: '备份至本地与网络',
              onSelect: () => { this.dismissSheet(); this.onCreateBackupBoth(); } })
          }
        }.columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12).padding({ left: 16, right: 16 })
      } else if (this.activeSheet === BackupSheetKind.RESTORE_OPTIONS) {
        Grid() {
          GridItem() {
            BackupOptionCard({ icon: 'folder', title: '本地恢复',
              onSelect: () => { this.dismissSheet(); this.onSelectRestore(); } })
          }
          GridItem() {
            BackupOptionCard({ icon: 'cloud', title: '网络恢复',
              onSelect: () => { this.dismissSheet(); this.requestNetworkRestore(); } })
          }
        }.columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12).padding({ left: 16, right: 16 })
      } else if (this.activeSheet === BackupSheetKind.RESTORE_FILES) {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.networkNames, (name: string) => {
              BackupSheetOption({ title: name, detail: '',
                onSelect: () => { this.dismissSheet(); this.onRestoreNetwork(name); } })
            }, (name: string) => name)
          }.width('100%').padding({ left: 16, right: 16 })
        }.height(360).scrollBar(BarState.Off).edgeEffect(EdgeEffect.None)
      } else if (this.activeSheet === BackupSheetKind.IGNORE_BACKUP_ITEMS ||
                 this.activeSheet === BackupSheetKind.IGNORE_RESTORE_ITEMS) {
        Column() {
          Row({ space: 8 }) {
            Column() {
              Text('配置忽略').fontSize(LABEL_MEDIUM_EMPHASIZED)
                .fontWeight(this.ignoreTab === 0 ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.ignoreTab === 0 ? this.themeColorTextPrimary : this.themeColorTextSecondary)
                .maxLines(1).textAlign(TextAlign.Center)
            }.layoutWeight(1).height(40).borderRadius(12)
              .backgroundColor(this.ignoreTab === 0 ? this.themeColorSurfaceElevated : this.themeColorSurfaceTertiary)
              .padding({ left: 8, right: 8, top: 8, bottom: 8 }).justifyContent(FlexAlign.Center)
              .onClick(() => this.ignoreTab = 0)
            Column() {
              Text('数据库忽略').fontSize(LABEL_MEDIUM_EMPHASIZED)
                .fontWeight(this.ignoreTab === 1 ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.ignoreTab === 1 ? this.themeColorTextPrimary : this.themeColorTextSecondary)
                .maxLines(1).textAlign(TextAlign.Center)
            }.layoutWeight(1).height(40).borderRadius(12)
              .backgroundColor(this.ignoreTab === 1 ? this.themeColorSurfaceElevated : this.themeColorSurfaceTertiary)
              .padding({ left: 8, right: 8, top: 8, bottom: 8 }).justifyContent(FlexAlign.Center)
              .onClick(() => this.ignoreTab = 1)
          }.width('100%').padding({ left: 16, right: 16, bottom: 8 })
          Scroll() {
            Column({ space: 4 }) {
              ForEach(this.visibleIgnoreItems(), (item: BackupIgnoreItem) => {
                BackupCheckItem({ title: item.title, checked: item.checked,
                  onChange: (checked: boolean) => this.toggleIgnoreItem(item.key, checked) })
              }, (item: BackupIgnoreItem) => item.key)
            }.width('100%').padding({ left: 8, right: 8 })
          }.layoutWeight(1).scrollBar(BarState.Off).edgeEffect(EdgeEffect.None)
        }.width('100%').layoutWeight(1)
      }
    }.width('100%').padding({ bottom: 16 })
  }

  @Builder
  private dialogContent() {
    Column() {
      if (this.activeDialog === BackupDialogKind.WEBDAV_AUTH) {
        Column() {
          Text('WebDav 账号').fontSize(HEADLINE_SMALL).fontColor(this.themeColorTextPrimary).width('100%')
          Column({ space: 12 }) {
            TextInput({ placeholder: 'WebDav 账号', text: this.accountDraft })
              .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).backgroundColor(Color.Transparent)
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .onChange((value: string) => this.accountDraft = value)
              .border({ width: 1, color: this.themeColorTextTertiary }).borderRadius(4)
            Row() {
              TextInput({ placeholder: 'WebDav 密码', text: this.passwordDraft })
                .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).backgroundColor(Color.Transparent)
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .type(this.passwordVisible ? InputType.Normal : InputType.Password)
                // 关掉 ArkUI 自带的密码可见图标，只保留下面与上游 trailingIcon 对应的那一个。
                .showPasswordIcon(false)
                .layoutWeight(1)
                .onChange((value: string) => this.passwordDraft = value)
              AppGlyph({ name: this.passwordVisible ? 'visibility' : 'visibilityOff', glyphSize: 20,
                tint: this.themeColorTextSecondary })
                .margin({ left: 12 })
                .accessibilityText(this.passwordVisible ? '隐藏密码' : '显示密码')
                .onClick(() => { this.passwordVisible = !this.passwordVisible; })
            }.width('100%').border({ width: 1, color: this.themeColorTextTertiary }).borderRadius(4)
          }.width('100%').margin({ top: 16 })
          Row({ space: 12 }) {
            Button('取消').type(ButtonType.Normal).layoutWeight(1).height(40).fontSize(LABEL_LARGE)
              .fontColor(this.themeColorAccent).backgroundColor(Color.Transparent)
              .border({ width: 1, color: this.themeColorTextTertiary }).borderRadius(20)
              .onClick(() => this.activeDialog = BackupDialogKind.NONE)
            Button('确认').type(ButtonType.Normal).layoutWeight(1).height(40).fontSize(LABEL_LARGE)
              .backgroundColor(this.themeColorAccent).borderRadius(20)
              .onClick(() => {
                this.activeDialog = BackupDialogKind.NONE;
                this.onSaveWebDavAuth(this.accountDraft, this.passwordDraft);
              })
          }.width('100%').margin({ top: 24 })
        }.width(312).padding(24).backgroundColor(this.themeColorSurfaceElevated).borderRadius(28)
      } else if (this.activeDialog === BackupDialogKind.CONFIRM_LOCAL_RESTORE_FALLBACK) {
        Column() {
          Text('恢复').fontSize(HEADLINE_SMALL).fontColor(this.themeColorTextPrimary).width('100%')
          Text(`WebDAV 出错\n${this.fallbackError}\n将从本地备份恢复。`)
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).margin({ top: 16 }).width('100%')
          Row({ space: 12 }) {
            Button('取消').type(ButtonType.Normal).layoutWeight(1).height(40).fontSize(LABEL_LARGE)
              .fontColor(this.themeColorAccent).backgroundColor(Color.Transparent)
              .border({ width: 1, color: this.themeColorTextTertiary }).borderRadius(20)
              .onClick(() => this.activeDialog = BackupDialogKind.NONE)
            Button('确认').type(ButtonType.Normal).layoutWeight(1).height(40).fontSize(LABEL_LARGE)
              .backgroundColor(this.themeColorAccent).borderRadius(20)
              .onClick(() => {
                this.activeDialog = BackupDialogKind.NONE;
                this.onConfirmLocalRestoreFallback();
              })
          }.width('100%').margin({ top: 24 })
        }.width(312).padding(24).backgroundColor(this.themeColorSurfaceElevated).borderRadius(28)
      } else {
        Column() {
          LoadingProgress().width(40).height(40).color(this.themeColorAccent)
          Text(this.webDavTesting ? '测试中…' : '加载中…')
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).margin({ top: 12 })
        }.width(240).padding(28).backgroundColor(this.themeColorSurfaceElevated).borderRadius(28)
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      }
    }
  }
}

/** 行内输入行：默认态显示标题/描述/当前值，点击后在行内展开输入框 + 默认/确认。 */
@Component
struct BackupInputRow {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  /** 真时本行自填 surfaceContainerLow + 4dp 圆角小卡（对齐 SettingItem.kt:53,73-79）。 */
  @Prop cardSurface: boolean = false;
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop value: string = '';
  @Prop defaultValue: string = '';
  @Prop editing: boolean = false;
  @Prop draft: string = '';
  onBegin: () => void = () => {};
  onDraft: (value: string) => void = (_value: string) => {};
  onConfirm: (value: string) => void = (_value: string) => {};
  build() {
    Column() {
      if (this.editing) {
        TextInput({ text: this.draft })
          .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
          .backgroundColor(Color.Transparent).border({ width: 1, color: this.themeColorTextTertiary }).borderRadius(4)
          .margin({ left: 16, right: 16, top: 8 })
          .onChange((value: string) => this.onDraft(value))
        Row({ space: 12 }) {
          Button('默认').type(ButtonType.Normal).layoutWeight(1).height(36).fontSize(TITLE_SMALL)
            .fontColor(this.themeColorAccent).backgroundColor(Color.Transparent)
            .border({ width: 1, color: this.themeColorTextTertiary }).borderRadius(18)
            .onClick(() => this.onDraft(this.defaultValue))
          Button('确认').type(ButtonType.Normal).layoutWeight(1).height(36).fontSize(TITLE_SMALL)
            .backgroundColor(this.themeColorAccent).borderRadius(18)
            .onClick(() => this.onConfirm(this.draft))
        }.width('calc(100% - 32vp)').margin({ left: 16, right: 16, top: 10, bottom: 12 })
      } else {
        Row() {
          Column() {
            Text(this.title).fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
            if (this.detail.length > 0) {
              Text(this.detail).fontSize(BODY_SMALL_EMPHASIZED).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
            }
            if (this.value.length > 0) {
              Text(this.value).fontSize(BODY_SMALL).fontColor(this.themeColorAccent).margin({ top: 2 })
            }
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Image($r('app.media.reader_next')).width(24).height(24).fillColor(this.themeColorTextTertiary)
        }.padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor(this.cardSurface ? this.themeColorSurfaceSecondary : Color.Transparent)
          .borderRadius(this.cardSurface ? 4 : 0)
          .onClick(() => this.onBegin())
      }
    }.width('100%')
  }
}

/** 两列网格选项卡：对齐上游 OptionSheet 的 100dp 见方、32dp 图标、单行居中文字。 */
@Component
struct BackupOptionCard {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @Prop icon: AppGlyphName = 'folder';
  @Prop title: string = '';
  @Prop disabled: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Column() {
      AppGlyph({ name: this.icon, glyphSize: 32, tint: this.disabled ? '#656873' : this.themeColorAccent })
      Text(this.title).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextPrimary)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 8 })
    }.width('100%').height(100).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .backgroundColor(this.themeColorSurfacePrimary).borderRadius(12)
      .opacity(this.disabled ? 0.5 : 1)
      .onClick(() => { if (!this.disabled) { this.onSelect(); } })
  }
}

@Component
struct BackupSheetOption {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop disabled: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Column() {
      Text(this.title).fontSize(TITLE_MEDIUM).fontColor(this.disabled ? this.themeColorTextTertiary : this.themeColorTextSecondary)
      if (this.detail.length > 0) {
        Text(this.detail).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary).margin({ top: 4 })
      }
    }.width('100%').padding(16).alignItems(HorizontalAlign.Start)
      .opacity(this.disabled ? 0.5 : 1)
      .backgroundColor('#292B33').borderRadius(14).margin({ bottom: 8 })
      .onClick(() => { if (!this.disabled) { this.onSelect(); } })
  }
}

/** 开关行：标题 +（可选）描述 + 右侧开关，整行可点。 */
@Component
struct BackupPreviewSwitchRow {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  /** 真时本行自填 surfaceContainerLow + 4dp 圆角小卡（对齐 SettingItem.kt:53,73-79）。 */
  @Prop cardSurface: boolean = false;
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop checked: boolean = false;
  onChange: (checked: boolean) => void = (_checked: boolean) => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        Text(this.detail).fontSize(BODY_SMALL_EMPHASIZED).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      UiSwitchControl({
        checked: this.checked,
        interactive: false,
        onChange: (checked: boolean) => this.onChange(checked)
      })
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor(this.cardSurface ? this.themeColorSurfaceSecondary : Color.Transparent)
      .borderRadius(this.cardSurface ? 4 : 0)
      .onClick(() => this.onChange(!this.checked))
  }
}

/** 点击行：上游 ClickableSettingItem 无 leading 图标，标题左缘与文字列对齐。 */
@Component
struct BackupActionRow {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  /** 真时本行自填 surfaceContainerLow + 4dp 圆角小卡（对齐 SettingItem.kt:53,73-79）。 */
  @Prop cardSurface: boolean = false;
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        Text(this.detail).fontSize(BODY_SMALL_EMPHASIZED).fontColor(this.themeColorTextTertiary).margin({ top: 2 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(24).height(24).fillColor(this.themeColorTextTertiary)
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor(this.cardSurface ? this.themeColorSurfaceSecondary : Color.Transparent)
      .borderRadius(this.cardSurface ? 4 : 0)
      .onClick(() => this.onSelect())
  }
}

/** 排除项清单行：左侧圆角复选框 + 标题，对齐上游 CheckboxItem。 */
@Component
struct BackupCheckItem {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @Prop title: string = '';
  @Prop checked: boolean = false;
  onChange: (checked: boolean) => void = (_checked: boolean) => {};
  build() {
    Row() {
      Checkbox({ name: this.title })
        .shape(CheckBoxShape.ROUNDED_SQUARE)
        .select(this.checked)
        .selectedColor(this.themeColorAccent)
      Text(this.title).fontSize(BODY_MEDIUM_EMPHASIZED).fontColor(this.themeColorTextPrimary)
        .maxLines(1).margin({ left: 12 }).layoutWeight(1)
    }.width('100%').padding({ left: 12, right: 12, top: 12, bottom: 12 })
      .borderRadius(12)
      .backgroundColor(this.checked ? this.themeColorSurfaceElevated : Color.Transparent)
      .onClick(() => this.onChange(!this.checked))
  }
}
