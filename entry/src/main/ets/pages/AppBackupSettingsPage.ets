import { DURATION_FADE, HEADER_COLLAPSE_THRESHOLD, HEADER_EXPAND_THRESHOLD } from '../components/UiTokens';
import { UiSwitchControl } from '../components/UiSwitchControl';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import curves from '@ohos.curves';
import { display } from '@kit.ArkUI';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { ThemeGroupColumn, ThemeGroupItem } from '../components/settings/ThemeGroupColumn';
import { UiDropdown } from '../components/settings/UiDropdown';
import { BackupCategoryOption } from '../data/BackupRepository';
import { WebDavSettings, defaultWebDavSettings } from '../lib/WebDavConfig';
import { WebDavSync } from '../lib/WebDavSync';
import {
  BACKUP_CONFIG_KEYS,
  BACKUP_CONFIG_TITLES,
  BACKUP_DB_KEYS,
  BACKUP_DB_TITLES,
  BackupConfigDialogKind,
  BackupConfigEffect,
  BackupConfigEffectKind,
  BackupConfigIntent,
  BackupConfigIntentKind,
  BackupConfigSheet,
  BackupConfigUiState,
  BackupConfigViewModel,
  BackupIgnoreItem,
  BackupLoadingTitle,
  buildIgnoreItems
} from '../viewmodel/BackupConfigViewModel';
import { BODY_MEDIUM_EMPHASIZED, BODY_SMALL, BODY_SMALL_EMPHASIZED, HEADLINE_SMALL, LABEL_LARGE, LABEL_MEDIUM, LABEL_MEDIUM_EMPHASIZED, LABEL_SMALL, TITLE_MEDIUM, TITLE_SMALL, TITLE_SMALL_LINE_HEIGHT } from '../components/typography/TypographyTokens';

/** 弹层高度上限占屏幕高度的比例：对齐上游 `AppModalBottomSheet.kt:134-137` 的 `containerHeight * 0.8f`。 */
const SHEET_MAX_SCREEN_RATIO: number = 0.8;

/**
 * 弹层头部占用的竖向预算：标题行高 + 头部 `padding(bottom = 16)` + 内容 `padding(bottom = 16)`。
 * 滚动区上限要把它扣掉，否则「头部 + 滚动区」会越过屏高 80%。
 */
const SHEET_HEADER_BUDGET: number = 54;

/** 本地备份与恢复页面，文件格式与 Android 原项目兼容。 */
@Component
export struct AppBackupSettingsPage {
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorBackground') themeColorBackground: string = '#F9FAEF';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#F0F1F5';
  @StorageProp('themeColorSecondaryContainer') themeColorSecondaryContainer: string = '#DCE7C8';
  @StorageProp('themeColorOnSecondaryContainer') themeColorOnSecondaryContainer: string = '#404A33';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop localBookCount: number = 0;
  @Prop categoryOptions: BackupCategoryOption[] = [];
  @Prop @Watch('onHostIgnoreKeys') backupIgnoreKeys: string[] = [];
  @Prop @Watch('onHostIgnoreKeys') restoreIgnoreKeys: string[] = [];
  /** 状态消息改走 showToast（对齐上游 Snackbar），不再在页内常驻成条。 */
  @Prop @Watch('syncStatusMessage') statusMessage: string = '';
  @Prop @Watch('syncDialog') busy: boolean = false;
  @Prop @Watch('onHostSettings') webDavSettings: WebDavSettings = defaultWebDavSettings();
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
  /**
   * 页面唯一状态对象：对应上游 `BackupConfigUiState`（BackupConfigContract.kt:9-19）。
   *
   * 上游是 `MutableStateFlow<BackupConfigUiState>`，Composable 只读这一份状态；
   * 本地用 `@State` 装同一个类实例，每次 intent 转移后由状态层整体替换，触发重绘。
   */
  @State state: BackupConfigUiState = new BackupConfigUiState();
  @State collapsedHeader: boolean = false;
  /** 顶栏连续折叠进度，对齐上游 TopAppBarState.collapsedFraction（不在 UiState 里）。 */
  @State headerFraction: number = 0;
  private backupScroller: Scroller = new Scroller();
  /** 状态层：intent 入口 + effect 出队，对应上游 BackupConfigViewModel。 */
  private viewModel: BackupConfigViewModel = new BackupConfigViewModel([], []);
  /** openCustomDialog 的 builder 需存成成员，且每次重开重建以刷新内部输入态。 */
  private dialogBuilder: CustomBuilder | undefined = undefined;
  private dialogId: number = -1;

  aboutToAppear(): void {
    this.viewModel = new BackupConfigViewModel(this.backupIgnoreKeys, this.restoreIgnoreKeys);
    this.viewModel.bindStateSink((next: BackupConfigUiState): void => {
      this.state = next;
      this.syncDialog();
    });
    this.viewModel.bindEffectSink((effect: BackupConfigEffect): void => this.handleEffect(effect));
    this.viewModel.syncSettings(this.webDavSettings);
  }

  /** 宿主设置变化（含宿主自己写盘后回灌）→ 同步进状态层，保持单一真相。 */
  private onHostSettings(): void {
    this.viewModel.syncSettings(this.webDavSettings);
  }

  /** 宿主忽略键变化 → 按上游四张配置表重建忽略项。 */
  private onHostIgnoreKeys(): void {
    this.viewModel.rebuildIgnoreItems(this.backupIgnoreKeys, this.restoreIgnoreKeys);
  }

  /** 发一个 intent：唯一入口，对应上游 `viewModel.onIntent(...)`。 */
  private send(kind: BackupConfigIntentKind): void {
    this.viewModel.onIntent(new BackupConfigIntent(kind));
  }

  private sendValue(kind: BackupConfigIntentKind, value: string): void {
    const intent = new BackupConfigIntent(kind);
    intent.value = value;
    this.viewModel.onIntent(intent);
  }

  /** 请求备份：mode 走独立字段（上游 RequestBackup(mode) 的 mode 语义）。 */
  private sendMode(kind: BackupConfigIntentKind, mode: string): void {
    const intent = new BackupConfigIntent(kind);
    intent.mode = mode;
    this.viewModel.onIntent(intent);
  }

  private sendBool(kind: BackupConfigIntentKind, value: boolean): void {
    const intent = new BackupConfigIntent(kind);
    intent.boolValue = value;
    this.viewModel.onIntent(intent);
  }

  private sendSheet(kind: BackupConfigIntentKind, sheet: BackupConfigSheet): void {
    const intent = new BackupConfigIntent(kind);
    intent.sheet = sheet;
    this.viewModel.onIntent(intent);
  }

  /** 行内输入：开始编辑（键 + 当前值作为草稿）。 */
  private beginEdit(key: string, draft: string): void {
    const intent = new BackupConfigIntent(BackupConfigIntentKind.BeginEditField);
    intent.value = key;
    intent.path = draft;
    this.viewModel.onIntent(intent);
  }

  /** 行内输入：提交（键 + 新值）。 */
  private commitEdit(key: string, value: string): void {
    const intent = new BackupConfigIntent(BackupConfigIntentKind.CommitEditField);
    intent.value = key;
    intent.path = value;
    this.viewModel.onIntent(intent);
  }

  /** 行内输入：点「默认」把草稿改回默认值（不提交）。 */
  private resetDraft(value: string): void {
    const intent = new BackupConfigIntent(BackupConfigIntentKind.ResetEditField);
    intent.path = value;
    this.viewModel.onIntent(intent);
  }

  /**
   * effect 执行：状态层只决定「要做什么」，真正的 IO 在页面这一层
   * （页面持有 context 与宿主回调，与上游 ViewModel 持 useCase 同层）。
   */
  private handleEffect(effect: BackupConfigEffect): void {
    switch (effect.kind) {
      case BackupConfigEffectKind.PersistSettings:
        this.onWebDavSettingsChange(this.state.settings);
        break;
      case BackupConfigEffectKind.ShowMessage:
        this.onUnavailableAction(effect.value);
        break;
      case BackupConfigEffectKind.LaunchBackupDirectoryPicker:
        this.onChooseBackupPath();
        break;
      case BackupConfigEffectKind.LaunchBackupAndRunDirectoryPicker:
        this.onChooseBackupPath();
        break;
      case BackupConfigEffectKind.LaunchRestoreFilePicker:
        this.onSelectRestore();
        break;
      case BackupConfigEffectKind.LaunchImportOldDataPicker:
        this.onImportOldShelf();
        break;
      case BackupConfigEffectKind.RequestStoragePermission:
        // 上游在这里向系统要存储权限、回调再走 PerformBackup；本地目录访问由宿主的
        // DocumentViewPicker + persistPermission 在选目录时已拿到，这里直接执行备份。
        this.runBackupByMode(effect.path, effect.mode);
        break;
      case BackupConfigEffectKind.RunBackup:
        this.runBackupByMode(effect.path, effect.mode);
        break;
      case BackupConfigEffectKind.RunLocalRestore:
        this.onSelectRestore();
        break;
      case BackupConfigEffectKind.RunNetworkRestore:
        this.onRestoreNetwork(effect.name);
        break;
      case BackupConfigEffectKind.RunWebDavTest:
        this.onTestWebDav();
        break;
      case BackupConfigEffectKind.LoadNetworkBackupNames:
        this.loadNetworkBackupNames();
        break;
      case BackupConfigEffectKind.PersistIgnoreItems:
        this.persistIgnoreItems(effect.scope);
        break;
      default:
        break;
    }
  }

  /** 按上游 mode 三态分派到宿主的三个备份入口（'local' / 'webdav' / 'both'）。 */
  private runBackupByMode(path: string, mode: string): void {
    if (mode === 'webdav') {
      this.onBackupToWebDav();
    } else if (mode === 'both') {
      this.onCreateBackupBoth();
    } else {
      this.onCreateBackup();
    }
  }

  /** 拉远端备份列表：成功回 NetworkNamesLoaded，失败回 NetworkNamesFailed（ViewModel :311-340）。 */
  private async loadNetworkBackupNames(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    try {
      const names: string[] = await WebDavSync.listBackups(context);
      if (names.length > 0) {
        const intent = new BackupConfigIntent(BackupConfigIntentKind.NetworkNamesLoaded);
        intent.names = names;
        this.viewModel.onIntent(intent);
      } else {
        const intent = new BackupConfigIntent(BackupConfigIntentKind.NetworkNamesFailed);
        intent.error = '没有找到远端备份文件';
        this.viewModel.onIntent(intent);
      }
    } catch (error) {
      const intent = new BackupConfigIntent(BackupConfigIntentKind.NetworkNamesFailed);
      intent.error = error instanceof Error ? error.message : String(error);
      this.viewModel.onIntent(intent);
    }
  }

  /**
   * 把某一侧的忽略项交给宿主写盘。
   *
   * 上游 `saveIgnoreItems`（ViewModel :180-190）把配置维度与数据库维度一起写进
   * `ignoreConfig` / `dbIgnoreConfig`；本地宿主的忽略列表按「侧」扁平存一份数组
   * （配置键与数据库键同在这个数组里），所以这里取两个页签的并集一次提交。
   */
  private persistIgnoreItems(scope: string): void {
    const backupSide: boolean = scope === 'backup';
    const configItems: BackupIgnoreItem[] = backupSide ? this.state.backupIgnoreItems : this.state.ignoreItems;
    const dbItems: BackupIgnoreItem[] = backupSide ? this.state.backupDbIgnoreItems : this.state.dbIgnoreItems;
    const keys: string[] = configItems
      .concat(dbItems)
      .filter((item: BackupIgnoreItem): boolean => item.checked)
      .map((item: BackupIgnoreItem): string => item.key);
    this.onSaveIgnoreItems(backupSide ? 'backup' : 'restore', keys);
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

  /** 打开忽略面板时按上游键序构建该侧的内存副本（checked 取当前该侧键集合）。 */
  private openIgnoreSheet(sheet: BackupConfigSheet): void {
    this.viewModel.rebuildIgnoreItems(this.backupIgnoreKeys, this.restoreIgnoreKeys);
    this.sendSheet(BackupConfigIntentKind.OpenSheet, sheet);
  }

  private visibleIgnoreItems(): BackupIgnoreItem[] {
    return this.viewModel.ignoreItemsOf(this.state.activeSheet, this.state.ignoreTab);
  }

  /**
   * 勾选一个忽略项：按「哪一侧 + 哪个页签」派发到上游四个 toggle intent
   * （ToggleIgnoreItem / ToggleDbIgnoreItem / ToggleBackupIgnoreItem / ToggleBackupDbIgnoreItem）。
   */
  private sendIgnoreToggle(key: string, checked: boolean): void {
    const backupSide: boolean = this.state.activeSheet === BackupConfigSheet.IGNORE_BACKUP_ITEMS;
    const dbTab: boolean = this.state.ignoreTab === 1;
    let kind: BackupConfigIntentKind = BackupConfigIntentKind.ToggleIgnoreItem;
    if (backupSide && dbTab) {
      kind = BackupConfigIntentKind.ToggleBackupDbIgnoreItem;
    } else if (backupSide) {
      kind = BackupConfigIntentKind.ToggleBackupIgnoreItem;
    } else if (dbTab) {
      kind = BackupConfigIntentKind.ToggleDbIgnoreItem;
    }
    const intent = new BackupConfigIntent(kind);
    intent.value = key;
    intent.boolValue = checked;
    this.viewModel.onIntent(intent);
  }

  /**
   * 弹层整高上限。
   *
   * 上游 `AppModalBottomSheet.kt:134-137` 是 `containerHeight * 0.8f`，`:165` 再 `.heightIn(max = maxHeight)`。
   * 这里不能用 `constraintSize({ maxHeight: '80%' })`：sheet 用 FIT_CONTENT 时高度由内容决定，
   * 内容再用百分比向上要高度就成了循环依赖，实测内容整块被算成 0 —— 上机时弹层只剩遮罩、卡片区全空
   * （`components/booksource/SourceLoginSheet.ets:713-716` 记过同一个坑）。
   * 改成按屏高算绝对 vp，与 `components/UiMenu.ets:83-89` 的菜单上限同法。
   */
  private sheetMaxHeight(): number {
    try {
      return this.getUIContext().px2vp(display.getDefaultDisplaySync().height) * SHEET_MAX_SCREEN_RATIO;
    } catch (_) {
      return 560;
    }
  }

  /**
   * 弹层内滚动区的高度上限。
   *
   * 上限不能挂在弹层内容根上：FIT_CONTENT 下根节点的 `maxHeight` 会被当成测量约束，
   * 内容于是被撑到上限值，弹层退化成固定高、卡片下方留一片空白（上机实测）。
   * 所以挂在真正会溢出的那一层——远端文件列表与忽略列表的 Scroll 上，
   * 并扣掉头部与页签条已占的竖向空间，等价于上游「整层 heightIn(max) + 内容区自滚」。
   */
  private sheetScrollMaxHeight(reserved: number): number {
    return Math.max(120, this.sheetMaxHeight() - SHEET_HEADER_BUDGET - reserved);
  }

  /** 关闭即保存：对齐上游 IgnoreItemsSheet 的 onDismissRequest = onConfirm。 */
  private dismissSheet(): void {
    this.send(BackupConfigIntentKind.DismissSheet);
  }

  private dialogVisible(): boolean {
    return this.state.activeDialog !== BackupConfigDialogKind.NONE || this.busy || this.webDavTesting;
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
          this.send(BackupConfigIntentKind.DismissDialog);
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
      // 上游 BackupConfigScreen.kt:160-167 用 LazyColumn(fillMaxSize,
      // contentPadding = adaptiveContentPadding(top = 顶栏高度, bottom = 120.dp)) 承载两组
      // SplicedColumnGroup（该文件只有 :168 与 :232 两个 item{}，没有 items() 动态列表）。
      // 本地改用 List + ListItem 一一对应这两个分组，垂直内边距走 contentStartOffset /
      // contentEndOffset（list.d.ts:1054 / :1090），水平 16 由 List 自身 padding 承担。
      List({ scroller: this.backupScroller }) {
        ListItem() {
          ThemeGroupColumn({ title: 'WebDav 设置', surfaceFill: false }) {
            ThemeGroupItem({ first: true }) {
              BackupInputRow({ cardSurface: true, title: 'WebDav 服务器地址', detail: '输入你的WebDav服务器地址',
                value: this.state.settings.url, defaultValue: '', editing: this.state.editingKey === 'url',
                draft: this.state.inputDraft,
                onBegin: () => this.beginEdit('url', this.state.settings.url),
                onDraft: (value: string) => this.sendValue(BackupConfigIntentKind.UpdateInputDraft, value),
                onConfirm: (value: string) => this.commitEdit('url', value) })
            }
            ThemeGroupItem() {
              BackupActionRow({ cardSurface: true, title: 'WebDav 账号', detail: this.webDavAuthDetail(),
                onSelect: () => this.send(BackupConfigIntentKind.OpenWebDavAuth) })
            }
            ThemeGroupItem() {
              BackupInputRow({ cardSurface: true, title: '子文件夹', detail: '',
                value: this.state.settings.dir.length > 0 ? this.state.settings.dir : 'legado',
                defaultValue: 'legado', editing: this.state.editingKey === 'dir',
                draft: this.state.inputDraft,
                onBegin: () => this.beginEdit('dir', this.state.settings.dir.length > 0 ? this.state.settings.dir : 'legado'),
                onDraft: (value: string) => this.sendValue(BackupConfigIntentKind.UpdateInputDraft, value),
                onConfirm: (value: string) => this.commitEdit('dir', value) })
            }
            ThemeGroupItem() {
              BackupInputRow({ cardSurface: true, title: '设备名称', detail: '',
                value: this.state.settings.deviceName, defaultValue: '', editing: this.state.editingKey === 'deviceName',
                draft: this.state.inputDraft,
                onBegin: () => this.beginEdit('deviceName', this.state.settings.deviceName),
                onDraft: (value: string) => this.sendValue(BackupConfigIntentKind.UpdateInputDraft, value),
                onConfirm: (value: string) => this.commitEdit('deviceName', value) })
            }
            ThemeGroupItem() {
              BackupActionRow({ cardSurface: true, title: '测试 WebDav 配置', detail: '测试 WebDav 服务工作状态',
                onSelect: () => this.send(BackupConfigIntentKind.TestWebDav) })
            }
            ThemeGroupItem() {
              BackupPreviewSwitchRow({ cardSurface: true, title: '同步阅读进度',
                detail: '进入退出阅读界面时同步阅读进度',
                checked: this.state.settings.syncBookProgress,
                onChange: (value: boolean) => this.sendBool(BackupConfigIntentKind.SetSyncBookProgress, value) })
            }
            if (this.state.settings.syncBookProgress) {
              ThemeGroupItem() {
                BackupPreviewSwitchRow({ cardSurface: true, title: '同步增强',
                  detail: '重新进入页面（息屏、后台返回等）或者网络变为可用时同步云端进度',
                  checked: this.state.settings.syncBookProgressPlus,
                  onChange: (value: boolean) => this.sendBool(BackupConfigIntentKind.SetSyncBookProgressPlus, value)
                }).transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE }))
              }
            }
            ThemeGroupItem() {
              BackupPreviewSwitchRow({ cardSurface: true, title: '自动检查新备份',
                detail: '打开软件时检查是否有新备份，有新备份时提示是否更新',
                checked: this.state.settings.autoCheckNewBackup,
                onChange: (value: boolean) => this.sendBool(BackupConfigIntentKind.SetAutoCheckNewBackup, value) })
            }
            ThemeGroupItem() {
              UiDropdown({ cardSurface: true, title: '自动备份同步', detail: '选择自动备份时的同步行为',
                option: this.state.settings.backupSyncMode,
                options: ['both', 'local', 'webdav'],
                labelOf: (value: string) => this.syncModeLabel(value),
                onSelect: (value: string) => this.sendValue(BackupConfigIntentKind.SetBackupSyncMode, value), showDivider: false })
            }
          }

        }
        ListItem() {
          ThemeGroupColumn({ title: '备份与恢复', surfaceFill: false }) {
            ThemeGroupItem({ first: true }) {
              BackupActionRow({ cardSurface: true, title: '备份路径',
                detail: this.state.settings.backupPath.trim().length === 0 ? '请选择备份路径' : this.state.settings.backupPath,
                onSelect: () => this.send(BackupConfigIntentKind.SelectBackupDirectory) })
            }
            ThemeGroupItem() {
              BackupActionRow({ cardSurface: true, title: '备份', detail: '本地和 WebDav 一起备份',
                onSelect: () => this.sendSheet(BackupConfigIntentKind.OpenSheet, BackupConfigSheet.BACKUP_OPTIONS) })
            }
            ThemeGroupItem() {
              BackupActionRow({ cardSurface: true, title: '恢复', detail: '选择从本地或网络恢复备份',
                onSelect: () => this.sendSheet(BackupConfigIntentKind.OpenSheet, BackupConfigSheet.RESTORE_OPTIONS) })
            }
            ThemeGroupItem() {
              BackupActionRow({ cardSurface: true, title: '恢复忽略列表', detail: '选择恢复忽略内容',
                onSelect: () => this.openIgnoreSheet(BackupConfigSheet.IGNORE_RESTORE_ITEMS) })
            }
            ThemeGroupItem() {
              BackupActionRow({ cardSurface: true, title: '备份忽略列表', detail: '选择备份忽略内容',
                onSelect: () => this.openIgnoreSheet(BackupConfigSheet.IGNORE_BACKUP_ITEMS) })
            }
            ThemeGroupItem() {
              BackupActionRow({ cardSurface: true, title: '导入旧版数据', detail: '选择旧版备份文件夹',
                onSelect: () => this.send(BackupConfigIntentKind.RequestImportOldData) })
            }
            ThemeGroupItem() {
              BackupPreviewSwitchRow({ cardSurface: true, title: '仅保留最新备份',
                detail: '本地备份仅保留最新备份文件',
                checked: this.state.settings.onlyLatestBackup,
                onChange: (value: boolean) => this.sendBool(BackupConfigIntentKind.SetOnlyLatestBackup, value) })
            }
          }
        }
      }.width('100%').padding({ left: 16, right: 16 }).contentStartOffset(16).contentEndOffset(120)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off)
      .onDidScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent
      // 上游 AppScaffold.kt:81-87 的 containerColor 是 `if (hasImageBg) Color.Transparent else
      // LegadoTheme.colorScheme.background`，取的是 background 令牌而不是 surface。
      // 本地 themeColorBackground（ThemePalette.ets:1143 = colors.background）与
      // themeColorSurfacePrimary（:1173 = colors.surface）是两个不同取值（默认浅色 #F9FAEF vs #F5F6F8），
      // 这里必须用前者才与上游同色。整页贴图与 blur 由宿主根层
      // （pages/Index.ets:13487-13499，对应上游 AppScaffold.kt:248-268）负责，本页只做「有背景图就透明」。
      : (this.themePureBlack ? '#000000' : this.themeColorBackground))
      .bindSheet(this.state.activeSheet !== BackupConfigSheet.NONE, this.backupSheetContent(), {
        // 上游 AppModalBottomSheet.kt:165 是 heightIn(max = 容器高 * 0.8) + :167 animateContentSize：
        // 内容少时 sheet 只占内容高度，最多 80%。原先按分支写死 560/420/320 固定像素，
        // 三卡备份弹层与两卡恢复弹层都会被拉到同一高度、卡片下面留大片空白。
        // ArkUI 对应档位是 SheetSize.FIT_CONTENT（common.d.ts:7968-7977，since 11「The height fit content」）；
        // 80% 上限不能挂在内容根上（FIT_CONTENT 下根节点的 maxHeight 会被当成测量约束，
        // 内容被撑到上限值、弹层又退化成固定高），改挂在真正会溢出的内层 Scroll 上，
        // 见 sheetScrollMaxHeight()。
        height: SheetSize.FIT_CONTENT,
        dragBar: true,
        showClose: false,
        backgroundColor: this.themeColorSurfaceTertiary,
        onDisappear: () => {
          if (this.state.activeSheet !== BackupConfigSheet.NONE) {
            this.dismissSheet();
          }
        }
      })
      .onAppear(() => this.syncDialog())
  }

  @Builder
  private backupSheetContent() {
    Column() {
      // 上游 AppModalBottomSheet.kt:175-204 的头是 `Box.fillMaxWidth().padding(bottom = 16.dp)`
      // + `contentAlignment = Center`，标题带 `padding(horizontal = 56.dp)` 给两侧动作留位。
      // 用 Box 居中而不是 Row + layoutWeight：右侧有时有保存图标、有时没有，Row 会让标题跟着左右偏。
      Stack({ alignContent: Alignment.Center }) {
        Text(this.state.activeSheet === BackupConfigSheet.CHOOSE_BACKUP_PATH ? '选择操作' :
          this.state.activeSheet === BackupConfigSheet.BACKUP_OPTIONS ? '备份' :
          this.state.activeSheet === BackupConfigSheet.RESTORE_OPTIONS ? '恢复' :
          this.state.activeSheet === BackupConfigSheet.RESTORE_FILES ? '选择恢复文件' :
          this.state.activeSheet === BackupConfigSheet.IGNORE_BACKUP_ITEMS ? '备份忽略列表' :
          this.state.activeSheet === BackupConfigSheet.IGNORE_RESTORE_ITEMS ? '恢复忽略列表' : '')
          .fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
          .textAlign(TextAlign.Center).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 56, right: 56 })
        if (this.state.activeSheet === BackupConfigSheet.IGNORE_BACKUP_ITEMS ||
            this.state.activeSheet === BackupConfigSheet.IGNORE_RESTORE_ITEMS) {
          Row() {
            Blank()
            AppGlyph({ name: 'profileSave', glyphSize: 22, tint: this.themeColorAccent })
              .accessibilityText('保存')
              .onClick(() => this.dismissSheet())
          }.width('100%')
        }
      }.width('100%').padding({ bottom: 16 })
      if (this.state.activeSheet === BackupConfigSheet.CHOOSE_BACKUP_PATH) {
        Grid() {
          GridItem() {
            BackupOptionCard({ icon: 'folder', title: '系统文件夹选择器',
              onSelect: () => this.send(BackupConfigIntentKind.SelectBackupDirectory) })
          }
        }.columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12)
        // 上游 OptionSheet.kt:49 在卡片流之后还有 `Spacer(modifier = Modifier.height(24.dp))`。
        Row().width('100%').height(24)
      } else if (this.state.activeSheet === BackupConfigSheet.BACKUP_OPTIONS) {
        Grid() {
          GridItem() {
            BackupOptionCard({ icon: 'folder', title: '备份至本地',
              onSelect: () => this.sendMode(BackupConfigIntentKind.RequestBackup, 'local') })
          }
          GridItem() {
            BackupOptionCard({ icon: 'cloud', title: '备份至网络',
              onSelect: () => this.sendMode(BackupConfigIntentKind.RequestBackup, 'webdav') })
          }
          GridItem() {
            BackupOptionCard({ icon: 'grid', title: '备份至本地与网络',
              onSelect: () => this.sendMode(BackupConfigIntentKind.RequestBackup, 'both') })
          }
        }.columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12)
        // 上游 OptionSheet.kt:49 在卡片流之后还有 `Spacer(modifier = Modifier.height(24.dp))`。
        Row().width('100%').height(24)
      } else if (this.state.activeSheet === BackupConfigSheet.RESTORE_OPTIONS) {
        Grid() {
          GridItem() {
            BackupOptionCard({ icon: 'folder', title: '本地恢复',
              onSelect: () => this.send(BackupConfigIntentKind.RequestLocalRestore) })
          }
          GridItem() {
            BackupOptionCard({ icon: 'cloud', title: '网络恢复',
              onSelect: () => this.send(BackupConfigIntentKind.RequestNetworkRestore) })
          }
        }.columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12)
        // 上游 OptionSheet.kt:49 在卡片流之后还有 `Spacer(modifier = Modifier.height(24.dp))`。
        Row().width('100%').height(24)
      } else if (this.state.activeSheet === BackupConfigSheet.RESTORE_FILES) {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.state.backupNames, (name: string) => {
              BackupSheetOption({ title: name, detail: '',
                onSelect: () => this.sendValue(BackupConfigIntentKind.RestoreNetwork, name) })
            }, (name: string) => name)
          }.width('100%').padding({ bottom: 16 })
        }.constraintSize({ maxHeight: this.sheetScrollMaxHeight(0) }).scrollBar(BarState.Off).edgeEffect(EdgeEffect.None)
      } else if (this.state.activeSheet === BackupConfigSheet.IGNORE_BACKUP_ITEMS ||
                 this.state.activeSheet === BackupConfigSheet.IGNORE_RESTORE_ITEMS) {
        // 上游 BackupConfigScreen.kt:407-442：内容是一个 `Column.fillMaxWidth().verticalScroll(...)`，
        // `verticalArrangement = spacedBy(4.dp)`，页签条 CardTabRow 与复选框同在这一个滚动容器里
        // （页签会随列表一起滚走，不吸顶）。所以这里也把页签条放进 Scroll，而不是单独吸在顶部。
        // 页签与复选框都不另加左右内缩：上游 CardTabRow 与 CheckboxItem 直接贴内容 Column 的边，
        // 左右 16 由 AppModalBottomSheet 的内容 padding 统一给（已在内容根上设置）。
        Scroll() {
          Column({ space: 4 }) {
            // 上游 CardTabRow.kt:101-139：每个页签是 NormalCard(cornerRadius 12)，
            // 文字 padding(horizontal 8, vertical 8)，非 scrollable 时 `Modifier.weight(1f)` 均分，
            // 选中色 secondaryContainer / 文字 onSecondaryContainer，
            // 未选中色 surfaceContainerLow / 文字 onSurfaceVariant，选中加粗。
            Row({ space: 8 }) {
              Column() {
                Text('配置忽略').fontSize(LABEL_MEDIUM_EMPHASIZED)
                  .fontWeight(this.state.ignoreTab === 0 ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.state.ignoreTab === 0 ? this.themeColorOnSecondaryContainer : this.themeColorTextSecondary)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .textAlign(TextAlign.Center).width('100%')
              }.layoutWeight(1).borderRadius(12)
                .backgroundColor(this.state.ignoreTab === 0 ? this.themeColorSecondaryContainer : this.themeColorSurfaceSecondary)
                .padding({ left: 8, right: 8, top: 8, bottom: 8 }).justifyContent(FlexAlign.Center)
                .onClick(() => this.sendValue(BackupConfigIntentKind.SelectIgnoreTab, '0'))
              Column() {
                Text('数据库忽略').fontSize(LABEL_MEDIUM_EMPHASIZED)
                  .fontWeight(this.state.ignoreTab === 1 ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.state.ignoreTab === 1 ? this.themeColorOnSecondaryContainer : this.themeColorTextSecondary)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .textAlign(TextAlign.Center).width('100%')
              }.layoutWeight(1).borderRadius(12)
                .backgroundColor(this.state.ignoreTab === 1 ? this.themeColorSecondaryContainer : this.themeColorSurfaceSecondary)
                .padding({ left: 8, right: 8, top: 8, bottom: 8 }).justifyContent(FlexAlign.Center)
                .onClick(() => this.sendValue(BackupConfigIntentKind.SelectIgnoreTab, '1'))
            }.width('100%')
            Column({ space: 4 }) {
              ForEach(this.visibleIgnoreItems(), (item: BackupIgnoreItem) => {
                BackupCheckItem({ title: item.title, checked: item.checked,
                  onChange: (checked: boolean) => this.sendIgnoreToggle(item.key, checked) })
                // key 里带上 checked：ArkUI 的 ForEach 在 key 不变时直接复用子组件，
                // 不会重新计算 @Prop，于是「勾了但行底色不变」（上机实测）。
                // 上游 Compose 侧靠不可变列表 + 重组，每次勾选都拿到新 BackupIgnoreItem，
                // 这里把 checked 并进 key，等价于让该行重新构建一次。
              }, (item: BackupIgnoreItem) => `${item.key}:${item.checked}`)
            }.width('100%')
          }.width('100%')
        }.constraintSize({ maxHeight: this.sheetScrollMaxHeight(0) })
          .scrollBar(BarState.Off).edgeEffect(EdgeEffect.None)
      }
    // 上游 AppModalBottomSheet.kt:159-164：`contentPaddingEnabled` 为真时内容 Column 统一加
    // `padding(start = 16, end = 16, bottom = 16)`，头部与各分支都在这个缩进里。
    // 所以左右 16 只在这里给一次，分支内不再重复。
    }.width('100%').padding({ left: 16, right: 16, bottom: 16 })
  }

  @Builder
  private dialogContent() {
    Column() {
      if (this.state.activeDialog === BackupConfigDialogKind.WEBDAV_AUTH) {
        Column() {
          Text('WebDav 账号').fontSize(HEADLINE_SMALL).fontColor(this.themeColorTextPrimary).width('100%')
          Column({ space: 12 }) {
            TextInput({ placeholder: 'WebDav 账号', text: this.state.authAccount })
              .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).backgroundColor(Color.Transparent)
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .onChange((value: string) => this.sendValue(BackupConfigIntentKind.EditWebDavAccount, value))
              .border({ width: 1, color: this.themeColorTextTertiary }).borderRadius(4)
            Row() {
              TextInput({ placeholder: 'WebDav 密码', text: this.state.authPassword })
                .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).backgroundColor(Color.Transparent)
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .type(this.state.authPasswordVisible ? InputType.Normal : InputType.Password)
                // 关掉 ArkUI 自带的密码可见图标，只保留下面与上游 trailingIcon 对应的那一个。
                .showPasswordIcon(false)
                .layoutWeight(1)
                .onChange((value: string) => this.sendValue(BackupConfigIntentKind.EditWebDavPassword, value))
              AppGlyph({ name: this.state.authPasswordVisible ? 'visibility' : 'visibilityOff', glyphSize: 20,
                tint: this.themeColorTextSecondary })
                .margin({ left: 12 })
                .accessibilityText(this.state.authPasswordVisible ? '隐藏密码' : '显示密码')
                .onClick(() => this.send(BackupConfigIntentKind.TogglePasswordVisibility))
            }.width('100%').border({ width: 1, color: this.themeColorTextTertiary }).borderRadius(4)
          }.width('100%').margin({ top: 16 })
          Row({ space: 12 }) {
            Button('取消').type(ButtonType.Normal).layoutWeight(1).height(40).fontSize(LABEL_LARGE)
              .fontColor(this.themeColorAccent).backgroundColor(Color.Transparent)
              .border({ width: 1, color: this.themeColorTextTertiary }).borderRadius(20)
              .onClick(() => this.send(BackupConfigIntentKind.DismissDialog))
            Button('确认').type(ButtonType.Normal).layoutWeight(1).height(40).fontSize(LABEL_LARGE)
              .backgroundColor(this.themeColorAccent).borderRadius(20)
              .onClick(() => this.send(BackupConfigIntentKind.SaveWebDavAuth))
          }.width('100%').margin({ top: 24 })
        }.width(312).padding(24).backgroundColor(this.themeColorSurfaceElevated).borderRadius(28)
      } else if (this.state.activeDialog === BackupConfigDialogKind.CONFIRM_LOCAL_RESTORE_FALLBACK) {
        Column() {
          Text('恢复').fontSize(HEADLINE_SMALL).fontColor(this.themeColorTextPrimary).width('100%')
          Text(`WebDAV 出错\n${this.state.fallbackError}\n将从本地备份恢复。`)
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).margin({ top: 16 }).width('100%')
          Row({ space: 12 }) {
            Button('取消').type(ButtonType.Normal).layoutWeight(1).height(40).fontSize(LABEL_LARGE)
              .fontColor(this.themeColorAccent).backgroundColor(Color.Transparent)
              .border({ width: 1, color: this.themeColorTextTertiary }).borderRadius(20)
              .onClick(() => this.send(BackupConfigIntentKind.DismissDialog))
            Button('确认').type(ButtonType.Normal).layoutWeight(1).height(40).fontSize(LABEL_LARGE)
              .backgroundColor(this.themeColorAccent).borderRadius(20)
              .onClick(() => this.send(BackupConfigIntentKind.ConfirmLocalRestoreFallback))
          }.width('100%').margin({ top: 24 })
        }.width(312).padding(24).backgroundColor(this.themeColorSurfaceElevated).borderRadius(28)
      } else {
        Column() {
          LoadingProgress().width(40).height(40).color(this.themeColorAccent)
          Text(this.state.loadingTitle.length > 0 ? this.state.loadingTitle : '加载中…')
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
  // 上游 CheckboxItem.kt:30-33 是 `GlassCard(cornerRadius = 12.dp,
  // containerColor = if (checked && enabled) secondaryContainer else color)`，
  // `color` 默认值 `LegadoTheme.colorScheme.onSheetContent`（ThemePalette.ets:1165 即 colors.surface）。
  // 所以每行都是一张独立小卡：未选中 surface、选中 secondaryContainer。
  @StorageProp('themeColorOnSheetContent') themeColorOnSheetContent: string = '#F5F6F8';
  @StorageProp('themeColorSecondaryContainer') themeColorSecondaryContainer: string = '#DCE7C8';
  @Prop title: string = '';
  @Prop checked: boolean = false;
  onChange: (checked: boolean) => void = (_checked: boolean) => {};
  build() {
    Row() {
      // 上游 CheckboxItem.kt:30-43 是 `Row.fillMaxWidth().toggleable(...)` 整行可点，
      // 里面的 `AppCheckbox(checked, onCheckedChange = null)` 自身不处理事件，选中态完全由外部
      // checked 驱动。ArkUI 的 Checkbox 默认会自己吃掉点击并翻转内部视觉，导致「复选框打了勾、
      // 但行底色和状态都没变」（上机实测），所以这里把它的命中测试关掉，点击统一交给整行。
      Checkbox({ name: this.title })
        .shape(CheckBoxShape.ROUNDED_SQUARE)
        .select(this.checked)
        .selectedColor(this.themeColorAccent)
        .hitTestBehavior(HitTestMode.None)
      Text(this.title).fontSize(BODY_MEDIUM_EMPHASIZED).fontColor(this.themeColorTextPrimary)
        .maxLines(1).margin({ left: 12 }).layoutWeight(1)
    }.width('100%').padding({ left: 12, right: 12, top: 12, bottom: 12 })
      .borderRadius(12)
      .backgroundColor(this.checked ? this.themeColorSecondaryContainer : this.themeColorOnSheetContent)
      .onClick(() => this.onChange(!this.checked))
  }
}
