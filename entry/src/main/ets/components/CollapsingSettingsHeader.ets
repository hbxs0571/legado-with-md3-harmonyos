@Component
export struct CollapsingSettingsHeader {
  @Prop title: string = '';
  @Prop collapsed: boolean = false;
  onBack: () => void = () => {};

  build() {
    Column() {
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
          .width(40).height(40).onClick(() => this.onBack())
        Text(this.title).fontSize(22).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
          .opacity(this.collapsed ? 1 : 0)
        Blank()
      }.width('100%').height(64).padding({ left: 12, right: 16 })
      Text(this.title).fontSize(28).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
        .width('100%').height(72).padding({ left: 16, bottom: 14 })
        .opacity(this.collapsed ? 0 : 1)
    }.width('100%').height(this.collapsed ? 64 : 136).clip(true).backgroundColor('#111217')
  }
}
