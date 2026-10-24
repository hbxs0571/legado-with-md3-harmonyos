@Component
export struct PageHeader {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  onBack: () => void = () => {};

  build() {
    Row() {
      Image($r('app.media.reader_back')).width(20).height(20).fillColor('#393832')
        .width(42)
        .onClick(() => this.onBack())
      Column() {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#292923')
        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(12)
            .fontColor('#79786F')
            .margin({ top: 3 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
  }
}

import { AppGlyph } from './AppGlyph';

