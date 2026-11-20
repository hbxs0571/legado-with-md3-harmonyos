// 书源登录页（P9，任务书 13.2/13.3）。对齐上游 SourceLoginSheets：
// Form 模式（loginUi 非空）渲染 5 种控件，提交执行书源 login()；
// Web 模式（loginUi 为空）内嵌 WebView 加载 loginUrl，靠 Cookie 持久化登录态。
import { webview } from '@kit.ArkWeb';
import { BookSourceLoginItem, CookieStore } from '@legado/sourceengine';
import { AppTopBar, TopBarBackButton } from '../components/TopBar';
import {
  BookSourceLoginCoordinator, LoginPrepare, LoginSubmitResult
} from '../bookSource/BookSourceLoginCoordinator';

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

  @State private mode: string = 'form';
  @State private sourceName: string = '';
  @State private items: FormItem[] = [];
  @State private entryUrl: string = '';
  @State private resultMessage: string = '';
  @State private submitting: boolean = false;
  private webController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    this.prepare();
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
        Text(item.viewName).fontSize(13).fontColor(this.themeColorTextTertiary)
          .width('100%').margin({ bottom: 4 })
        Select(this.selectOptions(item.chars))
          .value(item.value.length > 0 ? item.value : (item.chars.length > 0 ? item.chars[0] : ''))
          .onSelect((i: number) => { this.items[index].value = item.chars[i]; })
          .fontColor(this.themeColorTextPrimary)
      } else if (item.type === 'toggle') {
        Row() {
          Text(item.viewName).fontSize(15).fontColor(this.themeColorTextPrimary).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: item.value === 'true' || item.value === '1' })
            .onChange((on: boolean) => { this.items[index].value = on ? 'true' : 'false'; })
        }
      } else {
        Text(item.viewName).fontSize(13).fontColor(this.themeColorTextTertiary)
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

  build() {
    Column() {
      AppTopBar({
        title: '登录 · ' + this.sourceName,
        hasNavigation: true,
        navigationIcon: () => { this.loginNavSlot() }
      })
      if (this.mode === 'web') {
        // Web 模式：内嵌 WebView 加载入口页，cookie 由 onPageEnd 持久化。
        Column() {
          Text('此源使用网页登录，请在下方页面完成登录后返回。')
            .fontSize(13).fontColor(this.themeColorTextTertiary).padding(12)
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
        Scroll() {
          Column() {
            Text('请填写登录信息（表单由书源 loginUi 定义）')
              .fontSize(13).fontColor(this.themeColorTextTertiary).margin({ bottom: 16 })
            ForEach(this.items, (item: FormItem, index: number) => {
              this.ControlView(item, index)
            }, (item: FormItem): string => item.name)
            Button(this.submitting ? '提交中…' : '登录')
              .width('100%').enabled(!this.submitting).onClick(() => { this.submit(); })
              .margin({ top: 8 })
            if (this.resultMessage.length > 0) {
              Text(this.resultMessage).fontSize(13).fontColor(this.themeColorTextTertiary)
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
