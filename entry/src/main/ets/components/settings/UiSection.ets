import {
  FONT_SECTION_TITLE, ROW_PADDING_H, SECTION_GAP, SECTION_TITLE_BOTTOM, SECTION_TITLE_TOP
} from '../UiTokens';

/**
 * 设置页的区块容器：可选的区块标题 + 一张卡片。
 *
 * 取代七份私有实现（Ai/Cover/Cache/Privacy/Read/Translation/OtherSettings 的 Section）。
 * 阅读菜单的 MenuSettingSection 不在范围内：它是深色专用，不跟随主题。
 */
@Component
export struct UiSection {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  @StorageProp('themeCardBorderWidth') themeCardBorderWidth: number = 0;
  @StorageProp('themeCardBorderColor') themeCardBorderColor: string = '#6A6D77';
  @StorageProp('themeCardBackground') themeCardBackground: string = '';
  @StorageProp('themeContainerBackground') themeContainerBackground: string = '';

  /** 区块标题。传空串表示不要标题，只渲染卡片。 */
  @Prop title: string = '';

  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
  }

  build() {
    Column() {
      if (this.title.length > 0) {
        Text(this.title)
          .fontSize(FONT_SECTION_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorAccent)
          .alignSelf(ItemAlign.Start)
          .padding({ left: ROW_PADDING_H, top: SECTION_TITLE_TOP, bottom: SECTION_TITLE_BOTTOM })
      }
      Column() {
        this.content();
      }
      .margin({ left: 16, right: 16 })
      .backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : this.themeColorSurfaceSecondary)
      .borderRadius(this.themeCardRadius)
      .border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor })
      .backgroundImage(
        this.themeContainerBackground.length > 0
          ? 'file://' + this.themeContainerBackground
          : $r('app.media.transparent_pixel'),
        ImageRepeat.NoRepeat
      )
    }
    .width('100%')
    .margin({ bottom: SECTION_GAP })
  }
}
