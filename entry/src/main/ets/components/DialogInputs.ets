/**
 * 对话框内的输入控件，供 `openCustomDialog` 里的 builder 使用。
 *
 * 为什么单独做成 struct 而不是直接用页面的 @State：
 * `openCustomDialog({ builder })` 的 builder 是页面实例上的一个 @Builder，它捕获的是
 * 页面状态；但对话框是独立窗口，页面状态变化不一定能可靠触发对话框重绘（实测在部分
 * 机型上输入框会卡住不刷新）。把文本状态放在 struct 内部，输入即时由 struct 自己的
 * @State 驱动重绘，页面只通过回调拿到最终值。
 */
import { BODY_MEDIUM, LABEL_MEDIUM } from './typography/TypographyTokens';

@Component
export struct DialogTextInput {
  @StorageProp('themeColorOnSheetContent') themeColorOnSheetContent: string = '#E9EBF0';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';

  /** 初始文本；只在组件首次创建时读一次。 */
  @Prop initialText: string = '';
  @Prop placeholder: string = '';
  /** 上游 `maxLines`：`SourceInputDialog` 传 5，密码框单行传 1。 */
  @Prop maxLines: number = 5;
  /** 是否密码框（上游 `AppTextField` 的密码分支）。 */
  @Prop isPassword: boolean = false;

  @State private text: string = '';

  onValueChange: (value: string) => void = () => {};

  aboutToAppear(): void {
    this.text = this.initialText;
  }

  build() {
    if (this.isPassword) {
      TextInput({ text: this.text, placeholder: this.placeholder })
        .type(InputType.Password)
        .fontSize(BODY_MEDIUM).fontColor(this.themeColorTextPrimary)
        .placeholderColor(this.themeColorTextTertiary)
        .backgroundColor(this.themeColorOnSheetContent)
        .borderRadius(8).width('100%').height(48)
        .onChange((value: string) => {
          this.text = value;
          this.onValueChange(value);
        })
    } else {
      // 上游 `AppTextField(maxLines = 5)`：多行输入，随内容长高到 5 行。
      TextArea({ text: this.text, placeholder: this.placeholder })
        .fontSize(BODY_MEDIUM).fontColor(this.themeColorTextPrimary)
        .placeholderColor(this.themeColorTextTertiary)
        .backgroundColor(this.themeColorOnSheetContent)
        .borderRadius(8).width('100%')
        .constraintSize({ minHeight: 48, maxHeight: 48 + (this.maxLines - 1) * 22 })
        .onChange((value: string) => {
          this.text = value;
          this.onValueChange(value);
        })
    }
  }
}

/**
 * 对话框内的单行勾选行，供 `openCustomDialog` 的 builder 使用。
 * 对应上游 `AppAlertDialog` 的 `content` 里那种 `Row { AppCheckbox; AppText }`（如删除确认的
 * 「删除源文件」）。同样自持状态，理由见上。
 */
@Component
export struct DialogCheckRow {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';

  @Prop label: string = '';
  @Prop initialChecked: boolean = false;
  @State private checked: boolean = false;

  onCheckedChange: (checked: boolean) => void = () => {};

  aboutToAppear(): void {
    this.checked = this.initialChecked;
  }

  build() {
    Row() {
      Checkbox()
        .select(this.checked)
        .onChange((value: boolean) => {
          this.checked = value;
          this.onCheckedChange(value);
        })
      Text(this.label)
        .fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextPrimary)
        .margin({ left: 4 })
    }
    .width('100%')
  }
}
