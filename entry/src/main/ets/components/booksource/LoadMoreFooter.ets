import { pasteboard } from '@kit.BasicServicesKit';
import { AppGlyph } from '../AppGlyph';
import {
  BODY_SMALL,
  BODY_SMALL_LINE_HEIGHT,
  LABEL_MEDIUM,
  LABEL_MEDIUM_LINE_HEIGHT
} from '../typography/TypographyTokens';
import { SPACE_12, SPACE_16, SPACE_8 } from '../UiTokens';

/**
 * 列表底部「加载中 / 出错 / 到底了 / 加载更多」四态条，对齐上游
 * `ui/widget/components/LoadMoreFooter.kt`（324 行）。
 *
 * 上游签名：`LoadMoreFooter(isLoading, errorMsg: String?, isEnd, onRetry, onLoadMore = null, autoLoad = true)`。
 * - `autoLoad = true` 时自己发起 `onRetry()`（滚动到底自动加载），并且「还有下一页」这一态不画任何东西；
 * - 探索结果页（`ExploreShowScreen.kt:500-517`）传的是 `autoLoad = false`，
 *   所以四态都会画出来，且不会自己触发加载。
 *
 * 四态的卡片形态（`GlassCard` 圆角按上游默认，本地用主题卡片圆角）：
 * - 出错：`errorContainer` alpha 0.6 底；信息行（Info 图标 + 错误文本两行）+ 分隔线 + 「重新加载」操作行；
 *   点卡片本身弹「错误详情」（可拷贝全文）。
 * - 加载中：转圈 + 「加载中…」（不套卡片）。
 * - 到底了 + 有 onLoadMore：「已经到底了~」信息行 + 分隔线 + 「尝试加载下一页」操作行。
 * - 到底了 + 无 onLoadMore：只有信息行。
 * - 其余 + autoLoad 关闭：整卡可点，只有「加载更多」信息行。
 *
 * 与上游的一处能力差别（记入 `tmp/appearance-impl-report.md` 待办账本）：
 * 上游「错误详情」弹窗是可选中文本 + 最多 400dp 可滚的自定义内容
 * （`AppAlertDialog(content = { SelectionContainer { Text(...) } })`）。
 * 本地没有带自定义内容的 AlertDialog 组件，这里用系统 `showAlertDialog` 承载，
 * 文本不可选中，但「拷贝内容」按钮把全文写进剪贴板，拷贝能力不缺。
 */
@Component
export struct LoadMoreFooter {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#4A4C55';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorError') themeColorError: string = '#BA1A1A';
  @StorageProp('themeColorErrorContainer') themeColorErrorContainer: string = '#FFDAD6';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorOutlineVariant') themeColorOutlineVariant: string = '#C6C7D0';

  @Prop isLoading: boolean = false;
  /** 空串表示没有错误（上游是 `String?`）。 */
  @Prop errorMsg: string = '';
  @Prop isEnd: boolean = false;
  /** 上游 `autoLoad`；探索结果页传 false。 */
  @Prop autoLoad: boolean = true;
  /** 上游 `onLoadMore: (() -> Unit)?`；空回调表示「没有下一页可尝试」。 */
  @Prop showLoadMore: boolean = false;

  /** 上游 `onRetry`：重新拉当前页（也用于滚动到底自动加载）。 */
  onRetry: () => void = () => {};
  /** 上游 `onLoadMore`：强制抓下一页。 */
  onLoadMore: () => void = () => {};

  /**
   * 上游 `if (autoLoad && !isLoading && errorMsg == null && !isEnd) return`：
   * 自动加载模式下「空闲且未到底」这一态不画。
   */
  private hidden(): boolean {
    return this.autoLoad && !this.isLoading && this.errorMsg.length === 0 && !this.isEnd;
  }

  /** 上游错误详情弹窗：标题「错误详情」，确认「拷贝内容」，取消「关闭」。 */
  private showErrorDetails(): void {
    const message = this.errorMsg;
    try {
      this.getUIContext().showAlertDialog({
        title: '错误详情',
        message: message,
        autoCancel: true,
        primaryButton: { value: '关闭', action: () => {} },
        secondaryButton: {
          value: '拷贝内容',
          action: () => {
            const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, message);
            pasteboard.getSystemPasteboard().setData(data).catch(() => {});
          }
        }
      });
    } catch (error) {
      // 弹窗失败不影响列表本身；错误原文已经显示在卡片上。
    }
  }

  /** 信息行：图标 + 一段两行截断的文字。 */
  @Builder
  InfoRow(icon: string, tint: string, text: string, textColor: string) {
    Row() {
      AppGlyph({ name: 'info', glyphSize: 20, tint: tint })
      Text(text)
        .fontSize(BODY_SMALL)
        .lineHeight(BODY_SMALL_LINE_HEIGHT)
        .fontColor(textColor)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: SPACE_12 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(SPACE_16)
  }

  /** 分隔线：上游 `HorizontalDivider(outlineVariant.copy(alpha = 0.3f))`。 */
  @Builder
  Divider() {
    Row()
      .width('100%')
      .height(1)
      .backgroundColor(this.themeColorOutlineVariant)
      .opacity(0.3)
  }

  /** 操作行：图标 + 标签，整行可点。 */
  @Builder
  ActionRow(label: string, tint: string, action: () => void) {
    Row() {
      AppGlyph({ name: 'profileRefresh', glyphSize: 20, tint: tint })
      Text(label)
        .fontSize(LABEL_MEDIUM)
        .lineHeight(LABEL_MEDIUM_LINE_HEIGHT)
        .fontColor(tint)
        .margin({ left: SPACE_8 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .padding({ top: 10, bottom: 10 })
    .onClick(action)
  }

  build() {
    Column() {
      if (!this.hidden()) {
        if (this.errorMsg.length > 0) {
          // 出错：errorContainer alpha 0.6 底的可点卡片。
          Column() {
            this.InfoRow('info', this.themeColorError, this.errorMsg, this.themeColorError)
            this.Divider()
            this.ActionRow('重新加载', this.themeColorError, () => this.onRetry())
          }
          .width('100%')
          .backgroundColor(this.themeColorErrorContainer)
          .opacity(0.6)
          .borderRadius(12)
          .onClick(() => this.showErrorDetails())
        } else if (this.isLoading) {
          Column() {
            LoadingProgress().width(24).height(24).color(this.themeColorAccent)
            Text('加载中…')
              .fontSize(BODY_SMALL)
              .lineHeight(BODY_SMALL_LINE_HEIGHT)
              .fontColor(this.themeColorTextTertiary)
              .margin({ top: SPACE_12 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: SPACE_16, bottom: SPACE_16 })
        } else if (this.isEnd) {
          if (this.showLoadMore) {
            Column() {
              this.InfoRow('info', this.themeColorTextPrimary, '已经到底了~', this.themeColorTextPrimary)
              this.Divider()
              this.ActionRow('尝试加载下一页', this.themeColorAccent, () => this.onLoadMore())
            }
            .width('100%')
            .backgroundColor(this.themeColorSurfaceTertiary)
            .borderRadius(12)
          } else {
            Column() {
              this.InfoRow('info', this.themeColorTextPrimary, '已经到底了~', this.themeColorTextPrimary)
            }
            .width('100%')
            .backgroundColor(this.themeColorSurfaceTertiary)
            .borderRadius(12)
          }
        } else if (!this.autoLoad) {
          // 上游 `else -> if (!autoLoad)`：整卡可点，只有「加载更多」一行。
          Column() {
            this.InfoRow('info', this.themeColorTextPrimary, '加载更多', this.themeColorTextPrimary)
          }
          .width('100%')
          .backgroundColor(this.themeColorSurfaceTertiary)
          .borderRadius(12)
          .onClick(() => this.onRetry())
        }
      }
    }
    .width('100%')
    // 上游 `Modifier.fillMaxWidth().adaptiveHorizontalPadding(vertical = 8.dp)`。
    .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_8, bottom: SPACE_8 })
    .alignItems(HorizontalAlign.Center)
  }
}
