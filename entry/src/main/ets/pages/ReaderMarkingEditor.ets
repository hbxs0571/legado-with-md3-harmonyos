import { ReaderMarking, ReaderMarkingEffect } from '../model/ReaderMarking';

const READER_MARKING_EFFECTS: ReaderMarkingEffect[] = [
  'solid', 'double', 'dashed', 'wave', 'strike', 'highlight', 'background', 'text'
];
const READER_MARKING_LABELS: string[] = [
  '实线下划线', '双下划线', '虚线下划线', '波浪下划线', '删除线', '强调线', '背景高亮', '文字颜色'
];
const READER_MARKING_COLORS: string[] = ['#63C37D', '#F2C94C', '#64B5F6', '#E58AA8', '#B59AF3', '#F28B52'];

/** 编辑一次选区标记的样式与备注。 */
@Component
export struct ReaderMarkingEditor {
  @Prop marking: ReaderMarking = {
    id: '', bookId: '', bookName: '', bookAuthor: '', bookUrl: '', chapterIndex: 0, chapterName: '',
    chapterPosition: 0, endPosition: 1, selectedText: '', contextBefore: '', contextAfter: '',
    effect: 'solid', color: '#63C37D', note: '', enabled: true, createdAt: 0, updatedAt: 0
  };
  @Prop isNew: boolean = true;
  @State effect: ReaderMarkingEffect = 'solid';
  @State color: string = '#63C37D';
  @State note: string = '';
  onSave: (effect: ReaderMarkingEffect, color: string, note: string) => void =
    (_effect: ReaderMarkingEffect, _color: string, _note: string) => {};
  onDelete: () => void = () => {};
  onClose: () => void = () => {};

  aboutToAppear(): void {
    this.effect = this.marking.effect;
    this.color = this.marking.color;
    this.note = this.marking.note;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor('#99000000').onClick(() => this.onClose())
      Column() {
        Row() {
          Text(this.isNew ? '划线与笔记' : '编辑标记').fontSize(19).fontWeight(FontWeight.Medium)
            .fontColor('#E5E6EB').layoutWeight(1)
          Text('关闭').fontSize(13).fontColor('#AFC2FF').onClick(() => this.onClose())
        }.width('100%').margin({ bottom: 10 })
        Text(this.marking.bookName).fontSize(13).fontColor('#D9DAE0').maxLines(1).width('100%')
        Text(this.marking.chapterName).fontSize(12).fontColor('#AFC2FF').maxLines(1).width('100%')
          .margin({ top: 3, bottom: 8 })
        Scroll() {
          Text(this.marking.selectedText).fontSize(13).fontColor('#D8D9E0').lineHeight(20)
            .width('100%')
        }.height(76).width('100%').padding(9).backgroundColor('#15161B').borderRadius(10)
        Text('样式').fontSize(13).fontColor('#D8D9E0').margin({ top: 10, bottom: 5 })
          .alignSelf(ItemAlign.Start)
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(READER_MARKING_EFFECTS, (item: ReaderMarkingEffect, index: number) => {
            Text(READER_MARKING_LABELS[index] ?? '划线')
              .fontSize(11).fontColor(this.effect === item ? '#E7E9F5' : '#B9BBC5')
              .padding({ left: 9, right: 9, top: 7, bottom: 7 }).margin({ right: 6, bottom: 5 })
              .backgroundColor(this.effect === item ? '#454B62' : '#292A31').borderRadius(14)
              .onClick(() => this.effect = item)
          }, (item: ReaderMarkingEffect) => item)
        }.width('100%')
        Text('颜色').fontSize(13).fontColor('#D8D9E0').margin({ top: 2, bottom: 5 }).alignSelf(ItemAlign.Start)
        Row() {
          ForEach(READER_MARKING_COLORS, (item: string) => {
            Stack() {
              Row().width(28).height(28).backgroundColor(item).borderRadius(14)
              if (item === this.color) {
                Text('✓').fontSize(14).fontColor('#171820').fontWeight(FontWeight.Bold)
              }
            }.width(34).height(34).margin({ right: 7 })
              .onClick(() => this.color = item)
          }, (item: string) => item)
        }.width('100%')
        Text('笔记').fontSize(13).fontColor('#D8D9E0').margin({ top: 8, bottom: 5 }).alignSelf(ItemAlign.Start)
        TextArea({ text: this.note, placeholder: '添加笔记（可选）' })
          .fontSize(14).fontColor('#E3E4E8').placeholderColor('#92949E')
          .backgroundColor('#15161B').height(82).width('100%')
          .onChange((value: string) => this.note = value)
        Row() {
          if (!this.isNew) {
            Text('删除').fontSize(13).fontColor('#F2A6A6')
              .padding({ left: 10, right: 10, top: 9, bottom: 9 }).onClick(() => this.onDelete())
          }
          Blank()
          Text('取消').fontSize(13).fontColor('#C5C7D0')
            .padding({ left: 10, right: 10, top: 9, bottom: 9 }).onClick(() => this.onClose())
          Text('保存').fontSize(13).fontColor('#D7DFFB')
            .padding({ left: 16, right: 16, top: 9, bottom: 9 })
            .backgroundColor('#454B62').borderRadius(18)
            .onClick(() => this.onSave(this.effect, this.color, this.note))
        }.width('100%').margin({ top: 10 })
      }.width('calc(100% - 32vp)').padding(16).backgroundColor('#242127').borderRadius(20)
        .margin({ bottom: 12 })
    }.width('100%').height('100%')
  }
}
