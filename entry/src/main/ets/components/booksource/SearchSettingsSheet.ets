/**
 * 搜索设置面板。
 *
 * 逐项对齐上游 `SearchScreen.kt:686-767`：
 *   ① `CompactDropdownSettingItem(layout_mode, entries = [search_layout_source_grouped, search_layout_list],
 *      entryValues = ["1","0"], imageVector = GridView | FormatListBulleted)`
 *   ② `CompactClickableSettingItem(content_quality_detection, content_quality_detection_summary, Book)`
 *   ③ `Row { AppIcon(Layers); Spacer(8.dp); AppText(search_type, titleSmall) }`
 *   ④ 四个 `SelectionItemCard`：all（`selectedSourceTypes.isEmpty()`）/ 小说=0 / 漫画=2 / 音频=1，
 *      均 `containerColor = onSheetContent, inSelectionMode = true`
 *   ⑤ `Spacer(20.dp)`
 *
 * 布局下拉用本仓的 `UiDropdown`（等价 `CompactDropdownSettingItem`）；
 * 可点击项用 Row 手写（本仓无 `CompactClickableSettingItem`）。
 */
import { AppGlyph } from '../AppGlyph';
import { SelectionItemCard } from './SelectionItemCard';
import { UiDropdown } from '../settings/UiDropdown';
import { BODY_SMALL, TITLE_SMALL } from '../typography/TypographyTokens';
import { SPACE_12, SPACE_16, SPACE_4, SPACE_8 } from '../UiTokens';

/** 布局下拉的两个取值；对齐上游 `entryValues = ["1","0"]`。 */
const LAYOUT_VALUES: string[] = ['1', '0'];
/** 布局下拉的两条展示文案；对齐上游 `search_layout_source_grouped` / `search_layout_list`。 */
const LAYOUT_LABELS: string[] = ['来源分组', '列表布局'];

/** 搜索类型三项：值 → 文案（对齐上游 `0 to noval, 2 to manga, 1 to audio`）。 */
interface SourceTypeOption {
  type: number;
  label: string;
}

const SOURCE_TYPE_OPTIONS: SourceTypeOption[] = [
  { type: 0, label: '小说' },
  { type: 2, label: '漫画' },
  { type: 1, label: '音频' }
];

@Component
export struct SearchSettingsSheet {
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#4A4C55';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';

  /** 0 = 列表布局，1 = 来源分组；对齐上游 `layoutMode`。 */
  @Prop layoutMode: number = 0;
  /** 已选书源类型；空数组表示「全部」。 */
  @Prop selectedSourceTypes: number[] = [];

  onLayoutModeChange: (mode: number) => void = (_mode: number) => {};
  onOpenContentQuality: () => void = () => {};
  onToggleSourceType: (type: number) => void = (_type: number) => {};
  /** 点「全部」：清空所有已选类型（上游 `selectedSourceTypes.forEach { ToggleSourceType(it) }`）。 */
  onClearAllSourceTypes: () => void = () => {};

  private layoutLabelOf(value: string): string {
    const index = LAYOUT_VALUES.indexOf(value);
    return index >= 0 ? LAYOUT_LABELS[index] : value;
  }

  @Builder
  private SectionLabel(icon: 'list' | 'book', text: string) {
    Row({ space: SPACE_8 }) {
      AppGlyph({ name: icon, glyphSize: 20, tint: this.themeColorTextSecondary })
      Text(text)
        .fontSize(TITLE_SMALL)
        .fontColor(this.themeColorTextPrimary)
    }
    .width('100%')
    .padding({ top: SPACE_12, bottom: SPACE_8 })
  }

  build() {
    Column() {
      Text('设置')
        .fontSize(TITLE_SMALL)
        .fontColor(this.themeColorTextPrimary)
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_12, bottom: SPACE_8 })

      Column({ space: SPACE_8 }) {
        // ① 布局模式下拉。
        UiDropdown({
          title: '布局模式',
          option: `${this.layoutMode}`,
          options: LAYOUT_VALUES,
          labelOf: (value: string): string => this.layoutLabelOf(value),
          onSelect: (value: string) => {
            const next = Number.parseInt(value, 10);
            if (!Number.isNaN(next) && next !== this.layoutMode) {
              this.onLayoutModeChange(next);
            }
          }
        })

        // ② 内容质量检测入口。
        Row() {
          Column() {
            Text('内容质量检测')
              .fontSize(TITLE_SMALL)
              .fontColor(this.themeColorTextPrimary)
              .width('100%')
              .textAlign(TextAlign.Start)
            Text('过滤章节内容异常或与目标书籍无关的书源')
              .fontSize(BODY_SMALL)
              .fontColor(this.themeColorTextTertiary)
              .width('100%')
              .textAlign(TextAlign.Start)
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          AppGlyph({ name: 'book', glyphSize: 22, tint: this.themeColorTextSecondary })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ top: SPACE_8, bottom: SPACE_8 })
        .onClick(() => { this.onOpenContentQuality(); })

        // ③ 搜索类型标题。
        this.SectionLabel('list', '搜索类型')

        // ④ 四个选项：全部 / 小说 / 漫画 / 音频。
        Column({ space: SPACE_4 }) {
          SelectionItemCard({
            title: '全部',
            isSelected: this.selectedSourceTypes.length === 0,
            inSelectionMode: true,
            onToggleSelection: () => { this.onClearAllSourceTypes(); }
          })
          ForEach(SOURCE_TYPE_OPTIONS, (item: SourceTypeOption) => {
            SelectionItemCard({
              title: item.label,
              isSelected: this.selectedSourceTypes.includes(item.type),
              inSelectionMode: true,
              onToggleSelection: () => { this.onToggleSourceType(item.type); }
            })
          }, (item: SourceTypeOption) => `${item.type}`)
        }
        .width('100%')

        // ⑤ 上游 `Spacer(20.dp)`。
        Blank().height(20)
      }
      .width('100%')
      .padding({ left: SPACE_16, right: SPACE_16, bottom: SPACE_16 })
    }
    .width('100%')
    .backgroundColor(this.themeColorSurfaceTertiary)
  }
}
