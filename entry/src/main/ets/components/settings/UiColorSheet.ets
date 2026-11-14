import {
  FONT_INPUT, FONT_ROW_DETAIL, RADIUS_INNER, SPACE_12, SPACE_16, SPACE_2, SPACE_8
} from '../UiTokens';

/**
 * 取色面板，对齐上游 ui/widget/components/dialog/ColorPickerSheet.kt。
 *
 * 上游结构：标题「选择颜色」+ 左「重置」+ 右「保存」（色值非法时置灰不可点），
 * 正文是 ColorPalette(rows = 8, hueColumns = 12, showPreview = false) 加一行
 * 「40dp 预览方块 + hex 输入框」。本地 ArkUI 没有 ColorPalette 组件，色板按同一
 * 网格自己算：列是色相每列 30 度，行是明度每行递减 7.5%，与 ReaderMarkingEditor
 * 里那份算法同源（那里注释就写着「对齐上游 ColorPickerSheet 的 rows = 8」）。
 *
 * 与上游的两处差异，写在前面免得后来人当成 bug：
 * - 上游「重置」填 Color.Transparent（#00000000）；这里填 resetColor 入参，
 *   因为封面文字色透明没有意义，调用方给的是该字段的业务默认值。
 * - 上游展示 8 位 ARGB（Int 转 hex 补足 8 位）；这里保持调用方传进来的原始
 *   #RRGGBB / #AARRGGBB 串，不做位宽改造，否则写回偏好会改变既有数据形态。
 */
@Component
export struct UiColorSheet {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';

  /** 面板标题，上游固定是 R.string.select_color（「选择颜色」）。 */
  @Prop title: string = '选择颜色';
  /** 进入时灌进色板的颜色。 */
  @Prop initialColor: string = '#000000';
  /** 「重置」填回的颜色；上游固定填透明，这里由调用方给业务默认值。 */
  @Prop resetColor: string = '#000000';

  onCancel: () => void = () => {};
  onConfirm: (color: string) => void = (_color: string) => {};

  @State currentColor: string = '#000000';
  @State hexInput: string = '#000000';

  aboutToAppear(): void {
    this.currentColor = this.initialColor;
    this.hexInput = this.initialColor;
  }

  /** 色板或手输框改动后同步两处：currentColor 管预览块，hexInput 管输入框。 */
  private pickColor(value: string): void {
    this.currentColor = value;
    this.hexInput = value;
  }

  /** 当前 hex 解析出的合法颜色；空串表示非法，此时预览留空、「保存」不可点。 */
  private resolved(): string {
    return normalizeColorText(this.hexInput);
  }

  build() {
    Column() {
      // 标题行：左「重置」、中标题、右「保存」，对齐上游 AppModalBottomSheet 的两个 action。
      Row() {
        Text('重置')
          .fontSize(FONT_INPUT)
          .fontColor(this.themeColorTextSecondary)
          .onClick(() => this.pickColor(this.resetColor));
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorTextPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center);
        Text('保存')
          .fontSize(FONT_INPUT)
          // 上游 endAction 的 enabled = parsedHexColor != null && !isHexInputError。
          .fontColor(this.resolved().length > 0 ? this.themeColorAccent : this.themeColorTextTertiary)
          .onClick(() => {
            const value = this.resolved();
            if (value.length > 0) {
              this.onConfirm(value);
            }
          });
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: SPACE_8, bottom: SPACE_12 });

      Scroll() {
        Column() {
          // 8 行 × 12 列色板；每格 20vp，右上留 3vp 间隔。
          Column() {
            ForEach(PALETTE_ROWS, (row: number) => {
              Row() {
                ForEach(PALETTE_COLUMNS, (column: number) => {
                  Row()
                    .width(20)
                    .height(20)
                    .borderRadius(4)
                    .backgroundColor(paletteColor(row, column))
                    .margin({ right: 3, bottom: 3 })
                    .border({
                      width: this.resolved() === paletteColor(row, column) ? 2 : 0,
                      color: this.themeColorTextPrimary
                    })
                    .onClick(() => this.pickColor(paletteColor(row, column)));
                }, (column: number) => `col-${row}-${column}`);
              }.width('100%');
            }, (row: number) => `row-${row}`);
          }.width('100%');

          // 预览方块 40×40 + hex 输入框，对齐上游 ColorPickerSheet 正文最后一行。
          Row() {
            Row()
              .width(40)
              .height(40)
              .borderRadius(8)
              .backgroundColor(this.resolved().length > 0 ? this.resolved() : this.themeColorSurfaceTertiary)
              .border({ width: 1, color: this.themeColorTextTertiary });
            TextInput({ text: this.hexInput, placeholder: '#RRGGBB' })
              .fontSize(FONT_INPUT)
              .fontColor(this.themeColorTextPrimary)
              .placeholderColor(this.themeColorTextTertiary)
              .backgroundColor(this.themeColorSurfacePrimary)
              .borderRadius(RADIUS_INNER)
              .layoutWeight(1)
              .margin({ left: SPACE_12 })
              .onChange((value: string) => {
                // 只做归一化（去空格、转大写、补 #），合法性交给 resolved() 判；
                // 用户删字符到一半时不该被强行改写。
                this.hexInput = normalizeHexInput(value);
              });
          }
          .width('100%')
          .margin({ top: SPACE_16 });

          if (this.hexInput.length > 0 && this.resolved().length === 0) {
            Text('色值需为 #RRGGBB 或 #AARRGGBB')
              .fontSize(FONT_ROW_DETAIL)
              .fontColor('#E5484D')
              .width('100%')
              .margin({ top: SPACE_8 });
          }
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: SPACE_16 });
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%');
  }
}

/** 色板行数（明度梯度），对齐上游 ColorPickerSheet 的 rows = 8。 */
const PALETTE_ROWS: number[] = [0, 1, 2, 3, 4, 5, 6, 7];
/** 色板列数（色相梯度），对齐上游 ColorPickerSheet 的 hueColumns = 12。 */
const PALETTE_COLUMNS: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

/** HSL 转 #RRGGBB。hue 单位为度，saturation / lightness 取 0..1。 */
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
 * 返回空串表示非法。
 */
function normalizeColorText(input: string): string {
  const bare = input.trim().replace(/^#/, '');
  if (!/^(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(bare)) {
    return '';
  }
  return `#${bare.toUpperCase()}`;
}
