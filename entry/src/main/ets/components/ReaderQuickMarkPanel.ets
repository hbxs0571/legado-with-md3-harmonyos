import { ReaderMarkingEffect } from '../model/ReaderMarking';
import { AppGlyph } from '../components/AppGlyph';
import { BODY_SMALL, LABEL_LARGE, LABEL_MEDIUM, TITLE_SMALL } from '../components/typography/TypographyTokens';

/**
 * 划词菜单「行内快速标记」面板（批5，:127）。
 *
 * 上游是 `ReadBookRouteScreen.kt` 里按 `MarkingUiState.inlineMode` 切换的预览态，意图是
 * 「划词后当场选样式并落库，不离开正文」。本地原来 `menu_mark` 直接走整套标记编辑 Sheet，
 * 列表页与阅读页来回跳。这里做一个贴选区的小面板：七种样式 + 备注 + 应用/删除，
 * 面板只负责呈现与回调，落库仍由 Index 侧的仓储路径完成（与标记编辑 Sheet 同一条路）。
 *
 * 说明：面板命中已有标记时多一个「删除」，与上游 ApplyQuickMarking / DismissQuickMarking 两个意图对应。
 */

/** 与 ReaderMarkingEditor 的样式标签按下标一一对应，改一处必须两处一起改。 */
const QUICK_MARK_EFFECTS: ReaderMarkingEffect[] = [
  'solid', 'dashed', 'wave', 'strike', 'highlight', 'background', 'text'
];
const QUICK_MARK_LABELS: string[] = [
  '实线', '虚线', '波浪', '删除线', '强调', '背景', '文字色'
];

@Component
export struct ReaderQuickMarkPanel {
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  /** 当前选中的样式，由阅读页持有，面板只回传选择。 */
  @Prop quickStyle: ReaderMarkingEffect = 'solid';
  /** 备注草稿，同上。 */
  @Prop quickNote: string = '';
  /** 命中已有标记时为 true（多显示「删除」，标题改成「编辑标记」）。 */
  @Prop existingMarking: boolean = false;
  onStyleChange: (style: ReaderMarkingEffect) => void = (_style: ReaderMarkingEffect) => {};
  onNoteChange: (note: string) => void = (_note: string) => {};
  onApply: () => void = () => {};
  onDelete: () => void = () => {};
  onClose: () => void = () => {};

  build() {
    Column() {
      Row() {
        Text(this.existingMarking ? '编辑标记' : '标记').fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary)
          .layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileClose', glyphSize: 16, tint: this.themeColorTextSecondary })
        }.width(28).height(28).onClick(() => this.onClose())
        // 上游取 TextActionSelectionMenu.kt:491 back
        .accessibilityText('关闭')
      }.width('100%').height(28)

      // 样式：七个胶囊，选中填强调色
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(QUICK_MARK_EFFECTS, (item: ReaderMarkingEffect, index: number) => {
          Text(QUICK_MARK_LABELS[index])
            .fontSize(BODY_SMALL).fontWeight(this.quickStyle === item ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.quickStyle === item ? '#FFFFFF' : this.themeColorTextSecondary)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .margin({ right: 4, bottom: 4 })
            .borderRadius(14)
            .backgroundColor(this.quickStyle === item ? this.themeColorAccent : this.themeColorSurfaceTertiary)
            .onClick(() => this.onStyleChange(item))
        }, (item: ReaderMarkingEffect) => item)
      }.width('100%').margin({ top: 6 })

      TextInput({ placeholder: '备注（可选）', text: this.quickNote })
        .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextPrimary)
        .placeholderColor(this.themeColorTextSecondary)
        .backgroundColor(this.themeColorSurfaceTertiary)
        .height(40).margin({ top: 4 })
        .onChange((value: string) => this.onNoteChange(value))

      Row() {
        if (this.existingMarking) {
          Text('删除').fontSize(LABEL_LARGE).fontColor('#E57373')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .onClick(() => this.onDelete())
        }
        Blank()
        Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorTextSecondary)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .onClick(() => this.onClose())
        Text('应用').fontSize(LABEL_LARGE).fontColor('#FFFFFF')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .borderRadius(16).backgroundColor(this.themeColorAccent).margin({ left: 8 })
          .onClick(() => this.onApply())
      }.width('100%').margin({ top: 8 })
    }.width(300).padding(14)
      .backgroundColor(this.themeColorSurfaceSecondary).borderRadius(16)
      .shadow({ radius: 12, color: '#33000000', offsetX: 0, offsetY: 4 })
  }
}