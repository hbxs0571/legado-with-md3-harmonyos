import { ReaderBookmark } from '../model/ReaderBookmark';

@Component
export struct ReaderBookmarkEditor {
  @Prop bookmark: ReaderBookmark = {
    id: '', bookId: '', bookName: '', bookAuthor: '', bookUrl: '',
    chapterIndex: 0, chapterName: '', chapterPosition: 0, bookText: '', content: '', createdAt: 0
  };
  @Prop isNew: boolean = true;
  @State note: string = '';
  /** 书签原文，与上游 BookmarkEditSheet 的两个输入框对齐，保存时一并写回。 */
  @State bookText: string = '';
  onSave: (note: string, bookText: string) => void = (_note: string, _bookText: string) => {};
  onDelete: () => void = () => {};
  onClose: () => void = () => {};

  aboutToAppear(): void {
    this.note = this.bookmark.content;
    this.bookText = this.bookmark.bookText;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#99000000').onClick(() => this.onClose())
      Column() {
        Text(this.isNew ? '添加书签' : '编辑书签')
          .fontSize(19).fontColor('#E5E6EB').fontWeight(FontWeight.Medium)
          .alignSelf(ItemAlign.Start).margin({ bottom: 14 })
        Text(this.bookmark.bookName).fontSize(14).fontColor('#E1E2E8').maxLines(1)
          .alignSelf(ItemAlign.Start)
        Text(this.bookmark.chapterName).fontSize(13).fontColor('#AFC2FF').maxLines(1)
          .alignSelf(ItemAlign.Start).margin({ top: 4, bottom: 10 })
        Text('原文').fontSize(13).fontColor('#D8D9E0').alignSelf(ItemAlign.Start).margin({ bottom: 6 })
        TextArea({ text: this.bookText, placeholder: '书签原文（可编辑）' })
          .fontSize(13).fontColor('#C8CAD3').placeholderColor('#92949E')
          .backgroundColor('#15161B').height(118).width('100%')
          .onChange((value: string) => this.bookText = value)
        Text('备注').fontSize(13).fontColor('#D8D9E0').alignSelf(ItemAlign.Start).margin({ top: 12, bottom: 6 })
        TextArea({ text: this.note, placeholder: '添加书签备注（可选）' })
          .fontSize(14).fontColor('#E3E4E8').placeholderColor('#92949E')
          .backgroundColor('#15161B').height(92).width('100%')
          .onChange((value: string) => this.note = value)
        Row() {
          if (!this.isNew) {
            Text('删除').fontSize(14).fontColor('#F2A6A6').padding({ left: 10, right: 10, top: 10, bottom: 10 })
              .onClick(() => this.onDelete())
          }
          Blank()
          Text('取消').fontSize(14).fontColor('#C5C7D0').padding({ left: 10, right: 10, top: 10, bottom: 10 })
            .onClick(() => this.onClose())
          Text('保存').fontSize(14).fontColor('#D7DFFB').padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .backgroundColor('#454B62').borderRadius(18)
            .onClick(() => this.onSave(this.note, this.bookText))
        }.width('100%').margin({ top: 14 })
      }.width('calc(100% - 36vp)').padding(18).backgroundColor('#242127').borderRadius(20)
    }.width('100%').height('100%')
  }
}
