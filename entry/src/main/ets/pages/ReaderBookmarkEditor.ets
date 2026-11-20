import { ReaderBookmark } from '../model/ReaderBookmark';
import { LABEL_LARGE, LABEL_MEDIUM, TITLE_LARGE, TITLE_SMALL } from '../components/typography/TypographyTokens';

@Component
export struct ReaderBookmarkEditor {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  // 批3：页面底色/弹层容器字面量改走主题色位，默认值取本地默认配色「草野」夜档真值。
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#111217';
  @StorageProp('themeColorSurfaceBright') themeColorSurfaceBright: string = '#383A32';
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
      Column().width('100%').height('100%').backgroundColor('#66000000').onClick(() => this.onClose())
      Column() {
        Text(this.isNew ? '添加书签' : '编辑书签')
          .fontSize(TITLE_LARGE).fontColor('#E5E6EB').fontWeight(FontWeight.Medium)
          .alignSelf(ItemAlign.Start).margin({ bottom: 14 })
        Text(this.bookmark.bookName).fontSize(LABEL_LARGE).fontColor('#E1E2E8').maxLines(1)
          .alignSelf(ItemAlign.Start)
        Text(this.bookmark.chapterName).fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent).maxLines(1)
          .alignSelf(ItemAlign.Start).margin({ top: 4, bottom: 10 })
        Text('原文').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary).alignSelf(ItemAlign.Start).margin({ bottom: 6 })
        TextArea({ text: this.bookText, placeholder: '书签原文（可编辑）' })
          .fontSize(LABEL_MEDIUM).fontColor('#C8CAD3').placeholderColor(this.themeColorTextTertiary)
          .backgroundColor(this.themeColorSurfacePrimary).height(118).width('100%')
          .onChange((value: string) => this.bookText = value)
        Text('备注').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextSecondary).alignSelf(ItemAlign.Start).margin({ top: 12, bottom: 6 })
        TextArea({ text: this.note, placeholder: '添加书签备注（可选）' })
          .fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
          .backgroundColor(this.themeColorSurfacePrimary).height(92).width('100%')
          .onChange((value: string) => this.note = value)
        Row() {
          if (!this.isNew) {
            Text('删除').fontSize(TITLE_SMALL).fontColor('#F2A6A6').padding({ left: 10, right: 10, top: 10, bottom: 10 })
              .onClick(() => this.onDelete())
          }
          Blank()
          Text('取消').fontSize(TITLE_SMALL).fontColor('#C5C7D0').padding({ left: 10, right: 10, top: 10, bottom: 10 })
            .onClick(() => this.onClose())
          Text('保存').fontSize(TITLE_SMALL).fontColor('#D7DFFB').padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .backgroundColor('#454B62').borderRadius(18)
            .onClick(() => this.onSave(this.note, this.bookText))
        }.width('100%').margin({ top: 14 })
      }.width('calc(100% - 36vp)').padding(18).backgroundColor(this.themeColorSurfaceBright).borderRadius(20)
    }.width('100%').height('100%')
  }
}
