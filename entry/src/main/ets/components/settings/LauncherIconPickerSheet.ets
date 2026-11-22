/**
 * 桌面图标选择面板，对齐上游 `ui/config/themeConfig/LauncherIconPickerSheet.kt`（199 行）。
 *
 * 上游形态：`AppModalBottomSheet(title = R.string.change_icon)` 里一个 `LazyVerticalGrid(columns = 3)`，
 * 每格 `aspectRatio(1f)` + `MaterialTheme.shapes.large` 圆角 + 底色 `surfaceContainer`、
 * 选中时底色换 `secondaryContainer` 并加 2dp `primary` 描边，格内居中画 48dp 图标，
 * 点击即 `onValueChange(item.value)` 后关闭（`LauncherIconPickerSheet.kt:69-127`）。
 *
 * 与上游的唯一差异在数据来源：上游写死 8 个内置 mipmap（`LauncherIcons.list`，`:139-194`），
 * 鸿蒙的图标包由 AGC 下发、应用侧无法写死，所以改成向系统查询
 * （`data/LauncherIconLibrary.ets` 的 `queryLauncherIcons`）。
 */
import { AppGlyph } from '../AppGlyph';
import { BODY_SMALL, LABEL_MEDIUM, HEADLINE_SMALL } from '../typography/TypographyTokens';
import { SPACE_8, SPACE_12, SPACE_16, SPACE_24 } from '../UiTokens';
import {
  LauncherIconEntry, LauncherIconQuery, queryLauncherIcons,
  selectLauncherIcon, disableLauncherIcon, launcherIconErrorText
} from '../../data/LauncherIconLibrary';

/** 网格列数，对齐上游 `GridCells.Fixed(3)`。 */
const GRID_COLUMNS: number = 3;
/** 格子间距，对齐上游 `Arrangement.spacedBy(12.dp)`。 */
const GRID_GAP: number = 12;
/** 格内图标边长，对齐上游 `Modifier.size(48.dp)`。 */
const ICON_SIZE: number = 48;
/** 选中描边宽度，对齐上游 `Modifier.border(width = 2.dp, ...)`。 */
const SELECTED_BORDER: number = 2;

@Component
export struct LauncherIconPickerSheet {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSecondaryContainer') themeColorSecondaryContainer: string = '#DCE7C8';
  /** 当前正在使用的图标 id，空串表示用的是默认图标。 */
  @Prop selectedId: string = '';
  onDismiss: () => void = () => {};
  /** 切换成功后回调，参数是新图标 id；恢复默认时传空串。 */
  onIconChanged: (iconId: string) => void = (_iconId: string) => {};

  @State icons: LauncherIconEntry[] = [];
  @State failure: string = '';
  @State loading: boolean = true;

  aboutToAppear(): void {
    this.reload();
  }

  private async reload(): Promise<void> {
    this.loading = true;
    const result: LauncherIconQuery = await queryLauncherIcons();
    this.icons = result.icons;
    this.failure = result.failure;
    this.loading = false;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  private async chooseIcon(icon: LauncherIconEntry): Promise<void> {
    if (icon.enabled) {
      // 已经启用的那个再点一次没有意义，直接关掉面板（与上游「点中即关」的手感一致）。
      this.onDismiss();
      return;
    }
    const failure = await selectLauncherIcon(icon.id);
    if (failure.length > 0) {
      this.showToast(failure);
      return;
    }
    this.showToast('图标已修改');
    this.onIconChanged(icon.id);
    this.onDismiss();
  }

  private async restoreDefault(): Promise<void> {
    const failure = await disableLauncherIcon();
    if (failure.length > 0) {
      this.showToast(failure);
      return;
    }
    this.showToast('已恢复默认图标');
    this.onIconChanged('');
    this.onDismiss();
  }

  build() {
    Column() {
      // 标题行：中间标题，右侧「恢复默认」。上游这一屏只有标题（`:61`），
      // 恢复默认是本地补的入口 —— 上游靠禁用其余 component 回到默认，鸿蒙要显式调 disableDynamicIcon。
      Row() {
        Text('切换图标')
          .fontSize(HEADLINE_SMALL)
          .fontColor(this.themeColorTextPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding({ left: 56 })
        Text('恢复默认')
          .fontSize(LABEL_MEDIUM)
          .fontColor(this.themeColorAccent)
          .padding({ left: SPACE_8 })
          .onClick(() => { void this.restoreDefault(); })
      }
      .width('100%')
      .padding({ left: SPACE_16, right: SPACE_16, bottom: SPACE_12 })

      if (this.loading) {
        Row() {
          LoadingProgress().width(32).height(32).color(this.themeColorAccent)
        }
        .width('100%')
        .height(160)
        .justifyContent(FlexAlign.Center)
      } else if (this.failure.length > 0) {
        Column({ space: SPACE_8 }) {
          AppGlyph({ name: 'profileInfo', tint: this.themeColorTextTertiary, glyphSize: 32 })
          Text(this.failure)
            .fontSize(BODY_SMALL)
            .fontColor(this.themeColorTextTertiary)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ left: SPACE_24, right: SPACE_24, top: SPACE_24, bottom: SPACE_24 })
        .alignItems(HorizontalAlign.Center)
      } else if (this.icons.length === 0) {
        Text('当前应用还没有可切换的桌面图标')
          .fontSize(BODY_SMALL)
          .fontColor(this.themeColorTextTertiary)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ top: SPACE_24, bottom: SPACE_24 })
      } else {
        Grid() {
          ForEach(this.icons, (icon: LauncherIconEntry) => {
            GridItem() {
              Stack({ alignContent: Alignment.Center }) {
                if (icon.url.length > 0) {
                  Image(icon.url)
                    .width(ICON_SIZE)
                    .height(ICON_SIZE)
                    .objectFit(ImageFit.Contain)
                } else {
                  // 系统只给了 id 没给图时，用通用图标占位，不编造图片。
                  AppGlyph({ name: 'grid', tint: this.themeColorTextTertiary, glyphSize: ICON_SIZE })
                }
              }
              .width('100%')
              .aspectRatio(1)
              .backgroundColor(icon.enabled ? this.themeColorSecondaryContainer : this.themeColorSurfaceTertiary)
              .borderRadius(16)
              .border({
                width: icon.enabled ? SELECTED_BORDER : 0,
                color: icon.enabled ? this.themeColorAccent : '#00000000'
              })
              .onClick(() => { void this.chooseIcon(icon); })
              .accessibilityText(icon.enabled ? '当前桌面图标，已选中' : '切换到这个桌面图标')
            }
          }, (icon: LauncherIconEntry) => icon.id)
        }
        .columnsTemplate(this.gridTemplate())
        .columnsGap(GRID_GAP)
        .rowsGap(GRID_GAP)
        .width('100%')
        .padding({ left: SPACE_16, right: SPACE_16, bottom: SPACE_24 })
      }
    }
    .width('100%')
  }

  /** `GridCells.Fixed(3)` 对应的模板串。 */
  private gridTemplate(): string {
    const columns: string[] = [];
    for (let index = 0; index < GRID_COLUMNS; index++) {
      columns.push('1fr');
    }
    return columns.join(' ');
  }
}
