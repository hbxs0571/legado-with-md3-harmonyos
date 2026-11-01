@Component
export struct CollapsingSettingsHeader {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  /** 顶栏底色（含不透明度与模糊透明度），由 `Index.publishTopBottomBarStyle()` 广播。 */
  @StorageProp('themeTopBarBackground') themeTopBarBackground: string = '';
  /** 顶栏模糊半径；0 表示不模糊。 */
  @StorageProp('themeTopBarBlurRadius') themeTopBarBlurRadius: number = 0;
  @Prop title: string = '';
  @Prop collapsed: boolean = false;
  onBack: () => void = () => {};

  build() {
    Column() {
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary)
          .width(40).height(40).onClick(() => this.onBack())
        Text(this.title).fontSize(22).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
          .opacity(this.collapsed ? 1 : 0)
        Blank()
      }.width('100%').height(64).padding({ left: 12, right: 16 })
      Text(this.title).fontSize(28).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').height(72).padding({ left: 16, bottom: 14 })
        .opacity(this.collapsed ? 0 : 1)
    }.width('100%').height(this.collapsed ? 64 : 136).clip(true)
      .backgroundColor(this.themeTopBarBackground.length > 0 ? this.themeTopBarBackground
        : (this.themeAppBackground.length > 0 ? Color.Transparent
          : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)))
      .backdropBlur(this.themeTopBarBlurRadius)
  }
}
