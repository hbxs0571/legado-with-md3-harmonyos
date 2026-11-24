/**
 * 搜索输入条。
 *
 * 逐项对齐上游 `ui/widget/components/SearchBar.kt`（157 行）：
 *   `Surface(fillMaxWidth().padding(bottom = 4.dp), shape = RoundedCornerShape(32.dp),
 *            color = surfaceContainerLow)` 内嵌一个 `AppDenseTextField`——
 *   左侧搜索图标（水平内边距 12dp）、placeholder、右侧 trailingIcon、
 *   `ImeAction.Search` 键盘动作、单行、输入框自身底色透明。
 *
 * 与上游的两处必要差异：
 *   ① 上游用 `TextFieldState` + `LaunchedEffect(query)` 双向同步；ArkUI 的 `TextInput` 由
 *      `text` 受控，这里用 `@Prop @Watch('onExternalQueryChanged')` 回填外部值，
 *      并在 `onChange` 里上报，避免「受控值与内部编辑态互相打架」。
 *   ② 上游 `submitSearch` 里会 `clearFocus + hideKeyboard`；ArkUI 侧同样在 `onSubmit`
 *      与 trailing 点击后调用 `stopEditing()`。
 */
import { AppGlyph } from '../AppGlyph';
import { BODY_LARGE } from '../typography/TypographyTokens';
import { SPACE_4 } from '../UiTokens';

@Component
export struct SearchBar {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfaceContainerLow') themeColorSurfaceContainerLow: string = '#F7F7FB';
  /** 聚焦态的描边色；上游 M3 TextField 聚焦时 outline 变 primary。 */
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';

  /** 受控文本。外部改它（例如「用历史词再搜一次」）会同步进输入框。 */
  @Prop @Watch('onExternalQueryChanged') query: string = '';
  @Prop placeholder: string = '搜索书名、作者';
  /** 右侧是否显示清除按钮；上游是 `if (queryInput.isNotEmpty()) SmallPlainButton(Close)`。 */
  @Prop showClear: boolean = false;
  @Prop clearLabel: string = '清除';
  /** 进入页面即聚焦并弹键盘（上游 `autoFocus = true`）。 */
  @Prop autoFocus: boolean = false;

  /** 文本变化回调。 */
  onQueryChange: (value: string) => void = (_value: string) => {};
  /** 提交（键盘搜索键 / 点清除以外的确认动作）。 */
  onSearch: (value: string) => void = (_value: string) => {};
  /** 点清除按钮。 */
  onClear: () => void = () => {};

  /** 输入框内的实际文本；外部 query 变化时由 @Watch 回填。 */
  @State private text: string = '';
  @State private focused: boolean = false;

  aboutToAppear(): void {
    this.text = this.query;
    if (this.autoFocus) {
      // 首帧后聚焦：aboutToAppear 时组件还没挂到树上，requestFocus 无效。
      setTimeout(() => {
        try {
          this.getUIContext().getFocusController().requestFocus('search-bar-input');
        } catch (error) {
          console.info(`搜索框聚焦失败：${error instanceof Error ? error.message : String(error)}`);
        }
      }, 120);
    }
  }

  private onExternalQueryChanged(): void {
    if (this.query !== this.text) {
      this.text = this.query;
    }
  }

  /** 收起键盘并让输入框失焦（上游 `focusManager.clearFocus() + keyboardController?.hide()`）。 */
  private stopEditing(): void {
    try {
      this.getUIContext().getFocusController().clearFocus();
    } catch (error) {
      console.info(`搜索框失焦失败：${error instanceof Error ? error.message : String(error)}`);
    }
    this.focused = false;
  }

  build() {
    Row() {
      // 上游 `leadingIcon = AppIcon(Search, Modifier.padding(horizontal = 12.dp))`。
      AppGlyph({ name: 'search', glyphSize: 20, tint: this.themeColorTextTertiary })
        .margin({ left: 12, right: 4 })
      TextInput({ placeholder: this.placeholder, text: this.text })
        .id('search-bar-input')
        .fontSize(BODY_LARGE)
        .fontColor(this.themeColorTextPrimary)
        .placeholderColor(this.themeColorTextTertiary)
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0 })
        .layoutWeight(1)
        .height(48)
        // 上游 `KeyboardOptions(imeAction = ImeAction.Search)` + `onKeyboardAction { submitSearch(text) }`。
        .enterKeyType(EnterKeyType.Search)
        .onChange((value: string) => {
          this.text = value;
          this.onQueryChange(value);
        })
        .onSubmit((_enterKey: EnterKeyType, _event: SubmitEvent) => {
          this.stopEditing();
          this.onSearch(this.text);
        })
        .onFocus(() => { this.focused = true; })
        .onBlur(() => { this.focused = false; })
      if (this.showClear && this.text.length > 0) {
        // 上游 `SmallPlainButton(Modifier.padding(horizontal = 8.dp), onClick, Close, clear)`。
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileClose', glyphSize: 16, tint: this.themeColorTextTertiary })
        }
        .width(32)
        .height(32)
        .borderRadius(16)
        .margin({ right: 8 })
        .accessibilityText(this.clearLabel)
        .onClick(() => {
          this.text = '';
          this.onClear();
        })
      }
    }
    .width('100%')
    .height(48)
    // 上游 `shape = RoundedCornerShape(32.dp)`。
    .borderRadius(24)
    .backgroundColor(this.themeColorSurfaceContainerLow)
    .border({
      width: this.focused ? 1.5 : 0,
      color: this.themeColorAccent
    })
    // 上游 `Surface(...).padding(bottom = 4.dp)`：条与下方内容留 4vp。
    .margin({ bottom: SPACE_4 })
  }
}
