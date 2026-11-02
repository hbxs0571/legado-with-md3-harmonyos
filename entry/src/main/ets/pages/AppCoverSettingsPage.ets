import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import {
  CoverSettings, DEFAULT_COVER_SETTINGS, copyCoverSettings, CoverSettingsRepository
} from '../data/CoverSettingsRepository';

/**
 * 封面设置页。
 *
 * 只接本轮落地的那几项（显示书名/作者、描边、阴影、默认颜色、文字色、信息方向），
 * 其余上游项（网络封面、封面规则、默认封面相册、网络书籍角标）尚未迁移，
 * 仍按「未迁移」提示处理，避免出现看起来能改、实际不生效的开关。
 */
@Component
export struct AppCoverSettingsPage {
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 设置变化回调，由 Index 负责落盘并同步给书架。 */
  onChange: (settings: CoverSettings) => void = (_settings: CoverSettings) => {};
  @State collapsedHeader: boolean = false;
  /** 当前生效的封面设置；改动后立即落盘并同步给书架。 */
  @State settings: CoverSettings = copyCoverSettings(DEFAULT_COVER_SETTINGS);
  private settingsScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.settings = copyCoverSettings(CoverSettingsRepository.get());
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
            CoverSettingsAction({ title: '封面规则', detail: '进入详情页时按规则重新获取封面', onSelect: () => this.onUnavailableAction('封面规则编辑尚未迁移') })
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
              value: this.settings.showAuthor,
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
              value: this.settings.showAuthorDark,
              onToggle: (value: boolean) => this.applyChange((draft: CoverSettings) => { draft.showAuthorDark = value; })
            })
          }
          Text('网络封面、封面规则与默认封面相册尚未迁移；其余项改动即时生效。')
            .fontSize(15).fontColor('#858792').margin({ left: 18, right: 18, top: 6, bottom: 22 })
        }.width('100%').padding({ top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
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
  onToggle: (value: boolean) => void = (_value: boolean) => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(18).fontColor(this.themeColorTextSecondary)
        if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor(this.themeColorTextTertiary).margin({ top: 3 }) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.value })
        .onChange((value: boolean) => this.onToggle(value))
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 })
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
