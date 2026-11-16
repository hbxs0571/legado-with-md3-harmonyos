import { AppGlyph } from '../components/AppGlyph';
import { ThemeColorSelector, ThemeModeSelector } from '../components/ThemeSelectors';

@Component
export struct OnboardingPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
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

  @Builder
  private pageContent() {
    if (this.page === 0) {
      Scroll() {
        Column() {
          Text('隐私与应用说明').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.themeColorAccent)
            .alignSelf(ItemAlign.Start).margin({ bottom: 10 })
          Text('本 HarmonyOS 版本目前不包含自有服务端、Firebase 统计或 WebDAV 同步；不会在后台收集或上传阅读数据。书籍和阅读进度保存在本机应用空间。导入、导出文件时由你通过系统文件选择器选择文件。')
            .fontSize(14).fontColor(this.themeColorTextSecondary).lineHeight(22).width('100%')
          Text('用户协议与免责声明').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
            .alignSelf(ItemAlign.Start).margin({ top: 26, bottom: 12 })
          Text('一、软件性质\n本软件提供本地书籍管理、文本解析与阅读排版功能。当前 HarmonyOS 版本不提供在线书源访问、WebDAV、云同步或第三方内容服务。\n\n二、用户内容\n请确保导入、阅读、备份和分享的书籍及数据来源合法，并遵守适用法律和权利人的要求。\n\n三、本地数据与备份\n书籍正文保存在设备本地。Android 兼容备份不会包含 TXT/EPUB 正文；恢复未匹配的本地书目时会建立缺正文记录。备份文件可能包含个人阅读数据，请妥善保管。\n\n四、开源软件\n本软件为开源项目。未来接入的第三方规则或脚本由用户自行选择和使用；当前版本不会执行备份中保留的规则脚本。\n\n五、免责声明\n本软件按现有功能提供。因设备故障、用户操作或第三方内容造成的数据损失及权利争议，请相关责任方依法处理。')
            .fontSize(14).fontColor(this.themeColorTextSecondary).lineHeight(22).width('100%')
          Text('点击“阅读并同意”继续，即表示你已阅读并接受以上说明。')
            .fontSize(13).fontColor(this.themeColorTextTertiary).lineHeight(19).width('100%').margin({ top: 18 })
        }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
      }.edgeEffect(EdgeEffect.Spring).scrollBar(BarState.Off)
        .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.EaseInOut }))
    } else if (this.page === 1) {
      Column() {
        Text('本地 Android 兼容备份').fontSize(16).fontColor(this.themeColorTextSecondary)
          .alignSelf(ItemAlign.Start).margin({ bottom: 10 })
        Text('你可以稍后在「我的 - 备份与恢复」中选择 Android 阅读 ZIP，预览并恢复书目、阅读进度及可保留的数据条目。TXT/EPUB 正文需要从原文件重新导入。')
          .fontSize(14).fontColor(this.themeColorTextTertiary).lineHeight(22).width('100%')
        TextInput({ placeholder: 'WebDAV 服务器地址（尚未接入）' }).enabled(false).width('100%').height(52)
          .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(6).margin({ top: 20 })
        TextInput({ placeholder: 'WebDAV 账号' }).enabled(false).width('100%').height(52)
          .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(6).margin({ top: 10 })
        TextInput({ placeholder: 'WebDAV 密码' }).enabled(false).width('100%').height(52)
          .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(6).margin({ top: 10 })
        Text('WebDAV 云同步和本地备份密码尚未接入；这些字段仅说明 Android 原版设置位置，不会保存或发送凭据。')
          .fontSize(12).fontColor(this.themeColorTextTertiary).lineHeight(18).width('100%').margin({ top: 14 })
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
        .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.EaseInOut }))
    } else if (this.page === 2) {
      Column() {
        Text('本地书籍保存位置').fontSize(16).fontColor(this.themeColorTextSecondary)
          .alignSelf(ItemAlign.Start).margin({ bottom: 8 })
        Text('导入的 TXT/EPUB 会复制到应用私有空间，卸载应用可能会删除这些文件。当前版本暂不支持选择外部书籍目录；你仍可通过系统文件选择器导入书籍。')
          .fontSize(14).fontColor(this.themeColorTextTertiary).lineHeight(22).width('100%')
        Text('当前应用目录').fontSize(15).fontColor(this.themeColorTextPrimary).margin({ top: 24, bottom: 8 })
          .alignSelf(ItemAlign.Start)
        Text(this.localBooksPath.length > 0 ? this.localBooksPath : '应用私有文件目录 /books')
          .fontSize(13).fontColor(this.themeColorTextTertiary).lineHeight(19).width('100%')
          .padding(12).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(8)
        Text('目录选择会在后续适配系统文件授权后开放。')
          .fontSize(12).fontColor(this.themeColorTextTertiary).margin({ top: 12 }).alignSelf(ItemAlign.Start)
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
      Text(this.pageTitle()).fontSize(32).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
      Text(this.pageSummary()).fontSize(16).fontColor(this.themeColorTextTertiary).margin({ top: 4, bottom: 12 })
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
              .fontSize(14).fontColor(this.themeColorSurfacePrimary)
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
