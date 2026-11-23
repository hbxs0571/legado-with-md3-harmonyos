// 书源登录页（P9，任务书 13.2/13.3）。对齐上游 SourceLoginSheets：
// Form 模式（loginUi 非空）渲染 5 种控件，提交执行书源 login()；
// Web 模式（loginUi 为空）内嵌 WebView 加载 loginUrl，靠 Cookie 持久化登录态。
import { webview } from '@kit.ArkWeb';
import { pasteboard } from '@kit.BasicServicesKit';
import { BookSourceLoginItem, CookieStore } from '@legado/sourceengine';
import { AppTopBar, TopBarBackButton, TopBarButton } from '../components/TopBar';
import { BookSourceRepository } from '../data/BookSourceRepository';
import {
  BookSourceLoginCoordinator, LoginPrepare, LoginSubmitResult
} from '../bookSource/BookSourceLoginCoordinator';
import { LABEL_MEDIUM, TITLE_MEDIUM } from '../components/typography/TypographyTokens';

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
export struct SourceLoginPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';

  @Prop sourceUrl: string = '';
  onBack: () => void = () => {};
  /** 按钮 action 是外部 URL 时交给 Index 打开通用 WebView（验证码页）。 */
  onOpenWeb: (url: string) => void = (_url: string) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  // 三态：loading（对齐上游 SourceLoginSheetHost:66-77 的 CircularProgressIndicator）/
  // web（:79-83 SourceLoginWebSheet）/ form（:85 SourceLoginFormSheet）之外的 error（本地扩展）。
  @State private mode: string = 'form';
  @State private sheetLoading: boolean = true;
  @State private sourceName: string = '';
  @State private items: FormItem[] = [];
  @State private entryUrl: string = '';
  @State private resultMessage: string = '';
  @State private submitting: boolean = false;
  private webController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    this.prepare();
  }

  /** 登录说明（对齐上游 MarkdownSheet(title=login_header)）。本地无 Markdown 渲染器，纯文本呈现。 */
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

  /** 上游 login header 的复制入口（MediumTonalButton(ContentCopy) → copy_text）。 */
  private async copyLoginHeader(): Promise<void> {
    try {
      await pasteboard.getSystemPasteboard().setData(
        pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.loginHeader()));
      this.onUnavailableAction('登录说明已复制');
    } catch (_) {
      this.onUnavailableAction('复制失败');
    }
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

  @Builder ControlView(item: FormItem, index: number) {
    Column() {
      if (item.type === 'button') {
        Button(item.viewName)
          .width('100%').enabled(!this.submitting)
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
    }.width('100%').margin({ bottom: 12 })
  }

  // @BuilderParam 槽位须传 @Builder 方法引用；内联 lambda 直接实例化 struct 会
  // 在运行时变成裸构造函数调用（class constructor cannot called without 'new'）。
  @Builder loginNavSlot() {
    TopBarBackButton({ onSelect: () => this.onBack() })
  }

  /** 表单态顶栏动作：对齐上游 startAction(菜单)/endAction(确认)。 */
  @Builder loginActionsSlot() {
    // 文案取上游 `ui/login/SourceLoginSheets.kt`：拷贝登录头是 `endAction` 的
    // `MediumTonalButton(contentDescription = R.string.copy_text)`（`:94-99`），
    // 确认是 `endAction` 的 `MediumTonalButton(contentDescription = R.string.ok)`（`:138-143`）。
    TopBarButton({ icon: 'profileInfo', showDivider: false, accessibilityLabel: '拷贝内容', onSelect: () => this.copyLoginHeader() })
    TopBarButton({ icon: 'profileCheck', showDivider: false, accessibilityLabel: '确认', onSelect: () => { this.submit(); } })
  }

  build() {
    Column() {
      AppTopBar({
        title: '登录 · ' + this.sourceName,
        hasNavigation: true,
        navigationIcon: () => { this.loginNavSlot() },
        actions: () => { this.loginActionsSlot() }
      })
      if (this.sheetLoading) {
        // 态1：loading（上游 :66-77，sheet + CircularProgressIndicator）。
        Column() {
          LoadingProgress().width(48).height(48).color(this.themeColorAccent)
          Text('正在准备登录…').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
            .margin({ top: 12 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.mode === 'web') {
        // 态2：Web 登录（上游 :79-83 SourceLoginWebSheet）。

        // Web 模式：内嵌 WebView 加载入口页，cookie 由 onPageEnd 持久化。
        Column() {
          Text('此源使用网页登录，请在下方页面完成登录后返回。')
            .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary).padding(12)
          Web({ src: this.entryUrl, controller: this.webController })
            .javaScriptAccess(true).domStorageAccess(true)
            .width('100%').layoutWeight(1)
            .onPageEnd(() => {
              const cookie = CookieStore.forSource(this.sourceUrl).getCookie(this.entryUrl);
              if (cookie.trim().length > 0) {
                BookSourceLoginCoordinator.checkLogin(this.sourceUrl).then((r) => {
                  this.resultMessage = r.ok ? '登录已生效' : r.message;
                });
              }
            })
        }.width('100%').layoutWeight(1)
      } else {
        // 态3：表单登录（上游 :85 SourceLoginFormSheet）。
        Scroll() {
          Column() {
            if (this.loginHeader().length > 0) {
              Text(this.loginHeader()).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
                .width('100%').margin({ bottom: 12 })
            }
            Text('请填写登录信息（表单由书源 loginUi 定义）')
              .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary).margin({ bottom: 16 })
            ForEach(this.items, (item: FormItem, index: number) => {
              this.ControlView(item, index)
            }, (item: FormItem): string => item.name)
            Button(this.submitting ? '提交中…' : '登录')
              .width('100%').enabled(!this.submitting).onClick(() => { this.submit(); })
              .margin({ top: 8 })
            if (this.resultMessage.length > 0) {
              Text(this.resultMessage).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary)
                .margin({ top: 12 }).width('100%')
            }
          }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 24 })
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.themeAppBackground.length > 0 ? this.themeAppBackground : '#FFFFFF')
  }
}
