/** “我的”菜单下与 Android 页面结构对应的二级页面。 */
import { bundleManager } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import {
  PROFILE_PAGE_SUBTITLE_SIZE,
  PROFILE_PAGE_TITLE_SIZE,
  PROFILE_ROW_DETAIL_SIZE,
  PROFILE_ROW_TITLE_SIZE,
  PROFILE_ROW_VERTICAL_PADDING
} from '../components/ProfileUiMetrics';
import { ProfileRoute } from '../model/Book';

@Component
export struct BookSourceManagePage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop groups: string[] = [];
  @State selectedGroup: string = '';
  @State showSearch: boolean = false;
  @State searchQuery: string = '';

  build() {
    Column() {
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
          .width(36).onClick(() => this.onBack())
        Column() {
          Text('书源管理').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
          Text(this.selectedGroup.length === 0 ? '全部书源' : this.selectedGroup)
            .fontSize(PROFILE_PAGE_SUBTITLE_SIZE).fontColor('#92949E').margin({ top: 3 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        AppGlyph({ name: 'list', glyphSize: 19, tint: '#D8D9E0' }).padding({ left: 8, right: 8 })
          .onClick(() => this.onUnavailableAction('书源分组管理将在书源数据接入后提供'))
        AppGlyph({ name: 'search', glyphSize: 19, tint: '#D8D9E0' }).padding({ left: 8, right: 8 })
          .onClick(() => { this.showSearch = !this.showSearch; if (!this.showSearch) { this.searchQuery = ''; } })
        AppGlyph({ name: 'more', glyphSize: 18, tint: '#D8D9E0' }).padding({ left: 6, right: 8 })
          .onClick(() => this.onUnavailableAction('书源导入、排序和批量管理将在书源数据接入后提供'))
      }.width('100%').padding({ left: 12, right: 10, top: 11, bottom: 9 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索书源名称或 URL…', text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .onChange((value: string) => this.searchQuery = value)
        }.width('100%').padding({ left: 12, right: 14, top: 7, bottom: 7 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(22)
      }

      if (this.groups.length > 0) {
        Scroll() {
          Row() {
            ModuleTab({ label: '全部', selected: this.selectedGroup.length === 0, onSelect: () => this.selectedGroup = '' })
            ForEach(this.groups, (group: string) => {
              ModuleTab({ label: group, selected: this.selectedGroup === group, onSelect: () => this.selectedGroup = group })
            })
          }.width('100%').padding({ left: 16, right: 9, top: 8, bottom: 12 })
        }.scrollBar(BarState.Off)
      }

      ModuleEmpty({
        icon: 'web',
        title: this.searchQuery.length > 0 ? '没有匹配的书源' : '暂无书源',
        detail: '书源条目会显示名称、URL、分组、启用状态和发现能力'
      }).layoutWeight(1)
      Row() {
        Image($r('app.media.app_add')).width(18).height(18).fillColor('#151720')
        Text('添加书源').fontSize(15).fontColor('#151720').margin({ left: 7 })
      }.justifyContent(FlexAlign.Center).padding({ left: 20, right: 20, top: 13, bottom: 13 })
        .backgroundColor('#B9C8FF').borderRadius(28).margin({ right: 20, bottom: 18 }).alignSelf(ItemAlign.End)
        .onClick(() => this.onUnavailableAction('书源编辑与保存将在书源阶段接入'))
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
export struct ReplaceRulesPage {
  onBack: () => void = () => {};
  onOpenEditor: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop groups: string[] = [];
  @State selectedGroup: string = '';
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State sortMode: string = 'asc';

  @Builder
  private ReplaceRuleMenu() {
    Menu() {
      MenuItem({ content: '导入' })
        .onClick(() => this.onUnavailableAction('替换规则导入尚未接入，未导入任何数据'))
      MenuItem({ content: '分组管理' })
        .onClick(() => this.onUnavailableAction('替换规则分组数据尚未接入'))
      MenuItem({ content: '旧的在前' })
        .onClick(() => { this.sortMode = 'asc'; this.onUnavailableAction('排序已切换：旧的在前') })
      MenuItem({ content: '新的在前' })
        .onClick(() => { this.sortMode = 'desc'; this.onUnavailableAction('排序已切换：新的在前') })
      MenuItem({ content: '名称升序' })
        .onClick(() => { this.sortMode = 'name_asc'; this.onUnavailableAction('排序已切换：名称升序') })
      MenuItem({ content: '名称降序' })
        .onClick(() => { this.sortMode = 'name_desc'; this.onUnavailableAction('排序已切换：名称降序') })
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40)
          .onClick(() => { this.showSearch = !this.showSearch; if (!this.showSearch) { this.searchQuery = ''; } })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40)
          .bindMenu(this.ReplaceRuleMenu, { placement: Placement.BottomRight })
      }.width('100%').height(40).padding({ left: 11, right: 12 })
        .margin({ top: -8 })

      Text('替换净化').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
        .width('100%').padding({ left: 12, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索', text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_replace_rule_search')
            .onAppear(() => focusControl.requestFocus('my_replace_rule_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(24)
      }

      if (this.groups.length > 0) {
        Scroll() {
          Row() {
            ModuleTab({ label: '全部', selected: this.selectedGroup.length === 0, onSelect: () => this.selectedGroup = '' })
            ForEach(this.groups, (group: string) => {
              ModuleTab({ label: group, selected: this.selectedGroup === group, onSelect: () => this.selectedGroup = group })
            })
          }.width('100%').padding({ left: 16, right: 9, top: 8, bottom: 12 })
        }.scrollBar(BarState.Off)
      }

      Blank().layoutWeight(1)
      Stack({ alignContent: Alignment.Center }) {
        AppGlyph({ name: 'add', glyphSize: 22, tint: '#B9C8FF' })
      }.width(50).height(50).backgroundColor('#454F70').borderRadius(14)
        .onClick(() => this.onOpenEditor())
        .margin({ right: 16, bottom: 16 }).alignSelf(ItemAlign.End)
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
export struct ReplaceRuleEditPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State name: string = '';
  @State group: string = '默认';
  @State pattern: string = '';
  @State replacement: string = '';
  @State scopeTitle: boolean = false;
  @State scopeContent: boolean = false;
  @State isRegex: boolean = false;
  @State scope: string = '';
  @State excludeScope: string = '';
  @State timeout: string = '3000';
  @State keyboardVisible: boolean = false;
  @State showPasteAuthorization: boolean = false;
  @State activeField: string = 'pattern';

  @Builder
  private RuleActionsMenu() {
    Menu() {
      MenuItem({ content: '拷贝规则' })
        .onClick(() => this.copyRule())
      MenuItem({ content: '粘贴规则' })
        .onClick(() => this.showPasteAuthorization = true)
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  @Builder
  private GroupMenu() {
    Menu() {
      MenuItem({ content: '默认' }).onClick(() => this.group = '默认')
      MenuItem({ content: '分组管理' })
        .onClick(() => this.onUnavailableAction('替换规则分组数据尚未接入'))
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  private clipboardJson(): string {
    return JSON.stringify({
      id: Date.now(), name: this.name, group: this.group, pattern: this.pattern,
      replacement: this.replacement, scope: this.scope, scopeTitle: this.scopeTitle,
      scopeContent: this.scopeContent, excludeScope: this.excludeScope,
      isEnabled: true, isRegex: this.isRegex,
      timeoutMillisecond: Number(this.timeout) || 3000, order: -2147483648
    });
  }

  private async copyRule(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.clipboardJson());
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制到剪贴板');
    } catch (_error) {
      this.onUnavailableAction('复制规则失败');
    }
  }

  private async pasteRule(result: PasteButtonOnClickResult): Promise<void> {
    this.showPasteAuthorization = false;
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得读取剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onUnavailableAction('剪贴板为空');
        return;
      }
      const parsed: ReplaceRuleClipboardData = JSON.parse(data.getRecord(0).toPlainText());
      if (typeof parsed.name !== 'string' || typeof parsed.pattern !== 'string' ||
        typeof parsed.replacement !== 'string') {
        this.onUnavailableAction('剪贴板规则格式无效');
        return;
      }
      this.name = parsed.name;
      this.group = typeof parsed.group === 'string' ? parsed.group : '默认';
      this.pattern = parsed.pattern;
      this.replacement = parsed.replacement;
      this.scope = typeof parsed.scope === 'string' ? parsed.scope : '';
      this.scopeTitle = parsed.scopeTitle === true;
      this.scopeContent = parsed.scopeContent !== false;
      this.excludeScope = typeof parsed.excludeScope === 'string' ? parsed.excludeScope : '';
      this.isRegex = parsed.isRegex !== false;
      this.timeout = typeof parsed.timeoutMillisecond === 'number' ? `${parsed.timeoutMillisecond}` : '3000';
      this.onUnavailableAction('规则已从剪贴板填入');
    } catch (_error) {
      this.onUnavailableAction('剪贴板规则格式无效');
    }
  }

  private insertQuickText(value: string): void {
    if (this.activeField === 'name') { this.name += value; }
    else if (this.activeField === 'replacement') { this.replacement += value; }
    else if (this.activeField === 'scope') { this.scope += value; }
    else if (this.activeField === 'excludeScope') { this.excludeScope += value; }
    else if (this.activeField === 'timeout') { this.timeout += value; }
    else { this.pattern += value; }
  }

  private saveRule(): void {
    if (this.pattern.trim().length === 0) {
      this.onUnavailableAction('替换规则为空或者不满足正则表达式要求');
      return;
    }
    if (this.isRegex) {
      try {
        new RegExp(this.pattern);
        if (this.pattern.endsWith('|') && !this.pattern.endsWith('\\|')) {
          this.onUnavailableAction('替换规则为空或者不满足正则表达式要求');
          return;
        }
      } catch (_error) {
        this.onUnavailableAction('替换规则为空或者不满足正则表达式要求');
        return;
      }
    }
    this.onUnavailableAction('替换规则存储尚未接入，规则未保存');
  }

  @Builder
  private RuleField(label: string, value: string, field: string) {
    Column() {
      TextInput({ placeholder: label, text: value })
        .fontSize(16).fontColor('#E3E4E8').placeholderColor('#C3C5CD')
        .height(50).backgroundColor('#24252C').borderRadius(8).padding({ left: 14, right: 14 })
        .width('100%')
        .onFocus(() => { this.activeField = field; this.keyboardVisible = true; })
        .onBlur(() => this.keyboardVisible = false)
        .onChange((text: string) => {
          if (field === 'name') { this.name = text; }
          else if (field === 'pattern') { this.pattern = text; }
          else if (field === 'replacement') { this.replacement = text; }
          else if (field === 'scope') { this.scope = text; }
          else if (field === 'excludeScope') { this.excludeScope = text; }
          else if (field === 'timeout') { this.timeout = text; }
        })
      Row().width('100%').height(1).backgroundColor('#898B94')
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 12 })
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        if (this.keyboardVisible) {
          Stack({ alignContent: Alignment.Center }) {
            Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
            AppGlyph({ name: 'profileSave', glyphSize: 20, tint: '#D8D9E0' })
          }.width(40).height(40).margin({ right: 8 })
            .onClick(() => this.saveRule())
        }
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40)
          .bindMenu(this.RuleActionsMenu, { placement: Placement.BottomRight })
      }.width('100%').height(40).padding({ left: 11, right: 12 })
        .margin({ top: -8 })
      Text('新建替换').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
        .width('100%').padding({ left: 14, right: 0, top: 12, bottom: 0 })
      Scroll() {
        Column() {
          this.RuleField('规则名称', this.name, 'name')
          Row() {
            Column() {
              Row() {
                Blank().width(14)
                Text('分组').fontSize(14).fontColor('#C3C5CD').textAlign(TextAlign.Start)
              }.width('100%')
              Row() {
                Blank().width(14)
                Text(this.group).fontSize(15).fontColor('#E3E4E8').layoutWeight(1)
                AppGlyph({ name: 'profileExpandMore', glyphSize: 20, tint: '#D8D9E0' })
                Blank().width(14)
              }.width('100%')
              Row().width('calc(100% - 4vp)').height(1).backgroundColor('#898B94').margin({ left: 2, right: 2 })
            }.width('calc(100% - 40vp)').height(56).justifyContent(FlexAlign.Center)
              .backgroundColor('#24252C').borderRadius(8)
              .bindMenu(this.GroupMenu, { placement: Placement.BottomRight })
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'profileSettings', glyphSize: 20, tint: '#D8D9E0' })
            }.width(48).height(56).onClick(() => this.onUnavailableAction('替换规则分组数据尚未接入'))
          }.width('100%')
          Blank().height(12)
          this.RuleField('匹配规则', this.pattern, 'pattern')
          this.RuleField('替换为', this.replacement, 'replacement')
          Row() {
            ReplaceScopeChip({ label: '标题', selected: this.scopeTitle,
              onSelect: () => this.scopeTitle = !this.scopeTitle })
            ReplaceScopeChip({ label: '内容', selected: this.scopeContent,
              onSelect: () => this.scopeContent = !this.scopeContent })
            Blank().layoutWeight(1)
            ReplaceScopeChip({ label: '正则', selected: this.isRegex,
              onSelect: () => this.isRegex = !this.isRegex })
          }.width('100%').margin({ top: 12, bottom: 15 })
          this.RuleField('特定范围', this.scope, 'scope')
          this.RuleField('排除范围', this.excludeScope, 'excludeScope')
          Column() {
            Text('超时 (ms)').fontSize(14).fontColor('#C3C5CD').width('100%').textAlign(TextAlign.Start)
            TextInput({ text: this.timeout, placeholder: '3000' })
              .fontSize(16).fontColor('#E3E4E8').backgroundColor(Color.Transparent)
              .height(30).padding({ left: 0, right: 0 }).width('100%')
              .onFocus(() => { this.activeField = 'timeout'; this.keyboardVisible = true; })
              .onBlur(() => this.keyboardVisible = false)
              .onChange((text: string) => this.timeout = text)
            Row().width('100%').height(1).backgroundColor('#898B94')
          }.width('100%').height(56).alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Center)
            .padding({ left: 14, right: 14 }).backgroundColor('#24252C').borderRadius(8)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 0, bottom: 140 })
          .layoutWeight(1)
      }.layoutWeight(1).scrollBar(BarState.Off)
      if (this.keyboardVisible) {
        Scroll() {
          Row() {
            ForEach(['.*', '\\d+', '\\w+', '[]', '()', '^', '$', '|', '{}', '<>'], (symbol: string) => {
              Text(symbol).fontSize(14).fontColor('#D8D9E0').padding({ left: 10, right: 10, top: 7, bottom: 7 })
                .backgroundColor('#303139').borderRadius(18).margin({ right: 7 })
                .onClick(() => this.insertQuickText(symbol))
            })
          }.padding({ left: 16, right: 16, top: 8, bottom: 8 })
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      }
      Row() {
        if (this.showPasteAuthorization) {
          PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
            .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) => await this.pasteRule(result))
        }
        Blank()
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileSave', glyphSize: 20, tint: '#B9C8FF' })
        }.width(50).height(50).backgroundColor('#454F70').borderRadius(14)
          .visibility(this.keyboardVisible ? Visibility.Hidden : Visibility.Visible)
          .onClick(() => this.saveRule())
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 16 })
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct ReplaceScopeChip {
  @Prop label: string = '';
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Row() {
      if (this.selected) {
        AppGlyph({ name: 'profileCheck', glyphSize: 16, tint: '#D8D9E0' }).margin({ right: 5 })
      }
      Text(this.label).fontSize(14).fontColor('#D8D9E0')
    }.padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor(this.selected ? '#3A4054' : Color.Transparent).borderRadius(12)
      .border({ width: 1, color: '#51535D' }).margin({ right: 8 }).onClick(() => this.onSelect())
  }
}

interface ReplaceRuleClipboardData {
  name?: string;
  group?: string | null;
  pattern?: string;
  replacement?: string;
  scope?: string | null;
  scopeTitle?: boolean;
  scopeContent?: boolean;
  excludeScope?: string | null;
  isRegex?: boolean;
  timeoutMillisecond?: number;
}

@Component
export struct TxtTocRulesPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State showAddRule: boolean = false;
  @State showPasteAuthorization: boolean = false;
  @State ruleName: string = '';
  @State chapterRegex: string = '';
  @State exampleText: string = '';
  @State volumeRegex: string = '';
  @State testError: string = '';
  @State testResults: TxtRuleTestLine[] = [];
  @State testHasRun: boolean = false;

  private buildClipboardRule(): string {
    return JSON.stringify({
      id: Date.now(),
      name: this.ruleName,
      chapterRule: this.chapterRegex,
      volumeRule: this.volumeRegex,
      example: this.exampleText,
      serialNumber: -1,
      enable: true
    });
  }

  private async copyRuleToClipboard(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.buildClipboardRule());
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制到剪贴板');
    } catch (_error) {
      this.onUnavailableAction('复制规则失败');
    }
  }

  private async pasteRuleFromClipboard(result: PasteButtonOnClickResult): Promise<void> {
    this.showPasteAuthorization = false;
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得读取剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onUnavailableAction('剪贴板为空');
        return;
      }
      const text = data.getRecord(0).toPlainText();
      const parsed: TxtRuleClipboardData = JSON.parse(text);
      const chapterRule = parsed.chapterRule ?? parsed.rule;
      if (typeof parsed.name !== 'string' || typeof chapterRule !== 'string' ||
        (typeof parsed.example !== 'string' && parsed.example !== null && parsed.example !== undefined) ||
        (typeof parsed.volumeRule !== 'string' && parsed.volumeRule !== undefined)) {
        this.onUnavailableAction('剪贴板规则格式无效');
        return;
      }
      this.ruleName = parsed.name;
      this.chapterRegex = chapterRule;
      this.exampleText = typeof parsed.example === 'string' ? parsed.example : '';
      this.volumeRegex = parsed.volumeRule ?? '';
      this.clearRuleTest();
      this.onUnavailableAction('规则已从剪贴板填入');
    } catch (_error) {
      this.onUnavailableAction('剪贴板规则格式无效');
    }
  }

  private clearRuleTest(): void {
    this.testError = '';
    this.testResults = [];
    this.testHasRun = false;
  }

  private runRuleTest(): void {
    const pattern = this.chapterRegex.trim();
    const normalized = this.exampleText.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
    if (pattern.length === 0) {
      this.testError = '章节正则不能为空';
      this.testResults = [];
      this.testHasRun = true;
      return;
    }
    if (normalized.trim().length === 0) {
      this.testError = '示例不能为空';
      this.testResults = [];
      this.testHasRun = true;
      return;
    }
    try {
      const regex = new RegExp(pattern, 'gm');
      const text = `\n${normalized}`;
      const ranges: TxtRuleMatchRange[] = [];
      let match = regex.exec(text);
      while (match !== null) {
        ranges.push({ start: match.index, end: match.index + match[0].length });
        if (match[0].length === 0) {
          regex.lastIndex += 1;
        }
        match = regex.exec(text);
      }
      const lines = normalized.split('\n');
      let offset = 1;
      this.testResults = lines.map((line: string): TxtRuleTestLine => {
        const lineStart = offset;
        const lineEnd = offset + line.length;
        const matched = ranges.some((range: TxtRuleMatchRange): boolean => {
          return range.start === range.end
            ? range.start >= lineStart && range.start <= lineEnd
            : range.start < lineEnd && range.end > lineStart;
        });
        offset = lineEnd + 1;
        return { line, matched };
      });
      this.testError = '';
      this.testHasRun = true;
    } catch (_error) {
      this.testError = '正则格式无效';
      this.testResults = [];
      this.testHasRun = true;
    }
  }

  @Builder
  private ImportMenu() {
    Menu() {
      MenuItem({ content: '导入' })
        .onClick(() => this.onUnavailableAction('TXT 目录规则导入存储尚未接入，未导入任何数据'))
      MenuItem({ content: '导入内置规则' })
        .onClick(() => this.onUnavailableAction('内置 TXT 目录规则库尚未接入，未导入任何数据'))
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  @Builder
  private EditMoreMenu() {
    Menu() {
      MenuItem({ content: '复制规则' })
        .onClick(() => this.copyRuleToClipboard())
      MenuItem({ content: '粘贴规则' })
        .onClick(() => this.showPasteAuthorization = true)
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  @Builder
  private ruleEditorSheet() {
    Column() {
      Row() {
        AppGlyph({ name: 'profileClose', glyphSize: 20, tint: '#D8D9E0' }).padding({ right: 12 })
          .onClick(() => this.showAddRule = false)
        Text('TXT 目录规则').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#E3E4E8').layoutWeight(1)
        AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
          .bindMenu(this.EditMoreMenu, { placement: Placement.BottomRight })
      }.width('100%').padding({ left: 18, right: 16, top: 8, bottom: 12 })
      Scroll() {
        Column() {
          Text('名称').fontSize(14).fontColor('#AEB0BA').width('100%').textAlign(TextAlign.Start)
          TextInput({ placeholder: '名称', text: this.ruleName })
            .fontSize(15).fontColor('#E3E4E8').placeholderColor('#92949E')
            .backgroundColor('#111217').borderRadius(12).padding(12).width('100%')
            .onChange((value: string) => { this.ruleName = value; this.clearRuleTest(); })
          Text('章节正则').fontSize(14).fontColor('#AEB0BA').width('100%').textAlign(TextAlign.Start).margin({ top: 12 })
          TextInput({ placeholder: '章节正则', text: this.chapterRegex })
            .fontSize(15).fontColor('#E3E4E8').placeholderColor('#92949E')
            .backgroundColor('#111217').borderRadius(12).padding(12).width('100%')
            .onChange((value: string) => { this.chapterRegex = value; this.clearRuleTest(); })
          Text('示例').fontSize(14).fontColor('#AEB0BA').width('100%').textAlign(TextAlign.Start).margin({ top: 12 })
          TextArea({ placeholder: '示例', text: this.exampleText })
            .fontSize(15).fontColor('#E3E4E8').placeholderColor('#92949E')
            .backgroundColor('#111217').borderRadius(12).height(96).padding(12).width('100%')
            .onChange((value: string) => { this.exampleText = value; this.clearRuleTest(); })
          Text('分卷正则').fontSize(14).fontColor('#AEB0BA').width('100%').textAlign(TextAlign.Start).margin({ top: 12 })
          TextInput({ placeholder: '分卷正则', text: this.volumeRegex })
            .fontSize(15).fontColor('#E3E4E8').placeholderColor('#92949E')
            .backgroundColor('#111217').borderRadius(12).padding(12).width('100%')
            .onChange((value: string) => { this.volumeRegex = value; this.clearRuleTest(); })
          if (this.testHasRun) {
            if (this.testError.length > 0) {
              Text(this.testError).fontSize(14).fontColor('#FF8A80').width('100%').textAlign(TextAlign.Start).margin({ top: 14 })
            } else {
              Text(`${this.testResults.filter((item: TxtRuleTestLine) => item.matched).length} / ${this.testResults.length}`)
                .fontSize(14).fontColor('#D8D9E0').width('100%').textAlign(TextAlign.Start).margin({ top: 14, bottom: 6 })
              ForEach(this.testResults, (item: TxtRuleTestLine, index: number) => {
                Row() {
                  AppGlyph({ name: item.matched ? 'profileCheck' : 'profileClose', glyphSize: 18,
                    tint: item.matched ? '#AFC2FF' : '#FF8A80' }).margin({ right: 8 })
                  Text(item.line.length > 0 ? item.line : '（空行）').fontSize(13)
                    .fontColor(item.matched ? '#D8D9E0' : '#92949E').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }.width('100%')
              }, (item: TxtRuleTestLine, index: number) => `txt_rule_test_${index}`)
            }
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 18 })
      }.layoutWeight(1).scrollBar(BarState.Off)
      Row() {
        Row() {
          AppGlyph({ name: 'profileRunningWithErrors', glyphSize: 20, tint: '#E3E4E8' })
          Text('测试').fontSize(14).fontColor('#E3E4E8').margin({ left: 7 })
        }.padding({ left: 14, right: 14, top: 10, bottom: 10 }).backgroundColor('#34353D').borderRadius(22)
          .onClick(() => this.runRuleTest())
        if (this.showPasteAuthorization) {
          PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
            .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) => {
              await this.pasteRuleFromClipboard(result);
            })
        }
        Blank()
        Row() {
          AppGlyph({ name: 'profileSave', glyphSize: 18, tint: '#151720' })
        }.width(44).height(44).justifyContent(FlexAlign.Center).backgroundColor('#B9C8FF').borderRadius(22)
          .onClick(() => {
            if (this.ruleName.trim().length === 0 || this.chapterRegex.trim().length === 0) {
              this.onUnavailableAction('名称和章节正则不能为空')
            } else if (!this.isValidRegex(this.chapterRegex)) {
              this.onUnavailableAction('正则格式无效，规则未保存')
            } else {
              this.onUnavailableAction('TXT 目录规则存储尚未接入，规则未保存')
            }
          })
      }.width('100%').justifyContent(FlexAlign.End).padding({ left: 16, right: 16, top: 10, bottom: 18 })
    }.width('100%').height('100%')
  }

  build() {
    Column() {
      Blank().height(32)
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
          .width(36).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        AppGlyph({ name: 'search', glyphSize: 19, tint: '#D8D9E0' }).padding({ left: 8, right: 8 })
          .onClick(() => {
            this.showSearch = !this.showSearch;
            if (!this.showSearch) { this.searchQuery = ''; }
          })
        AppGlyph({ name: 'more', glyphSize: 18, tint: '#D8D9E0' }).padding({ left: 6, right: 8 })
          .bindMenu(this.ImportMenu, { placement: Placement.BottomRight })
      }.width('100%').height(40).padding({ left: 18, right: 18 })
      Row() {
        Text('TXT 目录规则').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
      }.width('100%').padding({ left: 18, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索 TXT 目录规则', text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_txt_toc_search')
            .onAppear(() => focusControl.requestFocus('my_txt_toc_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(24)
      }

      Blank().layoutWeight(1)
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'add', glyphSize: 24, tint: '#151720' })
        }.width(56).height(56).backgroundColor('#B9C8FF').borderRadius(28)
          .onClick(() => {
            this.ruleName = '';
            this.chapterRegex = '';
            this.exampleText = '';
            this.volumeRegex = '';
            this.showAddRule = true;
          })
      }.width('100%').justifyContent(FlexAlign.End).padding({ right: 16, top: 8, bottom: 16 })
    }.width('100%').height('100%').backgroundColor('#111217')
      .bindSheet(this.showAddRule, this.ruleEditorSheet(), {
        height: 620,
        dragBar: true,
        showClose: false,
        backgroundColor: '#1C1D23',
        onDisappear: () => this.showAddRule = false
      })
  }

  private isValidRegex(pattern: string): boolean {
    try {
      new RegExp(pattern, 'm');
      return true;
    } catch (_error) {
      return false;
    }
  }
}

interface TxtRuleMatchRange {
  start: number;
  end: number;
}

interface TxtRuleTestLine {
  line: string;
  matched: boolean;
}

interface TxtRuleClipboardData {
  name?: string;
  chapterRule?: string;
  rule?: string;
  volumeRule?: string;
  example?: string | null;
}

@Component
export struct DictionaryRulesPage {
  onBack: () => void = () => {};
  onOpenEditor: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State showSearch: boolean = false;
  @State searchQuery: string = '';

  @Builder
  private ImportMenu() {
    Menu() {
      MenuItem({ content: '导入' })
        .onClick(() => this.onUnavailableAction('字典规则导入尚未接入，未导入任何数据'))
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40)
          .onClick(() => {
            this.showSearch = !this.showSearch;
            if (!this.showSearch) { this.searchQuery = ''; }
          })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40)
          .bindMenu(this.ImportMenu, { placement: Placement.BottomRight })
      }.width('100%').height(40).padding({ left: 11, right: 12 })
        .margin({ top: -8 })

      Text('字典规则').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
        .width('100%').padding({ left: 12, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索字典规则', text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_dictionary_rule_search')
            .onAppear(() => focusControl.requestFocus('my_dictionary_rule_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(24)
      }

      Blank().layoutWeight(1)
      Stack({ alignContent: Alignment.Center }) {
        AppGlyph({ name: 'add', glyphSize: 22, tint: '#B9C8FF' })
      }.width(50).height(50).backgroundColor('#454F70').borderRadius(14)
        .onClick(() => this.onOpenEditor())
        .margin({ right: 16, bottom: 16 }).alignSelf(ItemAlign.End)
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

interface DictionaryRuleClipboardData {
  name?: string;
  urlRule?: string;
  showRule?: string;
  enabled?: boolean;
  sortNumber?: number;
}

@Component
export struct DictionaryRuleEditPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State name: string = '';
  @State urlRule: string = '';
  @State showRule: string = '';
  @State showPasteAuthorization: boolean = false;

  @Builder
  private RuleActionsMenu() {
    Menu() {
      MenuItem({ content: '复制规则' }).onClick(() => this.copyRule())
      MenuItem({ content: '粘贴规则' }).onClick(() => this.showPasteAuthorization = true)
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  private clipboardJson(): string {
    return JSON.stringify({
      name: this.name,
      urlRule: this.urlRule,
      showRule: this.showRule,
      enabled: true,
      sortNumber: 0
    });
  }

  private async copyRule(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.clipboardJson());
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制到剪贴板');
    } catch (_error) {
      this.onUnavailableAction('复制规则失败');
    }
  }

  private async pasteRule(result: PasteButtonOnClickResult): Promise<void> {
    this.showPasteAuthorization = false;
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得读取剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onUnavailableAction('剪贴板为空');
        return;
      }
      const parsed: DictionaryRuleClipboardData = JSON.parse(data.getRecord(0).toPlainText());
      if (typeof parsed.name !== 'string' || typeof parsed.urlRule !== 'string' ||
        typeof parsed.showRule !== 'string') {
        this.onUnavailableAction('剪贴板规则格式无效');
        return;
      }
      this.name = parsed.name;
      this.urlRule = parsed.urlRule;
      this.showRule = parsed.showRule;
      this.onUnavailableAction('规则已从剪贴板填入');
    } catch (_error) {
      this.onUnavailableAction('剪贴板规则格式无效');
    }
  }

  @Builder
  private RuleField(label: string, value: string, field: string, multiline: boolean = false) {
    Column() {
      if (multiline) {
        TextArea({ placeholder: label, text: value })
          .fontSize(16).fontColor('#E3E4E8').placeholderColor('#C3C5CD')
          .height(120).backgroundColor('#24252C').borderRadius(8).padding({ left: 14, right: 14, top: 14 })
          .width('100%').onChange((text: string) => this.updateField(field, text))
      } else {
        TextInput({ placeholder: label, text: value })
          .fontSize(16).fontColor('#E3E4E8').placeholderColor('#C3C5CD')
          .height(58).backgroundColor('#24252C').borderRadius(8).padding({ left: 14, right: 14 })
          .width('100%').onChange((text: string) => this.updateField(field, text))
      }
      Row().width('100%').height(1).backgroundColor('#898B94')
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 12 })
  }

  private updateField(field: string, value: string): void {
    if (field === 'name') { this.name = value; }
    else if (field === 'urlRule') { this.urlRule = value; }
    else { this.showRule = value; }
  }

  private saveRule(): void {
    if (this.name.trim().length === 0) {
      this.onUnavailableAction('名称不能为空');
      return;
    }
    this.onUnavailableAction('字典规则存储尚未接入，规则未保存');
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'profileClose', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).bindMenu(this.RuleActionsMenu, { placement: Placement.BottomRight })
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: -8 })
      Text('字典规则').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
        .width('100%').padding({ left: 14, right: 0, top: 12 })
      Scroll() {
        Column() {
          this.RuleField('名称', this.name, 'name')
          this.RuleField('Url规则 (urlRule)', this.urlRule, 'urlRule')
          this.RuleField('显示规则 (showRule)', this.showRule, 'showRule', true)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 0, bottom: 140 })
          .layoutWeight(1)
      }.layoutWeight(1).scrollBar(BarState.Off)
      Row() {
        if (this.showPasteAuthorization) {
          PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
            .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) => await this.pasteRule(result))
        }
        Blank()
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileSave', glyphSize: 20, tint: '#B9C8FF' })
        }.width(50).height(50).backgroundColor('#454F70').borderRadius(14).onClick(() => this.saveRule())
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 16 })
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
export struct HighlightTagRulesPage {
  onBack: () => void = () => {};
  onOpenEditor: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State showSearch: boolean = false;
  @State searchQuery: string = '';

  @Builder
  private ImportMenu() {
    Menu() {
      MenuItem({ content: '导入' })
        .onClick(() => this.onUnavailableAction('标签规则导入尚未接入，未导入任何数据'))
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40)
          .onClick(() => {
            this.showSearch = !this.showSearch;
            if (!this.showSearch) { this.searchQuery = ''; }
          })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).bindMenu(this.ImportMenu, { placement: Placement.BottomRight })
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: -8 })

      Text('标签规则').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
        .width('100%').padding({ left: 12, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索标签规则', text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_highlight_tag_search')
            .onAppear(() => focusControl.requestFocus('my_highlight_tag_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(24)
      }

      Blank().layoutWeight(1)
      Stack({ alignContent: Alignment.Center }) {
        AppGlyph({ name: 'add', glyphSize: 22, tint: '#B9C8FF' })
      }.width(50).height(50).backgroundColor('#454F70').borderRadius(14)
        .onClick(() => this.onOpenEditor())
        .margin({ right: 16, bottom: 16 }).alignSelf(ItemAlign.End)
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

interface HighlightTagRuleClipboardData {
  id?: number;
  title?: string;
  pattern?: string;
  enabled?: boolean;
  order?: number;
}

@Component
export struct HighlightTagRuleEditPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State title: string = '';
  @State pattern: string = '';
  @State ruleEnabled: boolean = true;
  @State showPasteAuthorization: boolean = false;

  @Builder
  private RuleActionsMenu() {
    Menu() {
      MenuItem({ content: '复制规则' }).onClick(() => this.copyRule())
      MenuItem({ content: '粘贴规则' }).onClick(() => this.showPasteAuthorization = true)
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  private clipboardJson(): string {
    return JSON.stringify({ id: Date.now(), title: this.title, pattern: this.pattern, enabled: this.ruleEnabled, order: 0 });
  }

  private async copyRule(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.clipboardJson());
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制到剪贴板');
    } catch (_error) {
      this.onUnavailableAction('复制规则失败');
    }
  }

  private async pasteRule(result: PasteButtonOnClickResult): Promise<void> {
    this.showPasteAuthorization = false;
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得读取剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onUnavailableAction('剪贴板没有内容');
        return;
      }
      const parsed: HighlightTagRuleClipboardData = JSON.parse(data.getRecord(0).toPlainText());
      if (typeof parsed.title !== 'string' || typeof parsed.pattern !== 'string' ||
        (parsed.enabled !== undefined && typeof parsed.enabled !== 'boolean')) {
        this.onUnavailableAction('剪贴板规则格式无效');
        return;
      }
      this.title = parsed.title;
      this.pattern = parsed.pattern;
      this.ruleEnabled = parsed.enabled !== false;
      this.onUnavailableAction('规则已从剪贴板填入');
    } catch (_error) {
      this.onUnavailableAction('剪贴板规则格式无效');
    }
  }

  private saveRule(): void {
    this.onUnavailableAction('标签规则存储尚未接入，规则未保存');
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'profileClose', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).bindMenu(this.RuleActionsMenu, { placement: Placement.BottomRight })
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: -8 })
      Text('添加规则').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
        .width('100%').padding({ left: 14, right: 0, top: 12 })
      Scroll() {
        Column() {
          TextInput({ placeholder: '标题（可选）', text: this.title })
            .fontSize(16).fontColor('#E3E4E8').placeholderColor('#C3C5CD')
            .height(58).backgroundColor('#24252C').borderRadius(8).padding({ left: 14, right: 14 }).width('100%')
            .onChange((value: string) => this.title = value)
          Row().width('100%').height(1).backgroundColor('#898B94').margin({ bottom: 12 })
          TextArea({ placeholder: '匹配规则', text: this.pattern })
            .fontSize(16).fontColor('#E3E4E8').placeholderColor('#C3C5CD')
            .height(120).backgroundColor('#24252C').borderRadius(8).padding({ left: 14, right: 14, top: 14 }).width('100%')
            .onChange((value: string) => this.pattern = value)
          Row().width('100%').height(1).backgroundColor('#898B94').margin({ bottom: 12 })
          Row() {
            Text('已启用').fontSize(16).fontColor('#E3E4E8').layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.ruleEnabled }).onChange((value: boolean) => this.ruleEnabled = value)
          }.width('100%').padding({ top: 8, bottom: 8 })
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 140 })
          .layoutWeight(1)
      }.layoutWeight(1).scrollBar(BarState.Off)
      Row() {
        if (this.showPasteAuthorization) {
          PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
            .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) => await this.pasteRule(result))
        }
        Blank()
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileSave', glyphSize: 20, tint: '#B9C8FF' })
        }.width(50).height(50).backgroundColor('#454F70').borderRadius(14).onClick(() => this.saveRule())
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 16 })
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

export interface BookmarkBookSummary {
  key: string;
  title: string;
  author: string;
  bookmarkCount: number;
  noteCount: number;
}

export interface BookmarkEntrySummary {
  id: string;
  bookKey: string;
  chapterName: string;
  excerpt: string;
  note: string;
  kind: 'bookmark' | 'note';
}

const BOOKMARK_EMPTY_FACES: string[] = [
  '(；′⌒`)', '(つ﹏⊂)', '(•̀ᴗ•́)و', '(๑•́ ₃ •̀๑)', '(눈‸눈)', '(ಥ﹏ಥ)', '(｡•́︿•̀｡)'
];

@Component
export struct AllBookmarksPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop books: BookmarkBookSummary[] = [];
  @Prop entries: BookmarkEntrySummary[] = [];
  @State selectedBookKey: string = '';
  @State selectedBookTitle: string = '';
  @State selectedBookmarkCount: number = 0;
  @State selectedNoteCount: number = 0;
  @State selectedTab: number = 0;
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State emptyFaceIndex: number = Math.floor(Math.random() * BOOKMARK_EMPTY_FACES.length);

  private getVisibleBooks(): BookmarkBookSummary[] {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    return this.books.filter((book: BookmarkBookSummary) => {
      if (query.length === 0) { return true; }
      const basicMatch = book.title.toLocaleLowerCase().includes(query) || book.author.toLocaleLowerCase().includes(query);
      const noteMatch = this.entries.some((entry: BookmarkEntrySummary) =>
        entry.bookKey === book.key && (entry.excerpt.toLocaleLowerCase().includes(query) || entry.note.toLocaleLowerCase().includes(query)));
      return basicMatch || noteMatch;
    });
  }

  private getVisibleEntries(bookKey: string): BookmarkEntrySummary[] {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    return this.entries.filter((entry: BookmarkEntrySummary) => {
      if (entry.bookKey !== bookKey || (this.selectedTab === 0 && entry.kind !== 'bookmark') ||
        (this.selectedTab === 1 && entry.kind !== 'note')) { return false; }
      return query.length === 0 || entry.chapterName.toLocaleLowerCase().includes(query) ||
        entry.excerpt.toLocaleLowerCase().includes(query) || entry.note.toLocaleLowerCase().includes(query);
    });
  }

  private handleBack(): void {
    if (this.selectedBookKey.length > 0) {
      this.selectedBookKey = '';
      this.selectedBookTitle = '';
      this.selectedBookmarkCount = 0;
      this.selectedNoteCount = 0;
      this.searchQuery = '';
      this.selectedTab = 0;
    } else {
      this.onBack();
    }
  }

  private randomizeEmptyFace(): void {
    this.emptyFaceIndex = Math.floor(Math.random() * BOOKMARK_EMPTY_FACES.length);
  }

  @Builder
  private BookmarkEmptyMessage(message: string) {
    Column() {
      Text(BOOKMARK_EMPTY_FACES[this.emptyFaceIndex]).fontSize(32).fontColor('#E3E4E8')
        .textAlign(TextAlign.Center).onClick(() => this.randomizeEmptyFace())
      Text(message).fontSize(14).fontColor('#D8D9E0').textAlign(TextAlign.Center).maxLines(2)
        .margin({ top: 2 })
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .padding({ left: 16, right: 16 })
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.handleBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => {
          this.showSearch = !this.showSearch;
          if (!this.showSearch) { this.searchQuery = ''; }
        })
        if (this.selectedBookKey.length > 0) {
          Stack({ alignContent: Alignment.Center }) {
            Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
            AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
          }.width(40).height(40).onClick(() => this.onUnavailableAction('书签导出尚未接入，未导出数据'))
        }
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: -8 })

      Text(this.selectedBookKey.length === 0 ? '所有书签' : this.selectedBookTitle)
        .fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%').padding({ left: 12, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: this.selectedBookKey.length === 0
            ? '搜索笔记内容'
            : `搜索当前${this.selectedTab === 0 ? '书签' : '笔记'}`, text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_bookmark_search')
            .onAppear(() => focusControl.requestFocus('my_bookmark_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(24)
      }

      if (this.selectedBookKey.length > 0) {
        Row() {
          ModuleTab({ label: `书签 ${this.selectedBookmarkCount}`, selected: this.selectedTab === 0, onSelect: () => { this.selectedTab = 0; this.searchQuery = ''; } })
          ModuleTab({ label: `笔记 ${this.selectedNoteCount}`, selected: this.selectedTab === 1, onSelect: () => { this.selectedTab = 1; this.searchQuery = ''; } })
        }.margin({ left: 16, right: 16, top: 8, bottom: 12 })
        if (this.getVisibleEntries(this.selectedBookKey).length === 0) {
          this.BookmarkEmptyMessage(this.searchQuery.length > 0 ? '没有找到相关笔记' : (this.selectedTab === 0 ? '暂无书签' : '暂无笔记'))
        } else {
          Scroll() {
            Column() {
              ForEach(this.getVisibleEntries(this.selectedBookKey), (entry: BookmarkEntrySummary) => {
                BookmarkEntryCard({ entry: entry, onSelect: () => this.onUnavailableAction('书签定位与编辑将在本地书签功能接入后提供') })
              }, (entry: BookmarkEntrySummary) => entry.id)
            }.padding({ left: 16, right: 16, top: 4, bottom: 20 })
          }.layoutWeight(1).scrollBar(BarState.Off)
        }
      } else if (this.getVisibleBooks().length === 0) {
        this.BookmarkEmptyMessage(this.searchQuery.length > 0 ? '没有找到相关笔记' : '暂无书签')
      } else {
        Scroll() {
          Column() {
            ForEach(this.getVisibleBooks(), (book: BookmarkBookSummary) => {
              BookmarkOverviewCard({
                book: book,
                onSelect: () => {
                  this.selectedBookKey = book.key;
                  this.selectedBookTitle = book.title;
                  this.selectedBookmarkCount = book.bookmarkCount;
                  this.selectedNoteCount = book.noteCount;
                  this.selectedTab = 0;
                  this.searchQuery = '';
                }
              })
            }, (book: BookmarkBookSummary) => book.key)
          }.padding({ left: 16, right: 16, top: 8, bottom: 20 })
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct BookmarkOverviewCard {
  @Prop book: BookmarkBookSummary = { key: '', title: '', author: '', bookmarkCount: 0, noteCount: 0 };
  onSelect: () => void = () => {};
  build() {
    Row() {
      AppGlyph({ name: 'bookmark', glyphSize: 22, tint: '#AFC2FF' }).width(38)
      Column() {
        Text(this.book.title).fontSize(17).fontColor('#D8D9E0').maxLines(2)
        if (this.book.author.length > 0) { Text(this.book.author).fontSize(14).fontColor('#92949E').margin({ top: 3 }) }
        Text(`${this.book.bookmarkCount} 条书签 · ${this.book.noteCount} 条笔记`).fontSize(12).fontColor('#92949E').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(18).height(18).fillColor('#92949E')
    }.width('100%').padding(14).backgroundColor('#1A1B21').borderRadius(14).margin({ bottom: 8 })
      .onClick(() => this.onSelect())
  }
}

@Component
struct BookmarkEntryCard {
  @Prop entry: BookmarkEntrySummary = { id: '', bookKey: '', chapterName: '', excerpt: '', note: '', kind: 'bookmark' };
  onSelect: () => void = () => {};
  build() {
    Column() {
      Text(this.entry.chapterName).fontSize(14).fontColor('#AFC2FF').maxLines(1)
      if (this.entry.excerpt.length > 0) { Text(this.entry.excerpt).fontSize(14).fontColor('#D8D9E0').maxLines(3).margin({ top: 6 }) }
      if (this.entry.note.length > 0) { Text(this.entry.note).fontSize(14).fontColor('#92949E').maxLines(3).margin({ top: 4 }) }
    }.width('100%').padding(16).backgroundColor('#1A1B21').borderRadius(14).margin({ bottom: 8 })
      .onClick(() => this.onSelect())
  }
}

@Component
export struct ReadRecordsPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State displayMode: number = 0;
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State emptyFaceIndex: number = Math.floor(Math.random() * BOOKMARK_EMPTY_FACES.length);
  @State showActionsSheet: boolean = false;

  private getModeLabel(): string {
    if (this.displayMode === 1) { return '时间线视图'; }
    if (this.displayMode === 2) { return '最后阅读视图'; }
    return '汇总视图';
  }

  private cycleDisplayMode(): void {
    this.displayMode = (this.displayMode + 1) % 3;
  }

  @Builder
  private ReadRecordEmptyMessage(message: string) {
    Column() {
      Text(BOOKMARK_EMPTY_FACES[this.emptyFaceIndex]).fontSize(32).fontColor('#E3E4E8')
        .textAlign(TextAlign.Center).onClick(() => {
          this.emptyFaceIndex = Math.floor(Math.random() * BOOKMARK_EMPTY_FACES.length);
        })
      Text(message).fontSize(14).fontColor('#D8D9E0').textAlign(TextAlign.Center).maxLines(2).margin({ top: 2 })
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .padding({ left: 16, right: 16 })
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.onBack())
        Column() {
          Text('阅读记录').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
          Text(this.getModeLabel()).fontSize(PROFILE_PAGE_SUBTITLE_SIZE).fontColor('#92949E').margin({ top: 3 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 2 })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: this.displayMode === 0 ? 'profileTimeline' : (this.displayMode === 1 ? 'clock' : 'list'), glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => this.cycleDisplayMode())
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => {
          this.showSearch = !this.showSearch;
          if (!this.showSearch) { this.searchQuery = ''; }
        })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => this.showActionsSheet = true)
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: -8 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索', text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_read_record_search')
            .onAppear(() => focusControl.requestFocus('my_read_record_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(24)
      }

      this.ReadRecordEmptyMessage('没有阅读记录')
    }.width('100%').height('100%').backgroundColor('#111217')
      .bindSheet(this.showActionsSheet, this.ReadRecordOptionsSheet(), {
        height: 500,
        dragBar: true,
        showClose: false,
        backgroundColor: '#1C1D23',
        onDisappear: () => this.showActionsSheet = false
      })
  }

  @Builder
  private ReadRecordOptionsSheet() {
    Column() {
      Text('阅读记录选项').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
        .width('100%').padding({ left: 18, right: 16, top: 12, bottom: 14 })
      ReadRecordOptionRow({ icon: 'clock', title: '显示阅读日历', detail: '按日期查看阅读记录', onSelect: () => this.onUnavailableAction('阅读日历尚未迁移，未更改设置') })
      ReadRecordOptionRow({ icon: 'clock', title: '启用阅读记录', detail: '记录书籍阅读时长', onSelect: () => this.onUnavailableAction('阅读记录设置尚未迁移，未更改设置') })
      ReadRecordOptionRow({ icon: 'search', title: '扫描阅读记录问题', detail: '检查重复或异常记录', onSelect: () => this.onUnavailableAction('记录扫描尚未迁移，未检查数据') })
      ReadRecordOptionRow({ icon: 'swap', title: '修复阅读记录', detail: '修复重复记录和阅读时段', onSelect: () => this.onUnavailableAction('记录修复尚未迁移，未修改数据') })
      ReadRecordOptionRow({ icon: 'delete', title: '清空阅读记录', detail: '删除本地阅读历史', onSelect: () => this.onUnavailableAction('当前没有可清空的阅读记录') })
    }.width('100%').padding({ bottom: 16 })
  }
}

@Component
export struct CacheManagementPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State selectedCacheGroup: string = '全部';

  @Builder
  private CacheGroupMenu() {
    Menu() {
      MenuItem({ content: '全部', labelInfo: this.selectedCacheGroup === '全部' ? '✓' : '' })
        .onClick(() => this.selectedCacheGroup = '全部')
      MenuItem({ content: '无分组', labelInfo: this.selectedCacheGroup === '无分组' ? '✓' : '' })
        .onClick(() => this.selectedCacheGroup = '无分组')
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => {
          this.showSearch = !this.showSearch;
          if (!this.showSearch) { this.searchQuery = ''; }
        })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'profileFilterAlt', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).bindMenu(this.CacheGroupMenu, { placement: Placement.BottomRight })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'profileRefresh', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => this.onUnavailableAction('缓存数据仓储尚未接入，未刷新缓存'))
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: -8 })

      Text('缓存管理').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
        .width('100%').padding({ left: 12, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '筛选书名/作者', text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_cache_manage_search')
            .onAppear(() => focusControl.requestFocus('my_cache_manage_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(24)
      }

      Column() {
        CacheEmptySection({
          title: '书架书籍',
          message: '没有书架内书籍缓存或下载任务'
        })
        CacheEmptySection({
          title: '未在书架',
          message: '没有未在书架的书籍下载状态'
        })
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 8, bottom: 18 })
        .layoutWeight(1)
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct ReadRecordOptionRow {
  @Prop icon: AppGlyphName = 'info';
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};

  build() {
    Row() {
      AppGlyph({ name: this.icon, glyphSize: 19, tint: '#AFC2FF' }).width(32)
      Column() {
        Text(this.title).fontSize(15).fontColor('#E3E4E8')
        Text(this.detail).fontSize(12).fontColor('#92949E').margin({ top: 3 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .onClick(() => this.onSelect())
  }
}

@Component
struct CacheEmptySection {
  @Prop title: string = '';
  @Prop message: string = '';
  build() {
    Column() {
      Text(this.title).fontSize(14).fontColor('#AFC2FF')
        .alignSelf(ItemAlign.Start).margin({ left: 10, bottom: 7 })
      Text(this.message).fontSize(14).fontColor('#D8D9E0').width('100%').textAlign(TextAlign.Start)
        .padding({ left: 12, right: 12, top: 12, bottom: 12 }).backgroundColor('#1A1B21').borderRadius(8)
    }.width('100%').margin({ bottom: 14 })
  }
}


@Component
export struct AboutAppPage {
  onBack: () => void = () => {};
  onOpenPrivacyNotice: () => void = () => {};
  onOpenLicense: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State versionName: string = '';

  aboutToAppear(): void {
    this.loadVersionName();
  }

  private async loadVersionName(): Promise<void> {
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      this.versionName = bundleInfo.versionName;
    } catch (_) {
      this.versionName = '版本信息不可用';
    }
  }

  build() {
    Column() {
      Column() {
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
          }.width(36).height(36).backgroundColor('#1C1D23').borderRadius(18).onClick(() => this.onBack())
          Blank()
        }.width('100%')
        Text('关于').fontSize(PROFILE_PAGE_TITLE_SIZE + 4).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
          .alignSelf(ItemAlign.Start).margin({ top: 2 })
      }.width('100%').padding({ left: 16, right: 16, top: 2, bottom: 4 })
      Scroll() {
        Column() {
          Column() {
            Image($r('app.media.about_cat')).width(72).height(72)
            Blank().height(18)
            Blank().height(5)
            Text('阅读·D').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
            if (this.versionName.length > 0) {
              Text(this.versionName).fontSize(12).fontColor('#D8D9E0').padding({ left: 9, right: 9, top: 4, bottom: 4 })
                .backgroundColor('#1C1D23').borderRadius(8).margin({ top: 3 })
            }
            Text('全新设计的阅读 3.0').fontSize(12).fontColor('#92949E').margin({ top: 4 })
          }.width('100%').padding({ top: 4, bottom: 8 }).alignItems(HorizontalAlign.Center)

          Row() {
            AboutQuickAction({ icon: 'about_web', description: '项目主页', onSelect: () => this.onUnavailableAction('项目主页尚未接入外部链接') })
            AboutQuickAction({ icon: 'about_github', description: 'GitHub', onSelect: () => this.onUnavailableAction('GitHub 尚未接入外部链接') })
            AboutQuickAction({ icon: 'about_update', description: '检查更新', onSelect: () => this.onUnavailableAction('更新检查尚未迁移') })
          }.width('100%').padding({ left: 12, right: 12, bottom: 8 })

          Column() {
            AboutActionRow({ title: '开发人员', onSelect: () => this.onUnavailableAction('开发人员页面尚未迁移') })
            AboutActionRow({ title: '用户隐私与协议', onSelect: () => this.onOpenPrivacyNotice() })
            AboutActionRow({ title: '开源许可', onSelect: () => this.onOpenLicense() })
            AboutActionRow({ title: '免责声明', onSelect: () => this.onUnavailableAction('免责声明页面尚未迁移') })
            AboutActionRow({ title: '崩溃日志', onSelect: () => this.onUnavailableAction('崩溃日志页面尚未迁移') })
            AboutActionRow({ title: '保存日志', onSelect: () => this.onUnavailableAction('日志导出尚未迁移') })
            AboutActionRow({ title: '创建堆转储', last: true, onSelect: () => this.onUnavailableAction('堆转储尚未迁移') })
          }.width('100%').padding({ top: 2, bottom: 2 }).backgroundColor('#1A1B21').borderRadius(14)
        }.padding({ left: 16, right: 16, top: 4, bottom: 18 })
      }.layoutWeight(1).scrollBar(BarState.Off).offset({ y: -10 })
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct AboutQuickAction {
  @Prop icon: string = 'about_web';
  @Prop description: string = '';
  onSelect: () => void = () => {};
  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Image(this.icon === 'about_github' ? $r('app.media.about_github') :
          (this.icon === 'about_update' ? $r('app.media.about_update') : $r('app.media.about_web')))
          .width(20).height(20).fillColor('#D8D9E0').accessibilityText(this.description)
      }.width(36).height(36).backgroundColor('#3A4054').borderRadius(18).onClick(() => this.onSelect())
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }
}

@Component
struct AboutActionRow {
  @Prop title: string = '';
  @Prop last: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Column() {
      Row() {
        Text(this.title).fontSize(PROFILE_ROW_TITLE_SIZE).fontColor('#D8D9E0').layoutWeight(1)
      }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 16 }).onClick(() => this.onSelect())
      if (!this.last) { Row().height(1).width('100%').backgroundColor('#111217').margin({ left: 16, right: 16 }) }
    }.width('100%')
  }
}

@Component
export struct AppSettingsHomePage {
  onBack: () => void = () => {};
  onOpenCategory: (destination: ProfileRoute) => void = (_destination: ProfileRoute) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  build() {
    Column() {
      SettingsPageHeader({ title: '设置', onBack: () => this.onBack() })
      Scroll() {
        Column() {
          SettingsCategoryRow({ title: '外观', onSelect: () => this.onOpenCategory(ProfileRoute.APP_THEME_SETTINGS) })
          SettingsCategoryRow({ title: '高级', onSelect: () => this.onOpenCategory(ProfileRoute.APP_OTHER_SETTINGS) })
          SettingsCategoryRow({ title: '阅读界面', onSelect: () => this.onOpenCategory(ProfileRoute.APP_READ_SETTINGS) })
          SettingsCategoryRow({ title: '朗读设置', summary: '管理角色声音池、背景音乐池与角色配音分配', onSelect: () => this.onOpenCategory(ProfileRoute.APP_ALOUD_SETTINGS) })
          SettingsCategoryRow({ title: '封面设置', onSelect: () => this.onOpenCategory(ProfileRoute.APP_COVER_SETTINGS) })
          SettingsCategoryRow({ title: '下载与缓存', onSelect: () => this.onOpenCategory(ProfileRoute.APP_DOWNLOAD_CACHE_SETTINGS) })
          SettingsCategoryRow({ title: '备份与恢复', onSelect: () => this.onOpenCategory(ProfileRoute.APP_BACKUP_SETTINGS) })
          SettingsCategoryRow({ title: 'AI 设置', onSelect: () => this.onOpenCategory(ProfileRoute.APP_AI_SETTINGS) })
          SettingsCategoryRow({ title: '翻译设置', onSelect: () => this.onOpenCategory(ProfileRoute.APP_TRANSLATION_SETTINGS) })
          SettingsCategoryRow({ title: '隐私', onSelect: () => this.onOpenCategory(ProfileRoute.APP_PRIVACY_SETTINGS) })
          SettingsCategoryRow({ title: '实验室', last: true, onSelect: () => this.onOpenCategory(ProfileRoute.APP_LAB_SETTINGS) })
        }.padding({ left: 16, right: 16, top: 8, bottom: 16 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct SettingsPageHeader {
  @Prop title: string = '';
  onBack: () => void = () => {};
  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(36).height(36).backgroundColor('#1C1D23').borderRadius(18).onClick(() => this.onBack())
        Blank()
      }.width('100%')
      Text(this.title).fontSize(PROFILE_PAGE_TITLE_SIZE + 4).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
        .alignSelf(ItemAlign.Start).margin({ top: 2 })
    }.width('100%').padding({ left: 16, right: 16, top: 2, bottom: 4 })
  }
}

@Component
struct SettingsCategoryRow {
  @Prop title: string = '';
  @Prop summary: string = '';
  @Prop last: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(PROFILE_ROW_TITLE_SIZE).fontColor('#D8D9E0')
        if (this.summary.length > 0) {
          Text(this.summary).fontSize(PROFILE_ROW_DETAIL_SIZE).fontColor('#92949E').margin({ top: 4 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(18).height(18).fillColor('#92949E')
    }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 16 })
      .backgroundColor('#1A1B21').borderRadius(14).margin({ bottom: this.last ? 0 : 3 })
      .onClick(() => this.onSelect())
  }
}

@Component
export struct AiChatPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State historyVisible: boolean = false;
  @State draft: string = '';

  private handleBack(): void {
    if (this.historyVisible) {
      this.historyVisible = false;
    } else {
      this.onBack();
    }
  }

  private sendDraft(): void {
    if (this.draft.trim().length === 0) { return; }
    this.onUnavailableAction('AI服务商未配置，消息未发送');
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Row() {
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
            .width(36).onClick(() => this.handleBack())
          Column() {
            Text('AI 对话').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
            Text('新对话').fontSize(PROFILE_PAGE_SUBTITLE_SIZE).fontColor('#92949E').margin({ top: 3 })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          AppGlyph({ name: 'list', glyphSize: 19, tint: '#D8D9E0' }).padding({ left: 8, right: 8 })
            .onClick(() => this.historyVisible = true)
          AppGlyph({ name: 'add', glyphSize: 19, tint: '#D8D9E0' }).padding({ left: 8, right: 8 })
            .onClick(() => { this.draft = ''; this.onUnavailableAction('新会话已准备；配置 AI 服务后即可发送消息'); })
        }.width('100%').padding({ left: 12, right: 10, top: 11, bottom: 9 })

        Row() {
          AppGlyph({ name: 'sparkles', glyphSize: 16, tint: '#AFC2FF' }).margin({ right: 7 })
          Text('模型未配置').fontSize(14).fontColor('#D8D9E0')
          Blank()
          AppGlyph({ name: 'more', glyphSize: 16, tint: '#92949E' })
        }.padding({ left: 12, right: 12, top: 9, bottom: 9 }).margin({ left: 16, right: 16, top: 4 })
          .backgroundColor('#1A1B21').borderRadius(18)
          .onClick(() => this.onUnavailableAction('请先在“我的→设置→AI 设置”配置服务商和模型'))

        Column() {
          AppGlyph({ name: 'sparkles', glyphSize: 40, tint: '#AFC2FF' }).margin({ bottom: 14 })
          Text('和你的书对话').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#D8D9E0')
          Text('配置 AI 服务后，提问和回复会显示在这里。')
            .fontSize(14).fontColor('#858792').textAlign(TextAlign.Center).margin({ top: 8 })
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)

        Column() {
          Row() {
            TextInput({ placeholder: '输入消息…', text: this.draft })
              .fontSize(15).fontColor('#D8D9E0').placeholderColor('#92949E')
              .backgroundColor(Color.Transparent).layoutWeight(1).maxLines(4)
              .onChange((value: string) => this.draft = value)
            Image(('app.media.app_send')).width(18).height(18).fillColor(this.draft.trim().length > 0 ? '#151720' : '#92949E')
              .width(40).height(40).backgroundColor(this.draft.trim().length > 0 ? '#B9C8FF' : '#303139')
              .borderRadius(20).onClick(() => this.sendDraft())
          }.padding({ left: 14, right: 8, top: 7, bottom: 7 }).backgroundColor('#1A1B21').borderRadius(24)
          Row() {
            Text('推理模式：AUTO').fontSize(12).fontColor('#92949E')
            Blank()
            Text('AI 服务未配置').fontSize(12).fontColor('#858792')
          }.padding({ left: 6, right: 6, top: 7, bottom: 5 })
        }.padding({ left: 16, right: 16, top: 8, bottom: 12 })
      }.width('100%').height('100%').backgroundColor('#111217')

      if (this.historyVisible) {
        Stack({ alignContent: Alignment.TopStart }) {
          Column().width('100%').height('100%').backgroundColor('#99000000')
            .onClick(() => this.historyVisible = false)
          Column() {
            Row() {
              Text('最近会话').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#E3E4E8').layoutWeight(1)
              AppGlyph({ name: 'add', glyphSize: 19, tint: '#D8D9E0' }).padding(8)
                .onClick(() => { this.historyVisible = false; this.draft = ''; })
            }.padding({ left: 18, right: 12, top: 18, bottom: 16 })
            Row() {
              AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
              TextInput({ placeholder: '搜索会话…' }).fontSize(14).fontColor('#D8D9E0')
                .placeholderColor('#92949E').backgroundColor(Color.Transparent).layoutWeight(1)
            }.padding({ left: 12, right: 12, top: 8, bottom: 8 }).margin({ left: 14, right: 14 })
              .backgroundColor('#22232A').borderRadius(20)
            Column() {
              AppGlyph({ name: 'sparkles', glyphSize: 28, tint: '#92949E' }).margin({ bottom: 10 })
              Text('暂无会话记录').fontSize(14).fontColor('#AEB0BA')
            }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            Text('新建对话').fontSize(15).fontColor('#151720').textAlign(TextAlign.Center)
              .width('100%').padding(13).margin({ left: 14, right: 14, bottom: 20 })
              .backgroundColor('#B9C8FF').borderRadius(24)
              .onClick(() => { this.historyVisible = false; this.draft = ''; this.onUnavailableAction('配置 AI 服务后即可开始对话'); })
          }.width('82%').height('100%').backgroundColor('#17181E')
        }.width('100%').height('100%')
      }
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct ModuleHeader {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  build() {
    Column() {
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0').width(36).onClick(() => this.onBack())
        Column() {
          Text(this.title).fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
          Text(this.subtitle).fontSize(PROFILE_PAGE_SUBTITLE_SIZE).fontColor('#92949E').margin({ top: 3 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        AppGlyph({ name: 'search', glyphSize: 18, tint: '#D8D9E0' }).padding({ left: 8, right: 8 })
          .onClick(() => this.onUnavailableAction('设置搜索尚未迁移'))
        AppGlyph({ name: 'more', glyphSize: 17, tint: '#D8D9E0' }).padding({ left: 6, right: 6 })
          .onClick(() => this.onUnavailableAction('设置更多操作尚未迁移'))
      }.width('100%').padding({ left: 12, right: 10, top: 11, bottom: 9 })
    }
  }
}

@Component
struct ModuleSearch {
  @Prop hint: string = '';
  @State query: string = '';
  build() {
    Row() {
      AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
      TextInput({ placeholder: this.hint, text: this.query })
        .fontSize(16)
        .fontColor('#D8D9E0')
        .placeholderColor('#92949E')
        .backgroundColor(Color.Transparent)
        .onChange((value: string) => this.query = value)
        .layoutWeight(1)
    }.width('100%').padding({ left: 12, right: 14, top: 7, bottom: 7 }).margin({ left: 16, right: 16 }).backgroundColor('#1B1C22').borderRadius(22)
  }
}

@Component
struct ModuleTab {
  @Prop label: string = '';
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Text(this.label).fontSize(16).fontColor(this.selected ? '#E1E5F3' : '#A4A6B0')
      .textAlign(TextAlign.Center).layoutWeight(1).padding({ top: 9, bottom: 9 })
      .backgroundColor(this.selected ? '#41485D' : '#1A1B21').borderRadius(20).margin({ right: 7 })
      .onClick(() => this.onSelect())
  }
}

@Component
struct ModuleEmpty {
  @Prop icon: AppGlyphName = 'book';
  @Prop title: string = '';
  @Prop detail: string = '';
  build() {
    Column() {
      AppGlyph({ name: this.icon, glyphSize: 34, tint: '#AFC2FF' }).margin({ bottom: 14 })
      Text(this.title).fontSize(18).fontColor('#D8D9E0')
      Text(this.detail).fontSize(15).fontColor('#858792').textAlign(TextAlign.Center).margin({ left: 34, right: 34, top: 8 })
    }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }
}

@Component
struct MetricCard {
  @Prop label: string = '';
  @Prop value: string = '';
  build() {
    Column() {
      Text(this.label).fontSize(14).fontColor('#92949E')
      Text(this.value).fontSize(17).fontColor('#D8D9E0').margin({ top: 5 })
    }.layoutWeight(1).alignItems(HorizontalAlign.Start).padding(15).backgroundColor('#1C1D23')
      .borderRadius(14).margin({ right: 6 })
  }
}

@Component
struct FileCategoryRow {
  @Prop icon: AppGlyphName = 'folder';
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      AppGlyph({ name: this.icon, glyphSize: 20, tint: '#AFC2FF' }).width(36)
      Column() {
        Text(this.title).fontSize(PROFILE_ROW_TITLE_SIZE).fontColor('#D8D9E0')
        Text(this.detail).fontSize(PROFILE_ROW_DETAIL_SIZE).fontColor('#92949E').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(18).height(18).fillColor('#92949E')
    }.padding({ left: 15, right: 15, top: PROFILE_ROW_VERTICAL_PADDING, bottom: PROFILE_ROW_VERTICAL_PADDING }).margin({ left: 16, right: 16, bottom: 1 })
      .backgroundColor('#1A1B21').onClick(() => this.onSelect())
  }
}
