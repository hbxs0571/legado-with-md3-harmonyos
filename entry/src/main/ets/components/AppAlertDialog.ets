/**
 * M3 居中对话框外壳，对应上游 `ui/widget/components/alert/AppAlertDialog.kt`
 * 的 Material3 分支（`:99-152`）。
 *
 * 上游形态（Material3 `AlertDialog`）：
 * - 容器 `containerColor = surfaceContainer`、标题 `onSurface`、正文 `onSurfaceVariant`、
 *   `tonalElevation = AlertDialogDefaults.TonalElevation`；
 * - 正文区是 `Column(verticalScroll)`，先 `SelectionContainer { Text(text) }` 再 `content()`；
 * - 底部两个按钮等宽：`SecondaryButton`（OutlinedButton，取消）+ `PrimaryButton`
 *   （Button，确定），间距 12dp，上边距 24dp。
 *
 * 本地没有 `AlertDialog` 组件，用 `openCustomDialog` + 本 struct 承载同样形态：
 * 全仓 `openCustomDialog` 已有 6 处先例（`SourceLoginSheet` / `AppBackupSettingsPage` /
 * `BookshelfManagePage` / `BookSourceEditPage` / `OnboardingPage` / `ProfileSubPages`），
 * 而 `showAlertDialog` 带不了输入框，做不出 `SourceInputDialog` 那种带 TextField 的对话框。
 */
import { BODY_MEDIUM, HEADLINE_SMALL, LABEL_LARGE } from './typography/TypographyTokens';

@Component
export struct AppAlertDialog {
  @StorageProp('themeColorSurfaceContainer') themeColorSurfaceContainer: string = '#F1F2F6';
  @StorageProp('themeColorOnSurface') themeColorOnSurface: string = '#1B1C22';
  @StorageProp('themeColorOnSurfaceVariant') themeColorOnSurfaceVariant: string = '#4A4C55';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#FAF9FD';

  /** 上游 `title`，null 时不画标题。 */
  @Prop title: string = '';
  /** 上游 `text`，null 时不画正文；`content` 存在时正文底部留 16dp（上游 `:118`）。 */
  @Prop text: string = '';
  /** 上游 `confirmText` 默认 `android.R.string.ok`（zh-rCN「确认」）。 */
  @Prop confirmText: string = '确认';
  /** 上游 `dismissText` 默认 `android.R.string.cancel`（zh-rCN「取消」）。 */
  @Prop dismissText: string = '取消';
  /** 上游 `confirmEnabled`。 */
  @Prop confirmEnabled: boolean = true;

  onConfirm: () => void = () => {};
  onDismiss: () => void = () => {};
  /** 上游 `content`（正文下方的自定义内容区）。 */
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
  }

  build() {
    Column() {
      if (this.title.length > 0) {
        Text(this.title)
          .fontSize(HEADLINE_SMALL).fontColor(this.themeColorOnSurface)
          .width('100%').textAlign(TextAlign.Start)
      }
      // 上游 `text` 与 `content` 同在一个可滚动的 Column 里；本地给整块限高，
      // 不用 Scroll 包：Column 里的 Scroll 拿不到确定高度，内容撑不起时高度会塌成 0
      // （`SourceLoginSheet.ets` 的 LogDetailSheet 踩过同一个坑，注释里有记录）。
      Column() {
        if (this.text.length > 0) {
          Text(this.text)
            .fontSize(BODY_MEDIUM).fontColor(this.themeColorOnSurfaceVariant)
            .width('100%').textAlign(TextAlign.Start)
            .copyOption(CopyOptions.LocalDevice)
            .margin({ bottom: 16 })
        }
        this.content()
      }
      .width('100%').alignItems(HorizontalAlign.Start)
      .margin({ top: 16 })
      .constraintSize({ maxHeight: 320 })

      // 上游 `Row(fillMaxWidth, spacedBy 12dp, CenterVertically)`，两个按钮各 weight(1f)。
      Row({ space: 12 }) {
        // SecondaryButton = OutlinedButton：透明底 + 描边 + 强调色文字。
        Button(this.dismissText)
          .type(ButtonType.Normal).layoutWeight(1).height(40)
          .fontSize(LABEL_LARGE).fontColor(this.themeColorAccent)
          .backgroundColor(Color.Transparent)
          .borderRadius(20).border({ width: 1.5, color: this.themeColorAccent })
          .onClick(() => { this.onDismiss(); })
        // PrimaryButton = Button：强调色填充。
        Button(this.confirmText)
          .type(ButtonType.Normal).layoutWeight(1).height(40)
          .fontSize(LABEL_LARGE).fontColor(this.themeColorSurfacePrimary)
          .backgroundColor(this.themeColorAccent).borderRadius(20)
          .enabled(this.confirmEnabled)
          .opacity(this.confirmEnabled ? 1 : 0.38)
          .onClick(() => { this.onConfirm(); })
      }
      .width('100%').margin({ top: 24 })
    }
    .width(312).padding(24)
    .backgroundColor(this.themeColorSurfaceContainer)
    .borderRadius(28)
    .alignItems(HorizontalAlign.Start)
  }
}
