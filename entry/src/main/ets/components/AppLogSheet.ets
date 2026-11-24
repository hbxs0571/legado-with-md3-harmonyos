/**
 * 日志面板，对齐上游 `ui/widget/components/log/AppLogSheet.kt`（136 行）。
 *
 * 上游是公共组件：书架页、书架管理页、书源页等都用同一个 `AppLogSheet(show, onDismissRequest)`。
 * 本地原先各页面各写一份内联 `@Builder LogSheetContent()`（内容同源但形态各异），
 * 这里抽成唯一实现，调用方只管显隐。
 *
 * 与上游逐条对齐的点：
 * 1. 标题「日志」+ 右侧清空按钮（`MediumTonalButton(icon = DeleteSweep, contentDescription = clear)`）。
 * 2. 空态文案「暂无日志」（`EmptyMessage(message = no_logs)`，`AppLogSheet.kt:69-71`）。
 * 3. 列表 `contentPadding = PaddingValues(bottom = 16.dp)`（`:74-79`）。
 * 4. 每条：整行可点（点开看全文）、`padding(16.dp)`、时间 `labelMedium`/`outline`、
 *    正文 `bodyMedium`/`onSurface`/`maxLines = 2`/`padding(top = 4.dp)`（`LogItem`，`:110-136`）。
 * 5. 点条目弹 `LogDetailSheet(title = "Log", content = 全文)`（`:84-89`）。
 * 6. 每次显示时重新读 `AppLog`（上游 `LaunchedEffect(show) { if (show) logs = loadAllLogs() }`，`:48-52`）。
 */
import { AppLog, AppLogEntry } from '../lib/AppLog';
import { AppGlyph } from './AppGlyph';
import {
  BODY_MEDIUM,
  LABEL_MEDIUM
} from './typography/TypographyTokens';
import { SPACE_4, SPACE_8, SPACE_16 } from './UiTokens';

/** 清空按钮尺寸：上游 `MediumTonalButton` 无文字时是 40×40（SeriesIconButton.kt `MediumSeriesIconButtonSize`）。 */
const CLEAR_BUTTON_SIZE: number = 40;
/** 清空按钮图标：上游 `MediumSeriesIconSize = IconButtonDefaults.mediumIconSize`（24）。 */
const CLEAR_ICON_SIZE: number = 24;
/** 列表高度上限：上游 `LazyColumn` 在 Sheet 内没有固定高度，本地 Sheet 是 FIT_CONTENT，给一个上限避免顶出屏幕。 */
const LOG_LIST_MAX_HEIGHT: number = 440;
/** 详情面板高度上限：上游 `LogDetailSheet` 是独立 Sheet，本地用浮层承载。 */
const DETAIL_MAX_HEIGHT: number = 520;

@Component
export struct AppLogSheet {
  /** 是否显示。由调用方控制；组件自己不改它，只在关闭时回调 `onDismissRequest`。 */
  @Prop @Watch('onShowChanged') show: boolean = false;
  onDismissRequest: () => void = () => {};

  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#8B8D98';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#4C6FFF';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F1F2F6';

  /** 上游 `logs by remember { mutableStateOf(emptyList<LogEntry>()) }`。 */
  @State logs: AppLogEntry[] = [];
  /** 上游 `showDetail by remember { mutableStateOf<String?>(null) }`：非空即打开详情面板。 */
  @State detailContent: string = '';

  aboutToAppear(): void {
    if (this.show) {
      this.loadLogs();
    }
  }

  /** 上游 `LaunchedEffect(show) { if (show) logs = loadAllLogs() }`。 */
  onShowChanged(): void {
    if (this.show) {
      this.loadLogs();
    } else {
      // 关闭时收起详情，下次打开是干净的面板。
      this.detailContent = '';
    }
  }

  private loadLogs(): void {
    this.logs = AppLog.getAll();
  }

  /** 上游 `clearAllLogs()`：`AppLog.clear()` + 本地列表同步清空。 */
  private clearLogs(): void {
    AppLog.clear();
    this.logs = [];
  }

  /**
   * 清空按钮。
   * 上游 `MediumTonalButton(icon = Icons.Default.DeleteSweep, contentDescription = clear)`：
   * Tonal 样式 = `surfaceContainerLow` 底 + 40×40 圆 + 24 图标。
   */
  @Builder
  ClearButton() {
    Stack({ alignContent: Alignment.Center }) {
      AppGlyph({
        name: 'deleteSweep',
        glyphSize: CLEAR_ICON_SIZE,
        tint: this.themeColorTextPrimary
      })
    }
    .width(CLEAR_BUTTON_SIZE)
    .height(CLEAR_BUTTON_SIZE)
    .borderRadius(CLEAR_BUTTON_SIZE / 2)
    .backgroundColor(this.themeColorSurfaceTertiary)
    .onClick(() => this.clearLogs())
    .accessibilityText('清空')
  }

  /** 单条日志：上游 `LogItem`。 */
  @Builder
  LogItem(item: AppLogEntry) {
    Column() {
      Text(AppLog.formatTime(item.timestamp))
        .fontSize(LABEL_MEDIUM)
        .fontColor(this.themeColorTextTertiary)
        .width('100%')
      Text(item.content())
        .fontSize(BODY_MEDIUM)
        .fontColor(this.themeColorTextPrimary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: SPACE_4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(SPACE_16)
    .onClick(() => {
      // 上游 `LogItem(item) { showDetail = item.content }`。
      this.detailContent = item.content();
    })
  }

  /** 空态：上游 `EmptyMessage(modifier = fillMaxWidth, message = no_logs)`。 */
  @Builder
  EmptyState() {
    Column() {
      Text('暂无日志')
        .fontSize(LABEL_MEDIUM)
        .fontColor(this.themeColorTextTertiary)
    }
    .width('100%')
    .height(240)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  /** 详情浮层：上游 `LogDetailSheet(show = showDetail != null, title = "Log", content = showDetail)`。 */
  @Builder
  DetailOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#99000000')
        .onClick(() => { this.detailContent = ''; })
      Column() {
        Row() {
          Text('Log')
            .fontSize(BODY_MEDIUM)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColorTextPrimary)
            .layoutWeight(1)
          Text('关闭')
            .fontSize(LABEL_MEDIUM)
            .fontColor(this.themeColorAccent)
            .padding(SPACE_8)
            .onClick(() => { this.detailContent = ''; })
        }
        .width('100%')
        .padding({ bottom: SPACE_8 })
        Scroll() {
          Text(this.detailContent)
            .fontSize(BODY_MEDIUM)
            .fontColor(this.themeColorTextPrimary)
            .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: DETAIL_MAX_HEIGHT })
        .scrollBar(BarState.Auto)
        .align(Alignment.TopStart)
      }
      .width('92%')
      .constraintSize({ maxHeight: DETAIL_MAX_HEIGHT + 80 })
      .padding(SPACE_16)
      .backgroundColor(this.themeColorSurfaceSecondary)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      Column() {
        // 标题行：上游 `AppModalBottomSheet(title = log, endAction = { MediumTonalButton(...) })`。
        Row() {
          Text('日志')
            .fontSize(BODY_MEDIUM)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColorTextPrimary)
            .layoutWeight(1)
          this.ClearButton()
        }
        .width('100%')
        .padding({ top: SPACE_8, bottom: SPACE_8 })

        if (this.logs.length === 0) {
          this.EmptyState()
        } else {
          List() {
            ForEach(this.logs, (item: AppLogEntry) => {
              ListItem() {
                this.LogItem(item)
              }
            }, (item: AppLogEntry) => `${item.timestamp}:${item.message}`)
          }
          .width('100%')
          .constraintSize({ maxHeight: LOG_LIST_MAX_HEIGHT })
          .scrollBar(BarState.Off)
          // 上游 `contentPadding = PaddingValues(bottom = 16.dp)`。
          .padding({ bottom: SPACE_16 })
        }
      }
      .width('100%')

      if (this.detailContent.length > 0) {
        this.DetailOverlay()
      }
    }
    .width('100%')
  }
}
