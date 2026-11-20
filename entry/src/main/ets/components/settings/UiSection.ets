import { LABEL_LARGE_EMPHASIZED } from '../typography/TypographyTokens';

import { ROW_PADDING_H, SECTION_GAP, SECTION_TITLE_BOTTOM, SECTION_TITLE_TOP } from '../UiTokens';

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
  // 设置分组卡片对应上游 SplicedColumnGroup：读单独的 themeGroupRadius，只有它响应
  // 「关闭设置分组圆角」开关；普通卡片读 themeCardRadius，不受该开关影响。
  @StorageProp('themeGroupRadius') themeGroupRadius: number = 16;
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
          .fontSize(LABEL_LARGE_EMPHASIZED)
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
      .borderRadius(this.themeGroupRadius)
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
