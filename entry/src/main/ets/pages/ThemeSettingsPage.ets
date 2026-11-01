import { AppGlyph } from '../components/AppGlyph';
import { ThemeItemDivider } from '../components/ThemeItemDivider';
import {
  BOOK_INFO_BACKGROUND_OFF,
  BOOK_INFO_BACKGROUND_OFF_FOR_DEFAULT,
  BOOK_INFO_BACKGROUND_ON
} from '../data/ThemeSettingsRepository';
import {
  CARD_BORDER_WIDTH_MAX,
  CARD_BORDER_WIDTH_MIN,
  CARD_RADIUS_MAX,
  CARD_RADIUS_MIN,
  CONTAINER_OPACITY_MAX,
  CONTAINER_OPACITY_MIN,
  DIVIDER_LENGTH_MAX,
  DIVIDER_LENGTH_MIN,
  DIVIDER_WIDTH_MAX,
  DIVIDER_WIDTH_MIN
} from '../data/ThemeCardStyle';

@Component
export struct ThemeSettingsPage {
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 当前全局 themeMode（`"0"` 跟随系统 / `"1"` 亮色 / `"2"` 暗色），由 Index 传入。 */
  @Prop themeMode: string = '0';
  /** 当前调色板序号，由 Index 传入。 */
  @Prop paletteIndex: number = 0;
  /** 用户选了深色模式三选项之一，参数是三值字符串。 */
  onThemeModeChange: (themeMode: string) => void = (_themeMode: string) => {};
  /** 用户选了调色板，参数是序号 0..4。 */
  onPaletteChange: (paletteIndex: number) => void = (_paletteIndex: number) => {};
  /** 全局字体缩放 8..16（10 = 1.0x），对齐上游 `AppShellSettings.kt:5 fontScale`。 */
  @Prop fontScale: number = 10;
  /** 是否显示状态栏，对齐上游 `AppShellSettings.kt:10 showStatusBar`。 */
  @Prop showStatusBarVisible: boolean = true;
  /** 是否启用滑动时动画，对齐上游 `AppShellSettings.kt:11 swipeAnimation`。 */
  @Prop swipeAnimationEnabled: boolean = true;
  /** 字体大小滑块回调。 */
  onFontScaleChange: (fontScale: number) => void = (_fontScale: number) => {};
  /** 显示状态栏开关回调。 */
  onShowStatusBarChange: (visible: boolean) => void = (_visible: boolean) => {};
  /** 滑动动画开关回调。 */
  onSwipeAnimationChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  /** 书籍详情页界面颜色是否跟随封面取色，对齐上游 `ThemeSettings.bookInfoFollowCoverColor`。 */
  @Prop bookInfoFollowCoverColor: boolean = true;
  /** 网络封面背景模式 `off`/`on`/`off_for_default`。 */
  @Prop bookInfoNetworkCoverBackground: string = 'on';
  /** 默认封面背景模式。 */
  @Prop bookInfoDefaultCoverBackground: string = 'on';
  onBookInfoFollowCoverColorChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  /** 封面背景下拉回调，`isDefaultCover` 区分「网络封面」与「默认封面」两行。 */
  onBookInfoCoverBackgroundChange: (isDefaultCover: boolean, value: string) => void =
    (_isDefaultCover: boolean, _value: string) => {};
  /** 容器底色不透明度 0..100，对齐上游 `ThemeSettings.kt:24 containerOpacity`。 */
  @Prop containerOpacity: number = CONTAINER_OPACITY_MAX;
  /** 关闭设置分组圆角，对齐上游 `disableSplicedColumnGroupCornerRadius`。 */
  @Prop disableGroupCorner: boolean = false;
  /** 覆盖卡片圆角总开关，对齐上游 `overrideBaseCardCornerRadius`。 */
  @Prop overrideCardCorner: boolean = false;
  /** 卡片圆角数值 0..40，对齐上游 `baseCardCornerRadius`。 */
  @Prop cardCornerRadius: number = 16;
  /** 覆盖卡片边框总开关，对齐上游 `overrideBaseCardBorder`。 */
  @Prop overrideCardBorder: boolean = false;
  /** 边框宽度 0..5，对齐上游 `baseCardBorderWidth`。 */
  @Prop cardBorderWidth: number = 1;
  /** 日间边框色 `#RRGGBB`，空串表示未设置。 */
  @Prop cardBorderColorDay: string = '';
  /** 夜间边框色 `#RRGGBB`，空串表示未设置。 */
  @Prop cardBorderColorNight: string = '';
  /** 显示分隔线，对齐上游 `ThemeSettings.kt:63 enableItemDivider`。 */
  @Prop enableItemDivider: boolean = false;
  /** 分隔线宽度 0..5，对齐上游 `itemDividerWidth`。 */
  @Prop dividerWidth: number = 1;
  /** 分隔线长度 30..100（百分比），对齐上游 `itemDividerLength`。 */
  @Prop dividerLength: number = 80;
  /** 分隔线颜色 `#RRGGBB`，空串表示未设置。 */
  @Prop dividerColor: string = '';
  /** 容器背景图总开关，对齐上游 `enableContainerBackgroundImage`。 */
  @Prop enableContainerBackgroundImage: boolean = false;
  /** 大容器日间/夜间背景图路径，空串表示未选择。 */
  @Prop largeContainerBackgroundLight: string = '';
  @Prop largeContainerBackgroundDark: string = '';
  /** 项目日间/夜间背景图路径。 */
  @Prop itemBackgroundLight: string = '';
  @Prop itemBackgroundDark: string = '';
  onContainerOpacityChange: (value: number) => void = (_value: number) => {};
  onDisableGroupCornerChange: (value: boolean) => void = (_value: boolean) => {};
  onOverrideCardCornerChange: (value: boolean) => void = (_value: boolean) => {};
  onCardCornerRadiusChange: (value: number) => void = (_value: number) => {};
  onOverrideCardBorderChange: (value: boolean) => void = (_value: boolean) => {};
  onCardBorderWidthChange: (value: number) => void = (_value: number) => {};
  /** 边框颜色回调，`isNight` 区分日间/夜间两行。 */
  onCardBorderColorChange: (isNight: boolean, value: string) => void =
    (_isNight: boolean, _value: string) => {};
  /** 恢复默认主题配置回调（上游 `ThemeConfigIntent.ResetDefaults`）。 */
  onResetDefaults: () => void = () => {};
  /** 显示分隔线开关回调。 */
  onEnableItemDividerChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  /** 分隔线宽度回调。 */
  onDividerWidthChange: (value: number) => void = (_value: number) => {};
  /** 分隔线长度回调。 */
  onDividerLengthChange: (value: number) => void = (_value: number) => {};
  /** 分隔线颜色回调。 */
  onDividerColorChange: (value: string) => void = (_value: string) => {};
  /** 容器背景图总开关回调。 */
  onEnableContainerBackgroundImageChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  /** 选背景图回调，`isLarge` 区分大容器/项目，`isNight` 区分夜间/日间。 */
  onPickContainerBackground: (isLarge: boolean, isNight: boolean) => void =
    (_isLarge: boolean, _isNight: boolean) => {};
  /** 纯黑深色模式，对齐上游 `ThemeSettings.kt:6 isPureBlack`（默认 false）。 */
  @Prop pureBlack: boolean = false;
  /** 纯黑深色模式开关回调。 */
  onPureBlackChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  /** 护眼模式总开关，与阅读设置页共用同一份全局状态。 */
  @Prop eyeProtectionEnabled: boolean = false;
  /** 深色模式时自动开启护眼。 */
  @Prop eyeProtectionAutoNight: boolean = false;
  /** 护眼是否按时间段生效。 */
  @Prop eyeProtectionSchedule: boolean = false;
  /** 护眼强度 0..100，对齐上游 `colorTemperature`。 */
  @Prop eyeProtectionIntensity: number = 50;
  /** 定时开始时间 `HH:mm`。 */
  @Prop eyeProtectionStartTime: string = '22:00';
  /** 定时结束时间 `HH:mm`。 */
  @Prop eyeProtectionEndTime: string = '07:00';
  /** 护眼当前是否正在生效，用于色温行显示实际值。 */
  @Prop eyeProtectionActive: boolean = false;
  onEyeProtectionEnabledChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onEyeProtectionAutoNightChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onEyeProtectionScheduleChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onEyeProtectionIntensityChange: (intensity: number) => void = (_intensity: number) => {};
  onEyeProtectionStartTimeChange: (time: string) => void = (_time: string) => {};
  onEyeProtectionEndTimeChange: (time: string) => void = (_time: string) => {};
  @State showRefactorTip: boolean = true;
  @State predictiveBack: boolean = true;
  @State sharedElement: boolean = true;
  @State followCoverColor: boolean = true;
  @State blurEnabled: boolean = false;
  @State progressiveBlurEnabled: boolean = false;
  @State collapsedHeader: boolean = false;
  private themeScroller: Scroller = new Scroller();

  private updateHeader(): void {
    const offset = this.themeScroller.currentOffset().yOffset;
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      animateTo({ duration: 220, curve: Curve.EaseInOut }, () => this.collapsedHeader = shouldCollapse);
    }
  }

  private paletteColor(index: number): string {
    if (index === 0) { return '#B9C8FF'; }
    if (index === 1) { return '#A6D28A'; }
    if (index === 2) { return '#F4D45E'; }
    if (index === 3) { return '#B7B8BC'; }
    return '#85B7FF';
  }

  private paletteDarkColor(index: number): string {
    if (index === 0) { return '#5C637F'; }
    if (index === 1) { return '#315449'; }
    if (index === 2) { return '#665C32'; }
    if (index === 3) { return '#55565A'; }
    return '#385C8A';
  }

  /** 封面背景模式的中文文案，对齐上游 `values-zh-rCN/strings.xml:1751-1753`。 */
  private coverBackgroundOptions(): string[] {
    return [BOOK_INFO_BACKGROUND_ON, BOOK_INFO_BACKGROUND_OFF, BOOK_INFO_BACKGROUND_OFF_FOR_DEFAULT];
  }

  /** 护眼定时的起止时间选择，对齐阅读设置页同名能力。 */
  private pickEyeProtectionTime(isStart: boolean): void {
    const current = isStart ? this.eyeProtectionStartTime : this.eyeProtectionEndTime;
    const parts: string[] = current.split(':');
    const selected: Date = new Date();
    selected.setHours(Number(parts[0]), Number(parts[1]), 0, 0);
    this.getUIContext().showTimePickerDialog({
      selected: selected,
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult): void => {
        const hourText = value.hour < 10 ? `0${value.hour}` : `${value.hour}`;
        const minuteText = value.minute < 10 ? `0${value.minute}` : `${value.minute}`;
        const time = `${hourText}:${minuteText}`;
        if (isStart) {
          this.onEyeProtectionStartTimeChange(time);
        } else {
          this.onEyeProtectionEndTimeChange(time);
        }
      }
    });
  }

  /**
   * 边框颜色候选。
   *
   * 上游用 `ColorPickerSheet`（`ui/widget/components/dialog/ColorPickerSheet.kt:51`）：
   * 取色盘 + hex 输入 + 「重置」（置透明）。本地没有取色盘组件，用下拉给一组预设色 + 「默认描边色」，
   * 语义对齐「重置回未设置」——空串即上游的 `baseCardBorderColor = 0`。
   */
  private cardBorderColorOptions(): string[] {
    return ['', '#3F5BD9', '#AFC2FF', '#92949E', '#6A6D77', '#F4D45E', '#A6D28A'];
  }

  /**
   * 背景图选择行的摘要文案。
   *
   * 上游 `ThemeConfigScreen.kt:545`/`:564` 在两个路径都空时显示 `select_image`（「选择图片」），
   * 否则显示 `selected`（「已选择」）。本地把「日/夜各选没选」直接摊开，比「已选择」更好用。
   */
  private backgroundSummary(light: string, dark: string): string {
    const hasLight = light.length > 0;
    const hasDark = dark.length > 0;
    if (!hasLight && !hasDark) { return '选择图片'; }
    if (hasLight && hasDark) { return '日间/夜间已选择'; }
    return hasLight ? '已选日间，点击换图' : '已选夜间，点击换图';
  }

  /** 分隔线颜色候选，与边框色同一组预设；空串即上游 `itemDividerColor = 0` 的「默认灰」。 */
  private dividerColorOptions(): string[] {
    return ['', '#3F5BD9', '#AFC2FF', '#92949E', '#6A6D77', '#F4D45E', '#A6D28A'];
  }

  /**
   * 恢复默认主题配置的二次确认。
   *
   * 上游 `ThemeConfigScreen.kt:752` 弹 `AppAlertDialog`，文案取
   * `theme_config_reset_defaults` / `theme_config_reset_defaults_confirm`（`values-zh-rCN/strings.xml:1776-1778`）。
   */
  private confirmResetDefaults(): void {
    this.getUIContext().showAlertDialog({
      title: '恢复默认主题配置',
      message: '将恢复外观页中的主题、界面布局、背景图片、应用字体和导航图标等配置。已保存的主题、封面图集和书籍封面不会被删除。',
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '恢复',
        fontColor: $r('app.color.theme_accent'),
        action: () => this.onResetDefaults()
      }
    });
  }

  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  @StorageProp('themeCardBorderWidth') themeCardBorderWidth: number = 0;
  @StorageProp('themeCardBorderColor') themeCardBorderColor: string = '#6A6D77';
  @StorageProp('themeCardBackground') themeCardBackground: string = '';
  @StorageProp('themeContainerBackground') themeContainerBackground: string = '';
  build() {
    Column() {
      Column() {
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            Image($r('app.media.reader_back')).width(20).height(20).fillColor($r('app.color.theme_text_secondary'))
          }.width(40).height(40).onClick(() => this.onBack())
          Text('外观').fontSize(22).fontWeight(FontWeight.Medium).fontColor($r('app.color.theme_text_primary'))
            .opacity(this.collapsedHeader ? 1 : 0)
          Blank()
        }.width('100%').height(64).padding({ left: 12, right: 16 })
        Text('外观').fontSize(28).fontWeight(FontWeight.Medium).fontColor($r('app.color.theme_text_primary'))
          .width('100%').height(72).padding({ left: 16, bottom: 14 })
          .opacity(this.collapsedHeader ? 0 : 1)
      }.width('100%').height(this.collapsedHeader ? 64 : 136).clip(true)

      Scroll(this.themeScroller) {
        Column() {
          Column() {
            Column() {
              Row().width(54).height(12).backgroundColor('#AEB0B8').borderRadius(6)
              Column() {
                Row().width(30).height(5).backgroundColor($r('app.color.theme_accent')).borderRadius(3)
                Row().width(42).height(7).backgroundColor($r('app.color.theme_text_secondary')).borderRadius(4).margin({ top: 8 })
                Row().width(34).height(6).backgroundColor('#858792').borderRadius(3).margin({ top: 5 })
              }.width(62).height(95).padding(9).margin({ top: 8 }).backgroundColor('#454B62').borderRadius(8)
                .alignItems(HorizontalAlign.Start)
            }.width('100%').alignItems(HorizontalAlign.Start)
            Blank().layoutWeight(1)
            Row() {
              Row().width(28).height(8).backgroundColor(this.paletteColor(this.paletteIndex)).borderRadius(5)
              Blank()
              Row().width(14).height(14).backgroundColor(this.paletteColor(this.paletteIndex)).borderRadius(7)
            }.width('100%').padding({ left: 8, right: 8, top: 10, bottom: 10 })
              .backgroundColor(this.themePureBlack ? '#121212' : $r('app.color.theme_surface_elevated')).borderRadius(10)
          }.width(112).height(224).padding(10).backgroundColor(this.themePureBlack ? '#000000' : $r('app.color.theme_surface_primary')).borderRadius(22)
            .border({ width: 1, color: $r('app.color.theme_accent') })
            .alignSelf(ItemAlign.Center).margin({ top: 18, bottom: 16 })

          if (this.showRefactorTip) {
            Row() {
              Text('仍有部分界面未用Compose重构，这些界面会与大部分界面有较大差异。')
                .fontSize(14).fontColor($r('app.color.theme_text_secondary')).layoutWeight(1)
              AppGlyph({ name: 'profileClose', glyphSize: 18, tint: '#C5C7D0' })
                .onClick(() => this.showRefactorTip = false)
            }.width('calc(100% - 32vp)').padding(16).margin({ bottom: 24 })
              .backgroundColor(this.themePureBlack ? '#121212' : $r('app.color.theme_surface_elevated')).borderRadius(16)
              .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
          }

          ThemeSectionTitle({ title: '主题模式' })
          Row() {
            ThemeModeItem({ title: '跟随系统', selected: this.themeMode === '0', first: true,
              onSelect: () => this.onThemeModeChange('0') })
            ThemeModeItem({ title: '浅色', selected: this.themeMode === '1',
              onSelect: () => this.onThemeModeChange('1') })
            ThemeModeItem({ title: '深色', selected: this.themeMode === '2', last: true,
              onSelect: () => this.onThemeModeChange('2') })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16, bottom: 18 })
            .backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : $r('app.color.theme_surface_secondary')).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          Row() {
            ForEach([0, 1, 2, 3, 4], (index: number) => {
              ThemePaletteItem({
                index: index,
                title: index === 0 ? '动态取色' : (index === 1 ? '草野' : (index === 2 ? '柠檬' : (index === 3 ? '黑白' : '晴空'))),
                lightColor: this.paletteColor(index),
                darkColor: this.paletteDarkColor(index),
                selected: this.paletteIndex === index,
                onSelect: () => this.onPaletteChange(index)
              })
            }, (index: number) => index.toString())
          }.width('100%').padding({ left: 16, right: 16, bottom: 20 })

          Column() {
            Row() {
              Column() {
                Text('纯黑深色模式').fontSize(16).fontColor($r('app.color.theme_text_secondary'))
                Text('使用纯黑阅读背景').fontSize(13).fontColor($r('app.color.theme_text_tertiary')).margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.pureBlack })
                .onChange((enabled: boolean) => this.onPureBlackChange(enabled))
            }.padding({ left: 16, right: 16, top: 14, bottom: 14 })
            ThemeItemDivider()
            ThemeSettingsOption({ title: '字体设置', detail: '', onSelect: () => this.onUnavailableAction('字体设置尚未迁移') })
            ThemeItemDivider()
            ThemeSettingsOption({ title: '主题风格', detail: 'Material Design', onSelect: () => this.onUnavailableAction('主题风格切换尚未接入') })
            ThemeItemDivider()
            ThemeSettingsOption({ title: '切换图标', detail: '切换软件显示在桌面的图标', onSelect: () => this.onUnavailableAction('启动图标设置尚未迁移') })
            ThemeItemDivider()
            ThemeSwitchRow({ title: '预见性返回手势', detail: '启用系统预见性返回手势', checked: this.predictiveBack, onChange: (value: boolean) => { this.predictiveBack = value; this.onUnavailableAction('预见性返回设置暂未保存') } })
            ThemeItemDivider()
            ThemeSwitchRow({ title: '阅读界面共享元素动画', detail: '进入阅读界面时从封面展开，关闭后使用渐变过渡', checked: this.sharedElement, onChange: (value: boolean) => { this.sharedElement = value; this.onUnavailableAction('共享元素动画设置暂未保存') } })
            ThemeItemDivider()
            Column() {
              Row() {
                Text('字体大小').fontSize(16).fontColor($r('app.color.theme_text_secondary')).layoutWeight(1)
                Text(`${(this.fontScale / 10).toFixed(1)}x`).fontSize(14).fontColor($r('app.color.theme_text_tertiary'))
              }.width('100%')
              Slider({ value: this.fontScale, min: 8, max: 16, step: 1, style: SliderStyle.OutSet })
                .width('100%').onChange((value: number) => this.onFontScaleChange(value))
            }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 8 })
            ThemeItemDivider()
            ThemeSettingsOption({ title: '主题管理', detail: '管理、导入导出完整主题包', onSelect: () => this.onUnavailableAction('主题包管理尚未迁移') })
            ThemeItemDivider()
            ThemeSettingsOption({ title: '背景图片', detail: '日间/夜间背景图与背景虚化', onSelect: () => this.onUnavailableAction('背景图片设置尚未迁移') })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : $r('app.color.theme_surface_secondary')).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          ThemeSectionTitle({ title: '主界面' }).margin({ top: 20 })
          Column() {
            ThemeSettingsOption({ title: '首页与导航', detail: '配置首页、发现、订阅、默认主页面和导航栏图标', onSelect: () => this.onUnavailableAction('首页与导航设置尚未迁移') })
            ThemeItemDivider()
            ThemeSwitchRow({ title: '显示状态栏', checked: this.showStatusBarVisible, onChange: (value: boolean) => this.onShowStatusBarChange(value) })
            ThemeItemDivider()
            ThemeSwitchRow({ title: '启用滑动时动画', checked: this.swipeAnimationEnabled, onChange: (value: boolean) => this.onSwipeAnimationChange(value) })
            ThemeItemDivider()
            ThemeSettingsOption({ title: '顶栏与底栏', detail: '配置顶栏按钮与底部导航栏', onSelect: () => this.onUnavailableAction('顶栏与底栏设置尚未迁移') })
            ThemeItemDivider()
            ThemeSettingsOption({ title: '导航布局', detail: '', onSelect: () => this.onUnavailableAction('导航布局设置尚未迁移') })
            ThemeItemDivider()
            ThemeSettingsOption({ title: '多窗布局', detail: '', onSelect: () => this.onUnavailableAction('多窗布局设置尚未迁移') })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : $r('app.color.theme_surface_secondary')).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          ThemeSectionTitle({ title: '书籍详情页' }).margin({ top: 20 })
          Column() {
            ThemeSwitchRow({ title: '界面颜色跟随封面取色', detail: '仅在显示背景封面时生效', checked: this.bookInfoFollowCoverColor, onChange: (value: boolean) => this.onBookInfoFollowCoverColorChange(value) })
            ThemeItemDivider()
            ThemeSettingsDropdown({ title: '网络封面背景设置', value: this.bookInfoNetworkCoverBackground, options: this.coverBackgroundOptions(), onSelect: (value: string) => this.onBookInfoCoverBackgroundChange(false, value) })
            ThemeItemDivider()
            ThemeSettingsDropdown({ title: '默认封面背景设置', value: this.bookInfoDefaultCoverBackground, options: this.coverBackgroundOptions(), onSelect: (value: string) => this.onBookInfoCoverBackgroundChange(true, value) })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : $r('app.color.theme_surface_secondary')).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          ThemeSectionTitle({ title: '护眼模式' }).margin({ top: 20 })
          Column() {
            ThemeSwitchRow({ title: '启用护眼模式', detail: '使用暖色调降低蓝光', checked: this.eyeProtectionEnabled, onChange: (value: boolean) => this.onEyeProtectionEnabledChange(value) })
            ThemeItemDivider()
            ThemeSwitchRow({ title: '深色模式时自动开启', detail: '跟随阅读界面的深色/浅色模式自动切换', checked: this.eyeProtectionAutoNight, onChange: (value: boolean) => this.onEyeProtectionAutoNightChange(value) })
            ThemeItemDivider()
            if (this.eyeProtectionEnabled || this.eyeProtectionAutoNight) {
              ThemeSettingsSlider({
                title: '色温',
                detail: this.eyeProtectionActive ? `当前生效：${this.eyeProtectionIntensity}` : `强度 ${this.eyeProtectionIntensity}`,
                value: this.eyeProtectionIntensity,
                minValue: 0,
                maxValue: 100,
                onChange: (value: number) => this.onEyeProtectionIntensityChange(value)
              })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              ThemeSwitchRow({ title: '定时开启', detail: '仅在设定的时间段内生效', checked: this.eyeProtectionSchedule, onChange: (value: boolean) => this.onEyeProtectionScheduleChange(value) })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              if (this.eyeProtectionSchedule) {
                ThemeSettingsOption({ title: '开始时间', detail: this.eyeProtectionStartTime, onSelect: () => this.pickEyeProtectionTime(true) })
                  .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
                ThemeSettingsOption({ title: '结束时间', detail: this.eyeProtectionEndTime, onSelect: () => this.pickEyeProtectionTime(false) })
                  .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              }
            }
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : $r('app.color.theme_surface_secondary')).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          ThemeSectionTitle({ title: '模糊效果' }).margin({ top: 20 })
          Column() {
            ThemeSwitchRow({ title: '启用控件模糊', checked: this.blurEnabled, onChange: (value: boolean) => { this.blurEnabled = value; this.onUnavailableAction('模糊效果设置暂未保存') } })
            ThemeItemDivider()
            if (this.blurEnabled) {
              ThemeSwitchRow({ title: '启用渐变模糊', checked: this.progressiveBlurEnabled, onChange: (value: boolean) => { this.progressiveBlurEnabled = value; this.onUnavailableAction('渐变模糊设置暂未保存') } })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : $r('app.color.theme_surface_secondary')).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          ThemeSectionTitle({ title: '容器设置' }).margin({ top: 20 })
          Column() {
            ThemeSwitchRow({ title: '容器背景图', detail: '大容器和项目分别使用独立的日间/夜间图片', checked: this.enableContainerBackgroundImage, onChange: (value: boolean) => this.onEnableContainerBackgroundImageChange(value) })
            ThemeItemDivider()
            if (this.enableContainerBackgroundImage) {
              ThemeSettingsOption({ title: '大容器背景图片', detail: this.backgroundSummary(this.largeContainerBackgroundLight, this.largeContainerBackgroundDark), onSelect: () => this.onPickContainerBackground(true, false) })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              ThemeItemDivider()
              ThemeSettingsOption({ title: '项目背景图片', detail: this.backgroundSummary(this.itemBackgroundLight, this.itemBackgroundDark), onSelect: () => this.onPickContainerBackground(false, false) })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
            ThemeItemDivider()
            ThemeSettingsSlider({
              title: '容器背景不透明度',
              detail: `${this.containerOpacity}%`,
              value: this.containerOpacity,
              minValue: CONTAINER_OPACITY_MIN,
              maxValue: CONTAINER_OPACITY_MAX,
              onChange: (value: number) => this.onContainerOpacityChange(value)
            })
            ThemeItemDivider()
            ThemeSwitchRow({ title: '关闭设置分组圆角', detail: '让设置分组使用直角外轮廓', checked: this.disableGroupCorner, onChange: (value: boolean) => this.onDisableGroupCornerChange(value) })
            ThemeItemDivider()
            ThemeSwitchRow({ title: '覆盖卡片圆角', detail: '关闭时保留各卡片的默认值', checked: this.overrideCardCorner, onChange: (value: boolean) => this.onOverrideCardCornerChange(value) })
            ThemeItemDivider()
            if (this.overrideCardCorner) {
              ThemeSettingsSlider({
                title: '卡片圆角',
                detail: `${this.cardCornerRadius}vp`,
                value: this.cardCornerRadius,
                minValue: CARD_RADIUS_MIN,
                maxValue: CARD_RADIUS_MAX,
                onChange: (value: number) => this.onCardCornerRadiusChange(value)
              })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
            ThemeItemDivider()
            ThemeSwitchRow({ title: '覆盖卡片边框', detail: '关闭时保留各卡片的默认值', checked: this.overrideCardBorder, onChange: (value: boolean) => this.onOverrideCardBorderChange(value) })
            ThemeItemDivider()
            if (this.overrideCardBorder) {
              ThemeSettingsSlider({
                title: '边框宽度',
                detail: `${this.cardBorderWidth}vp`,
                value: this.cardBorderWidth,
                minValue: CARD_BORDER_WIDTH_MIN,
                maxValue: CARD_BORDER_WIDTH_MAX,
                onChange: (value: number) => this.onCardBorderWidthChange(value)
              })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              ThemeSettingsDropdown({
                title: '日间边框颜色',
                value: this.cardBorderColorDay,
                options: this.cardBorderColorOptions(),
                onSelect: (value: string) => this.onCardBorderColorChange(false, value)
              })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              ThemeSettingsDropdown({
                title: '夜间边框颜色',
                value: this.cardBorderColorNight,
                options: this.cardBorderColorOptions(),
                onSelect: (value: string) => this.onCardBorderColorChange(true, value)
              })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
            ThemeItemDivider()
            ThemeSwitchRow({ title: '显示分隔线', checked: this.enableItemDivider, onChange: (value: boolean) => this.onEnableItemDividerChange(value) })
            ThemeItemDivider()
            if (this.enableItemDivider) {
              ThemeSettingsSlider({
                title: '分隔线宽度', detail: `${this.dividerWidth}vp`,
                value: this.dividerWidth, minValue: DIVIDER_WIDTH_MIN, maxValue: DIVIDER_WIDTH_MAX,
                onChange: (value: number) => this.onDividerWidthChange(value)
              })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              ThemeSettingsSlider({
                title: '分隔线长度', detail: `${this.dividerLength}%`,
                value: this.dividerLength, minValue: DIVIDER_LENGTH_MIN, maxValue: DIVIDER_LENGTH_MAX,
                onChange: (value: number) => this.onDividerLengthChange(value)
              })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              ThemeSettingsDropdown({
                title: '分隔线颜色',
                value: this.dividerColor,
                options: this.dividerColorOptions(),
                onSelect: (value: string) => this.onDividerColorChange(value)
              })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : $r('app.color.theme_surface_secondary')).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
          Column() {
            ThemeSettingsOption({ title: '恢复默认主题配置', detail: '恢复外观页设置，不影响已保存主题和封面', onSelect: () => this.confirmResetDefaults() })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16, top: 20 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : $r('app.color.theme_surface_secondary')).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
        }.width('100%').padding({ top: 4, bottom: 18 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themePureBlack ? '#000000' : $r('app.color.theme_surface_primary'))
  }
}

@Component
struct ThemeSectionTitle {
  @Prop title: string = '';
  build() {
    Text(this.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.theme_accent'))
      .alignSelf(ItemAlign.Start).margin({ left: 18, bottom: 9 })
  }
}

@Component
struct ThemeModeItem {
  @Prop title: string = '';
  @Prop selected: boolean = false;
  @Prop first: boolean = false;
  @Prop last: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Text(this.title).fontSize(14).fontColor(this.selected ? '#F0F1F5' : '#AEB0B9')
      .textAlign(TextAlign.Center).layoutWeight(1).padding({ top: 12, bottom: 12 })
      .backgroundColor(this.selected ? '#454B62' : Color.Transparent)
      .borderRadius({ topLeft: this.first ? 14 : 0, bottomLeft: this.first ? 14 : 0,
        topRight: this.last ? 14 : 0, bottomRight: this.last ? 14 : 0 })
      .onClick(() => this.onSelect())
  }
}

@Component
struct ThemePaletteItem {
  @Prop index: number = 0;
  @Prop title: string = '';
  @Prop lightColor: string = '#B9C8FF';
  @Prop darkColor: string = '#5C637F';
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Row() {
          Column().layoutWeight(1).height(42).backgroundColor(this.lightColor)
          Column().layoutWeight(1).height(42).backgroundColor(this.darkColor)
        }.width(42).height(42).borderRadius(21)
        Column().width(20).height(20).backgroundColor(this.lightColor).borderRadius(10)
        if (this.selected) {
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'profileCheck', glyphSize: 18, tint: '#20212A' })
          }.width(34).height(34).backgroundColor($r('app.color.theme_accent')).borderRadius(17)
        }
      }.width(56).height(56).backgroundColor($r('app.color.theme_surface_secondary')).borderRadius(14)
        .border({ width: this.selected ? 2 : 0, color: $r('app.color.theme_accent') }).onClick(() => this.onSelect())
      Text(this.title).fontSize(11).fontColor(this.selected ? $r('app.color.theme_accent') : '#C5C7D0')
        .textAlign(TextAlign.Center).margin({ top: 8 })
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }
}

@Component
struct ThemeSettingsOption {
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(16).fontColor($r('app.color.theme_text_secondary'))
        if (this.detail.length > 0) {
          Text(this.detail).fontSize(12).fontColor($r('app.color.theme_text_tertiary')).margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(16).height(16).fillColor($r('app.color.theme_text_tertiary'))
    }.padding({ left: 16, right: 16, top: 14, bottom: 14 }).onClick(() => this.onSelect())
  }
}

@Component
struct ThemeSwitchRow {
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop checked: boolean = false;
  onChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(16).fontColor($r('app.color.theme_text_secondary'))
        if (this.detail.length > 0) {
          Text(this.detail).fontSize(12).fontColor($r('app.color.theme_text_tertiary')).margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .onChange((enabled: boolean) => this.onChange(enabled))
    }.padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}

/** 下拉行，对齐上游 `DropdownListSettingItem`：点开菜单选一项。 */
@Component
struct ThemeSettingsDropdown {
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop options: string[] = [];
  onSelect: (value: string) => void = (_value: string) => {};

  /**
   * 取值转显示文案。
   *
   * 封面背景三档对齐上游 `values-zh-rCN/strings.xml:1751-1753`；
   * 边框色两档（A41/A42）是颜色串，空串对应上游 `baseCardBorderColor = 0` 的「未设置」。
   */
  private label(value: string): string {
    if (value.length === 0) { return '默认描边色'; }
    if (value.startsWith('#')) { return value; }
    if (value === BOOK_INFO_BACKGROUND_OFF) { return '关闭模糊封面'; }
    if (value === BOOK_INFO_BACKGROUND_OFF_FOR_DEFAULT) { return '不显示背景封面'; }
    return '开启模糊封面';
  }

  @Builder
  private OptionMenu() {
    Menu() {
      ForEach(this.options, (option: string) => {
        MenuItem({ content: this.label(option) }).height(48).onClick(() => this.onSelect(option))
      }, (option: string) => option)
    }.backgroundColor(this.themePureBlack ? '#121212' : $r('app.color.theme_surface_elevated')).fontColor($r('app.color.theme_text_primary')).radius(16)
  }

  build() {
    Row() {
      Text(this.title).fontSize(16).fontColor($r('app.color.theme_text_secondary')).layoutWeight(1)
      Text(this.label(this.value)).fontSize(14).fontColor($r('app.color.theme_accent'))
      Image($r('app.media.reader_next')).width(16).height(16).fillColor($r('app.color.theme_text_tertiary'))
        .margin({ left: 4 })
    }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .bindMenu(this.OptionMenu, { placement: Placement.Bottom })
  }
}

/** 带数值的滑杆行，用于色温等连续参数；对齐上游 `SliderSettingItem`。 */
@Component
struct ThemeSettingsSlider {
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop value: number = 0;
  @Prop minValue: number = 0;
  @Prop maxValue: number = 100;
  onChange: (value: number) => void = (_value: number) => {};
  build() {
    Column() {
      Row() {
        Text(this.title).fontSize(16).fontColor($r('app.color.theme_text_secondary'))
        Blank()
        // 有 detail 时数值只显示在下方说明里，避免「3」与「3vp」重复
        if (this.detail.length === 0) {
          Text(`${this.value}`).fontSize(12).fontColor($r('app.color.theme_accent'))
        }
      }.width('100%')
      Slider({ value: this.value, min: this.minValue, max: this.maxValue, step: 1, style: SliderStyle.OutSet })
        .width('100%')
        .selectedColor($r('app.color.theme_accent'))
        .trackColor($r('app.color.theme_surface_tertiary'))
        .onChange((value: number) => this.onChange(Math.round(value)))
      if (this.detail.length > 0) {
        Text(this.detail).fontSize(12).fontColor($r('app.color.theme_text_tertiary')).margin({ top: 3 })
      }
    }.alignItems(HorizontalAlign.Start).width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}
