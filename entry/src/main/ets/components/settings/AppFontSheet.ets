import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import { AppFontEntry, AppFontFolderState, AppFontLibrary, AppFontScan, AppFontSort,
  APP_FONT_SORT_LABELS, normalizeAppFontSort } from '../../data/AppFontLibrary';
import { OtherSettingsRepository } from '../../data/OtherSettingsRepository';
import { AppGlyph, AppGlyphName } from '../AppGlyph';
import { UiMenuItem, UiMenuPanel } from '../UiMenu';
import { BODY_MEDIUM, BODY_SMALL, HEADLINE_SMALL, LABEL_LARGE, LABEL_MEDIUM } from '../typography/TypographyTokens';
import { SPACE_12, SPACE_16, SPACE_2, SPACE_4, SPACE_8 } from '../UiTokens';

/**
 * 字体选择面板，对齐上游 `ui/widget/components/FontSelectSheet.kt` + `FontSelectGrid.kt`。
 *
 * 上游形态（`FontSelectSheet.kt:95-146`）：
 * - `AppModalBottomSheet` 的 `startAction` 是「清除」图标按钮（`FontSelectSheet.kt:127-133`，
 *   图标 `Icons.Default.Delete`、`contentDescription = R.string.clear`），
 *   点它既清字体又关面板；
 * - `endAction` 是并排两枚 `MediumTonalButton`：`Icons.Default.FileOpen`「导入」+
 *   `folderIcon`「选择文件夹」（`:136-143`）；
 * - 正文是 `FontSelectGrid`：`SearchBar`（右侧排序按钮 + 六档菜单）、
 *   文件夹状态提示行、`LazyVerticalGrid(columns = 2)` 字体网格，
 *   每个条目的名字用**该字体自己**渲染（`FontSelectGrid.kt:250-280`），选中项右侧打勾。
 *
 * 本地差异（都写在这里，免得后来人当成 bug）：
 * - 上游 `AppModalBottomSheet` 的标题行是「左 action / 中标题 / 右 action」三栏，
 *   本地用同样三栏布局，但按钮画成文字 + 图标（本地没有 `MediumTonalButton` 组件，
 *   见 `pages/ReaderAloudSettingsPage.ets:235` 的同类近似）。
 * - 上游网格高 360dp（`FontSelectGrid.kt:70`），本地同值。
 * - 上游排序偏好落在 `OtherSettings.fontSort`，本地同键（`data/OtherSettingsRepository.ets`）。
 * - 上游字体文件夹偏好落在 `ReadSettings.fontFolder`，本地同键
 *   （`data/ReaderSettingsRepository.ets`），由页面传入并回写。
 */
@Component
export struct AppFontSheet {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorError') themeColorError: string = '#BA1A1A';

  /** 当前选中的字体绝对路径；空串表示系统默认字体（上游 `theme.appFontPath`）。 */
  @Prop selectedPath: string = '';
  /** 用户自选的字体文件夹；空串表示未配置（上游 `ReadSettings.fontFolder`）。 */
  @Prop folderPath: string = '';

  /** 选中某个字体文件。 */
  onSelectFont: (path: string) => void = (_path: string) => {};
  /** 「清除」：清空自定义字体并回落系统默认。 */
  onClearFont: () => void = () => {};
  /** 选完文件夹后回写偏好。 */
  onFolderChange: (path: string) => void = (_path: string) => {};

  @State fonts: AppFontEntry[] = [];
  @State folderState: number = AppFontFolderState.NotConfigured;
  @State query: string = '';
  @State sortIndex: number = 0;
  @State sortMenuVisible: boolean = false;

  aboutToAppear(): void {
    this.sortIndex = normalizeAppFontSort(OtherSettingsRepository.get().fontSort);
    this.reload();
  }

  /** 重新扫描「私有目录 + 用户文件夹」，扫描后按当前排序档排序。 */
  private reload(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const scan: AppFontScan = AppFontLibrary.scan(context, this.folderPath);
    this.fonts = AppFontLibrary.sort(scan.fonts, this.sortIndex);
    this.folderState = scan.folder;
  }

  /** 过滤 + 排序后的可见条目。 */
  private visibleFonts(): AppFontEntry[] {
    return AppFontLibrary.filter(this.fonts, this.query);
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_) {
    }
  }

  /** 上游 `fontFolderMessage()`：四态里只有 Unreadable / Empty / Loaded 空 出提示行。 */
  private folderMessage(): string {
    if (this.folderState === AppFontFolderState.Unreadable) {
      return '无法读取已选的字体文件夹（系统文件选择器可能已失效授权），已改为显示应用内字体；请重新选择文件夹或直接导入字体文件';
    }
    if (this.folderState === AppFontFolderState.Empty) {
      return '已选的字体文件夹里读不到任何文件。若字体确实放在里面仍不显示，是部分国产 ROM 的系统文件选择器不支持，请改用「导入字体文件」';
    }
    if (this.folderState === AppFontFolderState.Loaded && this.fonts.length === 0) {
      return '已选的字体文件夹里没有 .ttf/.otf 字体';
    }
    return '';
  }

  /** 选中判断：路径完全一致（上游比较的是文件名，本地路径已唯一，用路径更严格）。 */
  private isSelected(item: AppFontEntry): boolean {
    return this.selectedPath.length > 0 && this.selectedPath === item.path;
  }

  /** 条目预览字体族名；注册失败时回落系统默认（上游 `FontFamily?` 为 null 同理）。 */
  private itemFamily(item: AppFontEntry): string {
    return item.family.length > 0 ? item.family : 'HarmonyOS Sans';
  }

  /** 排序菜单条目：六档，当前档打勾（上游 DropdownMenu 的 `trailingIcon = Check`）。 */
  private sortMenuItems(): UiMenuItem[] {
    const items: UiMenuItem[] = [];
    for (let index = 0; index < APP_FONT_SORT_LABELS.length; index++) {
      items.push({ key: `${index}`, title: APP_FONT_SORT_LABELS[index], selected: index === this.sortIndex });
    }
    return items;
  }

  private applySort(key: string): void {
    const value = Number.parseInt(key, 10);
    this.sortIndex = normalizeAppFontSort(Number.isNaN(value) ? 0 : value);
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      const current = OtherSettingsRepository.get();
      current.fontSort = this.sortIndex;
      OtherSettingsRepository.save(context, current).catch(() => {
      });
    }
    this.fonts = AppFontLibrary.sort(this.fonts, this.sortIndex);
  }

  /**
   * 导入字体文件（上游 `FontSelectSheet.kt:84-93` 用 `OpenMultipleDocuments` 多选，
   * 导入后 toast `font_import_done` / `font_import_none` 并让网格重扫）。
   */
  private async importFonts(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      const options = new picker.DocumentSelectOptions();
      // 上游注释（FontSelectSheet.kt:46）：各家 provider 给的 MIME 不统一，
      // 所以放开选择、导入时再按扩展名过滤，本地同口径。
      options.maxSelectNumber = 20;
      const uris = await new picker.DocumentViewPicker(context).select(options);
      let imported = 0;
      for (let index = 0; index < uris.length; index++) {
        const uri = uris[index];
        if (uri === undefined) { continue; }
        const name = AppFontSheet.fileNameFromUri(uri);
        if (!AppFontLibrary.isFontName(name)) { continue; }
        try {
          AppFontLibrary.importFile(context, uri, name);
          imported++;
        } catch (_) {
        }
      }
      if (imported > 0) {
        this.showToast('已导入字体，可在下方列表中选择');
      } else {
        this.showToast('没有导入字体文件（仅支持 .ttf/.otf）');
      }
      this.reload();
    } catch (error) {
      this.showToast(error instanceof Error ? error.message : '导入字体失败');
    }
  }

  /** 选择字体文件夹（上游 `onOpenFolderPicker` → `ThemeConfigIntent.RequestFontFolder`）。 */
  private async pickFolder(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      const options = new picker.DocumentSelectOptions();
      options.selectMode = picker.DocumentSelectMode.FOLDER;
      options.maxSelectNumber = 1;
      const uris = await new picker.DocumentViewPicker(context).select(options);
      const uri = uris[0];
      if (uri === undefined) { return; }
      this.onFolderChange(uri);
      this.reload();
    } catch (error) {
      // 上游 `font_folder_not_accessible` 的成因之一就是选择器不支持目录；这里如实报出。
      this.showToast(error instanceof Error ? error.message : '此设备不能选择字体文件夹，请改用「导入字体文件」');
    }
  }

  private static fileNameFromUri(uri: string): string {
    const separator = uri.lastIndexOf('/');
    const raw = separator >= 0 ? uri.substring(separator + 1) : uri;
    try {
      return decodeURIComponent(raw);
    } catch (_) {
      return raw;
    }
  }

  @Builder
  SortMenu() {
    UiMenuPanel({
      items: this.sortMenuItems(),
      panelWidth: 200,
      onSelect: (key: string) => {
        this.sortMenuVisible = false;
        this.applySort(key);
      }
    })
  }

  /** 标题行按钮：图标 + 文字（上游 `MediumTonalButton` 的本地近似，labelMedium 字号）。 */
  @Builder
  ActionButton(icon: AppGlyphName, label: string, onTap: () => void) {
    Row({ space: SPACE_4 }) {
      AppGlyph({ name: icon, glyphSize: 18, tint: this.themeColorAccent })
      Text(label).fontSize(LABEL_MEDIUM).fontColor(this.themeColorAccent)
    }
    .padding({ left: SPACE_8, right: SPACE_8, top: SPACE_4, bottom: SPACE_4 })
    .onClick(onTap)
  }

  /** 网格里的一格：圆角 8 底 + 名字用自身字体 + 选中打勾（上游 `FontItem`）。 */
  @Builder
  FontCell(item: AppFontEntry) {
    Row() {
      Text(AppFontLibrary.displayName(item.name))
        .fontSize(BODY_MEDIUM)
        .fontFamily(this.itemFamily(item))
        .fontColor(this.themeColorTextPrimary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
      if (this.isSelected(item)) {
        AppGlyph({ name: 'profileCheck', glyphSize: 18, tint: this.themeColorAccent })
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: SPACE_12, right: SPACE_12 })
    .backgroundColor(this.themeColorSurfacePrimary)
    .borderRadius(8)
    .onClick(() => this.onSelectFont(item.path))
  }

  build() {
    Column() {
      // 标题行三栏：左「清除」图标、中标题、右「导入」「选择文件夹」。
      Row() {
        Row() {
          AppGlyph({ name: 'delete', glyphSize: 20, tint: this.themeColorTextSecondary })
        }
        .padding({ left: SPACE_8, right: SPACE_8, top: SPACE_4, bottom: SPACE_4 })
        .accessibilityText('清除')
        .onClick(() => this.onClearFont());

        Text('字体设置')
          .fontSize(HEADLINE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorTextPrimary)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1);

        Row({ space: SPACE_4 }) {
          this.ActionButton('uploadFile', '导入', () => { this.importFonts(); });
          this.ActionButton('profileFolder', '选择文件夹', () => { this.pickFolder(); });
        }
      }
      .width('100%')
      .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_8, bottom: SPACE_16 });

      // 搜索行：圆角 32、左侧放大镜、右侧排序按钮（上游 SearchBar 的非 Miuix 分支）。
      Row() {
        AppGlyph({ name: 'search', glyphSize: 20, tint: this.themeColorTextTertiary })
          .margin({ left: SPACE_12 });
        TextInput({ text: this.query, placeholder: '搜索' })
          .fontSize(BODY_MEDIUM)
          .fontColor(this.themeColorTextPrimary)
          .placeholderColor(this.themeColorTextTertiary)
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .padding({ left: SPACE_8 })
          .onChange((value: string) => { this.query = value; });
        Row() {
          AppGlyph({ name: 'list', glyphSize: 20, tint: this.themeColorTextTertiary })
        }
        .padding({ left: SPACE_12, right: SPACE_12 })
        .accessibilityText('排序')
        .onClick(() => { this.sortMenuVisible = !this.sortMenuVisible; })
        .bindPopup(this.sortMenuVisible, {
          builder: this.SortMenu,
          placement: Placement.Bottom,
          popupColor: '#00000000',
          enableArrow: false,
          autoCancel: true,
          width: 200,
          onStateChange: (event: PopupStateChangeParam) => { this.sortMenuVisible = event.isVisible; }
        });
      }
      .width('100%')
      .height(48)
      .backgroundColor(this.themeColorSurfaceTertiary)
      .borderRadius(32)
      .padding({ right: SPACE_4 });

      // 文件夹状态提示行（上游 `fontFolderMessage`，bodySmall + error 色）。
      if (this.folderMessage().length > 0) {
        Text(this.folderMessage())
          .fontSize(BODY_SMALL)
          .fontColor(this.themeColorError)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ left: SPACE_4, right: SPACE_4, top: SPACE_2, bottom: SPACE_2 })
          .margin({ top: SPACE_4 });
      }

      // 字体网格：两列、间距 8、高 360（上游 LazyVerticalGrid 同参数）。
      if (this.visibleFonts().length === 0) {
        Column() {
          Text('没有字体文件')
            .fontSize(BODY_MEDIUM)
            .fontColor(this.themeColorTextTertiary);
        }
        .width('100%')
        .height(360)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .margin({ top: SPACE_4 });
      } else {
        Grid() {
          ForEach(this.visibleFonts(), (item: AppFontEntry) => {
            GridItem() {
              this.FontCell(item);
            }
          }, (item: AppFontEntry) => item.path);
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(SPACE_8)
        .rowsGap(SPACE_8)
        .height(360)
        .width('100%')
        .margin({ top: SPACE_4 })
        .scrollBar(BarState.Off);
      }
    }
    .width('100%');
  }
}
