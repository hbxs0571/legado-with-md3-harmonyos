// 书源编辑页（P5）。对齐上游 BookSourceEditScreen / BookSourceEditViewModel 的
// 六 tab + 68 字段槽；编辑对象是整条 sourceJson（唯一真值），派生列在保存时按同一口径重建。
// path 是点路径（ruleSearch.bookList），读写走 readPath / writePath 两个辅助函数。

import { pasteboard } from '@kit.BasicServicesKit';
import { BookSource } from '../model/BookSource';
import { AppTopBar, TopBarBackButton, TopBarButton } from '../components/TopBar';
import { AppGlyph } from '../components/AppGlyph';

/** 一个字段槽：path 为点路径，label 为中文标签，multi 决定用 TextArea 还是 TextInput。 */
interface FieldSpec {
  path: string;
  label: string;
  multi: boolean;
}

/** 六个选项卡的静态字段表，合计 68 项（与上游 FIELD_SPECS 一致）。 */
const TAB_NAMES: string[] = ['基本', '搜索', '发现', '详情', '目录', '正文'];

const FIELDS_BASE: FieldSpec[] = [
  { path: 'bookSourceUrl', label: '源 URL', multi: false },
  { path: 'bookSourceName', label: '源名称', multi: false },
  { path: 'bookSourceGroup', label: '源分组', multi: false },
  { path: 'bookSourceComment', label: '源注释', multi: true },
  { path: 'loginUrl', label: '登录 URL', multi: false },
  { path: 'loginUi', label: '登录 UI', multi: true },
  { path: 'loginCheckJs', label: '登录检查 JS', multi: true },
  { path: 'coverDecodeJs', label: '封面解密', multi: true },
  { path: 'bookUrlPattern', label: '书籍 URL 正则', multi: false },
  { path: 'header', label: '请求头', multi: true },
  { path: 'variableComment', label: '变量说明', multi: true },
  { path: 'concurrentRate', label: '并发率', multi: false },
  { path: 'jsLib', label: 'jsLib', multi: true }
];

const FIELDS_SEARCH: FieldSpec[] = [
  { path: 'searchUrl', label: '搜索地址', multi: true },
  { path: 'ruleSearch.checkKeyWord', label: '校验关键字', multi: false },
  { path: 'ruleSearch.bookList', label: '书籍列表规则', multi: false },
  { path: 'ruleSearch.name', label: '书名规则', multi: false },
  { path: 'ruleSearch.author', label: '作者规则', multi: false },
  { path: 'ruleSearch.kind', label: '分类规则', multi: false },
  { path: 'ruleSearch.wordCount', label: '字数规则', multi: false },
  { path: 'ruleSearch.lastChapter', label: '最新章节规则', multi: false },
  { path: 'ruleSearch.intro', label: '简介规则', multi: false },
  { path: 'ruleSearch.coverUrl', label: '封面规则', multi: false },
  { path: 'ruleSearch.bookUrl', label: '详情页 URL 规则', multi: false }
];

const FIELDS_EXPLORE: FieldSpec[] = [
  { path: 'exploreUrl', label: '发现地址规则', multi: true },
  { path: 'ruleExplore.bookList', label: '书籍列表规则', multi: false },
  { path: 'ruleExplore.name', label: '书名规则', multi: false },
  { path: 'ruleExplore.author', label: '作者规则', multi: false },
  { path: 'ruleExplore.kind', label: '分类规则', multi: false },
  { path: 'ruleExplore.wordCount', label: '字数规则', multi: false },
  { path: 'ruleExplore.lastChapter', label: '最新章节规则', multi: false },
  { path: 'ruleExplore.intro', label: '简介规则', multi: false },
  { path: 'ruleExplore.coverUrl', label: '封面规则', multi: false },
  { path: 'ruleExplore.bookUrl', label: '详情页 URL 规则', multi: false },
  { path: 'homepageModules', label: '首页模块 (JSON)', multi: true }
];

const FIELDS_INFO: FieldSpec[] = [
  { path: 'ruleBookInfo.init', label: '预处理规则', multi: true },
  { path: 'ruleBookInfo.name', label: '书名规则', multi: false },
  { path: 'ruleBookInfo.author', label: '作者规则', multi: false },
  { path: 'ruleBookInfo.kind', label: '分类规则', multi: false },
  { path: 'ruleBookInfo.wordCount', label: '字数规则', multi: false },
  { path: 'ruleBookInfo.lastChapter', label: '最新章节规则', multi: false },
  { path: 'ruleBookInfo.intro', label: '简介规则', multi: false },
  { path: 'ruleBookInfo.coverUrl', label: '封面规则', multi: false },
  { path: 'ruleBookInfo.tocUrl', label: '目录 URL 规则', multi: false },
  { path: 'ruleBookInfo.canReName', label: '允许修改书名作者', multi: false },
  { path: 'ruleBookInfo.downloadUrls', label: '下载 URL 规则', multi: true },
  { path: 'ruleBookInfo.relatedBooks', label: '关联书籍', multi: true }
];

const FIELDS_TOC: FieldSpec[] = [
  { path: 'ruleToc.preUpdateJs', label: '更新之前 JS', multi: true },
  { path: 'ruleToc.chapterList', label: '目录列表规则', multi: false },
  { path: 'ruleToc.chapterName', label: '章节名称规则', multi: false },
  { path: 'ruleToc.chapterUrl', label: '章节 URL 规则', multi: false },
  { path: 'ruleToc.formatJs', label: '格式化规则', multi: true },
  { path: 'ruleToc.isVolume', label: 'Volume 标识', multi: false },
  { path: 'ruleToc.updateTime', label: '更新时间', multi: false },
  { path: 'ruleToc.isVip', label: 'VIP 标识', multi: false },
  { path: 'ruleToc.isPay', label: '购买标识', multi: false },
  { path: 'ruleToc.nextTocUrl', label: '目录下一页规则', multi: false }
];

const FIELDS_CONTENT: FieldSpec[] = [
  { path: 'ruleContent.content', label: '正文规则', multi: true },
  { path: 'ruleContent.subContent', label: '副文规则', multi: true },
  { path: 'ruleContent.title', label: '章节名称规则', multi: false },
  { path: 'ruleContent.nextContentUrl', label: '正文下一页 URL 规则', multi: false },
  { path: 'ruleContent.webJs', label: 'WebView JS', multi: true },
  { path: 'ruleContent.sourceRegex', label: '资源正则', multi: true },
  { path: 'ruleContent.replaceRegex', label: '替换规则', multi: true },
  { path: 'ruleContent.imageStyle', label: '图片样式', multi: false },
  { path: 'ruleContent.imageDecode', label: '图片解密', multi: true },
  { path: 'ruleContent.payAction', label: '购买操作', multi: true },
  { path: 'ruleContent.callBackJs', label: 'callBackJs', multi: true }
];

/** 六个选项卡的「类型/启用/发现/CookieJar/EventListener/自定义按钮」开关。 */
interface ToggleSpec {
  key: string;
  label: string;
  def: boolean;
}
const TOGGLE_SPECS: ToggleSpec[] = [
  { key: 'enabled', label: '启用', def: true },
  { key: 'enabledExplore', label: '发现', def: true },
  { key: 'enabledCookieJar', label: 'CookieJar', def: true },
  { key: 'eventListener', label: 'EventListener', def: false },
  { key: 'customButton', label: '自定义按钮', def: false }
];

/** 类型下拉四档，对齐上游 book_type 数组。 */
const SOURCE_TYPES: string[] = ['文本', '音频', '图片', '文件'];

/** Select 选项的显式类型（ArkTS 禁匿名对象字面量）。 */
interface TypeOption {
  value: string;
}

/** 溢出菜单项的显式类型。 */
interface MoreMenuItem {
  key: string;
  title: string;
}

const MORE_ITEMS: MoreMenuItem[] = [
  { key: 'login', title: '登录' }, { key: 'search', title: '搜索' },
  { key: 'clear_cookie', title: '清除 Cookie' }, { key: 'autocomplete', title: '自动补全' },
  { key: 'copy', title: '拷贝源' }, { key: 'paste', title: '粘贴源' },
  { key: 'variables', title: '设置源变量' }, { key: 'share', title: '字符串分享' },
  { key: 'log', title: '日志' }
];

@Entry
@Component
export struct BookSourceEditPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';

  /** 进入时携带的书源；undefined 表示新建。 */
  @Prop @Watch('onSourceChanged') editingSource?: BookSource = undefined;
  onBack: () => void = () => {};
  onSaveSource: (source: BookSource) => void = (_source: BookSource) => {};
  onOpenSourceSearch: (keyword: string, sourceUrl: string) => void = (_keyword: string, _sourceUrl: string) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** P9 登录/清 Cookie/源变量回调，由 Index 接线。 */
  onOpenSourceLogin: (sourceUrl: string) => void = (_sourceUrl: string) => {};
  onClearSourceCookie: (sourceUrl: string) => void = (_sourceUrl: string) => {};

  @State private activeTab: number = 0;
  @State private rootObj: Record<string, Object> = {};
  @State private rev: number = 0;
  @State private sourceTypeIndex: number = 0;
  @State private autoComplete: boolean = true;
  @State private moreMenuVisible: boolean = false;
  @State private variablePanelVisible: boolean = false;
  @State private variableDraft: string = '';

  aboutToAppear(): void {
    this.loadIntoRoot();
  }

  private onSourceChanged(): void {
    this.loadIntoRoot();
  }

  /** 把 editingSource.sourceJson 解析成可编辑对象；新建给最小骨架。 */
  private loadIntoRoot(): void {
    let obj: Record<string, Object> = {};
    if (this.editingSource !== undefined && this.editingSource.sourceJson.length > 0) {
      try {
        obj = JSON.parse(this.editingSource.sourceJson) as Record<string, Object>;
      } catch (_) {
        obj = {};
      }
    }
    this.rootObj = obj;
    this.sourceTypeIndex = this.editingSource?.bookSourceType ?? 0;
    this.rev++;
  }

  /** 读点路径（只认 string 值；布尔/数字由开关单独管理）。 */
  private readPath(path: string): string {
    const parts = path.split('.');
    let cur: Object | undefined = this.rootObj;
    for (let i = 0; i < parts.length; i++) {
      if (cur === undefined || cur === null || typeof cur !== 'object') { return ''; }
      cur = (cur as Record<string, Object>)[parts[i]];
    }
    return typeof cur === 'string' ? cur : '';
  }

  /** 写点路径，缺的中间段自动建空对象。 */
  private writePath(path: string, value: string): void {
    const parts = path.split('.');
    let cur: Record<string, Object> = this.rootObj;
    for (let i = 0; i < parts.length - 1; i++) {
      let next = cur[parts[i]];
      if (next === undefined || next === null || typeof next !== 'object') {
        const created: Record<string, Object> = {};
        cur[parts[i]] = created;
        next = created;
      }
      cur = next as Record<string, Object>;
    }
    cur[parts[parts.length - 1]] = value;
  }

  /** 读布尔开关（缺省用定义值）。 */
  private readBool(key: string, def: boolean): boolean {
    const value = this.rootObj[key];
    return typeof value === 'boolean' ? value : def;
  }

  private writeBool(key: string, value: boolean): void {
    this.rootObj[key] = value;
  }

  private fieldsForTab(): FieldSpec[] {
    if (this.activeTab === 0) { return FIELDS_BASE; }
    if (this.activeTab === 1) { return FIELDS_SEARCH; }
    if (this.activeTab === 2) { return FIELDS_EXPLORE; }
    if (this.activeTab === 3) { return FIELDS_INFO; }
    if (this.activeTab === 4) { return FIELDS_TOC; }
    return FIELDS_CONTENT;
  }

  /** 保存整条 sourceJson，并从 JSON 重建 5 个派生列（与 BookSourceImporter.toRule 同口径）。 */
  private save(): void {
    const url = this.readPath('bookSourceUrl').trim();
    if (url.length === 0) {
      this.onUnavailableAction('源 URL 不能为空');
      return;
    }
    // 把「类型」写回 JSON（bookSourceType 既是 JSON 字段也是派生列）。
    this.rootObj['bookSourceType'] = this.sourceTypeIndex;
    let json = '';
    try {
      json = JSON.stringify(this.rootObj);
    } catch (_) {
      this.onUnavailableAction('书源 JSON 序列化失败');
      return;
    }
    const name = this.readPath('bookSourceName');
    const group = this.readPath('bookSourceGroup');
    const saved: BookSource = {
      bookSourceUrl: url,
      bookSourceName: name,
      bookSourceGroup: group.length > 0 ? group : undefined,
      bookSourceType: this.sourceTypeIndex,
      enabled: this.readBool('enabled', true),
      customOrder: this.editingSource?.customOrder ?? 0,
      sourceJson: json
    };
    this.onSaveSource(saved);
  }

  /** 当前正在编辑的源 URL（未保存时用编辑页里的 bookSourceUrl 字段）。 */
  private currentSourceUrl(): string {
    return this.editingSource?.bookSourceUrl ?? this.readPath('bookSourceUrl').trim();
  }

  /** 溢出菜单动作。 */
  private async onMoreAction(key: string): Promise<void> {
    this.moreMenuVisible = false;
    if (key === 'copy') {
      try {
        await pasteboard.getSystemPasteboard()
          .setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, JSON.stringify(this.rootObj, null, 2)));
        this.onUnavailableAction('书源 JSON 已复制到剪贴板');
      } catch (_) {
        this.onUnavailableAction('复制失败');
      }
    } else if (key === 'paste') {
      try {
        const data = await pasteboard.getSystemPasteboard().getData();
        const text = data?.getPrimaryText() ?? '';
        if (text.length === 0) { this.onUnavailableAction('剪贴板没有文本'); return; }
        const obj = JSON.parse(text) as Record<string, Object>;
        this.rootObj = obj;
        this.sourceTypeIndex = typeof obj['bookSourceType'] === 'number' ? obj['bookSourceType'] as number : 0;
        this.rev++;
        this.onUnavailableAction('已从剪贴板粘贴书源');
      } catch (_) {
        this.onUnavailableAction('粘贴失败：剪贴板不是合法书源 JSON');
      }
    } else if (key === 'share') {
      try {
        await pasteboard.getSystemPasteboard()
          .setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, JSON.stringify(this.rootObj, null, 2)));
        this.onUnavailableAction('书源 JSON 已复制，可粘贴分享');
      } catch (_) {
        this.onUnavailableAction('分享失败');
      }
    } else if (key === 'search') {
      this.onOpenSourceSearch(this.readPath('bookSourceName'), this.readPath('bookSourceUrl'));
    } else if (key === 'autocomplete') {
      this.autoComplete = !this.autoComplete;
      this.onUnavailableAction(this.autoComplete ? '已开启自动补全' : '已关闭自动补全');
    } else if (key === 'login') {
      const url = this.currentSourceUrl();
      if (url.length === 0) { this.onUnavailableAction('请先保存书源再登录'); return; }
      this.onOpenSourceLogin(url);
    } else if (key === 'clear_cookie') {
      const url = this.currentSourceUrl();
      if (url.length === 0) { this.onUnavailableAction('请先保存书源'); return; }
      this.onClearSourceCookie(url);
    } else if (key === 'variables') {
      this.variableDraft = this.readPath('variable');
      this.variablePanelVisible = true;
    } else if (key === 'log') {
      this.onUnavailableAction('日志在 P10 实现');
    }
  }

  @Builder FieldRow(spec: FieldSpec) {
    Column() {
      Text(spec.label).fontSize(13).fontColor(this.themeColorTextTertiary).margin({ bottom: 4 }).width('100%')
      if (spec.multi) {
        TextArea({ placeholder: spec.label, text: this.readPath(spec.path) })
          .fontSize(15).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
          .backgroundColor(this.themeColorSurfaceTertiary).borderRadius(8).height(72)
          .onChange((value: string) => { this.writePath(spec.path, value); })
      } else {
        TextInput({ placeholder: spec.label, text: this.readPath(spec.path) })
          .fontSize(15).fontColor(this.themeColorTextPrimary).placeholderColor(this.themeColorTextTertiary)
          .backgroundColor(this.themeColorSurfaceTertiary).borderRadius(8)
          .onChange((value: string) => { this.writePath(spec.path, value); })
      }
    }.width('100%').margin({ bottom: 12 })
  }

  @Builder ToggleRow(toggle: ToggleSpec) {
    Row() {
      Text(toggle.label).fontSize(15).fontColor(this.themeColorTextPrimary).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.readBool(toggle.key, toggle.def) })
        .selectedColor(this.themeColorAccent)
        .onChange((isOn: boolean) => { this.writeBool(toggle.key, isOn); })
    }.width('100%').padding({ top: 8, bottom: 8 })
  }

  build() {
    Column() {
      AppTopBar({
        title: this.editingSource === undefined ? '新建书源' : '编辑书源',
        hasNavigation: true,
        navigationIcon: () => { TopBarBackButton({ onSelect: () => this.onBack() }) },
        actions: () => {
          TopBarButton({ icon: 'more', showDivider: false, onSelect: () => { this.moreMenuVisible = true; } })
        }
      })

      Tabs({ barPosition: BarPosition.Start, index: this.activeTab }) {
        ForEach(TAB_NAMES, (name: string, index: number) => {
          TabContent() {
            Scroll() {
              Column() {
                if (index === 0) {
                  Row() {
                    Text('类型').fontSize(15).fontColor(this.themeColorTextPrimary).layoutWeight(1)
                    Select(SOURCE_TYPES.map<TypeOption>((t: string): TypeOption => ({ value: t })))
                      .selected(this.sourceTypeIndex)
                      .onSelect((i: number) => { this.sourceTypeIndex = i; })
                      .fontColor(this.themeColorTextPrimary)
                  }.width('100%').padding({ top: 8, bottom: 8 })
                  ForEach(TOGGLE_SPECS, (toggle: ToggleSpec) => { this.ToggleRow(toggle) })
                }
                ForEach(this.fieldsForTab(), (spec: FieldSpec) => { this.FieldRow(spec) })
              }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 24 })
            }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
          }.tabBar(name)
        }, (name: string) => name)
      }
      .onChange((index: number) => { this.activeTab = index; })
      .layoutWeight(1)
      .barMode(BarMode.Scrollable)

      Row() {
        Button('保存').onClick(() => this.save()).layoutWeight(1)
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 16 })
    }
    .width('100%').height('100%')
    .backgroundColor(this.themeAppBackground.length > 0 ? this.themeAppBackground : this.themeColorSurfacePrimary)
    .bindSheet($$this.moreMenuVisible, this.MoreMenuBuilder(), { height: SheetSize.FIT_CONTENT, enableOutsideInteractive: false })
    .overlay(this.VariablePanelBuilder(), { align: Alignment.Bottom })
  }

  /** P9 源变量编辑面板：直接改 sourceJson 的 variable 键，保存时随整条写回。 */
  @Builder VariablePanelBuilder() {
    if (this.variablePanelVisible) {
      Column() {
        Row() {
          Text('设置源变量').fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
          Blank()
          Text('关闭').fontSize(15).fontColor(this.themeColorAccent)
            .onClick(() => { this.variablePanelVisible = false; })
        }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 8 })
        Text('变量名=值，每行一个。供书源 JS 通过 source.getVariable 读取。')
          .fontSize(12).fontColor(this.themeColorTextTertiary).padding({ left: 20, right: 20, bottom: 8 })
        TextArea({ placeholder: 'key=value', text: this.variableDraft })
          .fontSize(14).fontColor(this.themeColorTextPrimary)
          .backgroundColor(this.themeColorSurfaceTertiary).borderRadius(8).height(160)
          .margin({ left: 20, right: 20 })
          .onChange((value: string) => { this.variableDraft = value; })
        Button('保存变量').width('calc(100% - 40vp)').margin({ left: 20, right: 20, top: 12, bottom: 20 })
          .onClick(() => {
            this.writePath('variable', this.variableDraft);
            this.variablePanelVisible = false;
            this.onUnavailableAction('源变量已写入，点「保存」生效');
          })
      }
      .width('100%').backgroundColor(this.themeColorSurfacePrimary)
      .padding({ bottom: 16 })
    }
  }

  @Builder MoreMenuBuilder() {
    Column() {
      Text('更多操作').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').padding({ left: 20, top: 16, bottom: 12 })
      ForEach(MORE_ITEMS, (item: MoreMenuItem) => {
        Row() {
          Text(item.title).fontSize(16).fontColor(this.themeColorTextPrimary)
        }.width('100%').padding({ left: 20, top: 12, bottom: 12 })
        .onClick(() => { this.onMoreAction(item.key); })
      })
    }.padding({ bottom: 20 })
  }
}
