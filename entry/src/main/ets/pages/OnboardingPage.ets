@Component
export struct OnboardingPage {
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

  private paletteColor(index: number): string {
    if (index === 1) { return '#6B8B55'; }
    if (index === 2) { return '#D0A526'; }
    if (index === 3) { return '#777777'; }
    if (index === 4) { return '#D66A8D'; }
    return '#52638F';
  }

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
    return '选择你喜欢的界面样式。';
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
          Text('隐私与应用说明').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.theme_accent'))
            .alignSelf(ItemAlign.Start).margin({ bottom: 10 })
          Text('本 HarmonyOS 版本目前不包含自有服务端、Firebase 统计或 WebDAV 同步；不会在后台收集或上传阅读数据。书籍和阅读进度保存在本机应用空间。导入、导出文件时由你通过系统文件选择器选择文件。')
            .fontSize(14).fontColor($r('app.color.theme_text_secondary')).lineHeight(22).width('100%')
          Text('用户协议与免责声明').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.theme_text_primary'))
            .alignSelf(ItemAlign.Start).margin({ top: 26, bottom: 12 })
          Text('一、软件性质\n本软件提供本地书籍管理、文本解析与阅读排版功能。当前 HarmonyOS 版本不提供在线书源访问、WebDAV、云同步或第三方内容服务。\n\n二、用户内容\n请确保导入、阅读、备份和分享的书籍及数据来源合法，并遵守适用法律和权利人的要求。\n\n三、本地数据与备份\n书籍正文保存在设备本地。Android 兼容备份不会包含 TXT/EPUB 正文；恢复未匹配的本地书目时会建立缺正文记录。备份文件可能包含个人阅读数据，请妥善保管。\n\n四、开源软件\n本软件为开源项目。未来接入的第三方规则或脚本由用户自行选择和使用；当前版本不会执行备份中保留的规则脚本。\n\n五、免责声明\n本软件按现有功能提供。因设备故障、用户操作或第三方内容造成的数据损失及权利争议，请相关责任方依法处理。')
            .fontSize(14).fontColor($r('app.color.theme_text_secondary')).lineHeight(22).width('100%')
          Text('点击“阅读并同意”继续，即表示你已阅读并接受以上说明。')
            .fontSize(13).fontColor($r('app.color.theme_text_tertiary')).lineHeight(19).width('100%').margin({ top: 18 })
        }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
      }.scrollBar(BarState.Off)
        .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.EaseInOut }))
    } else if (this.page === 1) {
      Column() {
        Text('本地 Android 兼容备份').fontSize(16).fontColor($r('app.color.theme_text_secondary'))
          .alignSelf(ItemAlign.Start).margin({ bottom: 10 })
        Text('你可以稍后在「我的 - 备份与恢复」中选择 Android 阅读 ZIP，预览并恢复书目、阅读进度及可保留的数据条目。TXT/EPUB 正文需要从原文件重新导入。')
          .fontSize(14).fontColor($r('app.color.theme_text_tertiary')).lineHeight(22).width('100%')
        TextInput({ placeholder: 'WebDAV 服务器地址（尚未接入）' }).enabled(false).width('100%').height(52)
          .backgroundColor($r('app.color.theme_surface_tertiary')).borderRadius(6).margin({ top: 20 })
        TextInput({ placeholder: 'WebDAV 账号' }).enabled(false).width('100%').height(52)
          .backgroundColor($r('app.color.theme_surface_tertiary')).borderRadius(6).margin({ top: 10 })
        TextInput({ placeholder: 'WebDAV 密码' }).enabled(false).width('100%').height(52)
          .backgroundColor($r('app.color.theme_surface_tertiary')).borderRadius(6).margin({ top: 10 })
        Text('WebDAV 云同步和本地备份密码尚未接入；这些字段仅说明 Android 原版设置位置，不会保存或发送凭据。')
          .fontSize(12).fontColor($r('app.color.theme_text_tertiary')).lineHeight(18).width('100%').margin({ top: 14 })
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
        .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.EaseInOut }))
    } else if (this.page === 2) {
      Column() {
        Text('本地书籍保存位置').fontSize(16).fontColor($r('app.color.theme_text_secondary'))
          .alignSelf(ItemAlign.Start).margin({ bottom: 8 })
        Text('导入的 TXT/EPUB 会复制到应用私有空间，卸载应用可能会删除这些文件。当前版本暂不支持选择外部书籍目录；你仍可通过系统文件选择器导入书籍。')
          .fontSize(14).fontColor($r('app.color.theme_text_tertiary')).lineHeight(22).width('100%')
        Text('当前应用目录').fontSize(15).fontColor($r('app.color.theme_text_primary')).margin({ top: 24, bottom: 8 })
          .alignSelf(ItemAlign.Start)
        Text(this.localBooksPath.length > 0 ? this.localBooksPath : '应用私有文件目录 /books')
          .fontSize(13).fontColor($r('app.color.theme_text_tertiary')).lineHeight(19).width('100%')
          .padding(12).backgroundColor($r('app.color.theme_surface_tertiary')).borderRadius(8)
        Text('目录选择会在后续适配系统文件授权后开放。')
          .fontSize(12).fontColor($r('app.color.theme_text_tertiary')).margin({ top: 12 }).alignSelf(ItemAlign.Start)
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
        .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.EaseInOut }))
    } else {
      Column() {
        Row() {
          this.modeOption('跟随系统', 0)
          this.modeOption('浅色', 1)
          this.modeOption('深色', 2)
        }.width('100%')
        Row() {
          ForEach([0, 1, 2, 3, 4], (index: number) => {
            Column() {
              Stack({ alignContent: Alignment.Center }) {
                if (this.paletteIndex === index) {
                  Text('✓').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                }
              }.width(48).height(48).backgroundColor(this.paletteColor(index)).borderRadius(25)
                .border({ width: this.paletteIndex === index ? 3 : 0, color: $r('app.color.theme_text_primary') })
              Text(['动态色', '草原', '柠檬', '黑白', '玫瑰'][index])
                .fontSize(11).fontColor($r('app.color.theme_text_tertiary')).margin({ top: 7 })
            }.layoutWeight(1).onClick(() => {
              this.paletteIndex = index;
              this.onPaletteChange(index);
            })
          }, (index: number) => index.toString())
        }.width('100%').margin({ top: 26 })
        Column() {
          Text('主题预览').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.theme_text_primary'))
          Text('我的书架　　继续阅读').fontSize(14).fontColor(this.paletteColor(this.paletteIndex))
            .width('100%').padding(16).margin({ top: 12 }).backgroundColor($r('app.color.theme_surface_secondary')).borderRadius(12)
        }.width('100%').alignItems(HorizontalAlign.Start).padding(16).margin({ top: 24 })
          .backgroundColor($r('app.color.theme_surface_primary')).borderRadius(16)
        Text('深色模式点选即写入主题设置并在整个应用生效；配色序号会一并保存，配色渲染仍在迁移中。')
          .fontSize(12).fontColor($r('app.color.theme_text_tertiary')).lineHeight(18).margin({ top: 14 })
      }.width('100%').padding(16)
        .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.EaseInOut }))
    }
  }

  @Builder
  private modeOption(label: string, mode: number) {
    Text(label).fontSize(13)
      .fontColor(this.themeMode === mode ? $r('app.color.theme_surface_primary') : $r('app.color.theme_text_tertiary'))
      .textAlign(TextAlign.Center).layoutWeight(1).padding({ top: 12, bottom: 12 })
      .backgroundColor(this.themeMode === mode ? $r('app.color.theme_accent') : $r('app.color.theme_surface_tertiary'))
      .borderRadius(24)
      .margin({ left: 3, right: 3 }).onClick(() => {
        this.themeMode = mode;
        this.onThemeModeChange(mode);
      })
  }

  build() {
    Column() {
      Image($r('app.media.app_icon')).width(128).height(96).objectFit(ImageFit.Cover)
        .margin({ top: 16, bottom: 8 })
      Text(this.pageTitle()).fontSize(32).fontWeight(FontWeight.Bold).fontColor($r('app.color.theme_text_primary'))
      Text(this.pageSummary()).fontSize(16).fontColor($r('app.color.theme_text_tertiary')).margin({ top: 4, bottom: 12 })
      Progress({ value: this.page, total: 4, type: ProgressType.Linear })
        .width('calc(100% - 32vp)').height(4).color($r('app.color.theme_accent'))
        .backgroundColor($r('app.color.theme_surface_tertiary'))
        .margin({ left: 16, right: 16, bottom: 10 })
        .animation({ duration: 300, curve: Curve.EaseInOut })
      Column() {
        this.pageContent()
      }.width('100%').layoutWeight(1).margin({ left: 16, right: 16 })
        .backgroundColor($r('app.color.theme_surface_primary')).borderRadius(18)
      Row() {
        Blank()
        Button(this.page === 0 ? '阅读并同意　→' : this.page === 3 ? '完成　→' : '下一步　→')
          .fontSize(14).fontColor($r('app.color.theme_surface_primary')).backgroundColor($r('app.color.theme_accent')).borderRadius(28)
          .padding({ left: 22, right: 22, top: 12, bottom: 12 }).onClick(() => this.next())
      }.width('100%').padding({ left: 20, right: 20, top: 14, bottom: 18 })
    }.width('100%').height('100%').backgroundColor($r('app.color.theme_surface_primary')).justifyContent(FlexAlign.Start)
  }
}
