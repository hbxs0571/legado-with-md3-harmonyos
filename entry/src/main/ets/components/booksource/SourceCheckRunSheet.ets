// 书源校验「运行」弹层：对齐上游 BookSourceScreen.kt:780-819 的 CheckBookSourceSheet。
//
// 上游形态（现取自 bba5c64）：
//   AppModalBottomSheet(
//     title = R.string.check_book_source「校验书源」,
//     startAction = MediumTonalButton(Settings, contentDescription = check_source_config「校验设置」),
//     endAction   = MediumTonalButton(Check,    contentDescription = check_book_source「校验书源」),
//   ) {
//     AppTextField(value = keyword, label = search_book_key「搜索关键字」,
//                  singleLine = true, padding bottom 16)
//   }
// 关键字初值是 R.string.book_source_check_default_keyword「我的」（:788-789）。
//
// 它的 startAction 只负责回调 onOpenSettings，由页面把配置弹层重新打开；
// endAction 才真正触发 onConfirm(sourceIds, keyword.trim(), options)。
import { LABEL_MEDIUM, TITLE_MEDIUM } from '../typography/TypographyTokens';
import { ROW_PADDING_H } from '../UiTokens';
import { AppGlyph } from '../AppGlyph';

@Component
export struct SourceCheckRunSheet {
  /** 显隐由调用方持有；关闭时回写 false。 */
  @Link visible: boolean;
  /** 已选中的书源 URL 数量，仅用于标题下方的进度提示，不参与业务。 */
  @Prop sourceCount: number = 0;
  /** 打开校验配置（上游 startAction → onOpenSettings）。 */
  onOpenSettings: () => void = () => {};
  /** 开始校验（上游 endAction → onConfirm）。 */
  onConfirm: (keyword: string) => void = (_keyword: string) => {};

  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;

  /** 关键字，初值「我的」（上游 :788-789）。 */
  @State private keyword: string = '我的';

  /** 头部：标题居中、左设置、右确认（复刻 AppModalBottomSheet 的 hasHeader 布局）。 */
  @Builder
  private Header() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Row({ space: 4 }) {
          AppGlyph({ name: 'settings', glyphSize: 18, tint: this.themeColorTextTertiary })
        }
        .height(40).padding({ left: 8, right: 8 })
        .onClick(() => { this.onOpenSettings(); })
        .accessibilityText('校验设置')
      }.width(56)

      Text('校验书源')
        .fontSize(TITLE_MEDIUM)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary)
        .maxLines(1)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)

      Stack({ alignContent: Alignment.Center }) {
        Row({ space: 4 }) {
          AppGlyph({ name: 'profileCheck', glyphSize: 18, tint: this.themeColorAccent })
        }
        .height(40).padding({ left: 8, right: 8 })
        .onClick(() => {
          this.onConfirm(this.keyword.trim());
        })
        .accessibilityText('校验书源')
      }.width(56)
    }
    .width('100%')
    .padding({ bottom: 16 })
  }

  @Builder
  private SheetContent() {
    Column() {
      this.Header()
      // 上游 AppTextField(label=search_book_key, singleLine=true, padding bottom 16)。
      Column() {
        if (this.keyword.length === 0) {
          Text('搜索关键字')
            .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
            .width('100%').padding({ left: 12, top: 8 })
        }
        TextInput({ text: this.keyword, placeholder: '' })
          .width('100%')
          .maxLines(1)
          .fontColor(this.themeColorTextPrimary)
          .backgroundColor(Color.Transparent)
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
          .onChange((value: string) => { this.keyword = value; })
      }
      .width('100%')
      .backgroundColor(this.themeColorSurfaceElevated)
      .borderRadius(8)
      // 上游 Modifier.padding(bottom = 16.dp)。
      .margin({ bottom: 16 })
      if (this.sourceCount > 0) {
        Text('将校验 ' + this.sourceCount + ' 个书源')
          .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
          .width('100%')
      }
    }
    .width('100%')
    .padding({ left: ROW_PADDING_H, right: ROW_PADDING_H, top: 8, bottom: 24 })
    .backgroundColor(this.themePureBlack ? '#17181E' : this.themeColorSurfaceElevated)
  }

  build() {
    Column()
      .width(0).height(0)
      .bindSheet(this.visible, this.SheetContent(), {
        height: SheetSize.FIT_CONTENT,
        dragBar: true,
        backgroundColor: this.themePureBlack ? '#17181E' : this.themeColorSurfaceElevated,
        onDisappear: () => { this.visible = false; }
      })
  }
}
