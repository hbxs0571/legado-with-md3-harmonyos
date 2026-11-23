/**
 * 备份与恢复页的状态层，逐项对应上游 `BackupConfigContract.kt` + `BackupConfigViewModel.kt`。
 *
 * 上游是 `MutableStateFlow<BackupConfigUiState>` + `onIntent(intent)` 单一入口 + `SharedFlow<BackupConfigEffect>`
 * 出队副作用。ArkTS 没有 StateFlow / SharedFlow / sealed interface，这里用等价物：
 * - 状态：`BackupConfigUiState` 一个类装全部字段，每次转移都 `clone()` 出新实例，页面 `@State` 整体替换即刷新
 * - intent：`BackupConfigIntent` 一个接口 + `BackupConfigIntentKind` 枚举，`onIntent` 里 switch 派发
 * - effect：`BackupConfigEffect` 同样形态，由 `onEffect` 回调交给页面执行（页面持有 context，与上游 useCase 同层）
 *
 * 上游文件锚点：Contract `:9-19` UiState / `:21-26` BackupIgnoreItem / `:28-36` Sheet 七项 /
 * `:38-47` Dialog 三项 / `:49-88` Intent 三十七项 / `:90-97` Effect 六项；
 * ViewModel `:49-108` onIntent 派发 / `:114-123` syncBookProgressPlus 联动 / `:144-153` saveWebDavAuth /
 * `:170-246` 四组 ignore 的 toggle 与 save / `:248-272` 目录选择与 requestBackup / `:311-353` 网络恢复与回退。
 */

import { WebDavSettings, defaultWebDavSettings, cloneWebDavSettings } from '../lib/WebDavConfig';

/** 弹层分支：对应上游 `BackupConfigSheet` 七项（BackupConfigContract.kt:28-36）。 */
export enum BackupConfigSheet {
  NONE = 'none',
  CHOOSE_BACKUP_PATH = 'chooseBackupPath',
  CHOOSE_BACKUP_AND_RUN = 'chooseBackupAndRun',
  BACKUP_OPTIONS = 'backupOptions',
  RESTORE_OPTIONS = 'restoreOptions',
  RESTORE_FILES = 'restoreFiles',
  IGNORE_RESTORE_ITEMS = 'ignoreRestoreItems',
  IGNORE_BACKUP_ITEMS = 'ignoreBackupItems'
}

/** 对话框分支：对应上游 `BackupConfigDialog` 三项（BackupConfigContract.kt:38-47）。 */
export enum BackupConfigDialogKind {
  NONE = 'none',
  WEBDAV_AUTH = 'webDavAuth',
  CONFIRM_LOCAL_RESTORE_FALLBACK = 'confirmLocalRestoreFallback',
  LOADING = 'loading'
}

/** 加载对话框的标题来源：对应上游 `BackupConfigDialog.Loading(titleRes)`（BackupConfigContract.kt:46）。 */
export enum BackupLoadingTitle {
  NONE = '',
  TEST_SYNC = '测试中…',
  BACKUP = '备份中…',
  RESTORE = '恢复中…',
  LOADING = '加载中…'
}

/** 忽略项：对应上游 `BackupIgnoreItem` 三字段（BackupConfigContract.kt:22-26）。 */
export class BackupIgnoreItem {
  key: string = '';
  title: string = '';
  checked: boolean = false;

  constructor(key: string, title: string, checked: boolean) {
    this.key = key;
    this.title = title;
    this.checked = checked;
  }

  clone(): BackupIgnoreItem {
    return new BackupIgnoreItem(this.key, this.title, this.checked);
  }
}

/**
 * 页面唯一状态，对应上游 `BackupConfigUiState`（BackupConfigContract.kt:9-19）。
 *
 * 上游有 settings / activeSheet / activeDialog / backupNames / ignoreItems / backupIgnoreItems /
 * dbIgnoreItems / backupDbIgnoreItems 八项。这里另外装了对话框草稿（账号、密码、可见性）、
 * 行内输入草稿与忽略页签下标 —— 上游那几项在 Dialog 数据类与 Composable 的 `remember` 里，
 * 集中到一个类里才能让 intent 派发有单一真相。
 */
export class BackupConfigUiState {
  settings: WebDavSettings = defaultWebDavSettings();
  activeSheet: BackupConfigSheet = BackupConfigSheet.NONE;
  activeDialog: BackupConfigDialogKind = BackupConfigDialogKind.NONE;
  loadingTitle: BackupLoadingTitle = BackupLoadingTitle.NONE;
  backupNames: string[] = [];
  ignoreItems: BackupIgnoreItem[] = [];
  backupIgnoreItems: BackupIgnoreItem[] = [];
  dbIgnoreItems: BackupIgnoreItem[] = [];
  backupDbIgnoreItems: BackupIgnoreItem[] = [];
  /** WebDavAuth 对话框的三个字段（BackupConfigContract.kt:41）。 */
  authAccount: string = '';
  authPassword: string = '';
  authPasswordVisible: boolean = false;
  /** ConfirmLocalRestoreFallback 的 error（BackupConfigContract.kt:43）。 */
  fallbackError: string = '';
  /** 行内输入行：正在编辑的字段键，空串表示没有在编辑。 */
  editingKey: string = '';
  inputDraft: string = '';
  /** 忽略面板的页签下标：0 配置维度、1 数据库维度（上游 IgnoreItemsSheet 的 selectedTab）。 */
  ignoreTab: number = 0;

  clone(): BackupConfigUiState {
    const next = new BackupConfigUiState();
    next.settings = cloneWebDavSettings(this.settings);
    next.activeSheet = this.activeSheet;
    next.activeDialog = this.activeDialog;
    next.loadingTitle = this.loadingTitle;
    next.backupNames = this.backupNames.slice();
    next.ignoreItems = this.ignoreItems.map((item: BackupIgnoreItem): BackupIgnoreItem => item.clone());
    next.backupIgnoreItems = this.backupIgnoreItems.map((item: BackupIgnoreItem): BackupIgnoreItem => item.clone());
    next.dbIgnoreItems = this.dbIgnoreItems.map((item: BackupIgnoreItem): BackupIgnoreItem => item.clone());
    next.backupDbIgnoreItems = this.backupDbIgnoreItems.map((item: BackupIgnoreItem): BackupIgnoreItem => item.clone());
    next.authAccount = this.authAccount;
    next.authPassword = this.authPassword;
    next.authPasswordVisible = this.authPasswordVisible;
    next.fallbackError = this.fallbackError;
    next.editingKey = this.editingKey;
    next.inputDraft = this.inputDraft;
    next.ignoreTab = this.ignoreTab;
    return next;
  }
}

/** intent 种类：对应上游 `BackupConfigIntent` 三十七项（BackupConfigContract.kt:49-88）。 */
export enum BackupConfigIntentKind {
  // 设置字段（八项）
  SetWebDavUrl = 'setWebDavUrl',
  SetWebDavDir = 'setWebDavDir',
  SetWebDavDeviceName = 'setWebDavDeviceName',
  SetSyncBookProgress = 'setSyncBookProgress',
  SetSyncBookProgressPlus = 'setSyncBookProgressPlus',
  SetAutoCheckNewBackup = 'setAutoCheckNewBackup',
  SetOnlyLatestBackup = 'setOnlyLatestBackup',
  SetBackupSyncMode = 'setBackupSyncMode',
  // 弹层（两项）
  OpenSheet = 'openSheet',
  DismissSheet = 'dismissSheet',
  // WebDav 账号对话框（六项）
  OpenWebDavAuth = 'openWebDavAuth',
  EditWebDavAccount = 'editWebDavAccount',
  EditWebDavPassword = 'editWebDavPassword',
  TogglePasswordVisibility = 'togglePasswordVisibility',
  SaveWebDavAuth = 'saveWebDavAuth',
  TestWebDav = 'testWebDav',
  // 忽略列表（十项）
  OpenIgnoreDialog = 'openIgnoreDialog',
  ToggleIgnoreItem = 'toggleIgnoreItem',
  SaveIgnoreItems = 'saveIgnoreItems',
  OpenBackupIgnoreDialog = 'openBackupIgnoreDialog',
  ToggleBackupIgnoreItem = 'toggleBackupIgnoreItem',
  SaveBackupIgnoreItems = 'saveBackupIgnoreItems',
  ToggleDbIgnoreItem = 'toggleDbIgnoreItem',
  SaveDbIgnoreItems = 'saveDbIgnoreItems',
  ToggleBackupDbIgnoreItem = 'toggleBackupDbIgnoreItem',
  SaveBackupDbIgnoreItems = 'saveBackupDbIgnoreItems',
  // 对话框关闭（一项）
  DismissDialog = 'dismissDialog',
  // 目录与备份（六项）
  SelectBackupDirectory = 'selectBackupDirectory',
  SelectBackupAndRunDirectory = 'selectBackupAndRunDirectory',
  BackupDirectorySelected = 'backupDirectorySelected',
  RequestBackup = 'requestBackup',
  PerformBackup = 'performBackup',
  // 恢复（六项）
  RequestLocalRestore = 'requestLocalRestore',
  RestoreLocal = 'restoreLocal',
  RequestNetworkRestore = 'requestNetworkRestore',
  RestoreNetwork = 'restoreNetwork',
  ConfirmLocalRestoreFallback = 'confirmLocalRestoreFallback',
  RequestImportOldData = 'requestImportOldData',
  // 页面本地补充（上游在 Composable 的 remember 里，这里收进同一入口）
  BeginEditField = 'beginEditField',
  UpdateInputDraft = 'updateInputDraft',
  CommitEditField = 'commitEditField',
  ResetEditField = 'resetEditField',
  SelectIgnoreTab = 'selectIgnoreTab',
  // 副作用回报（对应上游 ViewModel 内部 await 之后的 _uiState.update）
  HostStateChanged = 'hostStateChanged',
  NetworkNamesLoaded = 'networkNamesLoaded',
  NetworkNamesFailed = 'networkNamesFailed',
  OperationFinished = 'operationFinished'
}

/** intent 载荷：字段按种类取用，未用到的留空。 */
export class BackupConfigIntent {
  kind: BackupConfigIntentKind = BackupConfigIntentKind.DismissSheet;
  value: string = '';
  boolValue: boolean = false;
  sheet: BackupConfigSheet = BackupConfigSheet.NONE;
  error: string = '';
  names: string[] = [];
  loadingTitle: BackupLoadingTitle = BackupLoadingTitle.NONE;
  /** 行内输入草稿（上游 BackupConfigIntent 里对应 EditXxx(value)，本页多一步草稿态）。 */
  path: string = '';
  /** 备份模式：'local' | 'webdav' | 'both'（上游 RequestBackup(mode)）。 */
  mode: string = '';

  constructor(kind: BackupConfigIntentKind) {
    this.kind = kind;
  }
}

/** effect 种类：对应上游 `BackupConfigEffect` 六项（BackupConfigContract.kt:90-97），另加执行类动作。 */
export enum BackupConfigEffectKind {
  /** 上游 :92 LaunchBackupDirectoryPicker */
  LaunchBackupDirectoryPicker = 'launchBackupDirectoryPicker',
  /** 上游 :93 LaunchBackupAndRunDirectoryPicker */
  LaunchBackupAndRunDirectoryPicker = 'launchBackupAndRunDirectoryPicker',
  /** 上游 :94 LaunchRestoreFilePicker */
  LaunchRestoreFilePicker = 'launchRestoreFilePicker',
  /** 上游 :95 LaunchImportOldDataPicker */
  LaunchImportOldDataPicker = 'launchImportOldDataPicker',
  /** 上游 :96 RequestStoragePermission(path, mode) */
  RequestStoragePermission = 'requestStoragePermission',
  /** 上游 :97 ShowMessage(messageRes, argument) */
  ShowMessage = 'showMessage',
  /** 写设置：上游 settingsGateway.update(transform)，本地设置在宿主，故作为 effect 出队 */
  PersistSettings = 'persistSettings',
  /** 执行备份：上游在 ViewModel 里直接 await useCase，本地 useCase 在宿主，故作为 effect 出队 */
  RunBackup = 'runBackup',
  /** 执行本地恢复：上游 backupRestoreUseCase.restoreLocal(uri)（ViewModel :300-309） */
  RunLocalRestore = 'runLocalRestore',
  /** 执行网络恢复：上游 webDavBackupUseCase.restore(name)（ViewModel :342-353） */
  RunNetworkRestore = 'runNetworkRestore',
  /** 拉远端备份文件名：上游 loadNetworkBackups()（ViewModel :311-340） */
  LoadNetworkBackupNames = 'loadNetworkBackupNames',
  /** 测试 WebDav：上游 testWebDav()（ViewModel :155-168） */
  RunWebDavTest = 'runWebDavTest',
  /** 落盘忽略列表：上游 saveIgnoreItems 系列写 BackupConfig 并 save */
  PersistIgnoreItems = 'persistIgnoreItems'
}

/** effect 载荷。 */
export class BackupConfigEffect {
  kind: BackupConfigEffectKind = BackupConfigEffectKind.ShowMessage;
  value: string = '';
  path: string = '';
  mode: string = '';
  name: string = '';
  /** PersistIgnoreItems 的四个维度：'ignore' | 'backupIgnore' | 'dbIgnore' | 'backupDbIgnore'。 */
  scope: string = '';

  constructor(kind: BackupConfigEffectKind) {
    this.kind = kind;
  }
}

/** 配置维度九项顺序：照 help/storage/BackupConfig.kt:145-155。 */
export const BACKUP_CONFIG_KEYS: string[] = [
  'readConfig', 'themeMode', 'themeConfig', 'coverConfig', 'bookshelfLayout',
  'showRss', 'threadCount', 'localBook', 'mangaConfig'
];

/** 数据库维度十九项顺序：照 help/storage/BackupConfig.kt:96-102。 */
export const BACKUP_DB_KEYS: string[] = [
  'bookmark', 'bookGroup', 'bookSource', 'rssSource', 'rssStar', 'replaceRule',
  'readRecord', 'searchHistory', 'sourceSub', 'txtTocRule', 'httpTTS',
  'keyboardAssists', 'dictRule', 'homepageModules', 'homepageCustomSets',
  'highlightRule', 'highlightTagRule', 'tagGroupRule', 'server'
];

/** 配置维度标题：照 help/storage/BackupConfig.kt:158-168 的 strings 真值。 */
export const BACKUP_CONFIG_TITLES: string[] = [
  '阅读界面', '深色模式', '主题配置', '封面设置', '书架布局',
  '显示订阅', '线程数', '本地书籍', '漫画设置'
];

/** 数据库维度标题：照 help/storage/BackupConfig.kt:104-124 的 strings 真值。 */
export const BACKUP_DB_TITLES: string[] = [
  '书签', '书架分组', '书源', '订阅源', 'RSS 收藏', '替换规则',
  '阅读记录', '搜索历史', '书源订阅', 'TXT 目录规则', 'HTTP TTS',
  '键盘辅助', '字典规则', '首页模块 (JSON)', '首页自定义',
  '高亮规则', '标签规则', '标签分组规则', '服务器配置'
];

/**
 * 按「键顺序表 + 已忽略键集合」构建忽略项列表。
 * 对应上游 `loadIgnoreItems()` 等四个 companion 函数（ViewModel :371-413）：
 * 顺序取 keys 表，标题按同一下标取 title 表，checked 取该侧配置里该键的值。
 */
export function buildIgnoreItems(keys: string[], titles: string[], ignored: string[]): BackupIgnoreItem[] {
  const items: BackupIgnoreItem[] = [];
  for (let i = 0; i < keys.length; i++) {
    items.push(new BackupIgnoreItem(keys[i], i < titles.length ? titles[i] : keys[i], ignored.includes(keys[i])));
  }
  return items;
}

/**
 * 状态层：持有 `BackupConfigUiState`，接收 intent，发出 effect。
 *
 * 构造时传入两组已忽略键（宿主 @Prop 的 backupIgnoreKeys / restoreIgnoreKeys），
 * 用来初始化四组忽略项 —— 上游那四组由 `BackupConfig.ignoreConfig` 等四处配置直接读，
 * 本地这四处配置由宿主持有并以「键数组」形式下传，所以构造期一次性快照。
 */
export class BackupConfigViewModel {
  private state: BackupConfigUiState = new BackupConfigUiState();
  private notifyState: (state: BackupConfigUiState) => void = (_state: BackupConfigUiState): void => {};
  private notifyEffect: (effect: BackupConfigEffect) => void = (_effect: BackupConfigEffect): void => {};

  constructor(backupIgnoreKeys: string[], backupDbIgnoreKeys: string[],
    restoreIgnoreKeys: string[], restoreDbIgnoreKeys: string[]) {
    this.state.backupIgnoreItems = buildIgnoreItems(BACKUP_CONFIG_KEYS, BACKUP_CONFIG_TITLES, backupIgnoreKeys);
    this.state.backupDbIgnoreItems = buildIgnoreItems(BACKUP_DB_KEYS, BACKUP_DB_TITLES, backupDbIgnoreKeys);
    this.state.ignoreItems = buildIgnoreItems(BACKUP_CONFIG_KEYS, BACKUP_CONFIG_TITLES, restoreIgnoreKeys);
    this.state.dbIgnoreItems = buildIgnoreItems(BACKUP_DB_KEYS, BACKUP_DB_TITLES, restoreDbIgnoreKeys);
  }

  /** 挂接状态订阅：每次转移后推一份新实例给页面 @State。 */
  bindStateSink(sink: (state: BackupConfigUiState) => void): void {
    this.notifyState = sink;
    this.notifyState(this.state.clone());
  }

  /** 挂接副作用订阅。 */
  bindEffectSink(sink: (effect: BackupConfigEffect) => void): void {
    this.notifyEffect = sink;
  }

  currentState(): BackupConfigUiState {
    return this.state;
  }

  /** 宿主设置同步：宿主是设置的持久化方，读回来直接替换 state 里的副本。 */
  syncSettings(settings: WebDavSettings): void {
    this.state.settings = cloneWebDavSettings(settings);
    this.notifyState(this.state.clone());
  }

  /** 宿主忙碌标志同步：上游这两个状态在 ViewModel 内部，本地由宿主执行、回灌到这里。 */
  syncBusy(loadingTitle: BackupLoadingTitle): void {
    const intent = new BackupConfigIntent(BackupConfigIntentKind.HostStateChanged);
    intent.loadingTitle = loadingTitle;
    this.onIntent(intent);
  }

  /** 宿主的忽略键变化后重建四组忽略项（对应上游读 BackupConfig 的四个配置表）。 */
  rebuildIgnoreItems(backupIgnoreKeys: string[], backupDbIgnoreKeys: string[],
    restoreIgnoreKeys: string[], restoreDbIgnoreKeys: string[]): void {
    this.mutate((state: BackupConfigUiState): void => {
      state.ignoreItems = buildIgnoreItems(BACKUP_CONFIG_KEYS, BACKUP_CONFIG_TITLES, restoreIgnoreKeys);
      state.dbIgnoreItems = buildIgnoreItems(BACKUP_DB_KEYS, BACKUP_DB_TITLES, restoreDbIgnoreKeys);
      state.backupIgnoreItems = buildIgnoreItems(BACKUP_CONFIG_KEYS, BACKUP_CONFIG_TITLES, backupIgnoreKeys);
      state.backupDbIgnoreItems = buildIgnoreItems(BACKUP_DB_KEYS, BACKUP_DB_TITLES, backupDbIgnoreKeys);
    });
  }

  /** 唯一入口：对应上游 `onIntent(intent)`（ViewModel :49-108）。 */
  onIntent(intent: BackupConfigIntent): void {
    switch (intent.kind) {
      // ---- 设置字段八项（ViewModel :51-63）----
      case BackupConfigIntentKind.SetWebDavUrl:
        this.updateSettings((settings: WebDavSettings): void => { settings.url = intent.value; });
        break;
      case BackupConfigIntentKind.SetWebDavDir:
        this.updateSettings((settings: WebDavSettings): void => { settings.dir = intent.value; });
        break;
      case BackupConfigIntentKind.SetWebDavDeviceName:
        this.updateSettings((settings: WebDavSettings): void => { settings.deviceName = intent.value; });
        break;
      case BackupConfigIntentKind.SetSyncBookProgress:
        // 上游 :114-123：`syncBookProgressPlus = it.syncBookProgressPlus && value`
        this.updateSettings((settings: WebDavSettings): void => {
          settings.syncBookProgress = intent.boolValue;
          settings.syncBookProgressPlus = settings.syncBookProgressPlus && intent.boolValue;
        });
        break;
      case BackupConfigIntentKind.SetSyncBookProgressPlus:
        this.updateSettings((settings: WebDavSettings): void => { settings.syncBookProgressPlus = intent.boolValue; });
        break;
      case BackupConfigIntentKind.SetAutoCheckNewBackup:
        this.updateSettings((settings: WebDavSettings): void => { settings.autoCheckNewBackup = intent.boolValue; });
        break;
      case BackupConfigIntentKind.SetOnlyLatestBackup:
        this.updateSettings((settings: WebDavSettings): void => { settings.onlyLatestBackup = intent.boolValue; });
        break;
      case BackupConfigIntentKind.SetBackupSyncMode:
        this.updateSettings((settings: WebDavSettings): void => { settings.backupSyncMode = intent.value; });
        break;

      // ---- 弹层两项（ViewModel :64-65）----
      case BackupConfigIntentKind.OpenSheet:
        this.mutate((state: BackupConfigUiState): void => { state.activeSheet = intent.sheet; });
        break;
      case BackupConfigIntentKind.DismissSheet:
        this.dismissSheet();
        break;

      // ---- WebDav 账号对话框（ViewModel :66-72）----
      case BackupConfigIntentKind.OpenWebDavAuth:
        this.openWebDavAuth();
        break;
      case BackupConfigIntentKind.EditWebDavAccount:
        this.mutate((state: BackupConfigUiState): void => { state.authAccount = intent.value; });
        break;
      case BackupConfigIntentKind.EditWebDavPassword:
        this.mutate((state: BackupConfigUiState): void => { state.authPassword = intent.value; });
        break;
      case BackupConfigIntentKind.TogglePasswordVisibility:
        this.mutate((state: BackupConfigUiState): void => {
          state.authPasswordVisible = !state.authPasswordVisible;
        });
        break;
      case BackupConfigIntentKind.SaveWebDavAuth:
        this.saveWebDavAuth();
        break;
      case BackupConfigIntentKind.TestWebDav:
        this.testWebDav();
        break;

      // ---- 忽略列表四组（ViewModel :73-93 / :170-246）----
      case BackupConfigIntentKind.OpenIgnoreDialog:
        this.mutate((state: BackupConfigUiState): void => {
          state.activeSheet = BackupConfigSheet.IGNORE_RESTORE_ITEMS;
          state.ignoreTab = 0;
        });
        break;
      case BackupConfigIntentKind.OpenBackupIgnoreDialog:
        this.mutate((state: BackupConfigUiState): void => {
          state.activeSheet = BackupConfigSheet.IGNORE_BACKUP_ITEMS;
          state.ignoreTab = 0;
        });
        break;
      case BackupConfigIntentKind.ToggleIgnoreItem:
        this.mutate((state: BackupConfigUiState): void => {
          state.ignoreItems = toggleIn(state.ignoreItems, intent.value, intent.boolValue);
        });
        break;
      case BackupConfigIntentKind.ToggleDbIgnoreItem:
        this.mutate((state: BackupConfigUiState): void => {
          state.dbIgnoreItems = toggleIn(state.dbIgnoreItems, intent.value, intent.boolValue);
        });
        break;
      case BackupConfigIntentKind.ToggleBackupIgnoreItem:
        this.mutate((state: BackupConfigUiState): void => {
          state.backupIgnoreItems = toggleIn(state.backupIgnoreItems, intent.value, intent.boolValue);
        });
        break;
      case BackupConfigIntentKind.ToggleBackupDbIgnoreItem:
        this.mutate((state: BackupConfigUiState): void => {
          state.backupDbIgnoreItems = toggleIn(state.backupDbIgnoreItems, intent.value, intent.boolValue);
        });
        break;
      case BackupConfigIntentKind.SaveIgnoreItems:
        // 上游 :180-190：配置维度与数据库维度一起落盘，然后关弹层。
        this.emitEffect(BackupConfigEffectKind.PersistIgnoreItems, 'ignore');
        this.mutate((state: BackupConfigUiState): void => { state.activeSheet = BackupConfigSheet.NONE; });
        break;
      case BackupConfigIntentKind.SaveBackupIgnoreItems:
        // 上游 :202-212：备份侧的配置维度与数据库维度一起落盘，然后关弹层。
        this.emitEffect(BackupConfigEffectKind.PersistIgnoreItems, 'backupIgnore');
        this.mutate((state: BackupConfigUiState): void => { state.activeSheet = BackupConfigSheet.NONE; });
        break;
      case BackupConfigIntentKind.SaveDbIgnoreItems:
        // 上游 :224-229：只落盘恢复侧的数据库维度，不关弹层
        this.emitEffect(BackupConfigEffectKind.PersistIgnoreItems, 'dbIgnore');
        break;
      case BackupConfigIntentKind.SaveBackupDbIgnoreItems:
        // 上游 :241-246：只落盘备份侧的数据库维度，不关弹层
        this.emitEffect(BackupConfigEffectKind.PersistIgnoreItems, 'backupDbIgnore');
        break;

      // ---- 对话框关闭（ViewModel :94）----
      case BackupConfigIntentKind.DismissDialog:
        this.mutate((state: BackupConfigUiState): void => {
          state.activeDialog = BackupConfigDialogKind.NONE;
          state.loadingTitle = BackupLoadingTitle.NONE;
        });
        break;

      // ---- 目录与备份（ViewModel :95-99 / :248-293）----
      case BackupConfigIntentKind.SelectBackupDirectory:
        this.mutate((state: BackupConfigUiState): void => { state.activeSheet = BackupConfigSheet.NONE; });
        this.emitEffect(BackupConfigEffectKind.LaunchBackupDirectoryPicker, '');
        break;
      case BackupConfigIntentKind.SelectBackupAndRunDirectory:
        this.mutate((state: BackupConfigUiState): void => { state.activeSheet = BackupConfigSheet.NONE; });
        this.emitEffect(BackupConfigEffectKind.LaunchBackupAndRunDirectoryPicker, '');
        break;
      case BackupConfigIntentKind.BackupDirectorySelected:
        // 上游 :256-261：先写 backupPath，runBackup 且路径非空时按 both 起备份
        this.updateSettings((settings: WebDavSettings): void => { settings.backupPath = intent.path; });
        if (intent.boolValue && intent.path.length > 0) {
          this.requestBackup('both', intent.path);
        }
        break;
      case BackupConfigIntentKind.RequestBackup:
        this.requestBackup(intent.mode, '');
        break;
      case BackupConfigIntentKind.PerformBackup:
        this.performBackup(intent.path, intent.mode);
        break;

      // ---- 恢复（ViewModel :100-104 / :295-353）----
      case BackupConfigIntentKind.RequestLocalRestore:
        this.mutate((state: BackupConfigUiState): void => {
          state.activeSheet = BackupConfigSheet.NONE;
          state.activeDialog = BackupConfigDialogKind.NONE;
        });
        this.emitEffect(BackupConfigEffectKind.LaunchRestoreFilePicker, '');
        break;
      case BackupConfigIntentKind.RestoreLocal:
        // 上游 :300-309：开「恢复中」并 await backupRestoreUseCase.restoreLocal(uri)
        this.startLoading(BackupLoadingTitle.RESTORE);
        this.emitEffect(BackupConfigEffectKind.RunLocalRestore, intent.value);
        break;
      case BackupConfigIntentKind.RequestNetworkRestore:
        this.loadNetworkBackups();
        break;
      case BackupConfigIntentKind.RestoreNetwork:
        this.restoreNetwork(intent.value);
        break;
      case BackupConfigIntentKind.ConfirmLocalRestoreFallback:
        this.requestLocalRestore();
        break;
      case BackupConfigIntentKind.RequestImportOldData:
        // 上游 :105-106：直接出队 picker
        this.emitEffect(BackupConfigEffectKind.LaunchImportOldDataPicker, '');
        break;

      // ---- 页面本地补充 ----
      case BackupConfigIntentKind.BeginEditField:
        this.mutate((state: BackupConfigUiState): void => {
          state.editingKey = intent.value;
          state.inputDraft = intent.path;
        });
        break;
      case BackupConfigIntentKind.UpdateInputDraft:
        this.mutate((state: BackupConfigUiState): void => { state.inputDraft = intent.value; });
        break;
      case BackupConfigIntentKind.CommitEditField:
        this.commitEditField(intent.value, intent.path);
        break;
      case BackupConfigIntentKind.ResetEditField:
        this.mutate((state: BackupConfigUiState): void => { state.inputDraft = intent.path; });
        break;
      case BackupConfigIntentKind.SelectIgnoreTab:
        this.mutate((state: BackupConfigUiState): void => { state.ignoreTab = intent.value === '1' ? 1 : 0; });
        break;

      // ---- 副作用回报 ----
      case BackupConfigIntentKind.HostStateChanged:
        this.mutate((state: BackupConfigUiState): void => {
          if (intent.loadingTitle === BackupLoadingTitle.NONE) {
            if (state.activeDialog === BackupConfigDialogKind.LOADING) {
              state.activeDialog = BackupConfigDialogKind.NONE;
              state.loadingTitle = BackupLoadingTitle.NONE;
            }
          } else {
            state.activeDialog = BackupConfigDialogKind.LOADING;
            state.loadingTitle = intent.loadingTitle;
          }
        });
        break;
      case BackupConfigIntentKind.NetworkNamesLoaded:
        // 上游 :317-326：关加载框、开 RestoreFiles 弹层、写入 backupNames
        this.mutate((state: BackupConfigUiState): void => {
          state.activeDialog = BackupConfigDialogKind.NONE;
          state.loadingTitle = BackupLoadingTitle.NONE;
          state.activeSheet = BackupConfigSheet.RESTORE_FILES;
          state.backupNames = intent.names.slice();
        });
        break;
      case BackupConfigIntentKind.NetworkNamesFailed:
        // 上游 :328-338：失败弹 ConfirmLocalRestoreFallback 并带 error
        this.mutate((state: BackupConfigUiState): void => {
          state.activeDialog = BackupConfigDialogKind.CONFIRM_LOCAL_RESTORE_FALLBACK;
          state.loadingTitle = BackupLoadingTitle.NONE;
          state.fallbackError = intent.error;
        });
        break;
      case BackupConfigIntentKind.OperationFinished:
        this.mutate((state: BackupConfigUiState): void => {
          state.activeDialog = BackupConfigDialogKind.NONE;
          state.loadingTitle = BackupLoadingTitle.NONE;
        });
        if (intent.value.length > 0) {
          this.emitEffect(BackupConfigEffectKind.ShowMessage, intent.value);
        }
        break;
      default:
        break;
    }
  }

  /** 设置字段统一走这里：clone → 改 → 推给宿主回调（由页面转成 onWebDavSettingsChange）。 */
  private updateSettings(change: (settings: WebDavSettings) => void): void {
    const next: WebDavSettings = cloneWebDavSettings(this.state.settings);
    change(next);
    this.state.settings = next;
    this.notifyState(this.state.clone());
    this.notifyEffect(new BackupConfigEffect(BackupConfigEffectKind.PersistSettings));
  }

  /** 状态转移：clone 一份、改、整体推给页面。 */
  private mutate(change: (state: BackupConfigUiState) => void): void {
    const next: BackupConfigUiState = this.state.clone();
    change(next);
    this.state = next;
    this.notifyState(this.state.clone());
  }

  /** 打开账号对话框：草稿取当前设置（ViewModel :125-135）。 */
  private openWebDavAuth(): void {
    this.mutate((state: BackupConfigUiState): void => {
      state.authAccount = state.settings.account;
      state.authPassword = state.settings.password;
      state.authPasswordVisible = false;
      state.activeDialog = BackupConfigDialogKind.WEBDAV_AUTH;
    });
  }

  /** 保存账号：写入设置、关对话框、随即测一次（ViewModel :144-153）。 */
  private saveWebDavAuth(): void {
    if (this.state.activeDialog !== BackupConfigDialogKind.WEBDAV_AUTH) {
      return;
    }
    const account: string = this.state.authAccount.trim();
    const password: string = this.state.authPassword;
    const next: WebDavSettings = cloneWebDavSettings(this.state.settings);
    next.account = account;
    next.password = password;
    this.state.settings = next;
    this.mutate((state: BackupConfigUiState): void => {
      state.activeDialog = BackupConfigDialogKind.NONE;
    });
    const effect = new BackupConfigEffect(BackupConfigEffectKind.PersistSettings);
    this.notifyEffect(effect);
    // 上游注释：testWebDav() 内部会重建 authorization，故这里不需要额外触发写配置
    this.testWebDav();
  }

  /** 测试 WebDav：先开「测试中」加载框，再出队执行（ViewModel :155-168）。 */
  private testWebDav(): void {
    this.startLoading(BackupLoadingTitle.TEST_SYNC);
    this.emitEffect(BackupConfigEffectKind.RunWebDavTest, '');
  }

  /** 起加载框。 */
  private startLoading(title: BackupLoadingTitle): void {
    this.mutate((state: BackupConfigUiState): void => {
      state.activeDialog = BackupConfigDialogKind.LOADING;
      state.loadingTitle = title;
    });
  }

  /** 关弹层；忽略面板关闭即保存（对齐上游 onDismissRequest = onConfirm）。 */
  private dismissSheet(): void {
    const sheet: BackupConfigSheet = this.state.activeSheet;
    if (sheet === BackupConfigSheet.IGNORE_RESTORE_ITEMS) {
      this.onIntent(new BackupConfigIntent(BackupConfigIntentKind.SaveIgnoreItems));
      return;
    }
    if (sheet === BackupConfigSheet.IGNORE_BACKUP_ITEMS) {
      this.onIntent(new BackupConfigIntent(BackupConfigIntentKind.SaveBackupIgnoreItems));
      return;
    }
    this.mutate((state: BackupConfigUiState): void => { state.activeSheet = BackupConfigSheet.NONE; });
  }

  /** 提交行内输入：按字段 trim 后写入设置并退出编辑（对齐上游各 SetXxx 的 trim）。 */
  private commitEditField(field: string, value: string): void {
    const trimmed: string = value.trim();
    const next: WebDavSettings = cloneWebDavSettings(this.state.settings);
    if (field === 'url') {
      next.url = trimmed;
    } else if (field === 'dir') {
      next.dir = trimmed;
    } else if (field === 'deviceName') {
      next.deviceName = trimmed;
    }
    this.state.settings = next;
    this.mutate((state: BackupConfigUiState): void => {
      state.editingKey = '';
    });
    this.notifyEffect(new BackupConfigEffect(BackupConfigEffectKind.PersistSettings));
  }

  /** 请求备份（ViewModel :263-272）：先关弹层，空路径且非 webdav 直接返回。 */
  private requestBackup(mode: string, selectedPath: string): void {
    const path: string = selectedPath.length > 0 ? selectedPath : this.state.settings.backupPath;
    this.mutate((state: BackupConfigUiState): void => { state.activeSheet = BackupConfigSheet.NONE; });
    if (path.length === 0 && mode !== 'webdav') {
      return;
    }
    if (path.length > 0 && !path.startsWith('content://')) {
      // 上游 :267-269：非 content scheme 先要存储权限，权限回调再走 PerformBackup
      const effect = new BackupConfigEffect(BackupConfigEffectKind.RequestStoragePermission);
      effect.path = path;
      effect.mode = mode;
      this.notifyEffect(effect);
      return;
    }
    this.performBackup(path, mode);
  }

  /** 执行备份（ViewModel :274-293）：开「备份中」加载框并出队。 */
  private performBackup(path: string, mode: string): void {
    this.startLoading(BackupLoadingTitle.BACKUP);
    const effect = new BackupConfigEffect(BackupConfigEffectKind.RunBackup);
    effect.path = path;
    effect.mode = mode;
    this.notifyEffect(effect);
  }

  /** 本地恢复：开「恢复中」加载框并出队 picker（ViewModel :295-298）。 */
  private requestLocalRestore(): void {
    this.mutate((state: BackupConfigUiState): void => {
      state.activeSheet = BackupConfigSheet.NONE;
      state.activeDialog = BackupConfigDialogKind.NONE;
    });
    this.emitEffect(BackupConfigEffectKind.LaunchRestoreFilePicker, '');
  }

  /** 拉远端备份列表（ViewModel :311-340）：先关弹层、开「加载中」，再出队。 */
  private loadNetworkBackups(): void {
    this.mutate((state: BackupConfigUiState): void => {
      state.activeSheet = BackupConfigSheet.NONE;
      state.activeDialog = BackupConfigDialogKind.LOADING;
      state.loadingTitle = BackupLoadingTitle.LOADING;
    });
    this.emitEffect(BackupConfigEffectKind.LoadNetworkBackupNames, '');
  }

  /** 网络恢复指定文件（ViewModel :342-353）：开「恢复中」并出队。 */
  private restoreNetwork(name: string): void {
    this.mutate((state: BackupConfigUiState): void => {
      state.activeSheet = BackupConfigSheet.NONE;
      state.activeDialog = BackupConfigDialogKind.LOADING;
      state.loadingTitle = BackupLoadingTitle.RESTORE;
    });
    const effect = new BackupConfigEffect(BackupConfigEffectKind.RunNetworkRestore);
    effect.name = name;
    this.notifyEffect(effect);
  }

  /** 取当前某一组忽略项，供页面按弹层选侧。 */
  ignoreItemsOf(sheet: BackupConfigSheet, tab: number): BackupIgnoreItem[] {
    const backupSide: boolean = sheet === BackupConfigSheet.IGNORE_BACKUP_ITEMS;
    if (tab === 0) {
      return backupSide ? this.state.backupIgnoreItems : this.state.ignoreItems;
    }
    return backupSide ? this.state.backupDbIgnoreItems : this.state.dbIgnoreItems;
  }

  private emitEffect(kind: BackupConfigEffectKind, value: string): void {
    const effect = new BackupConfigEffect(kind);
    effect.value = value;
    this.notifyEffect(effect);
  }
}

/** 把某一组里指定键的 checked 改成新值，其余原样。 */
function toggleIn(items: BackupIgnoreItem[], key: string, checked: boolean): BackupIgnoreItem[] {
  return items.map((item: BackupIgnoreItem): BackupIgnoreItem => {
    if (item.key === key) {
      return new BackupIgnoreItem(item.key, item.title, checked);
    }
    return item.clone();
  });
}
