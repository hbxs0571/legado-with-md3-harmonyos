import curves from '@ohos.curves';
import { UiSwitch } from '../components/settings/UiSwitch';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import { FONT_SECTION_TITLE, ROW_PADDING_H, SECTION_TITLE_BOTTOM, SECTION_TITLE_TOP, FONT_ROW_TITLE } from '../components/UiTokens';

@Component
export struct AppLabSettingsPage {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
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
      // 顶部折叠是位移，用弹簧收尾更自然；弹簧不吃 duration，删掉（写了也不生效）。
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
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
            UiSwitch({ title: '启用实验室', detail: '开启后显示实验性功能，可能不稳定', value: this.labEnabled, onChange: (value: boolean) => this.labEnabled = value })
          }.margin({ left: 16, right: 16, top: 12 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)

          if (this.labEnabled) {
            Text('显示').fontSize(FONT_SECTION_TITLE).fontWeight(FontWeight.Medium).fontColor(this.themeColorAccent)
              .alignSelf(ItemAlign.Start).padding({ left: ROW_PADDING_H, top: SECTION_TITLE_TOP, bottom: SECTION_TITLE_BOTTOM })
            Column() {
              UiSwitch({ title: '墨水屏显示', detail: '在平板界面显示墨水屏选项', value: this.eInkEnabled, onChange: (value: boolean) => this.eInkEnabled = value })
              if (this.eInkEnabled) {
                Text('可在“主题 → 显示”中调整墨水屏设置')
                  .fontSize(12).fontColor(this.themeColorAccent).padding({ left: 14, right: 14, bottom: 12 })
              }
            }.margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
              .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
          }

          Text('诊断').fontSize(FONT_SECTION_TITLE).fontWeight(FontWeight.Medium).fontColor(this.themeColorAccent)
            .alignSelf(ItemAlign.Start).padding({ left: ROW_PADDING_H, top: SECTION_TITLE_TOP, bottom: SECTION_TITLE_BOTTOM })
          Row() {
            Column() {
              Text('导出全文页码诊断').fontSize(FONT_ROW_TITLE).fontColor(this.themeColorTextSecondary)
              Text('分享本机最近的估算与校正记录，不会自动上传。')
                .fontSize(15).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('0 条').fontSize(12).fontColor(this.themeColorAccent)
            Image($r('app.media.reader_next')).width(15).height(15).fillColor(this.themeColorTextTertiary).margin({ left: 6 })
          }.padding({ left: 14, right: 14, top: 13, bottom: 13 }).margin({ left: 16, right: 16 })
            .backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
            .onClick(() => this.onUnavailableAction('全文页码诊断导出尚未迁移'))

          Text('实验室开关仅作页面预览，不会启用实验功能或导出诊断数据。')
            .fontSize(15).fontColor('#858792').margin({ left: 18, right: 18, top: 10, bottom: 22 })
        }.width('100%').padding({ top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}
