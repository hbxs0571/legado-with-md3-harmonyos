import { AppGlyph } from '../components/AppGlyph';
import {
  BOOK_INFO_BACKGROUND_OFF,
  BOOK_INFO_BACKGROUND_OFF_FOR_DEFAULT,
  BOOK_INFO_BACKGROUND_ON
} from '../data/ThemeSettingsRepository';

@Component
export struct ThemeSettingsPage {
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
  @State pureBlack: boolean = false;
  @State showRefactorTip: boolean = true;
  @State predictiveBack: boolean = true;
  @State sharedElement: boolean = true;
  @State followCoverColor: boolean = true;
  @State blurEnabled: boolean = false;
  @State progressiveBlurEnabled: boolean = false;
  @State containerBackgroundEnabled: boolean = false;
  @State disableGroupCorner: boolean = false;
  @State overrideCardCorner: boolean = false;
  @State overrideCardBorder: boolean = false;
  @State dividerEnabled: boolean = false;
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
              .backgroundColor($r('app.color.theme_surface_elevated')).borderRadius(10)
          }.width(112).height(224).padding(10).backgroundColor($r('app.color.theme_surface_primary')).borderRadius(22)
            .border({ width: 1, color: $r('app.color.theme_accent') })
            .alignSelf(ItemAlign.Center).margin({ top: 18, bottom: 16 })

          if (this.showRefactorTip) {
            Row() {
              Text('仍有部分界面未用Compose重构，这些界面会与大部分界面有较大差异。')
                .fontSize(14).fontColor($r('app.color.theme_text_secondary')).layoutWeight(1)
              AppGlyph({ name: 'profileClose', glyphSize: 18, tint: '#C5C7D0' })
                .onClick(() => this.showRefactorTip = false)
            }.width('calc(100% - 32vp)').padding(16).margin({ bottom: 24 })
              .backgroundColor($r('app.color.theme_surface_elevated')).borderRadius(16)
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
            .backgroundColor($r('app.color.theme_surface_secondary')).borderRadius(16)

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
                .onChange((enabled: boolean) => this.pureBlack = enabled)
            }.padding({ left: 16, right: 16, top: 14, bottom: 14 })
            ThemeSettingsOption({ title: '字体设置', detail: '', onSelect: () => this.onUnavailableAction('字体设置尚未迁移') })
            ThemeSettingsOption({ title: '主题风格', detail: 'Material Design', onSelect: () => this.onUnavailableAction('主题风格切换尚未接入') })
            ThemeSettingsOption({ title: '切换图标', detail: '切换软件显示在桌面的图标', onSelect: () => this.onUnavailableAction('启动图标设置尚未迁移') })
            ThemeSwitchRow({ title: '预见性返回手势', detail: '启用系统预见性返回手势', checked: this.predictiveBack, onChange: (value: boolean) => { this.predictiveBack = value; this.onUnavailableAction('预见性返回设置暂未保存') } })
            ThemeSwitchRow({ title: '阅读界面共享元素动画', detail: '进入阅读界面时从封面展开，关闭后使用渐变过渡', checked: this.sharedElement, onChange: (value: boolean) => { this.sharedElement = value; this.onUnavailableAction('共享元素动画设置暂未保存') } })
            Column() {
              Row() {
                Text('字体大小').fontSize(16).fontColor($r('app.color.theme_text_secondary')).layoutWeight(1)
                Text(`${(this.fontScale / 10).toFixed(1)}x`).fontSize(14).fontColor($r('app.color.theme_text_tertiary'))
              }.width('100%')
              Slider({ value: this.fontScale, min: 8, max: 16, step: 1, style: SliderStyle.OutSet })
                .width('100%').onChange((value: number) => this.onFontScaleChange(value))
            }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 8 })
            ThemeSettingsOption({ title: '主题管理', detail: '管理、导入导出完整主题包', onSelect: () => this.onUnavailableAction('主题包管理尚未迁移') })
            ThemeSettingsOption({ title: '背景图片', detail: '日间/夜间背景图与背景虚化', onSelect: () => this.onUnavailableAction('背景图片设置尚未迁移') })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor($r('app.color.theme_surface_secondary')).borderRadius(16)

          ThemeSectionTitle({ title: '主界面' }).margin({ top: 20 })
          Column() {
            ThemeSettingsOption({ title: '首页与导航', detail: '配置首页、发现、订阅、默认主页面和导航栏图标', onSelect: () => this.onUnavailableAction('首页与导航设置尚未迁移') })
            ThemeSwitchRow({ title: '显示状态栏', checked: this.showStatusBarVisible, onChange: (value: boolean) => this.onShowStatusBarChange(value) })
            ThemeSwitchRow({ title: '启用滑动时动画', checked: this.swipeAnimationEnabled, onChange: (value: boolean) => this.onSwipeAnimationChange(value) })
            ThemeSettingsOption({ title: '顶栏与底栏', detail: '配置顶栏按钮与底部导航栏', onSelect: () => this.onUnavailableAction('顶栏与底栏设置尚未迁移') })
            ThemeSettingsOption({ title: '导航布局', detail: '', onSelect: () => this.onUnavailableAction('导航布局设置尚未迁移') })
            ThemeSettingsOption({ title: '多窗布局', detail: '', onSelect: () => this.onUnavailableAction('多窗布局设置尚未迁移') })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor($r('app.color.theme_surface_secondary')).borderRadius(16)

          ThemeSectionTitle({ title: '书籍详情页' }).margin({ top: 20 })
          Column() {
            ThemeSwitchRow({ title: '界面颜色跟随封面取色', detail: '仅在显示背景封面时生效', checked: this.bookInfoFollowCoverColor, onChange: (value: boolean) => this.onBookInfoFollowCoverColorChange(value) })
            ThemeSettingsDropdown({ title: '网络封面背景设置', value: this.bookInfoNetworkCoverBackground, options: this.coverBackgroundOptions(), onSelect: (value: string) => this.onBookInfoCoverBackgroundChange(false, value) })
            ThemeSettingsDropdown({ title: '默认封面背景设置', value: this.bookInfoDefaultCoverBackground, options: this.coverBackgroundOptions(), onSelect: (value: string) => this.onBookInfoCoverBackgroundChange(true, value) })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor($r('app.color.theme_surface_secondary')).borderRadius(16)

          ThemeSectionTitle({ title: '护眼模式' }).margin({ top: 20 })
          Column() {
            ThemeSwitchRow({ title: '启用护眼模式', detail: '使用暖色调降低蓝光', checked: this.eyeProtectionEnabled, onChange: (value: boolean) => this.onEyeProtectionEnabledChange(value) })
            ThemeSwitchRow({ title: '深色模式时自动开启', detail: '跟随阅读界面的深色/浅色模式自动切换', checked: this.eyeProtectionAutoNight, onChange: (value: boolean) => this.onEyeProtectionAutoNightChange(value) })
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
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor($r('app.color.theme_surface_secondary')).borderRadius(16)

          ThemeSectionTitle({ title: '模糊效果' }).margin({ top: 20 })
          Column() {
            ThemeSwitchRow({ title: '启用控件模糊', checked: this.blurEnabled, onChange: (value: boolean) => { this.blurEnabled = value; this.onUnavailableAction('模糊效果设置暂未保存') } })
            if (this.blurEnabled) {
              ThemeSwitchRow({ title: '启用渐变模糊', checked: this.progressiveBlurEnabled, onChange: (value: boolean) => { this.progressiveBlurEnabled = value; this.onUnavailableAction('渐变模糊设置暂未保存') } })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor($r('app.color.theme_surface_secondary')).borderRadius(16)

          ThemeSectionTitle({ title: '容器设置' }).margin({ top: 20 })
          Column() {
            ThemeSwitchRow({ title: '容器背景图', detail: '大容器和项目分别使用独立的日间/夜间图片', checked: this.containerBackgroundEnabled, onChange: (value: boolean) => { this.containerBackgroundEnabled = value; this.onUnavailableAction('容器背景图片设置暂未保存') } })
            if (this.containerBackgroundEnabled) {
              ThemeSettingsOption({ title: '大容器背景图片', detail: '', onSelect: () => this.onUnavailableAction('背景图片选择尚未迁移') })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              ThemeSettingsOption({ title: '项目背景图片', detail: '', onSelect: () => this.onUnavailableAction('背景图片选择尚未迁移') })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
            ThemeSettingsOption({ title: '容器背景不透明度', detail: '', onSelect: () => this.onUnavailableAction('容器不透明度尚未迁移') })
            ThemeSwitchRow({ title: '关闭设置分组圆角', detail: '让设置分组使用直角外轮廓', checked: this.disableGroupCorner, onChange: (value: boolean) => { this.disableGroupCorner = value; this.onUnavailableAction('设置分组圆角暂未保存') } })
            ThemeSwitchRow({ title: '覆盖卡片圆角', detail: '关闭时保留各卡片的默认值', checked: this.overrideCardCorner, onChange: (value: boolean) => { this.overrideCardCorner = value; this.onUnavailableAction('卡片圆角设置暂未保存') } })
            if (this.overrideCardCorner) {
              ThemeSettingsOption({ title: '卡片圆角', detail: '', onSelect: () => this.onUnavailableAction('卡片圆角调节尚未迁移') })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
            ThemeSwitchRow({ title: '覆盖卡片边框', detail: '关闭时保留各卡片的默认值', checked: this.overrideCardBorder, onChange: (value: boolean) => { this.overrideCardBorder = value; this.onUnavailableAction('卡片边框设置暂未保存') } })
            if (this.overrideCardBorder) {
              ThemeSettingsOption({ title: '边框宽度', detail: '', onSelect: () => this.onUnavailableAction('边框宽度设置尚未迁移') })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              ThemeSettingsOption({ title: '日间边框颜色', detail: '', onSelect: () => this.onUnavailableAction('边框颜色选择尚未迁移') })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              ThemeSettingsOption({ title: '夜间边框颜色', detail: '', onSelect: () => this.onUnavailableAction('边框颜色选择尚未迁移') })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
            ThemeSwitchRow({ title: '显示分隔线', checked: this.dividerEnabled, onChange: (value: boolean) => { this.dividerEnabled = value; this.onUnavailableAction('分隔线设置暂未保存') } })
            if (this.dividerEnabled) {
              ThemeSettingsOption({ title: '分隔线宽度', detail: '', onSelect: () => this.onUnavailableAction('分隔线宽度设置尚未迁移') })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              ThemeSettingsOption({ title: '分隔线长度', detail: '', onSelect: () => this.onUnavailableAction('分隔线长度设置尚未迁移') })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
              ThemeSettingsOption({ title: '分隔线颜色', detail: '', onSelect: () => this.onUnavailableAction('分隔线颜色选择尚未迁移') })
                .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
            }
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor($r('app.color.theme_surface_secondary')).borderRadius(16)
          Column() {
            ThemeSettingsOption({ title: '恢复默认主题配置', detail: '恢复外观页设置，不影响已保存主题和封面', onSelect: () => this.onUnavailableAction('恢复默认配置尚未迁移') })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16, top: 20 }).backgroundColor($r('app.color.theme_surface_secondary')).borderRadius(16)
        }.width('100%').padding({ top: 4, bottom: 18 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor($r('app.color.theme_surface_primary'))
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
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop options: string[] = [];
  onSelect: (value: string) => void = (_value: string) => {};

  /** 取值转中文，对齐上游 `values-zh-rCN/strings.xml:1751-1753` 的三条文案。 */
  private label(value: string): string {
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
    }.backgroundColor($r('app.color.theme_surface_elevated')).fontColor($r('app.color.theme_text_primary')).radius(16)
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
        Text(`${this.value}`).fontSize(12).fontColor($r('app.color.theme_accent'))
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
