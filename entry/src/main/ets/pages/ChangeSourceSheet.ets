// 换源面板（P8）：候选源列表 + 迁移选项 + 换源执行。
// 挂 Index 根的条件覆盖组件（不用 bindSheet：BookInfoPage 已占用同组件的 sheet 槽），
// 搜索与校验在面板内完成，确认后把候选交给 Index 落库（Index 持有书架与进度写入能力）。
import { Book } from '../model/Book';
import {
  ChangeSourceCoordinator, ChangeSourceCandidate, ChangeSourceMigrationOptions, defaultMigrationOptions
} from '../bookSource/ChangeSourceCoordinator';
import { BookSourceRepository } from '../data/BookSourceRepository';

@Component
export struct ChangeSourceSheet {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  book: Book | null = null;
  onClose: () => void = () => {};
  /** 确认换源：Index 负责迁移进度、替换书与目录、清缓存。 */
  onConfirm: (candidate: ChangeSourceCandidate, options: ChangeSourceMigrationOptions) => Promise<void> =
    async (_c: ChangeSourceCandidate, _o: ChangeSourceMigrationOptions): Promise<void> => {};

  @State candidates: ChangeSourceCandidate[] = [];
  @State selectedUrl: string = '';
  @State searching: boolean = true;
  @State options: ChangeSourceMigrationOptions = defaultMigrationOptions();
  @State resultMessage: string = '';

  aboutToAppear(): void {
    this.runSearch();
  }

  private async runSearch(): Promise<void> {
    if (this.book === null) { return; }
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    this.searching = true;
    this.candidates = [];
    this.resultMessage = '';
    await BookSourceRepository.load(context);
    const list = await ChangeSourceCoordinator.searchCandidates(
      this.book.title, this.book.author, this.book.origin ?? ''
    );
    this.candidates = list;
    // 默认选第一个校验通过的候选。
    const first = list.find((c: ChangeSourceCandidate) => c.verified);
    if (first !== undefined) { this.selectedUrl = first.sourceUrl; }
    this.searching = false;
    if (list.length === 0) { this.resultMessage = '没有可用的候选源'; }
  }

  private selectedCandidate(): ChangeSourceCandidate | undefined {
    return this.candidates.find((c: ChangeSourceCandidate) => c.sourceUrl === this.selectedUrl);
  }

  private async confirm(): Promise<void> {
    const picked = this.selectedCandidate();
    if (picked === undefined || !picked.verified) {
      this.resultMessage = '请选择一个校验通过的候选源';
      return;
    }
    this.resultMessage = '正在换源…';
    await this.onConfirm(picked, this.options);
    this.onClose();
  }

  @Builder
  CandidateView(item: ChangeSourceCandidate) {
    Row() {
      Column() {
        Text(item.sourceName).fontSize(15).fontColor(this.themeColorTextPrimary).maxLines(1)
        Text(item.verified
          ? `${item.chapterCount} 章 · 校验通过`
          : (item.message.length > 0 ? item.message : '校验失败'))
          .fontSize(12).fontColor(item.verified ? this.themeColorAccent : this.themeColorTextTertiary)
          .margin({ top: 4 }).maxLines(2)
        if (item.book !== null) {
          Text(item.book.name + (item.book.author.length > 0 ? ' · ' + item.book.author : ''))
            .fontSize(11).fontColor(this.themeColorTextTertiary).margin({ top: 3 }).maxLines(1)
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (item.sourceUrl === this.selectedUrl && item.verified) {
        Text('✓').fontSize(18).fontColor(this.themeColorAccent)
      }
    }.width('100%').padding(12)
      .backgroundColor(this.itemBackground(item))
      .borderRadius(12).margin({ bottom: 8 })
      .onClick(() => {
        if (item.verified) { this.selectedUrl = item.sourceUrl; }
      })
  }

  private itemBackground(item: ChangeSourceCandidate): string {
    if (item.sourceUrl === this.selectedUrl && item.verified) { return this.themeColorAccent; }
    return this.themePureBlack ? '#1E1F26' : this.themeColorSurfaceElevated;
  }

  @Builder
  OptionRow(label: string, checked: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label).fontSize(14).fontColor(this.themeColorTextPrimary).layoutWeight(1)
      Toggle({ type: ToggleType.Checkbox, isOn: checked })
        .onChange((v: boolean) => onChange(v))
    }.width('100%').padding({ top: 8, bottom: 8 })
  }

  build() {
    Stack() {
      // 上半透明遮罩，点空白处关闭。
      Column()
        .width('100%').height('100%')
        .backgroundColor(this.themePureBlack ? '#99000000' : '#66000000')
        .onClick(() => this.onClose())

      Column() {
        Row() {
          Text('换源').fontSize(19).fontColor(this.themeColorTextPrimary).layoutWeight(1)
          Text('✕').fontSize(18).fontColor(this.themeColorTextTertiary)
            .onClick(() => this.onClose())
        }.width('100%').padding({ bottom: 12 })

        if (this.searching) {
          Row() {
            Text('正在搜索候选源并校验目录…').fontSize(13).fontColor(this.themeColorTextTertiary)
          }.width('100%').justifyContent(FlexAlign.Center).padding(24)
        } else if (this.candidates.length > 0) {
          Scroll() {
            Column() {
              ForEach(this.candidates, (item: ChangeSourceCandidate) => {
                this.CandidateView(item)
              }, (item: ChangeSourceCandidate) => item.sourceUrl)
            }.width('100%')
          }.width('100%').layoutWeight(1).scrollBar(BarState.Off)

          Column() {
            this.OptionRow('迁移阅读进度', this.options.migrateProgress, (v: boolean) => {
              this.options = { migrateProgress: v, migrateMetadata: this.options.migrateMetadata };
            })
            this.OptionRow('迁移封面与简介', this.options.migrateMetadata, (v: boolean) => {
              this.options = { migrateProgress: this.options.migrateProgress, migrateMetadata: v };
            })
          }.width('100%').padding({ top: 8, bottom: 8 })
        } else {
          Row() {
            Text(this.resultMessage.length > 0 ? this.resultMessage : '没有候选源')
              .fontSize(13).fontColor(this.themeColorTextTertiary)
          }.width('100%').justifyContent(FlexAlign.Center).padding(24)
        }

        if (this.resultMessage.length > 0 && !this.searching) {
          Text(this.resultMessage).fontSize(12).fontColor(this.themeColorTextTertiary)
            .margin({ bottom: 6 })
        }

        Row() {
          Text('取消').fontSize(15).fontColor(this.themeColorTextTertiary)
            .padding({ left: 24, right: 24, top: 12, bottom: 12 })
            .onClick(() => this.onClose())
          Text('确认换源').fontSize(15).fontColor('#FFFFFF')
            .backgroundColor(this.themeColorAccent).borderRadius(10)
            .padding({ left: 24, right: 24, top: 12, bottom: 12 })
            .onClick(() => this.confirm())
        }.width('100%').justifyContent(FlexAlign.SpaceEvenly).margin({ top: 8 })
      }
      .width('100%')
      .height('72%')
      .align(Alignment.Bottom)
      .backgroundColor(this.themePureBlack ? '#121216' : '#F2F3F6')
      .borderRadius({ topLeft: 20, topRight: 20 })
      .padding({ left: 20, right: 20, top: 20, bottom: 24 })
      .onClick((_e: ClickEvent) => { /* 阻止冒泡到遮罩 */ })
    }.width('100%').height('100%')
  }
}
