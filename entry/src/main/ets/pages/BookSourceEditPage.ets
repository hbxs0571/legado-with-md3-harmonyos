// 书源编辑页（P5）。对齐上游 BookSourceEditScreen / BookSourceEditViewModel 的
// 六 tab + 68 字段槽；编辑对象是整条 sourceJson（唯一真值），派生列在保存时按同一口径重建。
// path 是点路径（ruleSearch.bookList），读写走 readPath / writePath 两个辅助函数。

import { pasteboard } from '@kit.BasicServicesKit';
import { BookSource } from '../model/BookSource';
import { AppTopBar, TopBarBackButton, TopBarButton } from '../components/TopBar';
import { AppGlyph } from '../components/AppGlyph';
import { AppFab } from '../components/booksource/AppFab';
import { BODY_LARGE, BODY_MEDIUM, BODY_SMALL, LABEL_LARGE, LABEL_MEDIUM, TITLE_LARGE, TITLE_MEDIUM, TITLE_SMALL } from '../components/typography/TypographyTokens';
import { HEADER_COLLAPSE_THRESHOLD, HEADER_EXPAND_THRESHOLD } from '../components/UiTokens';

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
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
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
  /** 打开书源调试页（P10，溢出菜单「日志」）。 */
  onOpenSourceDebug: (sourceUrl: string) => void = (_sourceUrl: string) => {};

  @State private activeTab: number = 0;
  @State private rootObj: Record<string, Object> = {};
  @State private rev: number = 0;
  @State private sourceTypeIndex: number = 0;
  @State private autoComplete: boolean = true;
  @State private moreMenuVisible: boolean = false;
  @State private variablePanelVisible: boolean = false;
  @State private variableDraft: string = '';
  /** 字段编辑底部 sheet：对齐上游 editingFieldPath / SourceEditFieldSheet。 */
  @State private fieldSheetVisible: boolean = false;
  @State private editingFieldPath: string = '';
  @State private editingFieldLabel: string = '';
  @State private editingFieldDraft: string = '';
  /** 顶栏随内容滚动折叠（动画不作为验收项，按 yOffset 阈值切换）。 */
  @State private collapsedHeader: boolean = false;
  /** 六个 tab 各自独立的 Scroller，供顶栏折叠判定读取 yOffset。 */
  private tabScrollers: Scroller[] = [
    new Scroller(), new Scroller(), new Scroller(), new Scroller(), new Scroller(), new Scroller()
  ];

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
      const url = this.currentSourceUrl();
      if (url.length === 0) { this.onUnavailableAction('请先保存书源'); return; }
      this.onOpenSourceDebug(url);
    }
  }

  /**
   * 字段卡片：对齐上游 SourceEditFieldCard（BookSourceEditScreen.kt:193-218）。
   * label 用 titleSmall，值摘要用 bodyMedium/onSurfaceVariant、空值「—」、maxLines4 省略；
   * 点击整卡打开底部 sheet 编辑。字段 path 映射一行不改（只经 readPath 读摘要）。
   */
  @Builder FieldCard(spec: FieldSpec) {
    Column() {
      Text(spec.label).fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary).width('100%')
      Text(this.readPath(spec.path).length > 0 ? this.readPath(spec.path) : '—')
        .fontSize(BODY_MEDIUM).fontColor(this.themeColorTextSecondary)
        .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%').margin({ top: 4 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor(this.themeColorSurfaceSecondary)
    .borderRadius(12)
    .onClick(() => this.openFieldSheet(spec))
  }

  /** 打开字段编辑 sheet：把当前值灌进草稿，确认时按同一 path 写回。 */
  private openFieldSheet(spec: FieldSpec): void {
    this.editingFieldPath = spec.path;
    this.editingFieldLabel = spec.label;
    this.editingFieldDraft = this.readPath(spec.path);
    this.fieldSheetVisible = true;
  }

  @Builder ToggleRow(toggle: ToggleSpec) {
    Row() {
      Text(toggle.label).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.readBool(toggle.key, toggle.def) })
        .selectedColor(this.themeColorAccent)
        .onChange((isOn: boolean) => { this.writeBool(toggle.key, isOn); })
    }.width('100%').padding({ top: 8, bottom: 8 })
  }

  // @BuilderParam 槽位须传 @Builder 方法引用；内联 lambda 直接实例化 struct 会
  // 在运行时变成裸构造函数调用（class constructor cannot called without 'new'）。
  @Builder editNavSlot() {
    TopBarBackButton({ onSelect: () => this.onBack() })
  }

  @Builder editActionsSlot() {
    // 上游 :101-110 顺序：BugReport（保存并调试）在前、MoreVert（更多）在后。
    // 本地无 BugReport 图标，用语义最近的 profileRunningWithErrors（运行诊断）代替，
    // 差异写进报告；accessibility 文案按上游 contentDescription=debug_source「调试书源」。
    TopBarButton({ icon: 'profileRunningWithErrors', showDivider: false, onSelect: () => this.saveAndDebug() })
    TopBarButton({ icon: 'more', showDivider: false, onSelect: () => { this.moreMenuVisible = true; } })
  }

  /** 保存并调试：沿用现有保存，成功后把该源送到调试页。 */
  private saveAndDebug(): void {
    const url = this.readPath('bookSourceUrl').trim();
    if (url.length === 0) {
      this.onUnavailableAction('源 URL 不能为空');
      return;
    }
    this.save();
    this.onOpenSourceDebug(url);
  }

  /** 顶栏折叠判定：滚动偏移超过阈值折叠，低于阈值展开，中间区间保持原态。 */
  private updateHeaderOffset(scroller: Scroller): void {
    const offset = scroller.currentOffset().yOffset;
    const shouldCollapse = offset > HEADER_COLLAPSE_THRESHOLD ? true
      : offset < HEADER_EXPAND_THRESHOLD ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      this.collapsedHeader = shouldCollapse;
    }
  }

  build() {
    Column() {
      AppTopBar({
        title: this.editingSource === undefined ? '新建书源' : '编辑书源',
        hasNavigation: true,
        collapsed: this.collapsedHeader,
        navigationIcon: () => { this.editNavSlot() },
        actions: () => { this.editActionsSlot() }
      })

      Stack({ alignContent: Alignment.BottomEnd }) {
        Tabs({ barPosition: BarPosition.Start, index: this.activeTab }) {
          ForEach(TAB_NAMES, (name: string, index: number) => {
            TabContent() {
              Scroll(this.tabScrollers[index]) {
                Column({ space: 12 }) {
                  if (index === 0) {
                    Row() {
                      Text('类型').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).layoutWeight(1)
                      Select(SOURCE_TYPES.map<TypeOption>((t: string): TypeOption => ({ value: t })))
                        .selected(this.sourceTypeIndex)
                        .onSelect((i: number) => { this.sourceTypeIndex = i; })
                        .fontColor(this.themeColorTextPrimary)
                    }.width('100%').padding({ top: 8, bottom: 8 })
                    ForEach(TOGGLE_SPECS, (toggle: ToggleSpec) => { this.ToggleRow(toggle) })
                  }
                  ForEach(this.fieldsForTab(), (spec: FieldSpec) => { this.FieldCard(spec) })
                }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 96 })
              }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
                .onScroll(() => { this.updateHeaderOffset(this.tabScrollers[index]); })
            }.tabBar(this.tabCard(name, index))
          }, (name: string) => name)
        }
        .onChange((index: number) => { this.activeTab = index; })
        .width('100%').height('100%')
        .barMode(BarMode.Scrollable)

        // 右下保存 FAB：复用批3新建的 AppFab（批4调试页复用同一组件）。
        AppFab({
          icon: 'profileSave',
          fabAccessibilityText: '保存',
          onFabClick: () => this.save()
        })
        .margin({ right: 16, bottom: 16 })
      }
      .layoutWeight(1)
    }
    .width('100%').height('100%')
    .backgroundColor(this.themeAppBackground.length > 0 ? this.themeAppBackground : this.themeColorSurfacePrimary)
    .bindSheet($$this.moreMenuVisible, this.MoreMenuBuilder(), { height: SheetSize.FIT_CONTENT, enableOutsideInteractive: false })
    .bindSheet($$this.fieldSheetVisible, this.FieldSheetBuilder(), { height: SheetSize.FIT_CONTENT, enableOutsideInteractive: false })
    .overlay(this.VariablePanelBuilder(), { align: Alignment.Bottom })
  }

  /**
   * M3 分段 tab（AppTabRow.kt:40-56 的 PrimaryScrollableTabRow）：
   * 透明底、无分隔线、选中字用 primary、未选用 onSurfaceVariant、指示条在选中段下方。
   */
  @Builder tabCard(label: string, index: number) {
    Column() {
      Text(label)
        .fontSize(LABEL_LARGE)
        .fontWeight(this.activeTab === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.activeTab === index ? this.themeColorAccent : this.themeColorTextSecondary)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
      Row()
        .width(this.activeTab === index ? 24 : 0)
        .height(3)
        .borderRadius(2)
        .backgroundColor(this.themeColorAccent)
        .margin({ top: 4 })
    }
    .justifyContent(FlexAlign.Center)
    .padding({ left: 8, right: 8, top: 8, bottom: 4 })
    .constraintSize({ minWidth: 0 })
  }

  /**
   * 字段编辑 sheet：对齐上游 SourceEditFieldSheet（:220-252）——
   * 单一 AppTextField（minLines4/maxLines24），按字段 label 作标题，实时回写不另做确认。
   * 本地用 TextArea 承载多行；确认/取消是 ArkUI bindSheet 的关闭入口，数据只在确认时写回。
   */
  @Builder FieldSheetBuilder() {
    Column() {
      Text(this.editingFieldLabel).fontSize(TITLE_LARGE).fontColor(this.themeColorTextPrimary)
        .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 8 })
      TextArea({ placeholder: this.editingFieldLabel, text: this.editingFieldDraft })
        .fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary)
        .backgroundColor(this.themeColorSurfaceTertiary).borderRadius(8).height(160)
        .margin({ left: 20, right: 20 })
        .onChange((value: string) => { this.editingFieldDraft = value; })
      Row() {
        Blank()
        Text('取消').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextSecondary)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => { this.fieldSheetVisible = false; })
        Text('确认').fontSize(TITLE_MEDIUM).fontColor(this.themeColorAccent)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            this.writePath(this.editingFieldPath, this.editingFieldDraft);
            this.fieldSheetVisible = false;
          })
      }.width('100%').justifyContent(FlexAlign.End).padding({ right: 20, bottom: 16 })
    }
    .width('100%').backgroundColor(this.themeColorSurfacePrimary)
  }

  /** P9 源变量编辑面板：直接改 sourceJson 的 variable 键，保存时随整条写回。 */
  @Builder VariablePanelBuilder() {
    if (this.variablePanelVisible) {
      Column() {
        Row() {
          Text('设置源变量').fontSize(TITLE_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
          Blank()
          Text('关闭').fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
            .onClick(() => { this.variablePanelVisible = false; })
        }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 8 })
        Text('变量名=值，每行一个。供书源 JS 通过 source.getVariable 读取。')
          .fontSize(BODY_SMALL).fontColor(this.themeColorTextTertiary).padding({ left: 20, right: 20, bottom: 8 })
        TextArea({ placeholder: 'key=value', text: this.variableDraft })
          .fontSize(TITLE_SMALL).fontColor(this.themeColorTextPrimary)
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
      Text('更多操作').fontSize(BODY_LARGE).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').padding({ left: 20, top: 16, bottom: 12 })
      ForEach(MORE_ITEMS, (item: MoreMenuItem) => {
        Row() {
          Text(item.title).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary)
        }.width('100%').padding({ left: 20, top: 12, bottom: 12 })
        .onClick(() => { this.onMoreAction(item.key); })
      })
    }.padding({ bottom: 20 })
  }
}
