import { ReaderMarking, ReaderMarkingEffect } from '../model/ReaderMarking';

const READER_MARKING_EFFECTS: ReaderMarkingEffect[] = [
  'solid', 'double', 'dashed', 'wave', 'strike', 'highlight', 'background', 'text'
];
const READER_MARKING_LABELS: string[] = [
  '实线下划线', '双下划线', '虚线下划线', '波浪下划线', '删除线', '强调线', '背景高亮', '文字颜色'
];
/**
 * 预设颜色，逐条对齐上游 MarkingSheet.kt:449-464 的 MarkingPresetColors（15 个）。
 * 上游用 ARGB int，这里统一用 #RRGGBB；#63C37D 与其 DEFAULT_COLOR(0xFF63C37D) 一致，
 * 所以新建标记的默认色保持不变。
 */
const READER_MARKING_COLORS: string[] = [
  '#F44848', '#FF7417', '#FFC107', '#FFEB3B', '#9CCC65', '#22C55E', '#18B5A4', '#26C6DA',
  '#3B82F6', '#5C6BC0', '#9C27B0', '#A855F7', '#EC4899', '#9A4D0F', '#607D8B'
];

/** 色板的行数（明度梯度），对齐上游 ColorPickerSheet 的 rows = 8。 */
const READER_PALETTE_ROWS: number[] = [0, 1, 2, 3, 4, 5, 6, 7];
/** 色板的列数（色相梯度），对齐上游 ColorPickerSheet 的 hueColumns = 12。 */
const READER_PALETTE_COLUMNS: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

/** HSL 转 #RRGGBB。色板取色用，hue 单位为度，saturation/lightness 取 0..1。 */
function hslToHex(hue: number, saturation: number, lightness: number): string {
  const normalizedHue = ((hue % 360) + 360) % 360;
  const chroma = (1 - Math.abs(2 * lightness - 1)) * saturation;
  const second = chroma * (1 - Math.abs(((normalizedHue / 60) % 2) - 1));
  const offset = lightness - chroma / 2;
  let red = 0;
  let green = 0;
  let blue = 0;
  if (normalizedHue < 60) {
    red = chroma;
    green = second;
  } else if (normalizedHue < 120) {
    red = second;
    green = chroma;
  } else if (normalizedHue < 180) {
    green = chroma;
    blue = second;
  } else if (normalizedHue < 240) {
    green = second;
    blue = chroma;
  } else if (normalizedHue < 300) {
    red = second;
    blue = chroma;
  } else {
    red = chroma;
    blue = second;
  }
  const channel = (value: number): string => {
    const scaled = Math.round((value + offset) * 255);
    const clamped = scaled < 0 ? 0 : (scaled > 255 ? 255 : scaled);
    return clamped.toString(16).padStart(2, '0');
  };
  return `#${channel(red)}${channel(green)}${channel(blue)}`.toUpperCase();
}

/** 色板第 row 行第 column 列的颜色：色相每列 30 度，明度每行递减。 */
function paletteColor(row: number, column: number): string {
  return hslToHex(column * 30, 0.78, 0.82 - row * 0.075);
}

/** 归一化手输色值，对齐上游 ColorPickerSheet.normalizeHexInput。 */
function normalizeHexInput(input: string): string {
  const trimmed = input.trim().toUpperCase();
  return trimmed.startsWith('#') ? `#${trimmed.substring(1)}` : trimmed;
}

/**
 * 解析 #RRGGBB 或 #AARRGGBB，对齐上游 ColorPickerSheet.parseHexColor。
 * 返回空串表示非法，渲染侧只认这两种长度。
 */
function normalizeColorText(input: string): string {
  const bare = input.trim().replace(/^#/, '');
  if (!/^(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(bare)) {
    return '';
  }
  return `#${bare.toUpperCase()}`;
}

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
  /** 自定义取色面板是否展开。上游是独立 ColorPickerSheet，这里内联在同一面板内。 */
  @State colorPickerVisible: boolean = false;
  /** 取色面板里手输的色值，切换色板时同步。 */
  @State colorInput: string = '';
  onSave: (effect: ReaderMarkingEffect, color: string, note: string) => void =
    (_effect: ReaderMarkingEffect, _color: string, _note: string) => {};
  onDelete: () => void = () => {};
  onClose: () => void = () => {};

  aboutToAppear(): void {
    this.effect = this.marking.effect;
    this.color = this.marking.color;
    this.note = this.marking.note;
    this.colorInput = this.marking.color;
  }

  /** 当前颜色是否属于 15 个预设色之外（决定尾部按钮显示取色图标还是该色）。 */
  private isCustomColor(): boolean {
    return READER_MARKING_COLORS.indexOf(this.color) < 0;
  }

  /** 选中预设色或色板色后同步手输框。 */
  private pickColor(value: string): void {
    this.color = value;
    this.colorInput = value;
  }

  /** 取色面板：8 行 × 12 列的色板 + 手输色值，对齐上游 ColorPickerSheet。 */
  @Builder
  private ColorPickerPanel() {
    Column() {
      Row() {
        Text('自定义颜色').fontSize(13).fontColor('#D8D9E0').layoutWeight(1)
        Text('关闭').fontSize(12).fontColor('#AFC2FF')
          .onClick(() => this.colorPickerVisible = false)
      }.width('100%').margin({ bottom: 6 })
      Column() {
        ForEach(READER_PALETTE_ROWS, (row: number) => {
          Row() {
            ForEach(READER_PALETTE_COLUMNS, (column: number) => {
              Row()
                .width(20).height(20).borderRadius(4)
                .backgroundColor(paletteColor(row, column))
                .margin({ right: 3, bottom: 3 })
                .onClick(() => this.pickColor(paletteColor(row, column)))
            }, (column: number) => `${row}-${column}`)
          }.width('100%')
        }, (row: number) => `row-${row}`)
      }.width('100%')
      Row() {
        Row().width(28).height(28).borderRadius(7)
          .backgroundColor(normalizeColorText(this.colorInput).length > 0
            ? normalizeColorText(this.colorInput) : '#292A31')
          .margin({ right: 8 })
        TextInput({ text: this.colorInput, placeholder: '#RRGGBB' })
          .fontSize(13).fontColor('#E3E4E8').placeholderColor('#92949E')
          .backgroundColor('#15161B').layoutWeight(1)
          .onChange((value: string) => {
            // 手输框实时同步到选中色：合法立即生效，非法保留文本待用户改完
            this.colorInput = normalizeHexInput(value);
            const resolved = normalizeColorText(this.colorInput);
            if (resolved.length > 0) {
              this.color = resolved;
            }
          })
      }.width('100%').margin({ top: 8 })
      Text('支持 #RRGGBB 与 #AARRGGBB；背景高亮会自动叠加约 20% 透明度。')
        .fontSize(11).fontColor('#92949E').width('100%').margin({ top: 6 })
    }
    .width('100%').padding(10).backgroundColor('#1D1E24').borderRadius(12)
    .margin({ top: 8 })
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
        // 取色面板展开后内容会超出一屏，中间这部分必须能滚动，
        // 否则「笔记」与底部按钮会被挤出屏幕而无法保存。
        Scroll() {
          Column() {
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
            // 上游是横向滚动的单行色带，但本地面板外层套了「点空白关闭」的遮罩，
            // 横向手势会被遮罩吃掉，所以改成换行排列，与上方「样式」的排布一致。
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(READER_MARKING_COLORS, (item: string) => {
                Stack() {
                  Row().width(28).height(28).backgroundColor(item).borderRadius(14)
                  if (item === this.color) {
                    Text('✓').fontSize(14).fontColor('#171820').fontWeight(FontWeight.Bold)
                  }
                }.width(34).height(34).margin({ right: 7, bottom: 4 })
                  .onClick(() => this.pickColor(item))
              }, (item: string) => item)
              // 尾部自定义色：对齐上游 MarkingSheet.kt:305-310，未选自定义色时显示取色图标
              Stack() {
                Row().width(28).height(28).borderRadius(14)
                  .backgroundColor(this.isCustomColor() ? this.color : '#292A31')
                  .border({ width: 1, color: this.isCustomColor() ? '#AFC2FF' : '#4A4C56' })
                if (this.isCustomColor()) {
                  Text('✓').fontSize(14).fontColor('#171820').fontWeight(FontWeight.Bold)
                } else {
                  Text('+').fontSize(15).fontColor('#B9BBC5')
                }
              }.width(34).height(34).margin({ bottom: 4 })
                .onClick(() => {
                  this.colorInput = this.color;
                  this.colorPickerVisible = !this.colorPickerVisible;
                })
            }.width('100%')
            if (this.colorPickerVisible) {
              this.ColorPickerPanel()
            }
            Text('笔记').fontSize(13).fontColor('#D8D9E0').margin({ top: 8, bottom: 5 }).alignSelf(ItemAlign.Start)
            TextArea({ text: this.note, placeholder: '添加笔记（可选）' })
              .fontSize(14).fontColor('#E3E4E8').placeholderColor('#92949E')
              .backgroundColor('#15161B').height(82).width('100%')
              .onChange((value: string) => this.note = value)
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
        // 按钮行固定在面板底部，不随中间内容滚动，保证取色面板展开时依然可保存。
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
        // 面板高度最多占满屏幕，超过时由中间的 Scroll 消化，避免内容溢出到屏幕外。
        .constraintSize({ maxHeight: '100%' })
    }.width('100%').height('100%')
  }
}
