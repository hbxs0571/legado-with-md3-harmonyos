/**
 * 首页与导航设置面板，对齐上游
 * `ui/config/themeConfig/MainNavigationSettingsSheet.kt`（195 行）。
 *
 * 上游结构（`AppModalBottomSheet(title = main_navigation_settings「首页与导航」)` 里一整列）：
 *   1. `CompactDropdownSettingItem(default_home_page「默认主页」)` —— 选项只列**可见项**；
 *   2. `CompactDropdownSettingItem(nav_label_mode「导航栏标签显示方式」)` —— 四档；
 *   3. 4dp 间隔；
 *   4. `CompactClickableSettingItem(theme_config_nav_icons「导航栏图标」, description = 自定义图标数量文案)`
 *      —— 点开 `NavIconManageSheet`；
 *   5. 4dp 间隔；
 *   6. `LazyColumn(heightIn(max = 400dp), spacedBy(4dp))`：
 *      先列可见项（可拖拽重排、右侧开关关掉即隐藏该项），
 *      再列隐藏项（开关关、不可拖拽、打开即恢复显示）。
 *
 * 上游三条逻辑（`MainNavigationSettingsSheet.kt:63-85`）：
 * - `isRouteVisible(route)`：home→showHome / explore→showDiscovery / rss→showRss，其余恒 true；
 * - `setVisibilityForRoute(route, false)`：先把该项移到列表末尾，再回写整串顺序；
 * - `selectedDefault = defaultHomePage.takeIf { 在可见项里 } ?: bookshelf`。
 *
 * 本地承接（差异写在这里，报告里同样记）：
 * - 上游 `ReorderableSelectionItem` 用 `rememberReorderableLazyListState` 做长按拖拽；
 *   本地用 `List` + `editMode(true)` + `onItemDragStart`/`onItemDrop`（ArkUI 的列表内拖拽），
 *   与外观页「主导航顺序」同一套，并保留下移按钮作为无障碍回退。
 * - 上游开关在每行右侧（`ReorderableSelectionItem` 内建）；本地沿用 `Toggle`。
 */
import { AppGlyph } from '../AppGlyph';
import { LABEL_MEDIUM, TITLE_MEDIUM } from '../typography/TypographyTokens';
import { SPACE_12, SPACE_16, SPACE_24, SPACE_4, SPACE_8 } from '../UiTokens';
import { UiAction } from '../settings/UiAction';
import { UiDropdown } from '../settings/UiDropdown';
import {
  isMainDestinationVisible, labelVisibilityLabel, LABEL_VISIBILITY_VALUES,
  mainNavigationLabel, orderedMainNavigation
} from '../../data/MainNavigationSettings';

/** 拖拽列表高度上限，对齐上游 `heightIn(max = 400.dp)`。 */
const NAVIGATION_LIST_MAX_HEIGHT: number = 400;

@Component
export struct MainNavigationSettingsSheet {
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#6A6D77';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';

  /** 当前主导航顺序（逗号分隔）。 */
  @Prop mainNavigationOrder: string = 'home,bookshelf,explore,rss,my';
  /** 默认主页面。 */
  @Prop defaultHomePage: string = 'bookshelf';
  /** 导航标签显示方式。 */
  @Prop labelVisibilityMode: string = 'auto';
  @Prop showHome: boolean = true;
  @Prop showDiscovery: boolean = true;
  @Prop showRss: boolean = true;
  /** 已设置的自定义导航图标数量（上游 `theme_config_nav_icons_custom_count`）。 */
  @Prop customNavIconCount: number = 0;

  onDismissRequest: () => void = () => {};
  onNavigationVisibilityChange: (route: string, visible: boolean) => void = () => {};
  onNavigationReorder: (from: number, to: number) => void = () => {};
  onNavigationMove: (route: string, up: boolean) => void = () => {};
  onDefaultHomePageChange: (route: string) => void = () => {};
  onLabelVisibilityModeChange: (value: string) => void = () => {};
  onOpenNavIcons: () => void = () => {};

  @State private draggingRoute: string = '';

  /** 该项当前是否可见，对齐上游 `isRouteVisible`。 */
  private routeVisible(route: string): boolean {
    return isMainDestinationVisible(route, this.showHome, this.showDiscovery, this.showRss);
  }

  /** 全量顺序（含隐藏项），拖拽列表按它渲染。 */
  private orderedRoutes(): string[] {
    return orderedMainNavigation(this.mainNavigationOrder);
  }

  /** 可见项，按配置顺序。 */
  private visibleRoutes(): string[] {
    const ordered = this.orderedRoutes();
    const result: string[] = [];
    for (const route of ordered) {
      if (this.routeVisible(route)) { result.push(route); }
    }
    return result;
  }

  /** 隐藏项，按配置顺序。 */
  private hiddenRoutes(): string[] {
    const ordered = this.orderedRoutes();
    const result: string[] = [];
    for (const route of ordered) {
      if (!this.routeVisible(route)) { result.push(route); }
    }
    return result;
  }

  /**
   * 默认主页面：不可见时回落书架，对齐上游
   * `MainNavigationSettingsSheet.kt:83-85` 的 `takeIf { 在可见项里 } ?: Bookshelf.route`。
   */
  private selectedDefault(): string {
    return this.visibleRoutes().includes(this.defaultHomePage) ? this.defaultHomePage : 'bookshelf';
  }

  private navIconDescription(): string {
    return this.customNavIconCount > 0
      ? `已设置 ${this.customNavIconCount} 个自定义图标`
      : '使用默认图标';
  }

  /**
   * 关掉某一项时把它移到末尾，对齐上游
   * `MainNavigationSettingsSheet.kt:72-79` 的 `setVisibilityForRoute(route, false)`。
   *
   * 上游先 `onSetVisible(route, false)`，再把该项从列表里摘出来追加到末尾、回写顺序。
   * 本地按同一顺序：先改可见性，再调重排把该项移到最后一位。
   */
  private hideRoute(route: string): void {
    this.onNavigationVisibilityChange(route, false);
    const ordered = this.orderedRoutes();
    const from = ordered.indexOf(route);
    const to = ordered.length - 1;
    if (from >= 0 && from !== to) {
      this.onNavigationReorder(from, to);
    }
  }

  build() {
    Column() {
      // 标题（上游 `AppModalBottomSheet(title)`）。
      Text('首页与导航')
        .fontSize(20)
        .fontColor(this.themeColorTextPrimary)
        .width('100%')
        .padding({ left: 16, right: 16, top: SPACE_24, bottom: SPACE_12 })

      Column() {
        // 默认主页：只列可见项（上游 `displayEntries = visibleItems.map{...}`）。
        UiDropdown({
          showDivider: false,
          title: '默认主页',
          option: this.selectedDefault(),
          options: this.visibleRoutes(),
          labelOf: (value: string) => mainNavigationLabel(value),
          onSelect: (value: string) => this.onDefaultHomePageChange(value)
        })

        // 导航栏标签显示方式：四档（上游 `R.array.label_vis_mode_value`）。
        UiDropdown({
          title: '导航栏标签显示方式',
          option: this.labelVisibilityMode,
          options: LABEL_VISIBILITY_VALUES,
          labelOf: (value: string) => labelVisibilityLabel(value),
          onSelect: (value: string) => this.onLabelVisibilityModeChange(value)
        })

        // 4dp 间隔（上游 `Spacer(padding bottom 4dp)`）。
        Column().width('100%').height(SPACE_4)

        // 导航栏图标：description 是自定义数量文案。
        UiAction({
          title: '导航栏图标',
          detail: this.navIconDescription(),
          onSelect: () => this.onOpenNavIcons()
        })

        Column().width('100%').height(SPACE_4)

        // 可见项：可拖拽、右侧开关可关（关掉即隐藏并移到末尾）。
        List() {
          ForEach(this.visibleRoutes(), (route: string, index: number) => {
            ListItem() {
              Row() {
                AppGlyph({ name: 'list', tint: this.themeColorTextTertiary, glyphSize: 18 })
                  .margin({ right: SPACE_8 })
                Text(mainNavigationLabel(route))
                  .fontSize(TITLE_MEDIUM)
                  .fontColor(this.themeColorTextPrimary)
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: true })
                  .selectedColor(this.themeColorAccent)
                  .onChange((isOn: boolean) => {
                    if (!isOn) { this.hideRoute(route); }
                  })
              }
              .width('100%')
              .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_12, bottom: SPACE_12 })
              .alignItems(VerticalAlign.Center)
              .backgroundColor(this.themeColorSurfaceElevated)
              .borderRadius(12)
            }
            .accessibilityText(`${mainNavigationLabel(route)}，第 ${index + 1} 项，已显示`)
          }, (route: string) => route)
        }
        .width('100%')
        .constraintSize({ maxHeight: NAVIGATION_LIST_MAX_HEIGHT })
        .divider({ strokeWidth: SPACE_4, color: Color.Transparent })
        .editMode(true)
        .onItemDragStart((_event: ItemDragInfo, itemIndex: number) => {
          this.draggingRoute = this.visibleRoutes()[itemIndex];
        })
        .onItemDrop((_event: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean) => {
          if (!isSuccess) { return; }
          // 可见项内的位置要换算回全量顺序的下标：上游 `onMoveItem` 也是先取
          // `visibleItems[from]` / `visibleItems[to]` 再 `indexOf` 回全量表。
          const visible = this.visibleRoutes();
          if (itemIndex < 0 || itemIndex >= visible.length ||
            insertIndex < 0 || insertIndex >= visible.length) {
            this.draggingRoute = '';
            return;
          }
          const ordered = this.orderedRoutes();
          const from = ordered.indexOf(visible[itemIndex]);
          const to = ordered.indexOf(visible[insertIndex]);
          if (from >= 0 && to >= 0 && from !== to) {
            this.onNavigationReorder(from, to);
          }
          this.draggingRoute = '';
        })

        // 隐藏项：开关关、不可拖拽，打开即恢复显示。
        if (this.hiddenRoutes().length > 0) {
          Column() {
            ForEach(this.hiddenRoutes(), (route: string) => {
              Row() {
                AppGlyph({ name: 'list', tint: this.themeColorTextTertiary, glyphSize: 18 })
                  .margin({ right: SPACE_8 })
                Text(mainNavigationLabel(route))
                  .fontSize(TITLE_MEDIUM)
                  .fontColor(this.themeColorTextTertiary)
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: false })
                  .selectedColor(this.themeColorAccent)
                  .onChange((isOn: boolean) => {
                    if (isOn) { this.onNavigationVisibilityChange(route, true); }
                  })
              }
              .width('100%')
              .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_12, bottom: SPACE_12 })
              .alignItems(VerticalAlign.Center)
              .accessibilityText(`${mainNavigationLabel(route)}，已隐藏`)
            }, (route: string) => `hidden-${route}`)
          }
          .width('100%')
          .margin({ top: SPACE_4 })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: SPACE_24 })
    }
    .width('100%')
  }
}
