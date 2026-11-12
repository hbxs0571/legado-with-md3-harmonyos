import { AppGlyph } from '../components/AppGlyph';

/** 确认页里的一行待导入文件。 */
export interface ImportCandidate {
  uri: string;
  fileName: string;
  /** 仅用于列表展示，取不到时留空。 */
  sizeLabel: string;
  /** 已在书架：书名命中且正文不缺失。 */
  onShelf: boolean;
  selected: boolean;
}

/**
 * 本地书导入确认页（批 10 的 :555）。
 *
 * 鸿蒙的 DocumentViewPicker 只回 uri 列表，没有「目录枚举」能力，
 * 所以上游那种「浏览文件夹、逐项标已上架」的列表页在本地做成「多选之后的确认页」：
 * 列出这次选中的文件、标出已在书架的、可取消勾选、点导入。
 * 功能目的一致（导入前就知道哪本已上架），交互形态不同。
 */
@Component
export struct LocalBookImportPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C21';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#5C5F6B';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#858792';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#EDEEF2';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '#F5F6F8';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;

  @Prop candidates: ImportCandidate[] = [];
  onBack: () => void = () => {};
  onImportSelected: (uris: string[]) => Promise<void> = async (_uris: string[]) => {};

  @State items: ImportCandidate[] = [];
  @State busy: boolean = false;

  aboutToAppear(): void {
    this.items = this.copyItems(this.candidates);
  }

  /** ArkTS 不认对象展开，逐字段复制。 */
  private copyItems(source: ImportCandidate[]): ImportCandidate[] {
    const result: ImportCandidate[] = [];
    for (let index = 0; index < source.length; index += 1) {
      const item = source[index];
      if (item === undefined) {
        continue;
      }
      const copy: ImportCandidate = {
        uri: item.uri,
        fileName: item.fileName,
        sizeLabel: item.sizeLabel,
        onShelf: item.onShelf,
        selected: item.selected
      };
      result.push(copy);
    }
    return result;
  }

  private selectedCount(): number {
    let count = 0;
    for (let index = 0; index < this.items.length; index += 1) {
      const item = this.items[index];
      if (item !== undefined && item.selected) {
        count += 1;
      }
    }
    return count;
  }

  /** 勾选态整体替换：@State 不认数组内原地改。 */
  private toggle(index: number): void {
    const next: ImportCandidate[] = [];
    for (let cursor = 0; cursor < this.items.length; cursor += 1) {
      const item = this.items[cursor];
      if (item === undefined) {
        continue;
      }
      const copy: ImportCandidate = {
        uri: item.uri,
        fileName: item.fileName,
        sizeLabel: item.sizeLabel,
        onShelf: item.onShelf,
        selected: cursor === index ? !item.selected : item.selected
      };
      next.push(copy);
    }
    this.items = next;
  }

  private async submit(): Promise<void> {
    if (this.busy) {
      return;
    }
    const uris: string[] = [];
    for (let index = 0; index < this.items.length; index += 1) {
      const item = this.items[index];
      if (item !== undefined && item.selected) {
        uris.push(item.uri);
      }
    }
    if (uris.length === 0) {
      return;
    }
    this.busy = true;
    try {
      await this.onImportSelected(uris);
    } finally {
      this.busy = false;
    }
  }

  @Builder
  private CandidateRow(item: ImportCandidate, index: number) {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        if (item.selected) {
          Circle().width(22).height(22).fill('#3F5BD9');
          AppGlyph({ name: 'profileCheck', glyphSize: 14, tint: '#FFFFFF' });
        } else {
          Circle().width(22).height(22).fill(Color.Transparent).stroke('#6C7080').strokeWidth(1.5);
        }
      }
      .width(30)
      .height(30)
      .onClick(() => this.toggle(index));

      Column() {
        Text(item.fileName)
          .fontSize(15)
          .fontColor(this.themeColorTextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%');
        Row() {
          Text(item.onShelf ? '已在书架' : '未上架')
            .fontSize(11)
            .fontColor(item.onShelf ? '#3F5BD9' : this.themeColorTextTertiary);
          if (item.sizeLabel.length > 0) {
            Text(' · ' + item.sizeLabel)
              .fontSize(11)
              .fontColor(this.themeColorTextTertiary);
          }
        }
        .width('100%')
        .margin({ top: 3 });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 });
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.themePureBlack ? '#000000' : this.themeColorSurfaceElevated)
    .borderRadius(10)
    .margin({ bottom: 8 })
    .onClick(() => this.toggle(index));
  }

  build() {
    Column() {
      // 顶栏。返回按钮沿用 BookshelfManagePage 的「‹ 返回」文本按钮：
      // AppGlyphName 里没有返回箭头图标（只有 profileClose 等），不为此新增图标。
      Row() {
        Text('‹ 返回')
          .fontSize(14)
          .fontColor('#3F5BD9')
          .padding({ right: 4 })
          .onClick(() => this.onBack());

        Text('导入本地书')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorTextPrimary)
          .margin({ left: 12 })
          .layoutWeight(1);

        Text(this.busy ? '导入中…' : `导入 ${this.selectedCount()} 本`)
          .fontSize(14)
          .fontColor(this.selectedCount() > 0 && !this.busy ? '#3F5BD9' : this.themeColorTextTertiary)
          .padding({ left: 12, right: 4 })
          .onClick(() => {
            this.submit();
          });
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 });

      Text('已选文件（已在书架的可以跳过；取消勾选后不导入）')
        .fontSize(12)
        .fontColor(this.themeColorTextTertiary)
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 });

      Scroll() {
        Column() {
          ForEach(this.items, (item: ImportCandidate, index: number) => {
            this.CandidateRow(item, index);
          }, (item: ImportCandidate) => item.uri + '_' + (item.onShelf ? '1' : '0') + '_' +
          (item.selected ? '1' : '0'));
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 18 });
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themePureBlack ? '#000000' : this.themeAppBackground);
  }
}
