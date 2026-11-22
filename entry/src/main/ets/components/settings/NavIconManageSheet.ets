/**
 * 主导航图标管理面板，对齐上游 `ui/config/themeConfig/NavIconManageSheet.kt`（225 行）。
 *
 * 上游形态：`AppModalBottomSheet(title = R.string.theme_config_nav_icons)` 内
 * `Column(spacedBy(12.dp))` → 表头（「未选中」/「已选中」两列，每列 40dp 宽）→
 * 每个目标一张 `NormalCard(16dp 圆角, onSheetContent)`，行内是
 * `AppIcon(24dp) + 标签(labelMediumEmphasized, weight 1f) + 两个 NavigationIconSlot`。
 *
 * `NavigationIconSlot`：40×40 圆角 12、底色 `surfaceContainer`；有图时画图，无图时画加号
 * （`theme_config_add_nav_icon`）；有图时点开菜单两项「更换图片」/「清除」。
 *
 * 本地差异（都写在这里，不藏）：
 * - 本地没有 `NormalCard`，用 `Column` + 圆角 + `themeColorSurfaceTertiary` 承接；
 * - 菜单用本地 `UiMenuPanel`（`components/UiMenu.ets`），上游是 `RoundDropdownMenu`；
 * - 选图走 `picker.PhotoViewPicker`（上游是 `ActivityResultContracts.GetContent()`），
 *   落盘口径一致：复制进 `filesDir/nav_icons/<内容摘要>.png`。
 */

import { AppGlyph, AppGlyphName } from '../AppGlyph';
import { UiMenuPanel, UiMenuItem } from '../UiMenu';
import { BODY_SMALL, LABEL_LARGE, LABEL_MEDIUM, TITLE_MEDIUM } from '../typography/TypographyTokens';
import { SPACE_12, SPACE_4, SPACE_8, RADIUS_INNER } from '../UiTokens';
import { NavIconLibrary, NAV_ICON_SLOT_INFOS, NavIconSlotInfo } from '../../data/NavIconLibrary';
import { picker } from '@kit.CoreFileKit';

/** 槽位方块边长，对齐上游 `NavigationIconSlot` 的 `size(40.dp)`。 */
const SLOT_SIZE: number = 40;
/** 槽位圆角，对齐上游 `cornerRadius = 12.dp`。 */
const SLOT_RADIUS: number = 12;
/** 槽位内图标边长，对齐上游 `AppIcon(24.dp)`。 */
const SLOT_ICON_SIZE: number = 24;
/** 目标卡片圆角，对齐上游 `NormalCard(cornerRadius = 16.dp)`。 */
const CARD_RADIUS: number = 16;

@Component
export struct NavIconManageSheet {
  /** 当前十个槽位的路径，键为 `NavIconLibrary.NAV_ICON_SLOTS` 里的 slot 名。 */
  @Prop slotPaths: string[] = [];
  onSelectIcon: (slot: string, path: string) => void = (_slot: string, _path: string) => {};
  onClearIcon: (slot: string) => void = (_slot: string) => {};
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F2F2F7';
  @StorageProp('themeColorError') themeColorError: string = '#B3261E';
  /** 正在选图的槽位；空串表示没有在选择。 */
  @State pendingSlot: string = '';
  /** 菜单展开的槽位；空串表示没有展开。 */
  @State menuSlot: string = '';
  @State menuVisible: boolean = false;

  /** 取某个槽位当前的路径。 */
  private pathOf(slot: string): string {
    const index = NavIconLibrary.slotIndex(slot);
    if (index < 0 || index >= this.slotPaths.length) {
      return '';
    }
    return this.slotPaths[index];
  }

  /** 五个页面各自的「未选中 / 已选中」两个槽位名。 */
  private normalSlot(info: NavIconSlotInfo): string {
    return info.slot;
  }

  private selectedSlot(info: NavIconSlotInfo): string {
    return `${info.slot}Selected`;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
      // 提示失败不影响主流程
    }
  }

  /**
   * 选一张图并落到沙箱。
   *
   * 上游 `ThemeConfigRouteScreen.kt:59-86` 用 `ActivityResultContracts.GetContent()` 拿单张图，
   * 复制进 `filesDir/nav_icons/<内容摘要>.png` 后把绝对路径写进偏好。本地用
   * `picker.PhotoViewPicker`，落盘口径一致（见 `data/NavIconLibrary.ets`）。
   */
  private async pickIcon(slot: string): Promise<void> {
    this.pendingSlot = slot;
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showToast('无法访问文件，请重试');
      this.pendingSlot = '';
      return;
    }
    try {
      const options = new picker.PhotoSelectOptions();
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const pickerInstance = new picker.PhotoViewPicker(context);
      const result = await pickerInstance.select(options);
      if (result.photoUris.length === 0) {
        this.pendingSlot = '';
        return;
      }
      const target = NavIconLibrary.importIcon(context, result.photoUris[0]);
      this.onSelectIcon(slot, target);
    } catch (error) {
      this.showToast(error instanceof Error ? error.message : '选择图片失败');
    } finally {
      this.pendingSlot = '';
    }
  }

  @Builder
  private SlotMenu(slot: string) {
    UiMenuPanel({
      items: this.slotMenuItems(slot),
      panelWidth: 168,
      onSelect: (key: string) => {
        this.menuVisible = false;
        this.menuSlot = '';
        if (key === 'replace') {
          this.pickIcon(slot);
        } else if (key === 'clear') {
          this.onClearIcon(slot);
        }
      }
    })
  }

  private slotMenuItems(slot: string): UiMenuItem[] {
    const items: UiMenuItem[] = [];
    // 上游 `RoundDropdownMenu` 两项：更换图片（theme_config_replace_nav_icon）、清除（delete）。
    const replace: UiMenuItem = { key: 'replace', title: '更换图片' };
    const clear: UiMenuItem = { key: 'clear', title: '清除' };
    items.push(replace);
    items.push(clear);
    return items;
  }

  /** 表头一列：宽度与槽位方块一致，对齐上游 `NavigationIconColumnHeader` 的 `width(40.dp)`。 */
  @Builder
  private ColumnHeader(text: string) {
    Text(text)
      .fontSize(BODY_SMALL)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.themeColorTextTertiary)
      .width(SLOT_SIZE)
      .textAlign(TextAlign.Center)
      .maxLines(1)
  }

  /**
   * 一个图标槽位。
   *
   * 上游 `NavigationIconSlot`：无图时整块可点直接选图；有图时点开菜单选「更换图片 / 清除」。
   * 本地同口径，且把无障碍文案拆开：无图时是「添加<页面>图标」，有图时是「更换<页面>图标」。
   */
  @Builder
  private IconSlot(info: NavIconSlotInfo, slot: string) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.pathOf(slot).length > 0) {
        Image(`file://${this.pathOf(slot)}`)
          .width(SLOT_SIZE - SPACE_8)
          .height(SLOT_SIZE - SPACE_8)
          .objectFit(ImageFit.Contain)
          .borderRadius(SLOT_RADIUS - 4)
      } else {
        AppGlyph({ name: 'add', tint: this.themeColorAccent, glyphSize: SLOT_ICON_SIZE })
      }
    }
    .width(SLOT_SIZE)
    .height(SLOT_SIZE)
    .backgroundColor(this.themeColorSurfaceTertiary)
    .borderRadius(SLOT_RADIUS)
    .accessibilityText(this.pathOf(slot).length > 0
      ? `更换${info.label}图标` : `添加${info.label}图标`)
    .onClick(() => {
      if (this.pathOf(slot).length > 0) {
        this.menuSlot = slot;
        this.menuVisible = true;
      } else {
        this.pickIcon(slot);
      }
    })
    .bindPopup(this.menuVisible && this.menuSlot === slot, {
      builder: this.SlotMenu(slot),
      placement: Placement.Bottom,
      popupColor: '#00000000',
      enableArrow: false,
      autoCancel: true,
      width: 168,
      onStateChange: (event: PopupStateChangeParam) => {
        this.menuVisible = event.isVisible;
        if (!event.isVisible) {
          this.menuSlot = '';
        }
      }
    })
  }

  /** 一个目标一行：内置图标 + 标签 + 两个槽位，对齐上游 `NavIconDestination` 的行结构。 */
  @Builder
  private DestinationRow(info: NavIconSlotInfo) {
    Row({ space: SPACE_12 }) {
      AppGlyph({ name: info.fallbackSelectedIcon, tint: this.themeColorTextSecondary, glyphSize: SLOT_ICON_SIZE })
        .margin({ left: SPACE_4 })
      Text(info.label)
        .fontSize(LABEL_MEDIUM)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary)
        .layoutWeight(1)
        .maxLines(1)
      this.IconSlot(info, this.normalSlot(info))
      this.IconSlot(info, this.selectedSlot(info))
    }
    .width('100%')
    .padding(SPACE_12)
    .backgroundColor(this.themeColorSurfaceTertiary)
    .borderRadius(CARD_RADIUS)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column({ space: SPACE_12 }) {
      // 表头：左侧留出「图标 + 标签」的宽度，右侧两列各 40vp，与行内槽位对齐。
      Row({ space: SPACE_12 }) {
        Blank().layoutWeight(1)
        this.ColumnHeader('未选中')
        this.ColumnHeader('已选中')
      }
      .width('100%')
      .padding({ left: SPACE_12, right: SPACE_12 })

      ForEach(NAV_ICON_SLOT_INFOS, (info: NavIconSlotInfo) => {
        this.DestinationRow(info)
      }, (info: NavIconSlotInfo) => info.slot)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
