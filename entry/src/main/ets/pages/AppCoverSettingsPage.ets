import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import {
  CoverSettings, DEFAULT_COVER_SETTINGS, copyCoverSettings, CoverSettingsRepository
} from '../data/CoverSettingsRepository';
import {
  CoverRule, DEFAULT_COVER_RULE, copyCoverRule, isDefaultCoverRule, CoverRuleRepository
} from '../data/CoverRuleRepository';

/**
 * 封面设置页。
 *
 * 文字封面那几项（显示书名/作者、描边、阴影、默认颜色、文字色、信息方向）
 * 改完立即落盘并同步给书架；封面规则单独用一个 bindSheet 编辑，
 * 走 CoverRuleRepository 的 9 字段存储（对齐上游 CacheManager 里的 CoverRule）。
 * 其余上游项（网络封面、默认封面相册、网络书籍角标）本轮尚未迁移，
 * 仍按「未迁移」提示处理，避免出现看起来能改、实际不生效的开关。
 */
@Component
export struct AppCoverSettingsPage {
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
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
   * bindSheet 只生效最后一个的坑）。封面规则 sheet 用 'rule' 这个值。
   */
  @State activeSheet: string = '';
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

  private updateHeader(): void {
    const offset = this.settingsScroller.currentOffset().yOffset;
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      animateTo({ duration: 220, curve: Curve.EaseInOut }, () => this.collapsedHeader = shouldCollapse);
    }
  }

  /** 改一项就整份交出去，由 Index 落盘；页面本身只持有显示用的副本。 */
  private applyChange(update: (draft: CoverSettings) => void): void {
    const draft = copyCoverSettings(this.settings);
    update(draft);
    this.settings = draft;
    this.onChange(draft);
  }

  /** 文字色可选值，与阅读设置的强调色板保持同一套。 */
  private static readonly TEXT_COLOR_OPTIONS: string[] = [
    '#000000', '#FFFFFF', '#E7E8ED', '#AFC2FF', '#E8B77B', '#9AD0B7'
  ];

  build() {
    Column() {
      CollapsingSettingsHeader({ title: '封面设置', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Scroll(this.settingsScroller) {
        Column() {
          CoverSettingsSection({ title: '通用' }) {
            CoverSettingsAction({ title: '封面规则', detail: '编辑按规则获取封面用的搜索源与规则表达式', onSelect: () => this.openRuleSheet() })
            CoverSettingsAction({ title: '默认封面', detail: '未选择封面相册', onSelect: () => this.onUnavailableAction('默认封面相册选择尚未迁移') })
            CoverSettingsSwitch({
              title: '显示字体阴影', detail: '给书名与作者加一层阴影',
              value: this.settings.showShadow,
              onToggle: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.showShadow = value; })
            })
            CoverSettingsSwitch({
              title: '显示字体描边', detail: '深色封面上描白边，默认开启',
              value: this.settings.showStroke,
              onToggle: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.showStroke = value; })
            })
            CoverSettingsSwitch({
              title: '使用默认颜色', detail: '关闭后用下面日间/夜间封面里选的颜色',
              value: this.settings.useDefaultColor,
              onToggle: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.useDefaultColor = value; })
            })
          }

          CoverSettingsSection({ title: '书架显示' }) {
            CoverSettingsChoice({
              title: '封面信息方向', options: ['竖向', '横向'],
              selectedIndex: this.settings.infoOrientation === '1' ? 1 : 0,
              onSelect: (index: number) => this.applyChange((draft: CoverSettings) => {
                draft.infoOrientation = index === 1 ? '1' : '0';
              })
            })
            CoverSettingsAction({ title: '网络书籍角标', detail: '网络书籍角标尚未迁移', onSelect: () => this.onUnavailableAction('网络书籍角标设置尚未迁移') })
          }

          CoverSettingsSection({ title: '日间封面' }) {
            CoverSettingsColor({
              title: '文字颜色', colors: AppCoverSettingsPage.TEXT_COLOR_OPTIONS,
              color: this.settings.textColor, disabled: this.settings.useDefaultColor,
              onPick: (color: string) => this.applyChange((draft: CoverSettings) => { draft.textColor = color; })
            })
            CoverSettingsColor({
              title: '文字阴影颜色', colors: AppCoverSettingsPage.TEXT_COLOR_OPTIONS,
              color: this.settings.shadowColor, disabled: !this.settings.showShadow,
              onPick: (color: string) => this.applyChange((draft: CoverSettings) => { draft.shadowColor = color; })
            })
            CoverSettingsSwitch({
              title: '显示书名', value: this.settings.showName,
              onToggle: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.showName = value; })
            })
            CoverSettingsSwitch({
              title: '显示作者', detail: '关闭书名显示时不生效',
              value: this.settings.showAuthor, disabled: !this.settings.showName,
              onToggle: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.showAuthor = value; })
            })
          }

          CoverSettingsSection({ title: '夜间封面' }) {
            CoverSettingsColor({
              title: '文字颜色', colors: AppCoverSettingsPage.TEXT_COLOR_OPTIONS,
              color: this.settings.textColorDark, disabled: this.settings.useDefaultColor,
              onPick: (color: string) => this.applyChange((draft: CoverSettings) => { draft.textColorDark = color; })
            })
            CoverSettingsColor({
              title: '文字阴影颜色', colors: AppCoverSettingsPage.TEXT_COLOR_OPTIONS,
              color: this.settings.shadowColorDark, disabled: !this.settings.showShadow,
              onPick: (color: string) => this.applyChange((draft: CoverSettings) => { draft.shadowColorDark = color; })
            })
            CoverSettingsSwitch({
              title: '显示书名', value: this.settings.showNameDark,
              onToggle: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.showNameDark = value; })
            })
            CoverSettingsSwitch({
              title: '显示作者', detail: '关闭书名显示时不生效',
              value: this.settings.showAuthorDark, disabled: !this.settings.showNameDark,
              onToggle: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.showAuthorDark = value; })
            })
          }
          Text('有灰色动作提示的条目尚未迁移；其余开关与封面规则改动即时生效。')
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

  /** 一个 bindSheet 承载所有设置页 sheet；当前只有 'rule' 分支，后续批次在此追加。 */
  @Builder
  private CoverSettingsSheetContent() {
    Column() {
      if (this.activeSheet === 'rule') {
        Row() {
          Text('封面规则').fontSize(18).fontWeight(FontWeight.Medium)
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
      }
    }.width('100%').height('100%').padding({ top: 8 })
  }
}

@Component
struct CoverSettingsSection {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @Prop title: string = '';
  @BuilderParam content: () => void = this.emptyContent;
  @Builder
  emptyContent() {
  }
  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  @StorageProp('themeCardBorderWidth') themeCardBorderWidth: number = 0;
  @StorageProp('themeCardBorderColor') themeCardBorderColor: string = '#6A6D77';
  @StorageProp('themeCardBackground') themeCardBackground: string = '';
  @StorageProp('themeContainerBackground') themeContainerBackground: string = '';
  build() {
    Column() {
      Text(this.title).fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.themeColorAccent)
        .alignSelf(ItemAlign.Start).padding({ left: 18, top: 14, bottom: 8 })
      Column() { this.content() }.margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
    }
  }
}

@Component
struct CoverSettingsSwitch {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @Prop title: string = '';
  @Prop detail: string = '';
  /** 由父组件传入当前值，组件本身不再持有状态，避免与持久化数据不同步。 */
  @Prop value: boolean = false;
  /** 上游语义：显示作者依赖显示书名，书名关闭时本行置灰且不可改（保留原值）。 */
  @Prop disabled: boolean = false;
  onToggle: (value: boolean) => void = (_value: boolean) => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(18)
          .fontColor(this.disabled ? this.themeColorTextTertiary : this.themeColorTextSecondary)
        if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor(this.themeColorTextTertiary).margin({ top: 3 }) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.value })
        .enabled(!this.disabled)
        .onChange((value: boolean) => this.onToggle(value))
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 }).opacity(this.disabled ? 0.4 : 1)
  }
}

@Component
struct CoverSettingsAction {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(18).fontColor(this.themeColorTextSecondary)
        if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor(this.themeColorTextTertiary).margin({ top: 3 }) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(16).height(16).fillColor(this.themeColorTextTertiary)
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 }).onClick(() => this.onSelect())
  }
}

@Component
struct CoverSettingsChoice {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @Prop title: string = '';
  @Prop options: string[] = [];
  @Prop selectedIndex: number = 0;
  onSelect: (index: number) => void = (_index: number) => {};
  private getSelectedLabel(): string {
    if (this.options.length === 0) { return ''; }
    return this.options[Math.min(this.selectedIndex, this.options.length - 1)];
  }
  build() {
    Row() {
      Text(this.title).fontSize(18).fontColor(this.themeColorTextSecondary).layoutWeight(1)
      Text(this.getSelectedLabel()).fontSize(12).fontColor(this.themeColorAccent)
      Image($r('app.media.reader_next')).width(15).height(15).fillColor(this.themeColorTextTertiary).margin({ left: 6 })
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 }).onClick(() => {
      if (this.options.length > 0) {
        this.onSelect((this.selectedIndex + 1) % this.options.length);
      }
    })
  }
}

@Component
struct CoverSettingsColor {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @Prop title: string = '';
  @Prop colors: string[] = [];
  @Prop color: string = '#000000';
  /** 上游语义：使用默认颜色时文字色不生效、关闭阴影时阴影色不生效，这里把色块压暗提示。 */
  @Prop disabled: boolean = false;
  onPick: (color: string) => void = (_color: string) => {};
  private nextColor(): string {
    if (this.colors.length === 0) { return this.color; }
    const current = this.colors.findIndex((item: string) => item.toUpperCase() === this.color.toUpperCase());
    return this.colors[(current + 1) % this.colors.length];
  }
  build() {
    Row() {
      Text(this.title).fontSize(18).fontColor(this.disabled ? this.themeColorTextTertiary : this.themeColorTextSecondary).layoutWeight(1)
      Stack().width(26).height(26).backgroundColor(this.color).borderRadius(13)
        .border({ width: 1, color: '#676A75' })
        .opacity(this.disabled ? 0.4 : 1)
    }.padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .onClick(() => { if (!this.disabled) { this.onPick(this.nextColor()); } })
  }
}
