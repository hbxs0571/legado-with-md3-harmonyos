// 书源登录底部弹层（对齐上游 SourceLoginSheets.kt:59-106 的 SourceLoginSheetHost）。
//
// 上游形态（现取自 bba5c64）：
//   MainNavGraph.kt:390-408 登录是模态路由（ModalOverlaySceneStrategy.modalOverlay()），
//   不是整页；Host 在同一条模态壳里按 state 切三态：
//     :66-77  loading → AppModalBottomSheet(title=login「登录」) + Box(heightIn min 160) + CircularProgressIndicator
//     :79-83  Web     → SourceLoginWebSheet（:276-302：title=state.title、endAction=Check、
//                       contentPaddingEnabled=false、sheetGesturesEnabled=false、Box(heightIn min 520)）
//     :85     Form    → SourceLoginFormSheet（:114-191：title=state.title、startAction=MoreVert 菜单、
//                       endAction=Check、行按 calculateFlexRows 排布、spacedBy8、底部 padding 24）
//   标题文案 state.title = getString(R.string.login_source, tag)（SourceLoginViewModel.kt:154），
//   中文为「登录 %s」（values-zh-rCN/strings.xml）。
//
// 本地用 bindSheet 承载同一条壳：bindSheet 的 dragBar 即上游 BottomSheetDefaults.DragHandle，
// 标题与两侧动作用 build 里自绘的 header（ArkUI 的 SheetOptions 只有 title 文案位，没有 action 槽位）。
import { webview } from '@kit.ArkWeb';
import { pasteboard } from '@kit.BasicServicesKit';
import { BookSourceLoginItem, CookieStore } from '@legado/sourceengine';
import { BookSourceRepository } from '../../data/BookSourceRepository';
import {
  BookSourceLoginCoordinator, LoginPrepare, LoginSubmitResult
} from '../../bookSource/BookSourceLoginCoordinator';
import { LABEL_LARGE, LABEL_MEDIUM, TITLE_MEDIUM } from '../typography/TypographyTokens';
import { UiMenuItem, UiMenuPanel } from '../UiMenu';
import { AppGlyph } from '../AppGlyph';
import { MarkdownIntro } from '../MarkdownIntro';

/** 表单项的本地可变副本（引擎 BookSourceLoginItem 字段只读投影到 state）。 */
class FormItem {
  name: string = '';
  type: string = '';
  action: string = '';
  viewName: string = '';
  defaultValue: string = '';
  chars: string[] = [];
  value: string = '';
  constructor(name: string, type: string, viewName: string, def: string, action: string, chars: string[]) {
    this.name = name; this.type = type; this.viewName = viewName;
    this.defaultValue = def; this.value = def; this.action = action; this.chars = chars;
  }
}

@Component
export struct SourceLoginSheet {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#FDFBFF';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;

  /** 显隐由调用方（Index）持有，与上游 modalOverlay 的进出一一对应。 */
  @Link visible: boolean;
  /** 换源时要重跑 prepare，否则沿用上一次的表单项与模式。 */
  @Prop @Watch('onSourceUrlChanged') sourceUrl: string = '';
  /** 弹层关闭：上游 onDismissRequest → SourceLoginIntent.Back。 */
  onClose: () => void = () => {};
  /** 按钮 action 是外部 URL 时交给 Index 打开通用 WebView（验证码页）。 */
  onOpenWeb: (url: string) => void = (_url: string) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  // 三态照上游：loading（准备中）/ web（loginUi 为空走 WebView）/ form（loginUi 非空）/
  // error（本地扩展，prepare 失败时复用 loading 壳显示原因）。
  @State private mode: string = 'form';
  @State private sheetLoading: boolean = true;
  @State private sourceName: string = '';
  @State private items: FormItem[] = [];
  @State private entryUrl: string = '';
  @State private resultMessage: string = '';
  @State private submitting: boolean = false;
  /** startAction 的 MoreVert 菜单（上游 :118-137 三项）。 */
  @State private menuVisible: boolean = false;
  /** 登录头 MarkdownSheet（上游 :88-101，标题 login_header + endAction ContentCopy）。 */
  @State private headerSheetVisible: boolean = false;
  private webController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    this.prepare();
  }

  /** 换源（同一弹层实例复用到另一个书源）时重置为 loading 并重跑 prepare。 */
  onSourceUrlChanged(): void {
    this.sheetLoading = true;
    this.menuVisible = false;
    this.headerSheetVisible = false;
    this.prepare();
  }

  /** 登录说明（上游 MarkdownSheet(title=login_header, content=header.content)）。 */
  private loginHeader(): string {
    const all = BookSourceRepository.getAll();
    for (const source of all) {
      if (source.bookSourceUrl === this.sourceUrl && source.sourceJson.length > 0) {
        try {
          const obj = JSON.parse(source.sourceJson) as Record<string, Object>;
          const value = obj['loginHeader'];
          return typeof value === 'string' ? value : '';
        } catch (_) {
          return '';
        }
      }
    }
    return '';
  }

  /** 上游 :94-100 endAction MediumTonalButton(ContentCopy) → CopyLoginHeader。 */
  private async copyLoginHeader(): Promise<void> {
    try {
      await pasteboard.getSystemPasteboard().setData(
        pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.loginHeader()));
      this.onUnavailableAction('已复制');
    } catch (_) {
      this.onUnavailableAction('复制失败');
    }
  }

  /** 上游 :92 DeleteLoginHeader → source.removeLoginHeader()。 */
  private async deleteLoginHeader(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    this.resultMessage = await BookSourceLoginCoordinator.removeLoginHeader(context, this.sourceUrl);
  }

  private prepare(): void {
    const info: LoginPrepare = BookSourceLoginCoordinator.prepare(this.sourceUrl);
    this.sourceName = info.sourceName;
    this.entryUrl = info.entryUrl;
    this.resultMessage = info.message;
    const formItems: FormItem[] = [];
    for (const item of info.items) {
      formItems.push(new FormItem(item.name, item.type,
        item.viewName.length > 0 ? item.viewName : item.name,
        item.defaultValue.length > 0 ? item.defaultValue : item.value,
        item.action, item.chars.slice()));
    }
    this.items = formItems;
    this.mode = info.mode;
    if (info.mode === 'error') { this.resultMessage = info.message || '无法登录'; }
    // prepare 完成即退出 loading 态（上游 state.loading 为准备中）。
    this.sheetLoading = false;
  }

  private async submit(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.resultMessage = '无法获取应用上下文'; return; }
    this.submitting = true;
    this.resultMessage = '正在提交登录…';
    const values: Record<string, string> = {};
    for (const item of this.items) {
      if (item.type === 'button') { continue; }
      values[item.name] = item.value;
    }
    const result: LoginSubmitResult = await BookSourceLoginCoordinator.submit(
      context, this.sourceUrl, values);
    this.submitting = false;
    this.resultMessage = result.message;
    if (result.ok) {
      this.onUnavailableAction('登录完成：' + result.message);
    }
  }

  private selectOptions(chars: string[]): SelectOption[] {
    const options: SelectOption[] = [];
    for (const c of chars) {
      options.push({ value: c });
    }
    return options;
  }

  private async runItemAction(item: FormItem): Promise<void> {
    if (item.action.trim().length === 0) { return; }
    if (/^https?:\/\//i.test(item.action.trim())) {
      this.onOpenWeb(item.action.trim());
      return;
    }
    this.resultMessage = await BookSourceLoginCoordinator.runAction(this.sourceUrl, item.action);
  }

  /** 上游 :126-134 RoundDropdownMenu 三项。 */
  private menuItems(): UiMenuItem[] {
    const items: UiMenuItem[] = [];
    items.push({ key: 'show_header', title: '查看登录头' });
    items.push({ key: 'del_header', title: '删除登录头' });
    items.push({ key: 'log', title: '日志' });
    return items;
  }

  /** 上游 :114-191 SourceLoginFormSheet 的标题 = state.title。 */
  private sheetTitle(): string {
    return this.sheetLoading ? '登录' : '登录 · ' + this.sourceName;
  }

  @Builder ControlView(item: FormItem, index: number) {
    Column() {
      if (item.type === 'button') {
        // 上游 SourceLoginSheets.kt:223-242 把 button 交给 ExploreKindMultiTypeItem，
        // 后者（ExploreKindItem.kt:46-106）的壳是 GlassCard(cornerRadius=12dp,
        // containerColor=surface) + KindText 居中 labelMediumEmphasized、
        // Box heightIn(min=44dp) padding vertical 8dp——不是 Material Button 的 primary 底大胶囊。
        Text(item.viewName)
          .fontSize(LABEL_MEDIUM).fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorTextPrimary)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center).width('100%')
          .constraintSize({ minHeight: 44 })
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor(this.themeColorSurfacePrimary)
          .borderRadius(12)
          .enabled(!this.submitting)
          .onClick(() => { this.runItemAction(item); })
      } else if (item.type === 'select' || (item.type === 'toggle' && item.chars.length > 0)) {
        Text(item.viewName).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
          .width('100%').margin({ bottom: 4 })
        Select(this.selectOptions(item.chars))
          .value(item.value.length > 0 ? item.value : (item.chars.length > 0 ? item.chars[0] : ''))
          .onSelect((i: number) => { this.items[index].value = item.chars[i]; })
          .fontColor(this.themeColorTextPrimary)
      } else if (item.type === 'toggle') {
        Row() {
          Text(item.viewName).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: item.value === 'true' || item.value === '1' })
            .onChange((on: boolean) => { this.items[index].value = on ? 'true' : 'false'; })
        }
      } else {
        Text(item.viewName).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
          .width('100%').margin({ bottom: 4 })
        TextInput({ placeholder: item.viewName, text: item.value })
          .type(item.type === 'password' ? InputType.Password : InputType.Normal)
          .fontColor(this.themeColorTextPrimary)
          .backgroundColor(this.themeColorSurfaceTertiary).borderRadius(8)
          .onChange((value: string) => { this.items[index].value = value; })
      }
    }.width('100%').margin({ bottom: 8 })
  }

  /**
   * 弹层自绘 header：上游 AppModalBottomSheet.kt:171-215 的 hasHeader 布局——
   * 标题 titleMediumEmphasized 居中、左右各留 56 给 action，左 startAction、右 endAction。
   */
  @Builder SheetHeader() {
    Stack() {
      Text(this.sheetTitle())
        .fontSize(TITLE_MEDIUM)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .padding({ left: 56, right: 56 })
      // startAction：仅表单态有（上游 form sheet 的 MoreVert 菜单）。
      if (!this.sheetLoading && this.mode !== 'web') {
        Row() {
          AppGlyph({ name: 'more', glyphSize: 22, tint: this.themeColorTextTertiary })
        }
        .width(40).height(40)
        .borderRadius(20)
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: 0 })
        .onClick(() => { this.menuVisible = !this.menuVisible; })
      }
      // endAction：Check（上游 form :138-144 与 web :280-286 都是「确认」）。
      Row() {
        AppGlyph({ name: 'profileCheck', glyphSize: 22, tint: this.themeColorAccent })
      }
      .width(40).height(40)
      .borderRadius(20)
      .justifyContent(FlexAlign.Center)
      .position({ x: '100%', y: 0 })
      .markAnchor({ x: 40, y: 0 })
      .onClick(() => {
        if (this.sheetLoading) { return; }
        if (this.mode === 'web') {
          // 上游 Web 态 Confirm：检查登录态是否已生效。
          BookSourceLoginCoordinator.checkLogin(this.sourceUrl).then((r) => {
            this.resultMessage = r.ok ? '登录已生效' : r.message;
            if (r.ok) { this.onUnavailableAction('登录已生效'); }
          });
        } else {
          this.submit();
        }
      })
    }
    .width('100%')
    .height(40)
    .padding({ bottom: 16 })
  }

  @Builder MenuPanelBuilder() {
    UiMenuPanel({
      items: this.menuItems(),
      panelWidth: 160,
      onSelect: (key: string) => {
        this.menuVisible = false;
        if (key === 'show_header') {
          this.headerSheetVisible = true;
        } else if (key === 'del_header') {
          this.deleteLoginHeader();
        } else {
          // 上游 :132-134 打开 AppLogSheet；本地没有 AppLog 等价载体（见交付说明）。
          this.onUnavailableAction('本地未接入日志面板');
        }
      }
    })
  }

  @Builder SheetContent() {
    Column() {
      // @Builder 调用是语句不是组件实例，通用属性必须挂在包裹它的 Stack 上。
      Stack() {
        this.SheetHeader()
      }
      .width('100%')
      .bindPopup(this.menuVisible, {
        builder: () => { this.MenuPanelBuilder(); },
        placement: Placement.Bottom,
        enableArrow: false,
        autoCancel: true,
        onStateChange: (event: PopupStateChangeParam) => {
          if (!event.isVisible) { this.menuVisible = false; }
        }
      })

      if (this.sheetLoading) {
        // 上游 :66-77：Box(fillMaxWidth, heightIn(min 160), Center) + CircularProgressIndicator。
        Column() {
          LoadingProgress().width(48).height(48).color(this.themeColorAccent)
          if (this.resultMessage.length > 0) {
            Text(this.resultMessage)
              .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary).margin({ top: 12 })
          }
        }
        .width('100%').height(160)
        .justifyContent(FlexAlign.Center)
      } else if (this.mode === 'web') {
        // 上游 :276-302 SourceLoginWebSheet：contentPaddingEnabled=false、高度下限 520。
        // WebView 手势要留给网页本身，所以这个 sheet 不让内容区随手势拖拽（SheetType/滚动交给内容）。
        Web({ src: this.entryUrl, controller: this.webController })
          .javaScriptAccess(true).domStorageAccess(true)
          .width('100%').height(520)
          .onPageEnd(() => {
            const cookie = CookieStore.forSource(this.sourceUrl).getCookie(this.entryUrl);
            if (cookie.trim().length > 0) {
              BookSourceLoginCoordinator.checkLogin(this.sourceUrl).then((r) => {
                this.resultMessage = r.ok ? '登录已生效' : r.message;
              });
            }
          })
      } else {
        // 上游 :145-190 SourceLoginFormSheet 内容：verticalScroll + bottom 24 + spacedBy 8。
        Scroll() {
          Column() {
            ForEach(this.items, (item: FormItem, index: number) => {
              this.ControlView(item, index)
            }, (item: FormItem): string => item.name)
            if (this.resultMessage.length > 0) {
              Text(this.resultMessage).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
                .margin({ top: 12 }).width('100%')
            }
          }
          .width('100%')
          .padding({ bottom: 24 })
        }
        .width('100%')
        // 不给 Scroll 设百分比高度：sheet 是 FIT_CONTENT，百分比相对父容器会形成循环依赖，
        // 算出的高度小于内容 → 表单底部控件被裁掉。上游 AppModalBottomSheet.kt:145-168 的
        // 做法是 Column(verticalScroll) 不设高、由 sheet 的 heightIn(max=容器高*0.8) 兜底，
        // 内容超高时 sheet 自身封顶、内容区内部滚动。
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    // 上游 AppModalBottomSheet.kt:159-164 contentPaddingEnabled 时 start/end/bottom 各 16。
    .padding({ left: 16, right: 16, bottom: 16 })
    .backgroundColor(this.themePureBlack ? '#17181E' : this.themeColorSurfaceElevated)
  }

  /**
   * 上游 :88-101 登录头是独立的 MarkdownSheet(title=login_header「登录头」, content=header,
   * endAction=MediumTonalButton(ContentCopy))，与 form/web 弹层**同时**显示、各自独立关闭
   * （Host 里两个 AppModalBottomSheet 并列 show）。所以这里也是两个弹层叠加，不做内容替换。
   */
  @Builder LoginHeaderSheet() {
    Column() {
      // 上游 :94-100 endAction = MediumTonalButton(ContentCopy)：标题居中、右上角复制图标。
      Stack() {
        Text('登录头')
          .fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorTextPrimary)
          .maxLines(1).width('100%').textAlign(TextAlign.Center)
          .padding({ left: 56, right: 56 })
        Row() {
          AppGlyph({ name: 'profileContentPaste', glyphSize: 22, tint: this.themeColorAccent })
        }
        .width(40).height(40)
        .borderRadius(20)
        .justifyContent(FlexAlign.Center)
        .position({ x: '100%', y: 0 })
        .markAnchor({ x: 40, y: 0 })
        .accessibilityText('复制')
        .onClick(() => { this.copyLoginHeader(); })
      }
      .width('100%').height(40).margin({ bottom: 16 })
      Scroll() {
        Column() {
          MarkdownIntro({ source: this.loginHeader(), textColor: this.themeColorTextPrimary })
          Row().height(16)
        }.width('100%')
      }
      .width('100%').constraintSize({ maxHeight: '60%' }).scrollBar(BarState.Auto)
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 16 })
    .backgroundColor(this.themePureBlack ? '#17181E' : this.themeColorSurfaceElevated)
  }

  build() {
    // ArkUI 一个组件只能绑定一个半模态：后挂的会覆盖前一个、两个都弹不出来
    // （编辑页曾因同一写法导致点字段/帮助全无反应）。所以主弹层与登录头必须
    // 分别挂在不同层级的容器上——主弹层在外层 Column，登录头在内层 Stack。
    Column() {
      Stack() {
        // 占位 1x1，只为承载登录头半模态；主弹层挂在外层 Column。
      }
      .width(1).height(1)
      .bindSheet($$this.headerSheetVisible, this.LoginHeaderSheet(), {
        height: SheetSize.FIT_CONTENT,
        dragBar: true,
        // 上游 MarkdownSheet（AboutSheets.kt:33-60）没有右上关闭按钮。
        showClose: false,
        enableOutsideInteractive: true,
        backgroundColor: this.themePureBlack ? '#17181E' : this.themeColorSurfaceElevated,
        onDisappear: () => { this.headerSheetVisible = false; }
      })
    }
    .width(0).height(0)
    // 上游 MainNavGraph.kt:390-408 登录是模态覆盖层；本地用 bindSheet 承载同一条壳。
    .bindSheet($$this.visible, this.SheetContent(), {
      height: this.mode === 'web' && !this.sheetLoading ? SheetSize.LARGE : SheetSize.FIT_CONTENT,
      dragBar: true,
      // 上游 SourceLoginSheets.kt 三个弹层都走 AppModalBottomSheet，其 M3 分支
      // （AppModalBottomSheet.kt:145-153）只画 DragHandle、无右上关闭按钮。
      showClose: false,
      enableOutsideInteractive: true,
      backgroundColor: this.themePureBlack ? '#17181E' : this.themeColorSurfaceElevated,
      onDisappear: () => {
        this.visible = false;
        this.onClose();
      }
    })
  }
}
