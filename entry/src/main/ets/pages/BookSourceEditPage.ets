// 书源编辑页（P5）。对齐上游 BookSourceEditScreen / BookSourceEditViewModel 的
// 六 tab + 68 字段槽；编辑对象是整条 sourceJson（唯一真值），派生列在保存时按同一口径重建。
// path 是点路径（ruleSearch.bookList），读写走 readPath / writePath 两个辅助函数。

import { pasteboard } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import curves from '@ohos.curves';
import { BookSource } from '../model/BookSource';
import { AppTopBar, TopBarBackButton, TopBarButton } from '../components/TopBar';
import { AppGlyph } from '../components/AppGlyph';
import { AppFab } from '../components/booksource/AppFab';
import { MarkdownIntro } from '../components/MarkdownIntro';
import { UiMenuPanel, UiMenuItem } from '../components/UiMenu';
import { BODY_LARGE, BODY_LARGE_LINE_HEIGHT, BODY_MEDIUM, BODY_SMALL, LABEL_LARGE, LABEL_MEDIUM, LABEL_SMALL, TITLE_LARGE, TITLE_MEDIUM, TITLE_SMALL } from '../components/typography/TypographyTokens';
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

/** 类型下拉四档，对齐上游 book_type 数组。 */
const SOURCE_TYPES: string[] = ['文本', '音频', '图片', '文件'];

// 十项顺序与文案照上游 BookSourceEditScreen.kt:383-413 的 RoundDropdownMenuItem：
// login 登录 / search 搜索 / cookie 清除 Cookie / auto_complete 自动补全（带勾）/
// copy_source 拷贝源 / paste_source 粘贴源 / set_source_variable 设置源变量 /
// str_share 字符串分享 / log 日志 / help 帮助。
// 直接用 UiMenuItem（而不是另立同形 interface）：ArkTS 不支持结构类型互传。
const MORE_ITEMS: UiMenuItem[] = [
  { key: 'login', title: '登录' },
  { key: 'search', title: '搜索' },
  { key: 'clear_cookie', title: '清除 Cookie' },
  { key: 'autocomplete', title: '自动补全' },
  { key: 'copy', title: '拷贝源' },
  { key: 'paste', title: '粘贴源' },
  { key: 'variables', title: '设置源变量' },
  { key: 'share', title: '字符串分享' },
  { key: 'log', title: '日志' },
  { key: 'help', title: '帮助' }
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
  /** 类型选项卡的下拉菜单（对齐上游 SourceEditOptionCard type 的 RoundDropdownMenu）。 */
  @State private sourceTypeMenuVisible: boolean = false;
  @State private variablePanelVisible: boolean = false;
  @State private variableDraft: string = '';
  /** 字段编辑底部 sheet：对齐上游 editingFieldPath / SourceEditFieldSheet。 */
  @State private fieldSheetVisible: boolean = false;
  @State private editingFieldPath: string = '';
  @State private editingFieldLabel: string = '';
  @State private editingFieldDraft: string = '';
  /** 帮助弹层：对齐上游 BookSourceEditSheet.Help(content) + MarkdownSheet(R.string.help)。 */
  @State private helpSheetVisible: boolean = false;
  @State private helpText: string = '';
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

  /** 溢出菜单的动作列表；「自动补全」带当前勾选态（上游 isSelected = state.autoComplete）。 */
  private moreMenuItems(): UiMenuItem[] {
    const items: UiMenuItem[] = [];
    for (let i = 0; i < MORE_ITEMS.length; i++) {
      const item = MORE_ITEMS[i];
      items.push({
        key: item.key,
        title: item.title,
        selected: item.key === 'autocomplete' ? this.autoComplete : false
      });
    }
    return items;
  }

  /**
   * 溢出菜单动作。对齐上游 BookSourceEditViewModel.kt:66-99：
   * login/search/variables/log 都是 `save { 打开对应界面 }`，即**先保存再动作**，
   * 所以这里也先落一次 save()，不再要求用户手动点保存。
   */
  private async onMoreAction(key: string): Promise<void> {
    this.moreMenuVisible = false;
    const url = this.readPath('bookSourceUrl').trim();
    // 需要源 URL 的项：先保存再执行（上游 save 内部也会校验源 URL 非空）。
    const needUrl = key === 'login' || key === 'clear_cookie' || key === 'log' ||
      key === 'search' || key === 'variables';
    if (needUrl && url.length === 0) {
      this.onUnavailableAction('源 URL 不能为空');
      return;
    }
    if (needUrl) {
      this.save();
    }
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
      this.onOpenSourceSearch(this.readPath('bookSourceName'), url);
    } else if (key === 'autocomplete') {
      this.autoComplete = !this.autoComplete;
      this.onUnavailableAction(this.autoComplete ? '已开启自动补全' : '已关闭自动补全');
    } else if (key === 'login') {
      this.onOpenSourceLogin(url);
    } else if (key === 'clear_cookie') {
      this.onClearSourceCookie(url);
    } else if (key === 'variables') {
      this.variableDraft = this.readPath('variable');
      this.variablePanelVisible = true;
    } else if (key === 'log') {
      this.onOpenSourceDebug(url);
    } else if (key === 'help') {
      this.openHelp();
    }
  }

  /**
   * 打开帮助：对齐上游 BookSourceEditViewModel.kt:123-129 showHelp()，
   * 读 assets/web/help/md/ruleHelp.md 后塞进 Help sheet（MarkdownSheet + MarkdownBlock）。
   * 本地同一个文件放在 rawfile/web/help/md/ruleHelp.md，读取方式照 OpenSourceLicensePage.ets:44。
   */
  private openHelp(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.onUnavailableAction('无法读取随应用提供的书源帮助');
      return;
    }
    try {
      const data = context.resourceManager.getRawFileContentSync('web/help/md/ruleHelp.md');
      this.helpText = util.TextDecoder.create('utf-8').decodeToString(data);
      this.helpSheetVisible = true;
    } catch (_) {
      this.onUnavailableAction('书源帮助读取失败');
    }
  }

  /**
   * 字段卡片：对齐上游 SourceEditFieldCard（BookSourceEditScreen.kt:193-218）。
   * label 用 titleSmall，值摘要用 bodyMedium/onSurfaceVariant、空值「—」、maxLines4 省略；
   * 点击整卡打开底部 sheet 编辑。字段 path 映射一行不改（只经 readPath 读摘要）。
   */
  @Builder FieldCard(spec: FieldSpec) {
    Column() {
      // 上游 titleSmall = 14.sp Bold（Typography.kt:30），调用点须显式加 Bold。
      Text(spec.label).fontSize(TITLE_SMALL).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary).width('100%')
      Text(this.readPath(spec.path).length > 0 ? this.readPath(spec.path) : '—')
        .fontSize(BODY_MEDIUM).fontColor(this.themeColorTextSecondary)
        .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%').margin({ top: 4 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    // 上游 SourceEditFieldCard（BookSourceEditScreen.kt:193-218）用 GlassCard 壳：
    // containerColor 默认 surfaceContainer（= themeColorSurfaceTertiary，ThemePalette.ets 发布位），
    // cornerRadius 默认 themeSettings.baseCardCornerRadius=16f（GlassCard.kt:79 + ThemeSettings.kt:29）。
    .backgroundColor(this.themeColorSurfaceTertiary)
    .borderRadius(16)
    .onClick(() => this.openFieldSheet(spec))
  }

  /** 打开字段编辑 sheet：把当前值灌进草稿，确认时按同一 path 写回。 */
  private openFieldSheet(spec: FieldSpec): void {
    this.editingFieldPath = spec.path;
    this.editingFieldLabel = spec.label;
    this.editingFieldDraft = this.readPath(spec.path);
    this.fieldSheetVisible = true;
  }

  /**
   * 选项卡片：对齐上游 SourceEditOptionCard（BookSourceEditScreen.kt:321-370）——
   * GlassCard 壳 + labelSmall(11sp) 单行标题 + 可选 subtitle TextCard + 选中时 16dp Check。
   */
  @Builder OptionCard(title: string, subtitle: string, checked: boolean, onClick: () => void) {
    Row() {
      Text(title)
        .fontSize(LABEL_SMALL).fontColor(this.themeColorTextPrimary)
        // 上游 .basicMarquee()：单行超长时跑马灯滚动，本地对应 TextOverflow.MARQUEE。
        .maxLines(1).textOverflow({ overflow: TextOverflow.MARQUEE })
        .layoutWeight(1).padding({ top: 8, bottom: 8 })
      if (subtitle.length > 0) {
        // 上游 TextCard(backgroundColor = colorScheme.surface, cornerRadius = 16.dp)。
        Text(subtitle)
          .fontSize(LABEL_SMALL).fontColor(this.themeColorTextSecondary)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(16).backgroundColor(this.themeColorSurfacePrimary)
      }
      if (checked) {
        // 上游 AppIcon(Check, size 16, padding end 8, tint = primary)。
        AppGlyph({ name: 'profileCheck', glyphSize: 16, tint: this.themeColorAccent })
          .margin({ left: 4, right: 8 })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 4 })
    .justifyContent(FlexAlign.SpaceBetween).alignItems(VerticalAlign.Center)
    // 上游同样用 GlassCard 壳：surfaceContainer + baseCardCornerRadius(16f)。
    .backgroundColor(this.themeColorSurfaceTertiary).borderRadius(16)
    .onClick(onClick)
  }

  /** 类型下拉菜单项：对齐上游 RoundDropdownMenu 的四档，选中项打勾。 */
  private sourceTypeMenuItems(): UiMenuItem[] {
    const items: UiMenuItem[] = [];
    for (let i = 0; i < SOURCE_TYPES.length; i++) {
      items.push({ key: String(i), title: SOURCE_TYPES[i], selected: this.sourceTypeIndex === i });
    }
    return items;
  }

  /** 选项区：对齐上游 BookSourceOptions（BookSourceEditScreen.kt:254-319）两行三列网格。 */
  @Builder OptionsGrid() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Stack({ alignContent: Alignment.End }) {
          this.OptionCard(SOURCE_TYPES[this.sourceTypeIndex], SOURCE_TYPES[this.sourceTypeIndex], false, () => {
            this.sourceTypeMenuVisible = true;
          })
        }.layoutWeight(1)
        // @Builder 调用返回 void，不能链式挂属性；bindPopup 挂在外层 Stack 上。
        .bindPopup(this.sourceTypeMenuVisible, {
          builder: () => { this.TypeMenuBuilder(); },
          placement: Placement.Bottom,
          enableArrow: false,
          autoCancel: true,
          onStateChange: (event: PopupStateChangeParam) => {
            if (!event.isVisible) { this.sourceTypeMenuVisible = false; }
          }
        })
        Stack() {
          this.OptionCard('启用', '', this.readBool('enabled', true), () => {
            this.writeBool('enabled', !this.readBool('enabled', true)); this.rev++;
          })
        }.layoutWeight(1)
        Stack() {
          this.OptionCard('发现', '', this.readBool('enabledExplore', true), () => {
            this.writeBool('enabledExplore', !this.readBool('enabledExplore', true)); this.rev++;
          })
        }.layoutWeight(1)
      }.width('100%')
      Row({ space: 8 }) {
        Stack() {
          this.OptionCard('CookieJar', '', this.readBool('enabledCookieJar', true), () => {
            this.writeBool('enabledCookieJar', !this.readBool('enabledCookieJar', true)); this.rev++;
          })
        }.layoutWeight(1)
        Stack() {
          this.OptionCard('EventListener', '', this.readBool('eventListener', false), () => {
            this.writeBool('eventListener', !this.readBool('eventListener', false)); this.rev++;
          })
        }.layoutWeight(1)
        Stack() {
          this.OptionCard('自定义按钮', '', this.readBool('customButton', false), () => {
            this.writeBool('customButton', !this.readBool('customButton', false)); this.rev++;
          })
        }.layoutWeight(1)
      }.width('100%')
    }.width('100%')
  }

  @Builder TypeMenuBuilder() {
    UiMenuPanel({
      items: this.sourceTypeMenuItems(),
      panelWidth: 160,
      onSelect: (key: string) => {
        this.sourceTypeIndex = Number(key);
        this.sourceTypeMenuVisible = false;
      }
    })
  }

  // @BuilderParam 槽位须传 @Builder 方法引用；内联 lambda 直接实例化 struct 会
  // 在运行时变成裸构造函数调用（class constructor cannot called without 'new'）。
  @Builder editNavSlot() {
    TopBarBackButton({ onSelect: () => this.onBack() })
  }

  @Builder editActionsSlot() {
    // 上游 :101-110 顺序：BugReport（保存并调试）在前、MoreVert（更多）在后。
    // 图标已按上游 ic_bug_report.xml 补齐为 bugReport，不再用近似；
    // accessibility 文案按上游 contentDescription=debug_source「调试书源」。
    TopBarButton({ icon: 'bugReport', showDivider: false, onSelect: () => this.saveAndDebug() })
    // 「更多」是下拉菜单不是底部弹层：上游 BookSourceEditScreen.kt:382 用 RoundDropdownMenu。
    // @Builder 调用不能链式挂属性，故用 Stack 承载 bindPopup（项目内 UiMenu 的既有用法）。
    Stack() {
      TopBarButton({ icon: 'more', showDivider: false, onSelect: () => { this.moreMenuVisible = true; } })
    }
    .bindPopup(this.moreMenuVisible, {
      builder: () => { this.MoreMenuPanel(); },
      placement: Placement.Bottom,
      enableArrow: false,
      autoCancel: true,
      onStateChange: (event: PopupStateChangeParam) => {
        if (!event.isVisible) { this.moreMenuVisible = false; }
      }
    })
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
      // 对齐上游 GlassTopAppBarDefaults.defaultScrollBehavior()（BookSourceEditScreen.kt:70）的高度过渡：
      // 上游随 nestedScroll 连续插值，本地是布尔折叠，用 springMotion 包住赋值让高度/透明度有过渡，
      // 写法与项目内其它折叠页（AppAiSettingsPage.ets:21）一致。
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
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
                    this.OptionsGrid()
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

        // 源变量面板：必须放在 Stack 内条件渲染。原先用 `.overlay(this.VariablePanelBuilder())`，
        // 而 overlay 即便 Builder 内容为空也会生成一个覆盖全屏的 overlay 节点，把整页点击全部吃掉
        // （表现为字段卡片、tab、按钮全部点不动）。
        if (this.variablePanelVisible) {
          this.VariablePanelBuilder()
        }
      }
      .layoutWeight(1)
      // ArkUI 一个组件只能绑定一个半模态：原先 fieldSheet 与 helpSheet 都挂在最外层 Column 上，
      // 后一个会覆盖前一个，导致两个 sheet 都弹不出来（表现为点字段卡片、点「帮助」全无反应）。
      // 这里把 helpSheet 移到内层 Stack，两个 sheet 各归一个组件。
      .bindSheet($$this.helpSheetVisible, this.HelpSheetBuilder(), {
        height: SheetSize.FIT_CONTENT,
        // 上游 MarkdownSheet 走 AppModalBottomSheet，M3 分支（AppModalBottomSheet.kt:145-153）
        // 只画 DragHandle、无右上关闭按钮；bindSheet 的 showClose 默认 true 会多画一个 ×。
        showClose: false,
        enableOutsideInteractive: true
      })
    }
    .width('100%').height('100%')
    .backgroundColor(this.themeAppBackground.length > 0 ? this.themeAppBackground : this.themeColorSurfacePrimary)
    // 上游 AppModalBottomSheet 默认 enableOutsideInteractive=true、sheetGesturesEnabled=true：
    // 点遮罩或下滑都能关闭。字段 sheet 按上游去掉了「取消/确认」按钮（SourceEditFieldSheet.kt:220-252），
    // 因此这里必须保留遮罩可点，否则 sheet 打开后无任何关闭途径，整页看起来无法交互。
    .bindSheet($$this.fieldSheetVisible, this.FieldSheetBuilder(), {
      height: SheetSize.FIT_CONTENT,
      // 同上：上游 AppModalBottomSheet 的 M3 分支没有右上关闭按钮。
      showClose: false,
      enableOutsideInteractive: true
    })
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
   * 单一 AppTextField（minLines4/maxLines24），按字段 label 作标题，实时回写、无确认/取消按钮。
   * 本地用 TextArea 承载多行，constraintSize 近似 minLines/maxLines 的动态高度；
   * onChange 直接 writePath（上游 onValueChange 实时回写），关闭即完成。
   */
  @Builder FieldSheetBuilder() {
    Column() {
      Text(this.editingFieldLabel).fontSize(TITLE_LARGE).fontColor(this.themeColorTextPrimary)
        .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 8 })
      TextArea({ placeholder: this.editingFieldLabel, text: this.editingFieldDraft })
        .fontSize(BODY_MEDIUM).fontColor(this.themeColorTextPrimary)
        .backgroundColor(this.themeColorSurfaceTertiary).borderRadius(8)
        .constraintSize({ minHeight: 96, maxHeight: 320 })
        .margin({ left: 20, right: 20, bottom: 20 })
        .onChange((value: string) => {
          this.editingFieldDraft = value;
          this.writePath(this.editingFieldPath, value);
        })
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

  /** 下拉菜单面板：Reuse UiMenuPanel（对齐 RoundDropdownMenu 的两层卡片结构）。 */
  @Builder MoreMenuPanel() {
    UiMenuPanel({
      items: this.moreMenuItems(),
      panelWidth: 220,
      onSelect: (key: string) => { this.onMoreAction(key); }
    })
  }

  /**
   * 帮助弹层：对齐上游 BookSourceEditScreen.kt:184-190 的
   * `MarkdownSheet(title = R.string.help, content = helpSheet.content)`。
   */
  @Builder HelpSheetBuilder() {
    Column() {
      Text('帮助')
        .fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').textAlign(TextAlign.Center)
        .padding({ left: 56, right: 56, bottom: 16 })
      Scroll() {
        Column() {
          MarkdownIntro({
            source: this.helpText,
            textColor: this.themeColorTextPrimary,
            bodySize: BODY_LARGE,
            bodyLineHeight: BODY_LARGE_LINE_HEIGHT
          })
          Row().height(16)
        }.width('100%')
      }
      .width('100%').constraintSize({ maxHeight: '80%' })
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 16 })
    .backgroundColor(this.themeColorSurfaceTertiary)
    .borderRadius({ topLeft: 28, topRight: 28 })
  }
}
