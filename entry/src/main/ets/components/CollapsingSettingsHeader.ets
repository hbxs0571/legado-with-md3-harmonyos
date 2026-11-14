import { AppTopBar, TopBarBackButton } from './TopBar';

/**
 * 设置类子页的统一顶栏。
 * 原先是自己写一遍「收起行 + 展开行」，与 HomePage / SearchPage 各写一份、度量还各不相同；
 * 现在只做形态适配，结构交给 `AppTopBar`（照上游 GlassMediumFlexibleTopAppBar）。
 * 调用签名保持不变，16 个设置子页不需要改。
 *
 * 注意 @BuilderParam 的传法：这里用箭头函数包装 `@Builder` 方法引用，而不是直接传
 * `this.navigationSlot`。直接传方法引用时 ArkUI 会把 builder 的 this 重绑到接收组件
 * AppTopBar，导致 navigationSlot 里的 `this.onBack` 变成 undefined —— 编译与渲染都正常，
 * 但点返回按钮会抛 "undefined is not callable" 并让 app 退出。箭头函数的 this 是词法绑定，
 * 能保证 builder 仍以本组件的实例执行。
 */
@Component
export struct CollapsingSettingsHeader {
  @Prop title: string = '';
  @Prop collapsed: boolean = false;
  onBack: () => void = () => {};

  @Builder navigationSlot() {
    TopBarBackButton({ onSelect: () => this.onBack() })
  }

  build() {
    AppTopBar({
      title: this.title,
      collapsed: this.collapsed,
      hasNavigation: true,
      navigationIcon: () => { this.navigationSlot() }
    })
  }
}
