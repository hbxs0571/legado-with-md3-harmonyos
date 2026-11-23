import { AppGlyph } from '../components/AppGlyph';
import { ThemeColorSelector, ThemeModeSelector } from '../components/ThemeSelectors';
import { BODY_MEDIUM, BODY_MEDIUM_LINE_HEIGHT, BODY_SMALL, BODY_SMALL_LINE_HEIGHT, HEADLINE_LARGE, HEADLINE_SMALL, LABEL_LARGE, LABEL_MEDIUM, LABEL_MEDIUM_LINE_HEIGHT, LABEL_SMALL, LABEL_SMALL_LINE_HEIGHT, TITLE_LARGE, TITLE_MEDIUM, TITLE_SMALL, TITLE_SMALL_LINE_HEIGHT } from '../components/typography/TypographyTokens';

@Component
export struct OnboardingPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  /**
   * 状态栏高度（vp），由 `pages/Index.ets` 的 `publishAppTopInset()` 广播。
   *
   * 全屏布局下页面画到状态栏底下，欢迎页外层必须自己让开这段，
   * 否则第一屏的图标会与状态栏图标重叠。上游 `OnboardingScreen.kt:51-52`
   * 在外层 `Column` 上挂 `windowInsetsPadding(WindowInsets.safeDrawing)`，
   * 本地等价做法就是读这个既有广播键（仓库口径，见 `BookInfoPage.ets`）。
   */
  @StorageProp('appTopInset') appTopInset: number = 0;
  @Prop localBooksPath: string = '';
  onComplete: (themeMode: number, paletteIndex: number) => void = (_mode: number, _palette: number) => {};
  /**
   * 向导第 2 页（备份与恢复）的 WebDAV 三项与本地密码。
   *
   * 对齐上游 `OnboardingViewModel.kt:40-49` 的初始值：三项都取自 `BackupSettingsGateway.currentSettings`，
   * `appAccessPassword` 取自 `LocalConfig.password`。上游这三个输入框是**可编辑**的，
   * 输入值先进 UiState，点「保存」或「恢复」才写网关（`saveWebDavConfig()`）。
   * 本地照此：值由父组件持有，本页只回传改动。
   */
  @Prop webDavUrl: string = '';
  @Prop webDavAccount: string = '';
  @Prop webDavPassword: string = '';
  @Prop appAccessPassword: string = '';
  /** 忙碌提示文案（空串表示不显示），对齐上游 `BusyDialog(state.busyText)`。 */
  @Prop @Watch('onBusyTextChanged') busyText: string = '';
  /** 远端备份文件名列表（空数组表示不显示选择框），对齐上游 `BackupSelectorDialog(state.backupNames)`。 */
  @Prop @Watch('onBackupNamesChanged') backupNames: string[] = [];
  /** 恢复失败文案（空串表示不显示），对齐上游 `RestoreErrorDialog(state.restoreErrorMessage)`。 */
  @Prop @Watch('onRestoreErrorChanged') restoreErrorMessage: string = '';
  onChangeWebDavUrl: (value: string) => void = (_value: string) => {};
  onChangeWebDavAccount: (value: string) => void = (_value: string) => {};
  onChangeWebDavPassword: (value: string) => void = (_value: string) => {};
  onChangeAppAccessPassword: (value: string) => void = (_value: string) => {};
  /** 「保存」：写 WebDAV 三项后串一次连接测试，对齐上游 `SaveAndTestWebDav`。 */
  onSaveAndTestWebDav: () => void = () => {};
  /** 「恢复」：先存三项、刷新配置、拉远端备份名，对齐上游 `FetchBackups`。 */
  onFetchBackups: () => void = () => {};
  onRestoreBackup: (name: string) => void = (_name: string) => {};
  onDismissBackupSelector: () => void = () => {};
  /** 本地 ZIP 恢复，对齐上游 `StartLocalRestore`（→ `OpenRestoreFilePicker`）。 */
  onRestoreLocalFile: () => void = () => {};
  onDismissRestoreError: () => void = () => {};
  /**
   * 向导第 4 页点选深色模式三选项。
   *
   * 对齐上游 `OnboardingViewModel.kt:120-123`：点一下就写 `themeMode` 网关并
   * `ApplyDayNight`，不是「等走完向导再一起存」。所以这里在改本页 @State 的同时
   * 立刻回调父组件，由父组件走同一条 `applyThemeMode` 写入路径（与主题设置页 A1 共用）。
   */
  onThemeModeChange: (themeMode: number) => void = (_themeMode: number) => {};
  /** 向导第 4 页点选调色板，语义同 `onThemeModeChange`（上游 `SetThemeColor`）。 */
  onPaletteChange: (paletteIndex: number) => void = (_paletteIndex: number) => {};
  @State page: number = 0;
  @State themeMode: number = 0;
  @State paletteIndex: number = 0;
  /** 当前是否深色，由 Index 传入（`ThemeModeResolver.isDarkTheme` 派生），调色板预览据此取日/夜色值。 */
  @Prop readerNightMode: boolean = false;
  /** 备份选择框的 dialog id（-1 表示未打开），与 `syncDialogs()` 配对。 */
  private selectorDialogId: number = -1;
  /** 恢复失败框的 dialog id（-1 表示未打开）。 */
  private errorDialogId: number = -1;
  private selectorDialogBuilder: () => void = () => {};
  private errorDialogBuilder: () => void = () => {};

  private pageTitle(): string {
    if (this.page === 0) { return '欢迎'; }
    if (this.page === 1) { return '备份与恢复'; }
    if (this.page === 2) { return '书籍文件夹'; }
    return '主题样式';
  }

  private pageSummary(): string {
    if (this.page === 0) { return '请先阅读应用说明与用户协议。'; }
    if (this.page === 1) { return '了解本地备份与恢复设置。'; }
    if (this.page === 2) { return '本地书籍会保存在应用目录中。'; }
    return '在这里设置您喜爱的样式。';
  }

  private next(): void {
    if (this.page < 3) {
      animateTo({ duration: 300, curve: Curve.EaseInOut }, () => this.page += 1);
    } else {
      this.onComplete(this.themeMode, this.paletteIndex);
    }
  }

  /**
   * 三个对话框（忙碌 / 远端备份选择 / 恢复失败）用 `openCustomDialog` 独立开合，
   * 不用 bindContentCover 或页内遮罩：上游 `OnboardingScreen.kt:220-269` 的
   * `BusyDialog` / `BackupSelectorDialog` / `RestoreErrorDialog` 都是 `AppAlertDialog`，
   * 是真正的弹窗而不是页面的一部分。本仓 `pages/AppBackupSettingsPage.ets:404-433`
   * 已验证这个 SDK 版本下 `openCustomDialog` 的 builder 能挂载。
   */
  private syncDialogs(): void {
    const wantSelector: boolean = this.backupNames.length > 0 && this.restoreErrorMessage.length === 0;
    if (!wantSelector && this.selectorDialogId >= 0) {
      this.getUIContext().getPromptAction().closeCustomDialog(this.selectorDialogId);
      this.selectorDialogId = -1;
    }
    if (wantSelector && this.selectorDialogId < 0) {
      this.selectorDialogBuilder = (): void => { this.BackupSelectorContent(); };
      this.getUIContext().getPromptAction().openCustomDialog({
        builder: this.selectorDialogBuilder,
        autoCancel: false,
        alignment: DialogAlignment.Center,
        onWillDismiss: () => {
          this.selectorDialogId = -1;
          this.onDismissBackupSelector();
        }
      }).then((id: number) => {
        this.selectorDialogId = id;
      }).catch((error: Error) => {
        console.warn('打开备份选择对话框失败:', error);
      });
    }
    const wantError: boolean = this.restoreErrorMessage.length > 0;
    if (!wantError && this.errorDialogId >= 0) {
      this.getUIContext().getPromptAction().closeCustomDialog(this.errorDialogId);
      this.errorDialogId = -1;
    }
    if (wantError && this.errorDialogId < 0) {
      this.errorDialogBuilder = (): void => { this.RestoreErrorContent(); };
      this.getUIContext().getPromptAction().openCustomDialog({
        builder: this.errorDialogBuilder,
        autoCancel: false,
        alignment: DialogAlignment.Center,
        onWillDismiss: () => {
          this.errorDialogId = -1;
          this.onDismissRestoreError();
        }
      }).then((id: number) => {
        this.errorDialogId = id;
      }).catch((error: Error) => {
        console.warn('打开恢复失败对话框失败:', error);
      });
    }
  }

  private closeDialogs(): void {
    if (this.selectorDialogId >= 0) {
      this.getUIContext().getPromptAction().closeCustomDialog(this.selectorDialogId);
      this.selectorDialogId = -1;
    }
    if (this.errorDialogId >= 0) {
      this.getUIContext().getPromptAction().closeCustomDialog(this.errorDialogId);
      this.errorDialogId = -1;
    }
  }

  onBusyTextChanged(): void {
    this.syncDialogs();
  }

  onBackupNamesChanged(): void {
    this.syncDialogs();
  }

  onRestoreErrorChanged(): void {
    this.syncDialogs();
  }

  aboutToDisappear(): void {
    this.closeDialogs();
  }

  /**
   * 远端备份选择框，对齐上游 `OnboardingScreen.kt:232-252 BackupSelectorDialog`：
   * 标题「选择恢复文件」，列表逐条可点，点中即 `RestoreBackup(name)`。
   * 上游每条 `AppText(name, maxLines 2, Ellipsis, fillMaxWidth, clip RoundedCornerShape(8.dp),
   * clickable, padding vertical 10 horizontal 4)`。
   */
  @Builder
  private BackupSelectorContent() {
    Column() {
      Text('选择恢复文件').fontSize(HEADLINE_SMALL).fontColor(this.themeColorTextPrimary)
        .alignSelf(ItemAlign.Start)
      Scroll() {
        Column() {
          ForEach(this.backupNames, (name: string) => {
            Text(name).fontSize(BODY_MEDIUM).fontColor(this.themeColorTextPrimary)
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%').padding({ left: 4, right: 4, top: 10, bottom: 10 })
              .borderRadius(8).onClick(() => this.onRestoreBackup(name))
          }, (name: string) => name)
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').constraintSize({ maxHeight: 360 }).scrollBar(BarState.Off)
        .margin({ top: 12 })
      Row() {
        Blank()
        Button('取消').type(ButtonType.Normal).height(40).borderRadius(20)
          .backgroundColor(this.themeColorSurfaceTertiary).fontColor(this.themeColorAccent)
          .onClick(() => this.onDismissBackupSelector())
      }.width('100%').margin({ top: 12 })
    }
    .width(312).padding(24).borderRadius(28)
    .backgroundColor(this.themeColorSurfaceElevated)
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 恢复失败框，对齐上游 `OnboardingScreen.kt:254-269 RestoreErrorDialog`：
   * 标题「恢复」、正文是错误文案、「确定」执行 `StartLocalRestore`（改从本地文件恢复）。
   */
  @Builder
  private RestoreErrorContent() {
    Column() {
      Text('恢复').fontSize(HEADLINE_SMALL).fontColor(this.themeColorTextPrimary)
        .alignSelf(ItemAlign.Start)
      Text(this.restoreErrorMessage).fontSize(BODY_MEDIUM).fontColor(this.themeColorTextSecondary)
        .lineHeight(BODY_MEDIUM_LINE_HEIGHT).width('100%').margin({ top: 12 })
      Row() {
        Button('取消').type(ButtonType.Normal).layoutWeight(1).height(40).borderRadius(20)
          .backgroundColor(this.themeColorSurfaceTertiary).fontColor(this.themeColorAccent)
          .onClick(() => this.onDismissRestoreError())
        Button('确定').type(ButtonType.Normal).layoutWeight(1).height(40).borderRadius(20)
          .backgroundColor(this.themeColorAccent).fontColor(this.themeColorSurfacePrimary)
          .margin({ left: 12 }).onClick(() => this.onRestoreLocalFile())
      }.width('100%').margin({ top: 20 })
    }
    .width(312).padding(24).borderRadius(28)
    .backgroundColor(this.themeColorSurfaceElevated)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private pageContent() {
    if (this.page === 0) {
      Scroll() {
        Column() {
          Text('隐私与应用说明').fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorAccent)
            .alignSelf(ItemAlign.Start).margin({ bottom: 10 })
          Text('本 HarmonyOS 版本不包含自有服务端与 Firebase 统计；书籍和阅读进度保存在本机应用空间。在线书源抓取、WebDAV 备份同步与在线朗读只在你主动配置并使用对应功能时才发起请求，且直接发往你填写的目标地址。导入、导出文件时由你通过系统文件选择器选择文件。')
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).lineHeight(TITLE_SMALL_LINE_HEIGHT).width('100%')
          Text('用户协议与免责声明').fontSize(TITLE_LARGE).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
            .alignSelf(ItemAlign.Start).margin({ top: 26, bottom: 12 })
          Text('一、软件性质\n本软件提供本地书籍管理、文本解析与阅读排版功能。在线书源抓取、WebDAV 备份与在线朗读由你自行配置后使用；本软件不提供内容运营、内容存储或内容分发服务，不内置任何书源规则。\n\n二、用户内容\n请确保导入、阅读、备份和分享的书籍及数据来源合法，并遵守适用法律和权利人的要求。\n\n三、本地数据与备份\n书籍正文保存在设备本地。Android 兼容备份不会包含 TXT/EPUB 正文；恢复未匹配的本地书目时会建立缺正文记录。备份文件可能包含个人阅读数据，请妥善保管。\n\n四、开源软件\n本软件为开源项目。第三方规则或脚本由用户自行选择和使用，其来源、合法性与适用性由用户自行判断并承担责任。书源规则中的 JavaScript 经内置引擎执行，可能发起网络请求；备份恢复本身只解析数据，不执行其中的脚本。\n\n五、免责声明\n本软件按现有功能提供。因设备故障、用户操作或第三方内容造成的数据损失及权利争议，请相关责任方依法处理。')
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).lineHeight(TITLE_SMALL_LINE_HEIGHT).width('100%')
          Text('点击“阅读并同意”继续，即表示你已阅读并接受以上说明。')
            .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary).lineHeight(LABEL_MEDIUM_LINE_HEIGHT).width('100%').margin({ top: 18 })
        }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).scrollBar(BarState.Off)
        .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.EaseInOut }))
    } else if (this.page === 1) {
      // 上游 `OnboardingScreen.kt:161-217` `WebDavPage`：`Column(verticalScroll, padding 16, spacedBy 8)`
      // 内依次是三个可编辑的 `AppTextField`（服务器 / 账号 / 密码）、
      // `Row(spacedBy 12, padding top 4)` 里两个 `MediumTonalButton`（「恢复」= FetchBackups、
      // 「保存」= SaveAndTestWebDav）、`AppText(set_local_password_summary, labelSmall)`、
      // 最后一个 `AppTextField(appAccessPassword, label = set_local_password)`。
      // 本页不再只作说明：三项输入与密码都真的会写盘（见 pages/Index.ets 的同名回调）。
      Scroll() {
        Column({ space: 8 }) {
          TextInput({ text: this.webDavUrl, placeholder: 'WebDAV 服务器地址' })
            .width('100%').height(52).borderRadius(6)
            .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary))
            .onChange((value: string) => this.onChangeWebDavUrl(value))
          TextInput({ text: this.webDavAccount, placeholder: 'WebDAV 账号' })
            .width('100%').height(52).borderRadius(6)
            .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary))
            .onChange((value: string) => this.onChangeWebDavAccount(value))
          TextInput({ text: this.webDavPassword, placeholder: 'WebDAV 密码' })
            .type(InputType.Password).width('100%').height(52).borderRadius(6)
            .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary))
            .onChange((value: string) => this.onChangeWebDavPassword(value))
          // 上游两个按钮同排、等宽（`Modifier.weight(1f)`），文案分别是「恢复」与「保存」。
          Row({ space: 12 }) {
            Button('恢复').type(ButtonType.Normal).layoutWeight(1).height(40).borderRadius(20)
              .backgroundColor(this.themeColorSurfaceTertiary).fontColor(this.themeColorAccent)
              .onClick(() => this.onFetchBackups())
            Button('保存').type(ButtonType.Normal).layoutWeight(1).height(40).borderRadius(20)
              .backgroundColor(this.themeColorAccent).fontColor(this.themeColorSurfacePrimary)
              .onClick(() => this.onSaveAndTestWebDav())
          }.width('100%').margin({ top: 4 })
          Text('本地密码用于加密与解密备份中的敏感信息；若要在多台设备间同步，各设备的本地密码需保持一致。')
            .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary).lineHeight(LABEL_SMALL_LINE_HEIGHT)
            .width('100%').margin({ top: 8 })
          TextInput({ text: this.appAccessPassword, placeholder: '设置本地密码' })
            .type(InputType.Password).width('100%').height(52).borderRadius(6)
            .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary))
            .onChange((value: string) => this.onChangeAppAccessPassword(value))
          // 上游 `OnboardingScreen.kt:189-196` 还有一个「从本地文件恢复」入口（`StartLocalRestore`），
          // 排在 WebDAV 三项之下。上游这个按钮在 WebDavPage 里没有出现，只在 `RestoreErrorDialog`
          // 的 `onConfirm` 里被触发，所以本地同样只把它接到错误对话框的确认动作上。
        }.width('100%').alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16 })
      .scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
      .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.EaseInOut }))
    } else if (this.page === 2) {
      Column() {
        Text('本地书籍保存位置').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextSecondary)
          .alignSelf(ItemAlign.Start).margin({ bottom: 8 })
        Text('导入的 TXT/EPUB 会复制到应用私有空间，卸载应用可能会删除这些文件。当前版本暂不支持选择外部书籍目录；你仍可通过系统文件选择器导入书籍。')
          .fontSize(TITLE_SMALL).fontColor(this.themeColorTextTertiary).lineHeight(TITLE_SMALL_LINE_HEIGHT).width('100%')
        Text('当前应用目录').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).margin({ top: 24, bottom: 8 })
          .alignSelf(ItemAlign.Start)
        Text(this.localBooksPath.length > 0 ? this.localBooksPath : '应用私有文件目录 /books')
          .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary).lineHeight(LABEL_MEDIUM_LINE_HEIGHT).width('100%')
          .padding(12).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(8)
        Text('目录选择会在后续适配系统文件授权后开放。')
          .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).margin({ top: 12 }).alignSelf(ItemAlign.Start)
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
        .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.EaseInOut }))
    } else {
      // 上游 `OnboardingScreen.kt:326-359` `ThemePage` 只有两个节点：
      // `ThemeModeSelector`（:339-344）与 `padding(top = 16.dp)` 包裹的 `ThemeColorSelector`（:345-357）。
      // 没有预览卡、没有分组标题、没有说明文字，本地照此只留这两个组件。
      Column() {
        ThemeModeSelector({
          selectedMode: this.themeMode,
          onModeSelected: (mode: number) => {
            // 先改本页 @State 再回调父组件：只回调的话，父组件重渲染前本页选中态不更新
            // （与上游 `OnboardingViewModel.kt:120-123` 点一下即写网关的时序对应）。
            this.themeMode = mode;
            this.onThemeModeChange(mode);
          }
        })
        // 上游 `Box(Modifier.padding(top = 16.dp))`。用独立 Blank 而不是 margin，
        // 否则会与父 Column 的默认排布叠加。
        Blank().height(16)
        ThemeColorSelector({
          selectedIndex: this.paletteIndex,
          isDark: this.readerNightMode,
          onPaletteSelected: (index: number) => {
            this.paletteIndex = index;
            this.onPaletteChange(index);
          }
        })
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
        .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.EaseInOut }))
    }
  }

  build() {
    Column() {
      // 上游 `OnboardingScreen.kt:55-56` 用的是 `ic_launcher_foreground`（只有图形、没有底色），
      // 尺寸 128×96 + ContentScale.Crop。本地对应的就是分层图标里那张前景图。
      // ArkUI 的 ImageFit 没有 Crop，`Cover` 即「等比填满并裁掉溢出」，语义相同。
      Image($r('app.media.app_icon_foreground')).width(128).height(96).objectFit(ImageFit.Cover)
        .margin({ top: 16, bottom: 8 })
      Text(this.pageTitle()).fontSize(HEADLINE_LARGE).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
      Text(this.pageSummary()).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextTertiary).margin({ top: 4, bottom: 12 })
      Progress({ value: this.page, total: 4, type: ProgressType.Linear })
        .width('calc(100% - 32vp)').height(4).color(this.themeColorAccent)
        .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary))
        .margin({ left: 16, right: 16, bottom: 10 })
        .animation({ duration: 300, curve: Curve.EaseInOut })
      // 卡片拆成两层：外层只占位（layoutWeight），内层才是卡片、高度随内容。
      // 上游 `OnboardingScreen.kt:109-114` 是 `Box(fillMaxSize())` 里放 `GlassCard(fillMaxWidth())`——
      // 卡片高度随内容、贴顶，短页下方留白。本地原来把两层合成一个带 layoutWeight 的 Column，
      // 卡片会被拉满到按钮上方。底色取 `surfaceContainer` 而不是 `surface`：
      // `GlassCard.kt:133`/`:95` 默认 `LegadoTheme.colorScheme.surfaceContainer`，
      // 本地对应键是 `themeColorSurfaceTertiary`（`data/ThemePalette.ets:520`）。
      // `clip(true)` 必留：第 1 页内容是 Scroll，会顶出圆角。`alignItems(Start)` 让卡片贴顶。
      Column() {
        Column() {
          this.pageContent()
        }
        .width('100%')
        .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfaceTertiary))
        .borderRadius(18)
        .clip(true)
      }.width('100%').layoutWeight(1).alignItems(HorizontalAlign.Start)
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      Row() {
        Blank()
        // 上游 `OnboardingScreen.kt:138-141` 是 `MediumTonalButton { Text(...); Icon(ArrowForward) }`，
        // 文案与箭头是两个节点。本地原来用全角「　→」拼在按钮文字里，箭头随字号缩放且对不齐，
        // 这里拆成 Text + AppGlyph 两段。
        Button() {
          Row() {
            Text(this.page === 0 ? '阅读并同意' : this.page === 3 ? '完成' : '下一步')
              .fontSize(LABEL_LARGE).fontColor(this.themeColorSurfacePrimary)
            AppGlyph({ name: 'arrowForward', glyphSize: 18, tint: this.themeColorSurfacePrimary })
              .margin({ left: 8 })
          }.alignItems(VerticalAlign.Center)
        }
        .backgroundColor(this.themeColorAccent).borderRadius(28)
        .padding({ left: 22, right: 18, top: 12, bottom: 12 }).onClick(() => this.next())
      }.width('100%').padding({ left: 20, right: 20, top: 14, bottom: 18 })
    }.width('100%').height('100%').padding({ top: this.appTopInset }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)).justifyContent(FlexAlign.Start)
  }
}
