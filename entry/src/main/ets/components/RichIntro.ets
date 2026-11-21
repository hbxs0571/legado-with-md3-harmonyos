import { webview } from '@kit.ArkWeb';
import { TITLE_SMALL, TITLE_SMALL_LINE_HEIGHT } from './typography/TypographyTokens';
import { MarkdownIntro } from './MarkdownIntro';

/**
 * 简介富文本分派（批7 :1156/:1157/:1164/:1165）。
 *
 * 上游口径：`BookInfoScreen.kt:1710 parseBookInfoIntro`
 *   - `<useweb>` 前缀长 8（后面是一个网址，内容在远端）
 *   - `<usehtml>` 前缀长 9（后面是内联 HTML 字符串）
 *   - `<md>` 前缀长 4（后面是 Markdown）
 *   - 右边界一律 `intro.lastIndexOf("<")`：取最后一个 `<` 是为了顺带去掉尾标记
 *     `</usehtml>` / `</useweb>` / `</md>`，别改成 lastIndexOf('</')。
 *   - 前缀判定忽略大小写。
 * 三个前缀都没命中就是纯文本，保持改动前的 `Text` 排版（字号/行高/颜色一个字不动）。
 */
export type IntroKind = 'plain' | 'html' | 'web' | 'markdown';

export interface ParsedIntro {
  kind: IntroKind;
  /** plain 时为原文；html 时为内联 HTML；web 时为网址；markdown 时为 Markdown 源。 */
  payload: string;
}

const USE_WEB_PREFIX: number = 8;
const USE_HTML_PREFIX: number = 9;
const USE_MD_PREFIX: number = 4;

/** 解析简介前缀，等价上游 `parseBookInfoIntro` 的三分支。 */
export function parseIntro(intro: string): ParsedIntro {
  const text: string = intro ?? '';
  const lower: string = text.toLowerCase();
  if (lower.startsWith('<useweb>')) {
    return { kind: 'web', payload: parseIntroPayload(text, USE_WEB_PREFIX) };
  }
  if (lower.startsWith('<usehtml>')) {
    return { kind: 'html', payload: parseIntroPayload(text, USE_HTML_PREFIX) };
  }
  if (lower.startsWith('<md>')) {
    return { kind: 'markdown', payload: parseIntroPayload(text, USE_MD_PREFIX) };
  }
  return { kind: 'plain', payload: text };
}

/** 前缀之后到最后一个 `<` 之前的内容；最后一个 `<` 落在前缀里就整段作废。 */
function parseIntroPayload(text: string, prefixLength: number): string {
  const end: number = text.lastIndexOf('<');
  if (end <= prefixLength) {
    return '';
  }
  return text.substring(prefixLength, end).trim();
}

/**
 * 注入到 HTML 简介末尾的转发脚本。
 *
 * 交互约定照上游 `ui/widget/components/text/HtmlContent.kt:377-395`：
 *   `<button>名称@onclick:脚本</button>` → 名称进文本、脚本进回调；
 *   `<img data-click="脚本">` 单击带脚本，无脚本时带 src；
 *   长按（contextmenu）只带 src，上游 `IntroImageLongClick(source)` 拿的也是地址。
 * 必须跟着 loadData 的 data 一起拼进去：页面 onPageEnd 之前 runJavaScript 会丢。
 */
const INTRO_BRIDGE_SCRIPT: string = '<script>(function(){'
  + 'function btn(){var list=document.querySelectorAll("button");'
  + 'for(var i=0;i<list.length;i++){(function(b){'
  + 'var t=b.textContent||"";var at=t.indexOf("@onclick:");'
  + 'var name=at>=0?t.substring(0,at):t;var click=at>=0?t.substring(at+9):"";'
  + 'if(at>=0){b.textContent=name;}'
  + 'b.addEventListener("click",function(ev){ev.preventDefault();ev.stopPropagation();'
  + 'if(window.legadoIntro){window.legadoIntro.onButtonClick(name,click);}});'
  + '})(list[i]);}}'
  + 'function img(){var list=document.querySelectorAll("img");'
  + 'for(var i=0;i<list.length;i++){(function(im){'
  + 'im.addEventListener("click",function(ev){ev.preventDefault();'
  + 'var click=im.getAttribute("data-click")||im.src;'
  + 'if(window.legadoIntro){window.legadoIntro.onImageClick(click);}});'
  + 'im.addEventListener("contextmenu",function(ev){ev.preventDefault();'
  + 'if(window.legadoIntro){window.legadoIntro.onImageLongClick(im.src);}});'
  + '})(list[i]);}}'
  + 'btn();img();})();</script>';

/**
 * javaScriptProxy 注册的对象。字段默认是空操作，`RichIntro.aboutToAppear` 里
 * 换成真正回调 —— 这样即使桥提前触发也不会崩。
 */
export class IntroBridge {
  onButtonClick: (name: string, click: string) => void = (name: string, click: string): void => {
  };
  onImageClick: (click: string) => void = (click: string): void => {
  };
  onImageLongClick: (source: string) => void = (source: string): void => {
  };
}

@Component
export struct RichIntro {
  /** 简介原文（带或不带前缀）。 */
  @Prop intro: string = '';
  /** HTML 里相对链接的基准地址；空串时由 Web 按 about:blank 解析（不影响内联 HTML 显示）。 */
  @Prop baseUrl: string = '';
  /** 正文颜色，从页面主题取。 */
  @Prop textColor: string = '#D0D2DB';
  /** `<useweb>` 页面被拦截时给用户的说明；空串表示不显示提示条。 */
  @Prop webNotice: string = '';
  onButtonClick: (name: string, click: string) => void = (name: string, click: string): void => {
  };
  onImageClick: (click: string) => void = (click: string): void => {
  };
  onImageLongClick: (source: string) => void = (source: string): void => {
  };

  /** 先给一屏高：0 高度不会布局，也就量不到 scrollHeight（上游同做法）。 */
  @State htmlHeight: number = 320;
  @State notice: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: IntroBridge = new IntroBridge();
  /** 上一次提交的高度，差值 < 8 不提交（上游 BookInfoScreen.kt:1787-1795）。 */
  private lastMeasuredHeight: number = 0;
  private measureTimer: number = -1;

  aboutToAppear(): void {
    this.bridge.onButtonClick = (name: string, click: string): void => {
      this.onButtonClick(name, click);
    };
    this.bridge.onImageClick = (click: string): void => {
      this.onImageClick(click);
    };
    this.bridge.onImageLongClick = (source: string): void => {
      this.onImageLongClick(source);
    };
  }

  aboutToDisappear(): void {
    if (this.measureTimer !== -1) {
      clearTimeout(this.measureTimer);
      this.measureTimer = -1;
    }
  }

  private parsed(): ParsedIntro {
    return parseIntro(this.intro);
  }

  /** 内联 HTML 的完整文档：暗色套字色、图片不溢出、末尾接转发脚本。 */
  private htmlDocument(): string {
    const style: string = '<style>body{color:' + this.textColor
      + ';background:transparent;margin:0;font-size:16px;line-height:1.5;}'
      + 'img{max-width:100%;height:auto;}a{color:#9AB4FF;}button{color:inherit;}</style>';
    return '<html><head><meta name="viewport" content="width=device-width, initial-scale=1">'
      + style + '</head><body>' + this.parsed().payload + INTRO_BRIDGE_SCRIPT + '</body></html>';
  }

  /** `<useweb>` 只放行初始 URL 的同源请求，其余一律返回空响应（上游没有这道防护）。 */
  private allowSameOrigin(url: string): boolean {
    const base: string = this.parsed().payload;
    if (base.length === 0) {
      return false;
    }
    const origin = RichIntro.originOf(base);
    const target = RichIntro.originOf(url);
    return origin.length > 0 && origin === target;
  }

  private static originOf(url: string): string {
    const lower: string = url.toLowerCase();
    const schemeEnd: number = lower.indexOf('://');
    if (schemeEnd <= 0) {
      return '';
    }
    const afterScheme: number = schemeEnd + 3;
    const pathStart: number = lower.indexOf('/', afterScheme);
    return pathStart < 0 ? lower : lower.substring(0, pathStart);
  }

  /** 只拦非 http(s) 的跳转（sms:/tel:/market: 之类），同源与子页面放行。 */
  private shouldBlockNavigation(url: string): boolean {
    const lower: string = url.toLowerCase();
    if (lower.startsWith('about:') || lower.startsWith('data:') || lower.startsWith('blob:')) {
      return false;
    }
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return true;
    }
    return false;
  }

  private interceptReason(): void {
    if (this.webNotice.length > 0) {
      this.notice = this.webNotice;
    }
  }

  build() {
    Column() {
      if (this.parsed().kind === 'plain') {
        Text(this.parsed().payload).fontSize(TITLE_SMALL).lineHeight(TITLE_SMALL_LINE_HEIGHT)
          .fontColor(this.textColor).alignSelf(ItemAlign.Start)
      } else if (this.parsed().kind === 'markdown') {
        // 第 1158 步：五类语法的本地渲染器（标题/粗细/图片/链接/代码块，表格原样）。
        // 链接与图片共用 onImageClick —— 上游 `IntroImageClick(click)` 也是一条通道。
        MarkdownIntro({
          source: this.parsed().payload,
          textColor: this.textColor,
          onLinkClick: (url: string) => { this.onImageClick(url); },
          onImageClick: (url: string) => { this.onImageClick(url); }
        })
      } else if (this.parsed().kind === 'web') {
        if (this.notice.length > 0) {
          Text(this.notice).fontSize(TITLE_SMALL).fontColor('#E0A46A').alignSelf(ItemAlign.Start)
            .margin({ bottom: 6 })
        }
        // 远端网页：src 是网址，内部会跑对方脚本，所以拦下一切外部跳转。
        Web({ src: this.parsed().payload, controller: this.controller })
          .javaScriptAccess(false)
          .domStorageAccess(false)
          .darkMode(WebDarkMode.Auto)
          .width('100%').height(this.htmlHeight)
          .onLoadIntercept((event) => {
            const url: string = event.data.getRequestUrl();
            if (this.shouldBlockNavigation(url)) {
              this.interceptReason();
              return true;
            }
            return false;
          })
          .onInterceptRequest((event) => {
            const url: string = event.request.getRequestUrl();
            if (this.allowSameOrigin(url)) {
              return null;
            }
            this.interceptReason();
            const blocked = new WebResourceResponse();
            blocked.setResponseData('<html><body></body></html>');
            blocked.setResponseMimeType('text/html');
            blocked.setResponseEncoding('utf-8');
            blocked.setResponseCode(200);
            return blocked;
          })
          .onPageEnd(() => {
            this.measureWebHeight();
          })
      } else {
        Web({ src: '', controller: this.controller })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .javaScriptProxy({
            object: this.bridge,
            name: 'legadoIntro',
            methodList: ['onButtonClick', 'onImageClick', 'onImageLongClick'],
            controller: this.controller
          })
          .width('100%').height(this.htmlHeight)
          .onPageEnd(() => {
            this.measureWebHeight();
          })
          .onControllerAttached(() => {
            // 内联 HTML 走 loadData：component/web.d.ts:3296 那个 loadData 已废弃，
            // 这里用 @ohos.web.webview 的 loadData(data, mime, encoding, baseUrl)。
            this.controller.loadData(this.htmlDocument(), 'text/html', 'UTF-8',
              this.baseUrl.length > 0 ? this.baseUrl : 'about:blank');
          })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  /** 回读 document.body.scrollHeight 定高。返回的是 CSS px，与 vp 等值，别乘 px2vp。 */
  private measureWebHeight(): void {
    this.controller.runJavaScript('document.body.scrollHeight').then((value: string) => {
      const height: number = Number(value);
      if (isNaN(height) || height <= 0) {
        return;
      }
      if (Math.abs(height - this.lastMeasuredHeight) < 8) {
        return;
      }
      // 400ms 防抖：图片撑开高度时常连发几次，抖完后再一次性提交。
      if (this.measureTimer !== -1) {
        clearTimeout(this.measureTimer);
      }
      this.measureTimer = setTimeout(() => {
        this.measureTimer = -1;
        this.lastMeasuredHeight = height;
        this.htmlHeight = height;
      }, 400);
    }).catch((error: Error) => {
      console.error(`[RichIntro] 量简介高度失败：${error.message}`);
    });
  }
}