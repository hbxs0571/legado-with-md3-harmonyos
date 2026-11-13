import curves from '@ohos.curves';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import { ThemeItemDivider } from '../components/ThemeItemDivider';
import {
  LegacyThemeMigrationResult, SavedThemeEntry, ThemeConfigPatch, ThemePackageImport,
  ThemePackageRepository, ThemePackageSource, fromPortableConfig
} from '../data/ThemePackageRepository';

/**
 * 主题包管理页，对应上游 `ui/config/themeManage/ThemeManageScreen.kt`（331 行）。
 *
 * 结构与上游逐块对齐：
 * ① 顶部五个入口：保存当前设置 / 导出当前主题 / 导入主题包 / 导入旧版主题配置 / 迁移旧版主题；
 * ② 已存主题列表：搜索框 + 「已保存的主题」标题 + 每项一个卡片（名字 + 日/夜两组色点 +
 *    编辑 / 导出 / 删除三个按钮），点卡片本身是「应用主题」；
 * ③ 保存 / 应用 / 删除 / 编辑四个对话框，本地统一用 `showAlertDialog`（与
 *    `ThemeSettingsPage.confirmResetDefaults` 同一条范式）。
 *
 * 与上游的一处差异：上游「编辑」弹 `EditThemeSheet`（403 行，可改名字与日/夜各 6 个颜色位），
 * 本地编辑对话框只能改名字；颜色位编辑走「应用主题后再进自定义颜色页」，
 * 因为本地色位编辑面板（`CustomThemePage`）已经是唯一一套颜色编辑 UI，再造一份会分叉。
 */
@Component
export struct ThemeManagePage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  @StorageProp('themeCardBorderWidth') themeCardBorderWidth: number = 0;
  @StorageProp('themeCardBorderColor') themeCardBorderColor: string = '#6A6D77';
  @StorageProp('themeCardBackground') themeCardBackground: string = '';
  @StorageProp('themeContainerBackground') themeContainerBackground: string = '';
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 取当前设置快照，用于「保存当前设置」「导出当前主题」。 */
  provideSource: () => ThemePackageSource = () => {
    throw new Error('未注入主题来源');
  };
  /** 应用一份主题补丁（配置 + 已落盘的资产路径），由 `Index` 实现。 */
  onApplyTheme: (patch: ThemeConfigPatch, assets: Record<string, string>) => void =
    (_patch: ThemeConfigPatch, _assets: Record<string, string>) => {};
  @State collapsedHeader: boolean = false;
  @State savedThemes: SavedThemeEntry[] = [];
  @State searchKeyword: string = '';
  @State hasLegacyThemes: boolean = false;
  /** 是否打开了「保存当前设置」的名称输入面板。 */
  @State savingOpen: boolean = false;
  /** 保存面板的输入内容。 */
  @State pendingThemeName: string = '';
  /** 正在编辑名字的主题目录名；空串表示没有打开编辑框。 */
  @State renamingDirectory: string = '';
  @State renamingName: string = '';
  private settingsScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.refresh();
  }

  private updateHeader(): void {
    const offset = this.settingsScroller.currentOffset().yOffset;
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      // 顶部折叠是位移，用弹簧收尾更自然；弹簧不吃 duration，删掉（写了也不生效）。
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
    }
  }

  private hostContext(): Context | undefined {
    return this.getUIContext().getHostContext();
  }

  /** 重新读一遍已存主题列表与旧版迁移入口的可见性。 */
  private refresh(): void {
    const context = this.hostContext();
    if (context === undefined) { return; }
    try {
      this.savedThemes = ThemePackageRepository.loadSavedThemes(context);
      this.hasLegacyThemes = ThemePackageRepository.hasLegacySavedThemes(context);
    } catch (error) {
      this.onUnavailableAction(error instanceof Error ? error.message : '读取已保存主题失败');
    }
  }

  /** 按搜索词过滤（上游是名字包含匹配，忽略大小写）。 */
  private filteredThemes(): SavedThemeEntry[] {
    const keyword = this.searchKeyword.trim().toLowerCase();
    if (keyword.length === 0) { return this.savedThemes; }
    return this.savedThemes.filter((entry: SavedThemeEntry) =>
      entry.name.toLowerCase().includes(keyword));
  }

  /**
   * 打开保存面板并预填一个不重名的默认名。
   *
   * 上游是 `AppAlertDialog` 里嵌 `AppTextField`；ArkUI 的 `showAlertDialog` 不能带输入框，
   * 所以保存与重命名都用页面底部的固定输入面板（与 `CustomThemePage` 的色位面板同款）。
   */
  private promptSave(): void {
    const context = this.hostContext();
    if (context === undefined) { return; }
    this.renamingDirectory = '';
    this.pendingThemeName = ThemePackageRepository.uniqueSavedThemeName(context, '我的主题');
    this.savingOpen = true;
  }

  private saveCurrentTheme(): void {
    const context = this.hostContext();
    if (context === undefined) { return; }
    const name = this.pendingThemeName.trim();
    if (name.length === 0) {
      this.onUnavailableAction('主题名称不能为空');
      return;
    }
    try {
      ThemePackageRepository.saveTheme(context, name, this.provideSource());
      this.savingOpen = false;
      this.pendingThemeName = '';
      this.refresh();
      this.onUnavailableAction(`已保存主题「${name}」`);
    } catch (error) {
      this.onUnavailableAction(error instanceof Error ? error.message : '主题保存失败');
    }
  }

  private exportCurrent(): void {
    const context = this.hostContext();
    if (context === undefined) { return; }
    const name = ThemePackageRepository.uniqueSavedThemeName(context, '当前主题');
    ThemePackageRepository.exportCurrentTheme(context, name, this.provideSource())
      .then((saved: boolean) => {
        if (saved) { this.onUnavailableAction('主题导出成功'); }
      })
      .catch((error: Error) => {
        this.onUnavailableAction(error.message.length > 0 ? error.message : '主题导出失败');
      });
  }

  private importPackage(): void {
    const context = this.hostContext();
    if (context === undefined) { return; }
    ThemePackageRepository.importPackage(context)
      .then((result: ThemePackageImport | undefined) => {
        if (result === undefined) { return; }
        this.applyImport(result, '主题导入成功，部分设置需要重启生效');
      })
      .catch((error: Error) => {
        this.onUnavailableAction(error.message.length > 0 ? error.message : '主题导入失败');
      });
  }

  private importLegacy(): void {
    const context = this.hostContext();
    if (context === undefined) { return; }
    ThemePackageRepository.importLegacyJson(context)
      .then((result: ThemePackageImport | undefined) => {
        if (result === undefined) { return; }
        this.applyImport(result, '主题配置导入成功');
      })
      .catch((error: Error) => {
        this.onUnavailableAction(error.message.length > 0 ? error.message : '主题配置导入失败');
      });
  }

  /**
   * 导入成功后：把配置转成补丁交给 `Index` 应用，资产路径一并回填。
   *
   * 上游 `ThemePackageManager.kt:848 saveImportedTheme` 在应用之后还会用
   * `exportCurrent()` 把「应用后的当前设置」存成一条已存主题（重名走
   * `uniqueSavedThemeName`），所以这里也补一步：`onApplyTheme` 是同步的，
   * 返回后 `provideSource()` 读到的就是应用后的快照。
   */
  private applyImport(result: ThemePackageImport, successMessage: string): void {
    this.onApplyTheme(fromPortableConfig(result.config), result.assets);
    const context = this.hostContext();
    let savedNote: string = '';
    if (context !== undefined) {
      try {
        const baseName = result.name.length > 0 ? result.name : '导入的主题';
        const name = ThemePackageRepository.uniqueSavedThemeName(context, baseName);
        ThemePackageRepository.saveTheme(context, name, this.provideSource());
        this.refresh();
        savedNote = `，已存为「${name}」`;
      } catch (error) {
        savedNote = error instanceof Error ? `，保存主题失败：${error.message}` : '，保存主题失败';
      }
    }
    const ignored = result.ignoredAssetCount > 0
      ? `（${result.ignoredAssetCount} 个本地不支持的资源已忽略）` : '';
    this.onUnavailableAction(`${successMessage}${savedNote}${ignored}`);
  }

  private migrateLegacy(): void {
    const context = this.hostContext();
    if (context === undefined) { return; }
    try {
      const result: LegacyThemeMigrationResult = ThemePackageRepository.migrateLegacySavedThemes(context);
      this.refresh();
      if (result.failedCount > 0) {
        this.onUnavailableAction(`已迁移 ${result.migratedCount} 个主题，${result.failedCount} 个迁移失败`);
      } else {
        this.onUnavailableAction(`已迁移 ${result.migratedCount} 个旧版主题`);
      }
    } catch (error) {
      this.onUnavailableAction(error instanceof Error ? error.message : '迁移旧版主题失败');
    }
  }

  private confirmApply(entry: SavedThemeEntry): void {
    this.getUIContext().showAlertDialog({
      title: '应用主题',
      message: `确定应用主题「${entry.name}」？应用后需要重启才能完全生效。`,
      autoCancel: true,
      primaryButton: { value: '应用', action: () => this.applySaved(entry) },
      secondaryButton: { value: '取消', fontColor: this.themeColorTextTertiary, action: () => {} }
    });
  }

  private applySaved(entry: SavedThemeEntry): void {
    const context = this.hostContext();
    if (context === undefined) { return; }
    try {
      const result = ThemePackageRepository.readSavedTheme(context, entry.directoryName);
      if (result === undefined) {
        this.onUnavailableAction('主题目录已损坏，无法应用');
        return;
      }
      this.onApplyTheme(fromPortableConfig(result.config), result.assets);
      this.onUnavailableAction(`已应用主题「${entry.name}」`);
    } catch (error) {
      this.onUnavailableAction(error instanceof Error ? error.message : '主题应用失败');
    }
  }

  private confirmDelete(entry: SavedThemeEntry): void {
    this.getUIContext().showAlertDialog({
      title: '删除主题',
      message: `确定删除主题「${entry.name}」？此操作不可恢复。`,
      autoCancel: true,
      primaryButton: { value: '删除', action: () => this.deleteSaved(entry) },
      secondaryButton: { value: '取消', fontColor: this.themeColorTextTertiary, action: () => {} }
    });
  }

  private deleteSaved(entry: SavedThemeEntry): void {
    const context = this.hostContext();
    if (context === undefined) { return; }
    try {
      ThemePackageRepository.deleteSavedTheme(context, entry.directoryName);
      this.refresh();
    } catch (error) {
      this.onUnavailableAction(error instanceof Error ? error.message : '主题删除失败');
    }
  }

  private exportSaved(entry: SavedThemeEntry): void {
    const context = this.hostContext();
    if (context === undefined) { return; }
    ThemePackageRepository.exportSavedTheme(context, entry)
      .then((saved: boolean) => {
        if (saved) { this.onUnavailableAction('主题导出成功'); }
      })
      .catch((error: Error) => {
        this.onUnavailableAction(error.message.length > 0 ? error.message : '主题导出失败');
      });
  }

  /** 编辑名字：上游 `EditThemeSheet` 的基础组只有「名称」一项。 */
  private promptRename(entry: SavedThemeEntry): void {
    this.renamingDirectory = entry.directoryName;
    this.renamingName = entry.name;
  }

  private commitRename(): void {
    const context = this.hostContext();
    if (context === undefined || this.renamingDirectory.length === 0) { return; }
    const nextName = this.renamingName.trim();
    if (nextName.length === 0) {
      this.onUnavailableAction('主题名称不能为空');
      return;
    }
    try {
      ThemePackageRepository.renameSavedTheme(context, this.renamingDirectory, nextName);
      this.renamingDirectory = '';
      this.renamingName = '';
      this.refresh();
    } catch (error) {
      this.onUnavailableAction(error instanceof Error ? error.message : '主题重命名失败');
    }
  }

  /** 日/夜两组色点，对齐上游 `ThemeColorGroup`（各 3 个 12dp 圆点）。 */
  @Builder
  private ColorDots(colors: string[]) {
    Row() {
      ForEach(colors, (color: string, index: number) => {
        Row().width(12).height(12).borderRadius(6)
          .backgroundColor(color.length > 0 ? color : this.themeColorTextTertiary)
          .border({ width: 1, color: this.themeColorTextTertiary })
          .margin({ right: index < colors.length - 1 ? 4 : 0 })
      }, (color: string, index: number) => `${color}-${index}`)
    }
  }

  @Builder
  private SavedThemeCard(entry: SavedThemeEntry) {
    Column() {
      Row() {
        Column() {
          Text(entry.name).fontSize(17).fontColor(this.themeColorTextPrimary)
          Row() {
            this.ColorDots(ThemePackageRepository.previewColors(entry.config, false))
            Text('日间').fontSize(11).fontColor(this.themeColorTextTertiary).margin({ left: 6, right: 12 })
            this.ColorDots(ThemePackageRepository.previewColors(entry.config, true))
            Text('夜间').fontSize(11).fontColor(this.themeColorTextTertiary).margin({ left: 6 })
          }.margin({ top: 6 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text('应用').fontSize(14).fontColor(this.themeColorAccent)
      }.width('100%').onClick(() => this.confirmApply(entry))
      Row() {
        Text('编辑').fontSize(14).fontColor(this.themeColorTextSecondary).layoutWeight(1)
          .onClick(() => this.promptRename(entry))
        Text('导出').fontSize(14).fontColor(this.themeColorTextSecondary).layoutWeight(1)
          .onClick(() => this.exportSaved(entry))
        Text('删除').fontSize(14).fontColor('#E53935').layoutWeight(1)
          .onClick(() => this.confirmDelete(entry))
      }.width('100%').margin({ top: 12 })
    }.width('calc(100% - 32vp)').padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .margin({ left: 16, right: 16, top: 10 })
      .backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary)
      .borderRadius(this.themeCardRadius)
      .border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor })
      .backgroundImage(this.themeContainerBackground.length > 0
        ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
  }

  @Builder
  private EntryRow(title: string, summary: string, onSelect: () => void) {
    Row() {
      Column() {
        Text(title).fontSize(17).fontColor(this.themeColorTextSecondary)
        Text(summary).fontSize(13).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(16).height(16).fillColor(this.themeColorTextTertiary)
    }.width('100%').padding({ left: 16, right: 16, top: 13, bottom: 13 }).onClick(onSelect)
  }

  build() {
    Column() {
      CollapsingSettingsHeader({
        title: '主题包', collapsed: this.collapsedHeader, onBack: () => this.onBack()
      })

      Scroll(this.settingsScroller) {
        Column() {
          // ① 五个入口，顺序与文案逐条对齐 `strings.xml` 的 theme_manage_*。
          Column() {
            this.EntryRow('保存当前设置', '保存当前主题配置为新主题', () => this.promptSave())
            ThemeItemDivider()
            this.EntryRow('导出当前主题', '将配置、图片、字体导出为主题包', () => this.exportCurrent())
            ThemeItemDivider()
            this.EntryRow('导入主题包', '导入包含资源的主题包', () => this.importPackage())
            ThemeItemDivider()
            this.EntryRow('导入旧版主题配置', '从旧版 JSON 文件导入主题配置', () => this.importLegacy())
            if (this.hasLegacyThemes) {
              ThemeItemDivider()
              this.EntryRow('迁移旧版主题', '将已保存的 JSON 主题转换为新版主题格式', () => this.migrateLegacy())
            }
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16, top: 12 })
            .backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary)
            .borderRadius(this.themeCardRadius)
            .border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor })
            .backgroundImage(this.themeContainerBackground.length > 0
              ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          // ② 已存主题列表：上游只在有已存主题时显示搜索框与列表。
          if (this.savedThemes.length > 0) {
            TextInput({ text: this.searchKeyword, placeholder: '搜索主题' })
              .width('calc(100% - 32vp)').margin({ left: 16, right: 16, top: 16 })
              .backgroundColor(this.themeCardBackground.length > 0
                ? this.themeCardBackground : this.themeColorSurfaceSecondary)
              .borderRadius(this.themeCardRadius)
              .border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor })
              .onChange((value: string) => this.searchKeyword = value)
            Text('已保存的主题').fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.themeColorAccent)
              .alignSelf(ItemAlign.Start).padding({ left: 18, top: 18, bottom: 2 })
            ForEach(this.filteredThemes(), (entry: SavedThemeEntry) => {
              this.SavedThemeCard(entry)
            }, (entry: SavedThemeEntry) => entry.directoryName)
          } else {
            Text('还没有保存的主题。用上面的「保存当前设置」把当前配置存成主题。')
              .fontSize(14).fontColor(this.themeColorTextTertiary)
              .padding({ left: 18, right: 18, top: 18, bottom: 22 })
          }

          Column().height(32)
        }.width('100%')
      }.layoutWeight(1).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
        .onDidScroll(() => this.updateHeader())

      // ③ 名称输入面板：保存当前设置与重命名共用（上游是对话框里的 `AppTextField`）。
      if (this.savingOpen || this.renamingDirectory.length > 0) {
        Column() {
          Row() {
            Text(this.savingOpen ? '保存主题' : '编辑主题')
              .fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
              .layoutWeight(1)
            Text('取消').fontSize(15).fontColor(this.themeColorTextTertiary)
              .onClick(() => {
                this.savingOpen = false;
                this.pendingThemeName = '';
                this.renamingDirectory = '';
                this.renamingName = '';
              })
            Text('保存').fontSize(15).fontColor(this.themeColorAccent).margin({ left: 18 })
              .onClick(() => {
                if (this.savingOpen) { this.saveCurrentTheme(); } else { this.commitRename(); }
              })
          }.width('100%').padding({ bottom: 12 })
          TextInput({
            text: this.savingOpen ? this.pendingThemeName : this.renamingName,
            placeholder: '请输入主题名称'
          }).onChange((value: string) => {
            if (this.savingOpen) { this.pendingThemeName = value; } else { this.renamingName = value; }
          })
        }.width('calc(100% - 32vp)').padding(16).margin({ left: 16, right: 16, bottom: 12 })
          .backgroundColor(this.themeCardBackground.length > 0
            ? this.themeCardBackground : this.themeColorSurfaceElevated)
          .borderRadius(this.themeCardRadius)
          .border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor })
      }
    }.width('100%').height('100%')
      .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent
        : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .backgroundImage(this.themeAppBackground.length > 0
        ? `file://${this.themeAppBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
  }
}
