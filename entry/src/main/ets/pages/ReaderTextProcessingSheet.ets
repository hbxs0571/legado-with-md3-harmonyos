import { Book } from '../model/Book';
import { AppGlyph } from '../components/AppGlyph';
import { BookCover } from '../components/BookCover';
import { ReplaceRule, replaceRuleRowKey } from '../model/ReplaceRule';
import { BookContentProcess, ContentProcessDisplayItem, toContentProcessDisplayItem } from '../model/BookContentProcess';

/** 规则行高度（含 7dp 下间距），拖拽换位按这个步长判定。 */
const RULE_ROW_HEIGHT: number = 67;
const READER_REPLACE_FILTERS: string[] = ['全部', '已启用', '已停用', '当前有效'];

@Component
export struct ReaderTextProcessingSheet {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0, isLocal: true
  };
  @Prop chapterTitle: string = '';
  @Prop replaceEnabled: boolean = true;
  @Prop replaceUsesDefault: boolean = true;
  @Prop rules: ReplaceRule[] = [];
  @Prop contentProcesses: BookContentProcess[] = [];
  @Prop effectiveRuleIds: number[] = [];
  @State activeTab: number = 0;
  @State replaceQuery: string = '';
  @State contentQuery: string = '';
  /** 正在拖动的规则行下标（-1 表示没在拖）。 */
  @State dragRuleIndex: number = -1;
  /** 拖动已消费的纵向位移，用于「每半行换一次位」复位。 */
  @State dragRuleOffset: number = 0;
  /** 拖拽期间的规则 id 草稿顺序；空数组表示跟随 rules 原顺序。 */
  @State ruleOrderDraft: number[] = [];
  @State replaceFilter: string = '当前有效';
  @State viewedProcess: ContentProcessDisplayItem | undefined = undefined;
  @State deleteProcess: ContentProcessDisplayItem | undefined = undefined;
  onClose: () => void = () => {};
  onOpenReplaceRules: () => void = () => {};
  onReplaceEnabledChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onReplaceResetToDefault: () => void = () => {};
  onRuleEnabledChange: (id: number, enabled: boolean) => void = (_id: number, _enabled: boolean) => {};
  /** 拖拽松手后回传新的规则顺序（按规则 id）；上游对应 MoveReplaceRule。 */
  onRuleReorder: (orderedIds: number[]) => void = (_orderedIds: number[]) => {};
  onContentProcessToggle: (id: string, enabled: boolean) => void = (_id: string, _enabled: boolean) => {};
  onContentProcessDelete: (id: string) => void = (_id: string) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  aboutToAppear(): void {
    this.activeTab = 0;
    this.replaceQuery = '';
    this.contentQuery = '';
    this.replaceFilter = '当前有效';
  }

  @Builder
  private replaceFilterMenu() {
    Menu() {
      ForEach(READER_REPLACE_FILTERS, (filter: string) => {
        MenuItem({ content: filter })
          .onClick(() => this.replaceFilter = filter)
      }, (filter: string) => filter)
    }.backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).fontColor(this.themeColorTextPrimary).radius(18)
  }

  private openFullReplaceRules(): void {
    this.onClose();
    this.onOpenReplaceRules();
  }

  /** 行标题：分组非空时「名称 (分组)」，与上游 TextProcessingSheet.kt:574-575 一致。 */
  private ruleTitle(rule: ReplaceRule): string {
    const name = rule.name.length > 0 ? rule.name : rule.pattern;
    return rule.group.length > 0 ? `${name} (${rule.group})` : name;
  }

  private getVisibleRules(): ReplaceRule[] {
    // 拖拽期间按草稿顺序渲染，松手落库后才回到 rules 的权威顺序。
    const visible: ReplaceRule[] = this.rules.filter((rule: ReplaceRule) => {
      const query = this.replaceQuery.trim().toLowerCase();
      // 上游 TextProcessingSheet.kt:570-572 的搜索同时匹配分组名。
      const matchesQuery = query.length === 0 || rule.name.toLowerCase().includes(query) ||
        rule.pattern.toLowerCase().includes(query) || rule.replacement.toLowerCase().includes(query) ||
        rule.group.toLowerCase().includes(query);
      const matchesFilter = this.replaceFilter === '全部' ||
        (this.replaceFilter === '已启用' && rule.isEnabled) ||
        (this.replaceFilter === '已停用' && !rule.isEnabled) ||
        (this.replaceFilter === '当前有效' && this.replaceEnabled && rule.isEnabled && this.effectiveRuleIds.includes(rule.id));
      return matchesQuery && matchesFilter;
    });
    if (this.ruleOrderDraft.length === 0) { return visible; }
    const ordered: ReplaceRule[] = [];
    this.ruleOrderDraft.forEach((id: number) => {
      const found = visible.find((rule: ReplaceRule) => rule.id === id);
      if (found !== undefined) { ordered.push(found); }
    });
    visible.forEach((rule: ReplaceRule) => {
      if (!ordered.includes(rule)) { ordered.push(rule); }
    });
    return ordered;
  }

  /** 草稿内换位（拖拽用）：成功返回 true，越界返回 false。 */
  private swapDraftRule(from: number, delta: number): boolean {
    const to: number = from + delta;
    if (from < 0 || from >= this.ruleOrderDraft.length) { return false; }
    if (to < 0 || to >= this.ruleOrderDraft.length) { return false; }
    const next: number[] = this.ruleOrderDraft.slice();
    const moved: number[] = next.splice(from, 1);
    if (moved.length === 0) { return false; }
    next.splice(to, 0, moved[0]);
    this.ruleOrderDraft = next;
    return true;
  }

  private getVisibleContentProcesses(): ContentProcessDisplayItem[] {
    const query = this.contentQuery.trim().toLowerCase();
    const visible: ContentProcessDisplayItem[] = [];
    for (const process of this.contentProcesses) {
      const item = toContentProcessDisplayItem(process);
      if (item === undefined) { continue; }
      if (query.length > 0 && !item.selectedText.toLowerCase().includes(query) &&
        !item.replacementText.toLowerCase().includes(query)) {
        continue;
      }
      visible.push(item);
    }
    return visible;
  }

  private processKindTitle(kind: string): string {
    if (kind === 'ai_clean') { return 'AI 净化'; }
    if (kind === 'ai_rewrite') { return 'AI 改写'; }
    return kind;
  }

  private processActionTitle(item: ContentProcessDisplayItem): string {
    if (item.actionType === 'replace') { return '替换'; }
    if (item.actionType === 'delete') { return '删除'; }
    if (item.actionType === 'insert_before' || item.actionType === 'insert_after') { return '插入'; }
    return item.actionType;
  }
  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor('#88000000')
        .onClick(() => this.onClose())
      Column() {
        Row().width(34).height(4).backgroundColor('#C5C6CD').borderRadius(4)
          .alignSelf(ItemAlign.Center).margin({ top: 10, bottom: 14 })
        Row() {
          BookCover({ book: this.book, mini: true }).width(44).height(60).margin({ right: 12 })
          Column() {
            Text(this.book.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#E5E6EB')
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.chapterTitle).fontSize(11).fontColor('#B7B8C1').maxLines(1).margin({ top: 4 })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text(this.activeTab === 0 ? '替换净化' : '正文处理')
            .fontSize(11).fontColor(this.themeColorTextSecondary).padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary)).borderRadius(16)
        }.width('100%').padding({ left: 16, right: 16, bottom: 12 })

        Row() {
          Text('替换净化').fontSize(14).fontColor(this.activeTab === 0 ? '#ECECF2' : '#A9ABB4')
            .textAlign(TextAlign.Center).layoutWeight(1)
            .backgroundColor(this.activeTab === 0 ? '#454B62' : '#202127').borderRadius(18)
            .padding({ top: 10, bottom: 10 }).onClick(() => this.activeTab = 0)
          Text('正文处理').fontSize(14).fontColor(this.activeTab === 1 ? '#ECECF2' : '#A9ABB4')
            .textAlign(TextAlign.Center).layoutWeight(1)
            .backgroundColor(this.activeTab === 1 ? '#454B62' : '#202127').borderRadius(18)
            .padding({ top: 10, bottom: 10 }).onClick(() => this.activeTab = 1)
          if (this.activeTab === 0) {
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'profileFindReplace', glyphSize: 18, tint: this.themeColorTextSecondary })
            }.width(38).height(38).onClick(() => this.openFullReplaceRules())
          }
        }.width('100%').padding({ left: 16, right: 16, bottom: 10 })

        if (this.activeTab === 0) {
          Row() {
            Column() {
              Text('本书启用替换净化').fontSize(13).fontColor(this.themeColorTextPrimary)
              Text(this.replaceEnabled ? '按已启用规则处理正文' : '本书暂不应用替换规则')
                .fontSize(11).fontColor('#999BA5').margin({ top: 3 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.replaceEnabled })
              .onChange((enabled: boolean) => this.onReplaceEnabledChange(enabled))
            if (!this.replaceUsesDefault) {
              Text('使用默认').fontSize(11).fontColor('#B9C8FF').margin({ left: 8 })
                .onClick(() => this.onReplaceResetToDefault())
            }
          }.width('calc(100% - 32vp)').padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .margin({ left: 16, right: 16, bottom: 8 })
            .backgroundColor('#202127').borderRadius(12)
          Row() {
            Row() {
              AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
              TextInput({ text: this.replaceQuery, placeholder: '搜索规则…' })
                .fontSize(13).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
                .backgroundColor(Color.Transparent).layoutWeight(1)
                .onChange((value: string) => this.replaceQuery = value)
            }.layoutWeight(1).height(42).padding({ left: 12, right: 12 })
              .backgroundColor('#202127').borderRadius(12)
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'profileFindReplace', glyphSize: 18, tint: '#A9ABB4' })
            }.width(38).height(42).backgroundColor('#202127').borderRadius(12)
              .onClick(() => this.onReplaceEnabledChange(!this.replaceEnabled))
            Text(this.replaceFilter).fontSize(12).fontColor(this.themeColorTextSecondary)
              .padding({ left: 12, right: 12, top: 12, bottom: 12 })
              .backgroundColor('#292A31').borderRadius(12)
              .bindMenu(this.replaceFilterMenu, { placement: Placement.BottomRight })
          }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
          Scroll() {
            Column() {
              if (this.getVisibleRules().length === 0) {
                Blank().layoutWeight(1)
                Text(this.rules.length === 0 ? '暂无替换净化规则' : '没有符合条件的规则')
                  .fontSize(15).fontColor(this.themeColorTextSecondary)
                Text(this.rules.length === 0 ? '添加规则后会按顺序处理本地正文' : '可以更改搜索词或筛选条件')
                  .fontSize(12).fontColor('#999BA5').margin({ top: 7, bottom: 14 })
                Text('打开规则管理').fontSize(13).fontColor('#D5C2C6')
                  .padding({ left: 15, right: 15, top: 10, bottom: 10 })
                  .backgroundColor('#292A31').borderRadius(18)
                  .onClick(() => this.openFullReplaceRules())
                Blank().layoutWeight(1)
              } else {
                ForEach(this.getVisibleRules(), (rule: ReplaceRule, index: number) => {
                  Row() {
                    // 上游 ReorderableConfigList.kt:239-249 的把手是 32×32，draggableHandle() 直接可拖、
                    // 不需要长按；拖动行本身不抬升（:350）。
                    Stack({ alignContent: Alignment.Center }) {
                      AppGlyph({ name: 'more', glyphSize: 18, tint: '#A9ABB4' })
                    }.width(32).height(32).margin({ right: 6 })
                      .gesture(
                        PanGesture({ direction: PanDirection.Vertical })
                          .onActionStart(() => {
                            this.dragRuleIndex = index;
                            this.dragRuleOffset = 0;
                            this.ruleOrderDraft = this.getVisibleRules().map((item: ReplaceRule) => item.id);
                          })
                          .onActionUpdate((event: GestureEvent) => {
                            const offset: number = event.offsetY;
                            // 每越过半行换一次位；已消费的位移扣掉，避免一次拖动跳多格。
                            while (offset - this.dragRuleOffset > RULE_ROW_HEIGHT / 2) {
                              if (!this.swapDraftRule(this.dragRuleIndex, 1)) { break; }
                              this.dragRuleIndex = this.dragRuleIndex + 1;
                              this.dragRuleOffset = this.dragRuleOffset + RULE_ROW_HEIGHT;
                            }
                            while (offset - this.dragRuleOffset < -RULE_ROW_HEIGHT / 2) {
                              if (!this.swapDraftRule(this.dragRuleIndex, -1)) { break; }
                              this.dragRuleIndex = this.dragRuleIndex - 1;
                              this.dragRuleOffset = this.dragRuleOffset - RULE_ROW_HEIGHT;
                            }
                          })
                          .onActionEnd(() => {
                            // 松手才落库（上游 MoveReplaceRule 在 onDragEnd 才发）。
                            const order: number[] = this.ruleOrderDraft;
                            this.dragRuleIndex = -1;
                            this.dragRuleOffset = 0;
                            this.ruleOrderDraft = [];
                            if (order.length > 0) { this.onRuleReorder(order); }
                          })
                      )
                    Column() {
                      Text(this.ruleTitle(rule)).fontSize(13)
                        .fontColor(this.themeColorTextPrimary).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(`${rule.pattern} → ${rule.replacement}`).fontSize(11).fontColor('#999BA5')
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 })
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    Toggle({ type: ToggleType.Switch, isOn: rule.isEnabled })
                      .onChange((enabled: boolean) => this.onRuleEnabledChange(rule.id, enabled))
                  }.width('100%').padding({ left: 2, right: 12, top: 10, bottom: 10 })
                    .backgroundColor('#202127').borderRadius(10).margin({ bottom: 7 })
                    // 停用态整行 alpha 0.38（上游 TextProcessingSheet 行禁用态口径）。
                    .opacity(rule.isEnabled ? 1 : 0.38)
                }, (rule: ReplaceRule) => replaceRuleRowKey(rule))
              }
            }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
          }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
        } else {
          Row() {
            AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
            TextInput({ text: this.contentQuery, placeholder: '搜索正文处理记录…' })
              .fontSize(13).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
              .backgroundColor(Color.Transparent).layoutWeight(1)
              .onChange((value: string) => this.contentQuery = value)
          }.width('calc(100% - 32vp)').height(42).padding({ left: 12, right: 12 })
            .margin({ left: 16, right: 16, bottom: 10 })
            .backgroundColor('#202127').borderRadius(12)
          Scroll() {
            Column() {
              if (this.getVisibleContentProcesses().length === 0) {
                Blank().layoutWeight(1)
                Text(this.contentProcesses.length === 0 ? '暂无正文处理记录' : '没有符合条件的正文处理记录')
                  .fontSize(15).fontColor(this.themeColorTextSecondary)
                Text(this.contentProcesses.length === 0 ? '当前章节没有正文处理' : '可以更改搜索词')
                  .fontSize(12).fontColor('#999BA5').margin({ top: 7 })
                Blank().layoutWeight(1)
              } else {
                ForEach(this.getVisibleContentProcesses(), (item: ContentProcessDisplayItem) => {
                  Row() {
                    Column() {
                      Text(`${this.processKindTitle(item.kind)} · ${this.processActionTitle(item)}`)
                        .fontSize(13).fontColor(this.themeColorTextPrimary).maxLines(1)
                      Text(item.selectedText).fontSize(11).fontColor('#999BA5')
                        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 })
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    Toggle({ type: ToggleType.Switch, isOn: item.enabled })
                      .onChange((enabled: boolean) => this.onContentProcessToggle(item.id, enabled))
                    Text('删除').fontSize(11).fontColor('#E7A5AC').margin({ left: 10 })
                      .onClick(() => this.deleteProcess = item)
                  }.width('100%').padding({ left: 12, right: 12, top: 10, bottom: 10 })
                    .backgroundColor('#202127').borderRadius(10).margin({ bottom: 7 })
                    .onClick(() => this.viewedProcess = item)
                }, (item: ContentProcessDisplayItem) => item.id)
              }
            }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
          }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
        }
        Row() {
          Text('关闭').fontSize(13).fontColor(this.themeColorTextSecondary).textAlign(TextAlign.Center).layoutWeight(1)
            .padding({ top: 10, bottom: 10 }).onClick(() => this.onClose())
        }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 16 })
      }
      .width('100%').height('72%').backgroundColor(this.themeColorSurfaceSecondary)
      .borderRadius({ topLeft: 24, topRight: 24 })
      .onClick(() => {})
      if (this.viewedProcess !== undefined) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#99000000')
            .onClick(() => this.viewedProcess = undefined)
          Column() {
            Text(`${this.processKindTitle(this.viewedProcess.kind)} · ${this.processActionTitle(this.viewedProcess)}`)
              .fontSize(16).fontColor('#ECECF2').margin({ bottom: 14 })
            Text('处理前').fontSize(12).fontColor('#A9ABB4').width('100%')
            Text(this.viewedProcess.selectedText).fontSize(14).fontColor(this.themeColorTextPrimary)
              .width('100%').margin({ top: 4, bottom: 12 })
            Text('处理后').fontSize(12).fontColor('#A9ABB4').width('100%')
            Text(this.viewedProcess.actionType === 'delete' ? '已删除选中文本' : this.viewedProcess.replacementText)
              .fontSize(14).fontColor(this.themeColorTextPrimary).width('100%').margin({ top: 4, bottom: 16 })
            Text('关闭').fontSize(13).fontColor(this.themeColorTextSecondary).alignSelf(ItemAlign.End)
              .onClick(() => this.viewedProcess = undefined)
          }.width('88%').padding(18).backgroundColor('#202127').borderRadius(18).onClick(() => {})
        }.width('100%').height('100%')
      }
      if (this.deleteProcess !== undefined) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#99000000')
            .onClick(() => this.deleteProcess = undefined)
          Column() {
            Text('删除正文处理记录？').fontSize(16).fontColor('#ECECF2')
            Text(this.deleteProcess.selectedText).fontSize(13).fontColor('#A9ABB4')
              .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%').margin({ top: 10, bottom: 20 })
            Row() {
              Text('取消').fontSize(13).fontColor('#C5C7D0').layoutWeight(1).textAlign(TextAlign.Center)
                .onClick(() => this.deleteProcess = undefined)
              Text('删除').fontSize(13).fontColor('#E7A5AC').layoutWeight(1).textAlign(TextAlign.Center)
                .onClick(() => {
                  const item = this.deleteProcess;
                  if (item !== undefined) {
                    this.onContentProcessDelete(item.id);
                  }
                  this.deleteProcess = undefined;
                })
            }.width('100%')
          }.width('88%').padding(18).backgroundColor('#202127').borderRadius(18).onClick(() => {})
        }.width('100%').height('100%')
      }    }.width('100%').height('100%')
  }
}
