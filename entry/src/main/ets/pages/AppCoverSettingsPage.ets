import curves from '@ohos.curves';
import { UiSection } from '../components/settings/UiSection';
import { UiSwitch } from '../components/settings/UiSwitch';
import { UiAction } from '../components/settings/UiAction';
import { UiChoice } from '../components/settings/UiChoice';
import { UiColorSheet } from '../components/settings/UiColorSheet';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import { AppGlyph } from '../components/AppGlyph';
import {
  CoverSettings, DEFAULT_COVER_SETTINGS, copyCoverSettings, CoverSettingsRepository
} from '../data/CoverSettingsRepository';
import {
  CoverRule, DEFAULT_COVER_RULE, copyCoverRule, isDefaultCoverRule, CoverRuleRepository
} from '../data/CoverRuleRepository';
import {
  CoverAlbumItem, CoverAlbumImageItem, CoverAlbumRepository
} from '../data/CoverAlbumRepository';

/**
 * 封面设置页。
 *
 * 文字封面那几项（显示书名/作者、描边、阴影、默认颜色、文字色、信息方向）
 * 改完立即落盘并同步给书架；封面规则单独用一个 bindSheet 编辑，
 * 走 CoverRuleRepository 的 9 字段存储（对齐上游 CacheManager 里的 CoverRule）。
 * 默认封面相册也挂在同一个 bindSheet 上：选择 sheet / 管理页 / 图片编辑器 /
 * 名称输入四个视图用 albumView 切换，数据落 CoverAlbumRepository 的
 * cover_albums/albums.json（对应上游 CoverAlbumRepository.kt）。
 * 其余上游项（网络封面、网络书籍角标）本轮尚未迁移，
 * 仍按「未迁移」提示处理，避免出现看起来能改、实际不生效的开关。
 */
@Component
export struct AppCoverSettingsPage {
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 设置变化回调，由 Index 负责落盘并同步给书架。 */
  onChange: (settings: CoverSettings) => void = (_settings: CoverSettings) => {};
  @State collapsedHeader: boolean = false;
  /** 当前生效的封面设置；改动后立即落盘并同步给书架。 */
  @State settings: CoverSettings = copyCoverSettings(DEFAULT_COVER_SETTINGS);
  /**
   * 同一节点只挂一个 bindSheet，用 activeSheet 分支切内容（项目踩过多个
   * bindSheet 只生效最后一个的坑）。'rule' 是封面规则、'album' 是相册那一组视图。
   */
  @State activeSheet: string = '';
  /**
   * 相册 sheet 内部再用 albumView 分四层：select（选择）/ manage（管理页）/
   * editor（图片编辑器）/ name（新建·改名输入）。切换时 activeSheet 保持 'album'
   * 不变，bindSheet 的 isShow 就一直为 true，不会因为分支切换被 onDisappear 关掉。
   */
  @State albumView: string = 'select';
  /** 取色面板正在改的字段名，对应上游 CoverConfigSheet.Color(field)。 */
  @State colorField: string = '';
  /** 相册列表整份替换刷新：ArkUI V1 的 @State 观察不到数组就地 push。 */
  @State albums: CoverAlbumItem[] = [];
  @State selectedAlbumId: string = '';
  /** 'create' | 'rename'，与上游 CoverAlbumDialog.Create / Rename 对应。 */
  @State nameDialogMode: string = '';
  @State nameDraft: string = '';
  /** 改名/编辑器正在操作的相册 id。 */
  @State editingAlbumId: string = '';
  /** 编辑器页签：0 白天、1 夜间，对应上游 selectedTab（CoverAlbumManageScreen.kt:306-307）。 */
  @State editorTab: number = 0;
  /**
   * 规则 sheet 的三项输入草稿拆成 @State 基本类型：ArkUI V1 的 @State 观察不到
   * 普通对象内部属性的就地修改，照项目既有做法（applyChange 整份替换）用标量。
   * 其余 6 个 BaseSource 字段不在 sheet 上编辑，保存时按默认值重建。
   */
  @State ruleEnabled: boolean = DEFAULT_COVER_RULE.enable;
  @State ruleSearchUrl: string = DEFAULT_COVER_RULE.searchUrl;
  @State ruleExpression: string = DEFAULT_COVER_RULE.coverRule;
  private settingsScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.settings = copyCoverSettings(CoverSettingsRepository.get());
    this.loadRuleIntoDraft(CoverRuleRepository.get());
    // 缓存先给一帧，再异步从磁盘刷新（Index 启动时也会先灌一次缓存）。
    this.albums = CoverAlbumRepository.getAlbums();
    this.selectedAlbumId = CoverAlbumRepository.getSelection();
    this.refreshAlbums();
  }

  /** 把仓储里的规则拆进三项草稿，编辑不落库。 */
  private loadRuleIntoDraft(rule: CoverRule): void {
    this.ruleEnabled = rule.enable;
    this.ruleSearchUrl = rule.searchUrl;
    this.ruleExpression = rule.coverRule;
  }

  /** 用 UIContext 的 promptAction 弹一条短提示；未查到独立 toast 工具函数。 */
  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {}
  }

  /**
   * 打开取色 sheet。activeSheet 沿用同一个 bindSheet，取值是 'color'，
   * 具体改哪个字段由 colorField 记着（对应上游 CoverConfigSheet.Color(field)）。
   */
  private openColorSheet(field: string): void {
    this.colorField = field;
    this.activeSheet = 'color';
  }

  /** 取色面板的当前值：按 colorField 从 settings 里取，取不到给黑色。 */
  private colorFieldValue(): string {
    if (this.colorField === 'textColor') { return this.settings.textColor; }
    if (this.colorField === 'shadowColor') { return this.settings.shadowColor; }
    if (this.colorField === 'textColorDark') { return this.settings.textColorDark; }
    if (this.colorField === 'shadowColorDark') { return this.settings.shadowColorDark; }
    return '#000000';
  }

  /** 取色面板的「重置」目标值，取上游这几个键的默认值。 */
  private colorFieldDefault(): string {
    if (this.colorField === 'textColor') { return DEFAULT_COVER_SETTINGS.textColor; }
    if (this.colorField === 'shadowColor') { return DEFAULT_COVER_SETTINGS.shadowColor; }
    if (this.colorField === 'textColorDark') { return DEFAULT_COVER_SETTINGS.textColorDark; }
    if (this.colorField === 'shadowColorDark') { return DEFAULT_COVER_SETTINGS.shadowColorDark; }
    return '#000000';
  }

  /** 取色面板的标题，用界面上的行名，与上游 ColorField 的文案一致。 */
  private colorFieldTitle(): string {
    if (this.colorField === 'textColor' || this.colorField === 'textColorDark') { return '文字颜色'; }
    return '文字阴影颜色';
  }

  /** 取色确认：按 colorField 写回对应字段。 */
  private applyColor(color: string): void {
    const field = this.colorField;
    this.activeSheet = '';
    this.applyChange((draft: CoverSettings) => {
      if (field === 'textColor') { draft.textColor = color; }
      else if (field === 'shadowColor') { draft.shadowColor = color; }
      else if (field === 'textColorDark') { draft.textColorDark = color; }
      else if (field === 'shadowColorDark') { draft.shadowColorDark = color; }
    });
  }

  /** 打开规则 sheet：把仓储里的当前值复制进草稿，编辑不落库。 */
  private openRuleSheet(): void {
    this.loadRuleIntoDraft(CoverRuleRepository.get());
    this.activeSheet = 'rule';
  }

  /** 上游「恢复默认」只改 UI 状态、不落库（CoverConfigViewModel.kt:102-110）。 */
  private restoreDefaultRule(): void {
    this.loadRuleIntoDraft(DEFAULT_COVER_RULE);
    this.showToast('已恢复默认规则，点保存后生效');
  }

  /**
   * 保存：先做空值校验（CoverConfigViewModel.kt:130-133），不通过则 toast 且不关 sheet；
   * 与默认规则相同就删缓存回退默认（delCoverRule），否则整份写库（saveCoverRule）。
   * 对齐上游 CoverConfigViewModel.kt:135：用 3 个 UI 字段构造全新 CoverRule，
   * 其余 6 个 BaseSource 字段不带入编辑态，按默认重建。
   */
  private async saveRule(): Promise<void> {
    if (this.ruleSearchUrl.trim().length === 0 || this.ruleExpression.trim().length === 0) {
      this.showToast('搜索 URL 与规则不能为空');
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.onUnavailableAction('封面规则保存失败，当前值未更改');
      return;
    }
    const draft = copyCoverRule(DEFAULT_COVER_RULE);
    draft.enable = this.ruleEnabled;
    draft.searchUrl = this.ruleSearchUrl;
    draft.coverRule = this.ruleExpression;
    if (isDefaultCoverRule(draft)) {
      await CoverRuleRepository.del(context);
    } else {
      await CoverRuleRepository.save(context, draft);
    }
    this.activeSheet = '';
  }

  /** 从磁盘重建相册缓存与选择态，整份赋给 @State 触发刷新。 */
  private async refreshAlbums(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const items = await CoverAlbumRepository.load(context);
    const selection = await CoverAlbumRepository.loadSelection(context);
    this.albums = items;
    this.selectedAlbumId = selection;
  }

  /** A4 的摘要行：随选中相册变成「相册名 · 日 N / 夜 M」，没选中回事先写死的那句。 */
  private albumSummary(): string {
    const album = this.albums.find((item: CoverAlbumItem) => item.id === this.selectedAlbumId);
    if (album === undefined) { return '未选择相册'; }
    return `${album.name} · 日 ${album.lightImages.length} / 夜 ${album.darkImages.length}`;
  }

  private openAlbumSelect(): void {
    this.albumView = 'select';
    this.activeSheet = 'album';
    this.refreshAlbums();
  }

  /** B1/B2：空串表示「无」（上游 onSelect(null)），非空串表示选中某相册。 */
  private async selectAlbum(albumId: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    await CoverAlbumRepository.setSelection(context, albumId);
    await this.refreshAlbums();
    this.activeSheet = '';
  }

  /** B3/B6：新建与改名共用同一个名字输入视图（上游共用 saveName）。 */
  private openNameDialog(mode: string, albumId: string, name: string): void {
    this.nameDialogMode = mode;
    this.editingAlbumId = albumId;
    this.nameDraft = name;
    this.albumView = 'name';
  }

  private async saveAlbumName(): Promise<void> {
    const name = this.nameDraft.trim();
    if (name.length === 0) {
      this.showToast('相册名称不能为空');
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    if (this.nameDialogMode === 'rename') {
      await CoverAlbumRepository.renameAlbum(context, this.editingAlbumId, name);
    } else {
      await CoverAlbumRepository.createAlbum(context, name);
    }
    await this.refreshAlbums();
    this.albumView = 'manage';
  }

  /** B7：删除相册的二次确认，文案带相册名（上游 cover_album_delete_confirmation(name)）。 */
  private confirmDeleteAlbum(albumId: string, name: string): void {
    this.getUIContext().showAlertDialog({
      title: '删除相册',
      message: `删除相册「${name}」？该相册中的图片也会被删除`,
      autoCancel: true,
      primaryButton: { value: '删除', action: () => { this.doDeleteAlbum(albumId); } },
      secondaryButton: { value: '取消', fontColor: this.themeColorTextTertiary, action: () => {} }
    });
  }

  private async doDeleteAlbum(albumId: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    await CoverAlbumRepository.deleteAlbum(context, albumId);
    await this.refreshAlbums();
  }

  /** B5 点卡片进 B8 编辑器：默认停在白天页签。 */
  private openEditor(albumId: string): void {
    this.editingAlbumId = albumId;
    this.editorTab = 0;
    this.albumView = 'editor';
  }

  private currentEditorAlbum(): CoverAlbumItem | undefined {
    return this.albums.find((item: CoverAlbumItem) => item.id === this.editingAlbumId);
  }

  /** B8：按当前页签取那一套图（isDark = selectedTab == 1，上游 :328）。 */
  private editorImages(): CoverAlbumImageItem[] {
    const album = this.currentEditorAlbum();
    if (album === undefined) { return []; }
    return this.editorTab === 1 ? album.darkImages : album.lightImages;
  }

  /** B9：添加图片只加到当前页签那一套。 */
  private async addEditorImages(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    await CoverAlbumRepository.addImages(context, this.editingAlbumId, this.editorTab === 1);
    await this.refreshAlbums();
  }

  /** B10：删除单图不弹确认（与 B7 删相册不同，上游 :358-376）。 */
  private async removeEditorImage(imageId: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    await CoverAlbumRepository.removeImage(
      context, this.editingAlbumId, this.editorTab === 1, imageId);
    await this.refreshAlbums();
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

  /** 改一项就整份交出去，由 Index 落盘；页面本身只持有显示用的副本。 */
  private applyChange(update: (draft: CoverSettings) => void): void {
    const draft = copyCoverSettings(this.settings);
    update(draft);
    this.settings = draft;
    this.onChange(draft);
  }

  /**
   * 色行的 option 文案。上游 CoverConfigScreen.kt 用的是
   * "#" + Integer.toHexString(color).uppercase()，是 8 位 ARGB；本地这些字段存的是
   * 6 位 #RRGGBB（见 CoverSettingsRepository 的 coverColorToAndroidInt），
   * 所以这里只做大写规范化，不补 alpha 位，免得显示与实际存储不一致。
   */
  private colorOption(color: string): string {
    return color.toUpperCase();
  }

  build() {
    Column() {
      CollapsingSettingsHeader({ title: '封面设置', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Scroll(this.settingsScroller) {
        Column() {
          UiSection({ title: '通用' }) {
            UiSwitch({
              title: '仅 WiFi 下载封面', detail: '蜂窝网络下不加载网络封面',
              value: this.settings.loadOnlyOnWifi,
              onChange: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.loadOnlyOnWifi = value; })
            })
            UiAction({ title: '封面规则', detail: '编辑按规则获取封面用的搜索源与规则表达式', onSelect: () => this.openRuleSheet() })
            UiSwitch({
              title: '使用默认封面', detail: '忽略书籍自带封面，统一显示默认封面',
              value: this.settings.useDefaultCover,
              onChange: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.useDefaultCover = value; })
            })
            UiAction({ title: '默认封面', detail: this.albumSummary(), onSelect: () => this.openAlbumSelect() })
            UiSwitch({
              title: '显示字体阴影', detail: '给书名与作者加一层阴影',
              value: this.settings.showShadow,
              onChange: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.showShadow = value; })
            })
            UiSwitch({
              title: '显示字体描边', detail: '深色封面上描白边，默认开启',
              value: this.settings.showStroke,
              onChange: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.showStroke = value; })
            })
            UiSwitch({showDivider: false,
              title: '使用默认颜色', detail: '关闭后用下面日间/夜间封面里选的颜色',
              value: this.settings.useDefaultColor,
              onChange: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.useDefaultColor = value; })
            })
          }

          UiSection({ title: '书架显示' }) {
            UiChoice({
              title: '封面信息方向', options: ['竖向', '横向'],
              selectedIndex: this.settings.infoOrientation === '1' ? 1 : 0,
              onSelect: (index: number) => this.applyChange((draft: CoverSettings) => {
                draft.infoOrientation = index === 1 ? '1' : '0';
              })
            })
            UiSwitch({
              title: '限制封面比例', detail: '开启时搜索/详情封面固定 5:7，关闭后按原图比例',
              value: this.settings.restrictCoverRatio,
              onChange: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.restrictCoverRatio = value; })
            })
            UiChoice({showDivider: false,
              title: '网络书籍角标', options: ['全部显示', '隐藏书架内', '隐藏同名同作者', '仅显示书架外'],
              selectedIndex: this.settings.exploreFilterState,
              onSelect: (index: number) => this.applyChange((draft: CoverSettings) => {
                draft.exploreFilterState = index;
              })
            })
          }

          UiSection({ title: '日间封面' }) {
            UiAction({
              title: '文字颜色', option: this.colorOption(this.settings.textColor),
              swatchColor: this.settings.textColor, swatchDisabled: this.settings.useDefaultColor,
              onSelect: () => this.openColorSheet('textColor')
            })
            UiAction({
              title: '文字阴影颜色', option: this.colorOption(this.settings.shadowColor),
              swatchColor: this.settings.shadowColor, swatchDisabled: !this.settings.showShadow,
              onSelect: () => this.openColorSheet('shadowColor')
            })
            UiSwitch({
              title: '显示书名', value: this.settings.showName,
              onChange: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.showName = value; })
            })
            UiSwitch({showDivider: false,
              title: '显示作者', detail: '关闭书名显示时不生效',
              value: this.settings.showAuthor, disabled: !this.settings.showName,
              onChange: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.showAuthor = value; })
            })
          }

          UiSection({ title: '夜间封面' }) {
            UiAction({
              title: '文字颜色', option: this.colorOption(this.settings.textColorDark),
              swatchColor: this.settings.textColorDark, swatchDisabled: this.settings.useDefaultColor,
              onSelect: () => this.openColorSheet('textColorDark')
            })
            UiAction({
              title: '文字阴影颜色', option: this.colorOption(this.settings.shadowColorDark),
              swatchColor: this.settings.shadowColorDark, swatchDisabled: !this.settings.showShadow,
              onSelect: () => this.openColorSheet('shadowColorDark')
            })
            UiSwitch({
              title: '显示书名', value: this.settings.showNameDark,
              onChange: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.showNameDark = value; })
            })
            UiSwitch({showDivider: false,
              title: '显示作者', detail: '关闭书名显示时不生效',
              value: this.settings.showAuthorDark, disabled: !this.settings.showNameDark,
              onChange: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.showAuthorDark = value; })
            })
          }
          Text('仅 WiFi 下载封面、网络书籍角标随网络封面与在线书源一起接入；其余改动即时生效。')
            .fontSize(15).fontColor('#858792').margin({ left: 18, right: 18, top: 6, bottom: 22 })
        }.width('100%').padding({ top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.activeSheet.length > 0, this.CoverSettingsSheetContent(), {
        height: 620,
        dragBar: true,
        showClose: false,
        backgroundColor: this.themeColorSurfaceElevated,
        onDisappear: () => this.activeSheet = ''
      })
  }

  /** 一个 bindSheet 承载所有设置页 sheet：'rule' 是封面规则，'album' 里再按 albumView 分四层。 */
  @Builder
  private CoverSettingsSheetContent() {
    Column() {
      if (this.activeSheet === 'color') {
        // 取色面板：对应上游 ColorPickerSheet。四行色共用这一个分支，
        // 改哪个字段由 colorField 决定。
        UiColorSheet({
          title: this.colorFieldTitle(),
          initialColor: this.colorFieldValue(),
          resetColor: this.colorFieldDefault(),
          onCancel: () => { this.activeSheet = ''; },
          onConfirm: (color: string) => this.applyColor(color)
        })
      } else if (this.activeSheet === 'rule') {
        Row() {
          Text('封面规则').fontSize(20).fontWeight(FontWeight.Medium)
            .fontColor(this.themeColorTextPrimary).layoutWeight(1)
          Text('恢复默认').fontSize(14).fontColor(this.themeColorAccent)
            .onClick(() => this.restoreDefaultRule())
          Text('保存').fontSize(14).fontColor(this.themeColorAccent).margin({ left: 18 })
            .onClick(() => { this.saveRule(); })
        }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 12 })

        Scroll() {
          Column() {
            Row() {
              Text('启用').fontSize(15).fontColor(this.themeColorTextPrimary).layoutWeight(1)
              Toggle({ type: ToggleType.Checkbox, isOn: this.ruleEnabled })
                .onChange((value: boolean) => this.ruleEnabled = value)
            }.width('100%').padding({ top: 8, bottom: 8 })

            Column() {
              Text('搜索 URL').fontSize(13).fontColor(this.themeColorTextTertiary)
                .alignSelf(ItemAlign.Start).margin({ bottom: 6 })
              TextInput({ text: this.ruleSearchUrl, placeholder: '搜索 URL' })
                .fontSize(14).fontColor(this.themeColorTextPrimary)
                .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : this.themeColorSurfacePrimary)
                .borderRadius(8).padding(10)
                .onChange((value: string) => this.ruleSearchUrl = value)
            }.width('100%').margin({ bottom: 12 })

            Column() {
              Text('规则表达式').fontSize(13).fontColor(this.themeColorTextTertiary)
                .alignSelf(ItemAlign.Start).margin({ bottom: 6 })
              TextArea({ text: this.ruleExpression, placeholder: '规则表达式' })
                .width('100%').height(300).fontSize(12).fontColor(this.themeColorTextPrimary)
                .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : this.themeColorSurfacePrimary)
                .borderRadius(8).padding(10)
                .onChange((value: string) => this.ruleExpression = value)
            }.width('100%')
          }.width('100%').padding({ left: 16, right: 16, top: 4 })
        }.layoutWeight(1).scrollBar(BarState.Off)
      } else if (this.activeSheet === 'album') {
        if (this.albumView === 'select') {
          // B1/B2：选择 sheet。顶栏「管理相册」进管理页，对应上游 onManage。
          Row() {
            Text('选择封面相册').fontSize(20).fontWeight(FontWeight.Medium)
              .fontColor(this.themeColorTextPrimary).layoutWeight(1)
            Text('管理相册').fontSize(14).fontColor(this.themeColorAccent)
              .onClick(() => this.albumView = 'manage')
          }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 12 })

          Scroll() {
            Column() {
              // B1「无」项：清空选择、不使用任何相册（上游写 null，本地写空串）。
              Row() {
                CoverAlbumThumb({ path: '', w: 44, h: 60 })
                Column() {
                  Text('无').fontSize(15).fontColor(this.themeColorTextPrimary)
                  Text('不使用相册，回落到随机默认封面').fontSize(12)
                    .fontColor(this.themeColorTextTertiary).margin({ top: 4 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 })
                if (this.selectedAlbumId.length === 0) {
                  AppGlyph({ name: 'profileCheck', glyphSize: 18, tint: this.themeColorAccent })
                }
              }.width('100%').padding(10).margin({ bottom: 8 })
                .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(12)
                .onClick(() => { this.selectAlbum(''); })

              // B2 相册项：44×60 缩略图 + 名称 + 日夜计数 + 选中勾；B14 空相册照样列出。
              ForEach(this.albums, (album: CoverAlbumItem) => {
                Row() {
                  CoverAlbumThumb({ path: CoverAlbumRepository.previewPath(album), w: 44, h: 60 })
                  Column() {
                    Text(album.name.length > 0 ? album.name : '未命名相册').fontSize(15)
                      .fontColor(this.themeColorTextPrimary).maxLines(1)
                    Text(`日 ${album.lightImages.length} / 夜 ${album.darkImages.length}`)
                      .fontSize(12).fontColor(this.themeColorTextTertiary).margin({ top: 4 })
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 })
                  if (this.selectedAlbumId === album.id) {
                    AppGlyph({ name: 'profileCheck', glyphSize: 18, tint: this.themeColorAccent })
                  }
                }.width('100%').padding(10).margin({ bottom: 8 })
                  .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(12)
                  .onClick(() => { this.selectAlbum(album.id); })
              }, (album: CoverAlbumItem) => album.id)
            }.width('100%').padding({ left: 16, right: 16, top: 4 })
          }.layoutWeight(1).scrollBar(BarState.Off)
        } else if (this.albumView === 'manage') {
          // B3/B4/B5/B6/B7：管理页。顶栏返回选择 sheet、右侧「+」新建。
          Row() {
            Text('返回').fontSize(14).fontColor(this.themeColorAccent)
              .onClick(() => this.albumView = 'select')
            Text('封面相册').fontSize(20).fontWeight(FontWeight.Medium)
              .fontColor(this.themeColorTextPrimary).layoutWeight(1).textAlign(TextAlign.Center)
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'add', glyphSize: 20, tint: this.themeColorAccent })
            }.width(32).height(32)
              .onClick(() => this.openNameDialog('create', '', ''))
          }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 12 })

          if (this.albums.length === 0) {
            // B4 空态：仅整个列表为空时出现，居中集合图标 + 一行提示。
            Column() {
              AppGlyph({ name: 'folder', glyphSize: 48, tint: this.themeColorTextTertiary })
              Text('暂无相册').fontSize(15).fontColor(this.themeColorTextTertiary)
                .margin({ top: 12 })
            }.width('100%').height('100%').justifyContent(FlexAlign.Center)
          } else {
            Scroll() {
              Column() {
                ForEach(this.albums, (album: CoverAlbumItem) => {
                  // B5 管理页卡片：缩略图 64×88（与选择 sheet 的 44×60 是上游实测的两套尺寸）。
                  Row() {
                    CoverAlbumThumb({ path: CoverAlbumRepository.previewPath(album), w: 64, h: 88 })
                    Column() {
                      Text(album.name.length > 0 ? album.name : '未命名相册').fontSize(15)
                        .fontColor(this.themeColorTextPrimary).maxLines(1)
                      Text(`日 ${album.lightImages.length} / 夜 ${album.darkImages.length}`)
                        .fontSize(12).fontColor(this.themeColorTextTertiary).margin({ top: 4 })
                      if (this.selectedAlbumId === album.id) {
                        Text('使用中').fontSize(12).fontColor(this.themeColorAccent).margin({ top: 4 })
                      }
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 })
                  }.width('100%').padding(10).margin({ bottom: 8 })
                    .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(12)
                    .onClick(() => this.openEditor(album.id))

                  // B6 改名（铅笔）、B7 删除（垃圾桶，带二次确认）。
                  Row() {
                    Stack({ alignContent: Alignment.Center }) {
                      AppGlyph({ name: 'pencil', glyphSize: 18, tint: this.themeColorTextSecondary })
                    }.width(32).height(32)
                      .onClick(() => this.openNameDialog('rename', album.id, album.name))
                    Stack({ alignContent: Alignment.Center }) {
                      AppGlyph({ name: 'delete', glyphSize: 18, tint: this.themeColorTextSecondary })
                    }.width(32).height(32).margin({ left: 8 })
                      .onClick(() => this.confirmDeleteAlbum(album.id, album.name))
                  }.width('100%').justifyContent(FlexAlign.End).margin({ bottom: 16 })
                }, (album: CoverAlbumItem) => album.id)
              }.width('100%').padding({ left: 16, right: 16, top: 4 })
            }.layoutWeight(1).scrollBar(BarState.Off)
          }
        } else if (this.albumView === 'editor') {
          // B8/B9/B10：图片编辑器，日夜两套独立列表。
          Row() {
            Text('返回').fontSize(14).fontColor(this.themeColorAccent)
              .onClick(() => this.albumView = 'manage')
            Text(this.currentEditorAlbum()?.name ?? '相册').fontSize(20).fontWeight(FontWeight.Medium)
              .fontColor(this.themeColorTextPrimary).layoutWeight(1).textAlign(TextAlign.Center)
            AppGlyph({ name: 'add', glyphSize: 20, tint: this.themeColorAccent })
              .onClick(() => { this.addEditorImages(); })
          }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 12 })

          // B8 页签：默认白天（0）；切换后下方网格换成另一套图。
          Row() {
            Text('白天').fontSize(14)
              .fontColor(this.editorTab === 0 ? this.themeColorAccent : this.themeColorTextTertiary)
              .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 8, bottom: 8 })
              .onClick(() => this.editorTab = 0)
            Text('夜间').fontSize(14)
              .fontColor(this.editorTab === 1 ? this.themeColorAccent : this.themeColorTextTertiary)
              .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 8, bottom: 8 })
              .onClick(() => this.editorTab = 1)
          }.width('100%').margin({ bottom: 8 })

          Scroll() {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.editorImages(), (image: CoverAlbumImageItem) => {
                Stack({ alignContent: Alignment.TopEnd }) {
                  Image(image.path).width(76).aspectRatio(5 / 7).objectFit(ImageFit.Cover)
                    .borderRadius(8)
                  // B10 删除单图：右上角「×」，不弹确认。
                  Stack({ alignContent: Alignment.Center }) {
                    AppGlyph({ name: 'profileClose', glyphSize: 14, tint: '#FFFFFF' })
                  }.width(22).height(22).borderRadius(11).backgroundColor('#66000000')
                    .onClick(() => { this.removeEditorImage(image.id); })
                }.width(76).margin({ right: 8, bottom: 8 })
              }, (image: CoverAlbumImageItem) => image.id)
              Text('添加图片').fontSize(14).fontColor(this.themeColorAccent)
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .onClick(() => { this.addEditorImages(); })
            }.width('100%').padding({ left: 16, right: 16, top: 4 })
          }.layoutWeight(1).scrollBar(BarState.Off)
        } else {
          // B3/B6 名称输入：上游新建与改名共用 saveName；showAlertDialog 带不了输入框，
          // 所以用这一层页面内面板（上游 :420-449 的 CoverAlbumNameDialog）。
          Column() {
            Text(this.nameDialogMode === 'rename' ? '重命名相册' : '新建相册')
              .fontSize(20).fontWeight(FontWeight.Medium)
              .fontColor(this.themeColorTextPrimary).margin({ bottom: 16 })
            TextInput({ text: this.nameDraft, placeholder: '相册名称' })
              .fontSize(15).fontColor(this.themeColorTextPrimary)
              .backgroundColor(this.themeColorSurfacePrimary).borderRadius(8).padding(10)
              .onChange((value: string) => this.nameDraft = value)
            Row() {
              Text('取消').fontSize(14).fontColor(this.themeColorTextSecondary)
                .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 12, bottom: 12 })
                .onClick(() => this.albumView = 'manage')
              Text('确定').fontSize(14).fontColor(this.themeColorAccent)
                .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 12, bottom: 12 })
                .onClick(() => { this.saveAlbumName(); })
            }.width('100%').margin({ top: 20 })
          }.width('100%').padding(24)
        }
      }
    }.width('100%').height('100%').padding({ top: 8 })
  }
}

/** 相册缩略图：有图裁切铺满，无图显示集合图标。选择 sheet 44×60、管理页 64×88 由调用方传。 */
@Component
struct CoverAlbumThumb {
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @Prop path: string = '';
  @Prop w: number = 44;
  @Prop h: number = 60;
  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.path.length > 0) {
        Image(this.path).width('100%').height('100%').objectFit(ImageFit.Cover)
          .borderRadius(8)
      } else {
        AppGlyph({ name: 'folder', glyphSize: 28, tint: this.themeColorTextTertiary })
      }
    }.width(this.w).height(this.h).borderRadius(8).backgroundColor('#2A2B32').clip(true)
  }
}

