// 通用 WebView 页（P9，任务书 13.4）。对齐上游 WebViewRouteScreen/WebViewModel：
// 用于验证码页、源站正文加载、startBrowser 类规则。接受 URL + 可选 HTML 回传回调。
// cookie 由引擎 CookieStore 统一注入（configCookieSync），onPageEnd 回传 document 的 outerHTML。
import { webview } from '@kit.ArkWeb';
import { AppTopBar, TopBarBackButton, TopBarButton } from '../components/TopBar';
import { CookieStore } from '@legado/sourceengine';

@Component
export struct SourceWebPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';

  @Prop title: string = '网页';
  @Prop url: string = '';
  /** 页面加载完成后把完整 HTML 回传；不传则只做浏览。 */
  onHtmlLoaded: (html: string) => void = (_html: string) => {};
  onBack: () => void = () => {};

  private controller: webview.WebviewController = new webview.WebviewController();
  @State private loading: boolean = true;
  @State private pageTitle: string = '';

  aboutToAppear(): void {
    if (this.url.trim().length > 0) {
      const cookie = CookieStore.forSource(this.url).getCookie(this.url);
      if (cookie.trim().length > 0) {
        CookieStore.forSource(this.url).setCookies(this.url, cookie);
      }
    }
  }

  build() {
    Column() {
      AppTopBar({
        title: this.pageTitle.length > 0 ? this.pageTitle : this.title,
        hasNavigation: true,
        navigationIcon: () => { TopBarBackButton({ onSelect: () => this.onBack() }) },
        actions: () => {
          TopBarButton({ icon: 'web', showDivider: false, onSelect: () => {
            // 刷新：重新加载当前 URL。
            if (this.url.trim().length > 0) { this.controller.refresh(); }
          } })
        }
      })
      if (this.loading) {
        LoadingProgress().width(28).height(28).color(this.themeColorAccent)
      }
      Web({ src: this.url, controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .width('100%').layoutWeight(1)
        .onPageBegin(() => { this.loading = true; })
        .onPageEnd(() => {
          this.loading = false;
          this.pageTitle = this.controller.getTitle();
          // 回传 HTML：抓 document.documentElement.outerHTML。
          this.controller.runJavaScript('document.documentElement.outerHTML')
            .then((html: string) => { this.onHtmlLoaded(html); })
            .catch(() => { /* 跨域或脚本被拦时忽略回传 */ });
        })
    }
    .width('100%').height('100%')
    .backgroundColor(this.themeAppBackground.length > 0 ? this.themeAppBackground : '#FFFFFF')
  }
}
