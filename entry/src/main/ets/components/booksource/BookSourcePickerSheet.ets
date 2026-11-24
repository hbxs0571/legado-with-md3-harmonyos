/**
 * 「选择目标书源」面板。
 *
 * 逐项对齐上游 `ui/book/manage/BookshelfManageScreen.kt:1374-1515` 的 `BookSourcePickerSheet`
 * 与 `SourcePickerItem`：
 *   - 标题由调用方传入（批量换源用「选择目标书源」）。
 *   - 右上角确认按钮是 `MediumTonalButton(icon = Icons.Default.PlayArrow, contentDescription = ok)`，
 *     确认时把已选源交回调用方。
 *   - 内容自上而下：筛选输入框（`AppTextField(label = screen「筛选」)`）→
 *     「已选书源（长按拖拽排序）」区（`LazyColumn(heightIn(max = 280.dp), spacedBy(8.dp))`，
 *     每行 `ReorderableSelectionItem`，点行即移除）→「可选书源」区
 *     （`LazyColumn(heightIn(max = 560.dp), spacedBy(8.dp))`，每行 `SourcePickerItem`，点行即加入）。
 *   - 筛选用 `bookSourceName` / `bookSourceGroup` / `bookSourceUrl` 三字段不区分大小写的包含匹配。
 *   - 可选区只列「未选中」的源（上游 `availableSources = filteredSources.filterNot { selectedUrls.contains(...) }`）。
 *
 * 本仓没有 `AppModalBottomSheet` / `ReorderableSelectionItem`，所以面板本身只负责内容，
 * 外壳由调用方用 `bindSheet` 提供；拖拽用 ArkUI `List.editMode(true)` +
 * `onItemDragStart` / `onItemDrop` 承载（与 `BookshelfManagePage` 的行排序同一套做法）。
 */
import { BookSource } from '../../model/BookSource';
import { AppGlyph } from '../AppGlyph';
import { SelectionItemCard } from './SelectionItemCard';
import { BODY_SMALL, LABEL_MEDIUM, LABEL_SMALL, TITLE_LARGE, TITLE_MEDIUM } from '../typography/TypographyTokens';

/** 面板内部的行模型。ArkTS 不允许未声明类型的对象字面量。 */
interface SourcePickerRow {
  url: string;
  name: string;
  /** 分组；为空时上游回落到地址展示。 */
  group: string;
}

@Extend(Text)
function pickerSectionTitle(color: ResourceColor) {
  .fontSize(LABEL_MEDIUM)
  .fontColor(color)
  .width('100%')
}

@Component
export struct BookSourcePickerSheet {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorOnSheetContent') themeColorOnSheetContent: string = '#F5F6F8';

  /** 面板标题；上游由调用方传（批量换源是「选择目标书源」）。 */
  @Prop title: string = '选择目标书源';
  /** 全部已导入书源；组件内部按「启用 + 文本类型 + 有搜索地址」过滤，与上游 `state.bookSources` 同口径。 */
  @Prop sources: BookSource[] = [];
  /** 上次选过的源地址，重开面板时回填（上游 `remember(show)` 只在面板存活期内保留）。 */
  @Prop initialSelectedUrls: string[] = [];

  onDismissRequest: () => void = () => {};
  /** 确认：把已选源（按已选区顺序）交回调用方。 */
  onConfirm: (selected: BookSource[]) => void = () => {};

  @State searchKey: string = '';
  @State selectedUrls: string[] = [];
  /** 拖拽中的源地址，仅用于视觉提示。 */
  @State draggingUrl: string = '';

  aboutToAppear(): void {
    this.selectedUrls = this.initialSelectedUrls.slice(0);
  }

  /** 可被选的书源：启用 + 文本类型 + 有搜索地址（与 `SearchCoordinator.searchableSources` 同判据）。 */
  private pickableSources(): BookSource[] {
    return this.sources.filter((source: BookSource) => {
      return source.enabled && source.bookSourceType === 0 && source.bookSourceUrl.length > 0;
    });
  }

  private rowOf(source: BookSource): SourcePickerRow {
    const name: string = source.bookSourceName.length > 0 ? source.bookSourceName : source.bookSourceUrl;
    const group: string = source.bookSourceGroup ?? '';
    return { url: source.bookSourceUrl, name: name, group: group };
  }

  /** 上游 `filteredSources`：名称 / 分组 / 地址三字段不区分大小写的包含匹配。 */
  private filteredRows(): SourcePickerRow[] {
    const key: string = this.searchKey.trim().toLowerCase();
    const all: SourcePickerRow[] = this.pickableSources().map((source: BookSource): SourcePickerRow => {
      return this.rowOf(source);
    });
    if (key.length === 0) {
      return all;
    }
    return all.filter((row: SourcePickerRow) => {
      return row.name.toLowerCase().indexOf(key) >= 0
        || row.group.toLowerCase().indexOf(key) >= 0
        || row.url.toLowerCase().indexOf(key) >= 0;
    });
  }

  /** 已选区：按 `selectedUrls` 的顺序取行，保持拖拽后的次序。 */
  private selectedRows(): SourcePickerRow[] {
    const rows: SourcePickerRow[] = [];
    for (const url of this.selectedUrls) {
      const source: BookSource | undefined = this.pickableSources().find((item: BookSource) => item.bookSourceUrl === url);
      if (source !== undefined) {
        rows.push(this.rowOf(source));
      }
    }
    return rows;
  }

  /** 可选区：过滤后但未选中的源（上游 `availableSources`）。 */
  private availableRows(): SourcePickerRow[] {
    return this.filteredRows().filter((row: SourcePickerRow) => this.selectedUrls.indexOf(row.url) < 0);
  }

  private toggle(url: string): void {
    const index: number = this.selectedUrls.indexOf(url);
    if (index >= 0) {
      this.selectedUrls = this.selectedUrls.filter((item: string) => item !== url);
      return;
    }
    this.selectedUrls = this.selectedUrls.concat([url]);
  }

  /** 拖拽排序：把 fromUrl 移到 toUrl 的位置（上游 `move(from.index, to.index)`）。 */
  private moveSelected(fromUrl: string, toUrl: string): void {
    const from: number = this.selectedUrls.indexOf(fromUrl);
    const to: number = this.selectedUrls.indexOf(toUrl);
    if (from < 0 || to < 0 || from === to) {
      return;
    }
    const next: string[] = this.selectedUrls.slice(0);
    const moved: string[] = next.splice(from, 1);
    next.splice(to, 0, moved[0]);
    this.selectedUrls = next;
  }

  private confirm(): void {
    const picked: BookSource[] = [];
    for (const url of this.selectedUrls) {
      const source: BookSource | undefined = this.pickableSources().find((item: BookSource) => item.bookSourceUrl === url);
      if (source !== undefined) {
        picked.push(source);
      }
    }
    this.onConfirm(picked);
  }

  /** 已选行：名称 + 分组，右侧拖拽把手；点行移除。 */
  @Builder
  private SelectedRow(row: SourcePickerRow) {
    Row() {
      Column() {
        Text(row.name).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Text(row.group.length > 0 ? row.group : row.url)
          .fontSize(LABEL_SMALL).fontColor(this.themeColorTextTertiary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%').margin({ top: 3 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      AppGlyph({ name: 'unfoldMore', glyphSize: 16, tint: this.themeColorTextTertiary })
    }
    .width('100%').padding(12)
    .backgroundColor(this.themeColorOnSheetContent)
    .borderRadius(12)
    .onClick(() => this.toggle(row.url))
    .accessibilityText(`${row.name}，已选中，点击移除`)
  }

  build() {
    // 【单根节点】@Builder 作 bindSheet 的 builder 时只能有一个根节点。
    Column() {
      Row() {
        Text(this.title).fontSize(TITLE_LARGE).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Row() {
          AppGlyph({ name: 'playArrow', glyphSize: 20, tint: this.themeColorAccent })
        }
        .width(40).height(40).justifyContent(FlexAlign.Center).borderRadius(20)
        .accessibilityText('确认')
        .onClick(() => this.confirm())
      }.width('100%').padding({ bottom: 12 })

      // 上游 `AppTextField(value = searchKey, label = screen「筛选」)`。
      TextInput({ text: this.searchKey, placeholder: '筛选书源名称 / 分组 / 地址' })
        .height(44).fontSize(BODY_SMALL).width('100%')
        .onChange((value: string) => { this.searchKey = value; })

      Scroll() {
        Column() {
          if (this.selectedRows().length > 0) {
            Text('已选书源（长按拖拽排序）').fontSize(LABEL_MEDIUM)
              .fontColor(this.themeColorAccent).width('100%').margin({ top: 12, bottom: 8 })
            // 上游 `LazyColumn(heightIn(max = 280.dp), spacedBy(8.dp))` + `ReorderableSelectionItem`。
            List({ space: 8 }) {
              ForEach(this.selectedRows(), (row: SourcePickerRow) => {
                ListItem() {
                  this.SelectedRow(row)
                }
              }, (row: SourcePickerRow) => 'picked-' + row.url)
            }
            .width('100%').height(Math.min(280, this.selectedRows().length * 62))
            .scrollBar(BarState.Off)
            .editMode(true)
            .onItemDragStart((_event: ItemDragInfo, itemIndex: number) => {
              const rows: SourcePickerRow[] = this.selectedRows();
              if (itemIndex >= 0 && itemIndex < rows.length) {
                const row: SourcePickerRow = rows[itemIndex];
                this.draggingUrl = row.url;
              }
            })
            .onItemDrop((_event: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean) => {
              if (!isSuccess) {
                this.draggingUrl = '';
                return;
              }
              const rows: SourcePickerRow[] = this.selectedRows();
              if (itemIndex < 0 || itemIndex >= rows.length || insertIndex < 0 || insertIndex >= rows.length) {
                this.draggingUrl = '';
                return;
              }
              this.moveSelected(rows[itemIndex].url, rows[insertIndex].url);
              this.draggingUrl = '';
            })
          }

          Text('可选书源').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
            .width('100%').margin({ top: 12, bottom: 8 })
          if (this.availableRows().length === 0) {
            Text('没有可添加的书源').fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary)
              .width('100%').padding({ top: 12, bottom: 12 })
          } else {
            // 上游 `LazyColumn(heightIn(max = 560.dp), spacedBy(8.dp))` + `SourcePickerItem`。
            ForEach(this.availableRows(), (row: SourcePickerRow) => {
              SelectionItemCard({
                title: row.name,
                subtitle: row.group.length > 0 ? row.group : row.url,
                isSelected: false,
                inSelectionMode: false,
                containerColor: this.themeColorOnSheetContent,
                contentDescription: `${row.name}，点击添加`,
                onToggleSelection: () => this.toggle(row.url)
              }).margin({ bottom: 8 })
            }, (row: SourcePickerRow) => 'avail-' + row.url)
          }
        }.width('100%')
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }
}
