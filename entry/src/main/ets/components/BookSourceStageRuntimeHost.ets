// 书源 ArkWeb 阶段运行时宿主（P9，任务书 13.1）。
// 引擎 BookSourceStageWebRuntime.execute() 需要一个真实的 Web 控制器才能跑登录/脚本。
// 照 P0-bis/P2 探针验证过的挂载范式：1x1 透明 Web，onControllerAttached → attach，
// onPageEnd → setReady(true, controller)。挂在 Index 根 Stack 常驻，不随页面销毁。
import { webview } from '@kit.ArkWeb';
import { BookSourceStageWebRuntime } from '@legado/sourceengine';

@Component
export struct BookSourceStageRuntimeHost {
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    BookSourceStageWebRuntime.get().attach(this.controller);
  }

  aboutToDisappear(): void {
    BookSourceStageWebRuntime.get().detach(this.controller);
  }

  build() {
    Web({ src: 'about:blank', controller: this.controller })
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .width(1).height(1)
      .opacity(0.01)
      .onControllerAttached(() => {
        // 控制器真正创建后再 attach（attach 内部按 controller 去重，重复调用安全）。
        BookSourceStageWebRuntime.get().attach(this.controller);
      })
      .onPageEnd(() => {
        BookSourceStageWebRuntime.get().setReady(true, this.controller);
      })
  }
}
