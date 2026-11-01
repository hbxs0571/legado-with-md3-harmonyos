@Component
export struct CollapsingSettingsHeader {
  @Prop title: string = '';
  @Prop collapsed: boolean = false;
  onBack: () => void = () => {};

  build() {
    Column() {
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor($r('app.color.theme_text_secondary'))
          .width(40).height(40).onClick(() => this.onBack())
        Text(this.title).fontSize(22).fontWeight(FontWeight.Medium).fontColor($r('app.color.theme_text_primary'))
          .opacity(this.collapsed ? 1 : 0)
        Blank()
      }.width('100%').height(64).padding({ left: 12, right: 16 })
      Text(this.title).fontSize(28).fontWeight(FontWeight.Medium).fontColor($r('app.color.theme_text_primary'))
        .width('100%').height(72).padding({ left: 16, bottom: 14 })
        .opacity(this.collapsed ? 0 : 1)
    }.width('100%').height(this.collapsed ? 64 : 136).clip(true).backgroundColor($r('app.color.theme_surface_primary'))
  }
}
