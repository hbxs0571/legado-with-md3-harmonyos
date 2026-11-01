import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';

@Component
export struct AppLabSettingsPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State labEnabled: boolean = false;
  @State eInkEnabled: boolean = false;
  @State collapsedHeader: boolean = false;
  private settingsScroller: Scroller = new Scroller();

  private updateHeader(): void {
    const offset = this.settingsScroller.currentOffset().yOffset;
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      animateTo({ duration: 220, curve: Curve.EaseInOut }, () => this.collapsedHeader = shouldCollapse);
    }
  }

  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  @StorageProp('themeCardBorderWidth') themeCardBorderWidth: number = 0;
  @StorageProp('themeCardBorderColor') themeCardBorderColor: string = '#6A6D77';
  @StorageProp('themeCardBackground') themeCardBackground: string = '';
  @StorageProp('themeContainerBackground') themeContainerBackground: string = '';
  build() {
    Column() {
      CollapsingSettingsHeader({ title: '实验室', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Scroll(this.settingsScroller) {
        Column() {
          Column() {
            LabSettingsSwitch({ title: '启用实验室', detail: '开启后显示实验性功能，可能不稳定', value: this.labEnabled, onChange: (value: boolean) => this.labEnabled = value })
          }.margin({ left: 16, right: 16, top: 12 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : $r('app.color.theme_surface_secondary')).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          if (this.labEnabled) {
            Text('显示').fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.theme_accent'))
              .alignSelf(ItemAlign.Start).padding({ left: 18, top: 14, bottom: 8 })
            Column() {
              LabSettingsSwitch({ title: '墨水屏显示', detail: '在平板界面显示墨水屏选项', value: this.eInkEnabled, onChange: (value: boolean) => this.eInkEnabled = value })
              if (this.eInkEnabled) {
                Text('可在“主题 → 显示”中调整墨水屏设置')
                  .fontSize(12).fontColor($r('app.color.theme_accent')).padding({ left: 14, right: 14, bottom: 12 })
              }
            }.margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : $r('app.color.theme_surface_secondary')).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
              .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
          }

          Text('诊断').fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.theme_accent'))
            .alignSelf(ItemAlign.Start).padding({ left: 18, top: 14, bottom: 8 })
          Row() {
            Column() {
              Text('导出全文页码诊断').fontSize(18).fontColor($r('app.color.theme_text_secondary'))
              Text('分享本机最近的估算与校正记录，不会自动上传。')
                .fontSize(15).fontColor($r('app.color.theme_text_tertiary')).margin({ top: 3 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('0 条').fontSize(12).fontColor($r('app.color.theme_accent'))
            Image($r('app.media.reader_next')).width(15).height(15).fillColor($r('app.color.theme_text_tertiary')).margin({ left: 6 })
          }.padding({ left: 14, right: 14, top: 13, bottom: 13 }).margin({ left: 16, right: 16 })
            .backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : $r('app.color.theme_surface_secondary')).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
            .onClick(() => this.onUnavailableAction('全文页码诊断导出尚未迁移'))

          Text('实验室开关仅作页面预览，不会启用实验功能或导出诊断数据。')
            .fontSize(15).fontColor('#858792').margin({ left: 18, right: 18, top: 10, bottom: 22 })
        }.width('100%').padding({ top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor($r('app.color.theme_surface_primary'))
  }
}

@Component
struct LabSettingsSwitch {
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop value: boolean = false;
  onChange: (value: boolean) => void = (_value: boolean) => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(18).fontColor($r('app.color.theme_text_secondary'))
        if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor($r('app.color.theme_text_tertiary')).margin({ top: 3 }) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.value })
        .onChange((value: boolean) => this.onChange(value))
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }
}
