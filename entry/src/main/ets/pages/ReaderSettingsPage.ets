import { ReaderBackgroundStyle, READER_BACKGROUND_STYLES } from '../data/ReaderSettingsRepository';
import {
  ReaderActionOption, ReaderBottomActionConfig, READER_ACTION_OPTIONS,
  READER_LOCAL_BOTTOM_ACTION_DEFAULTS, READER_LOCAL_TOP_ACTION_DEFAULTS,
  ReaderInfoSettings, DEFAULT_READER_INFO_SETTINGS, ReaderPaddingSettings, DEFAULT_READER_PADDING_SETTINGS,
  copyReaderPaddingSettings, updateReaderInfoSettings,
  READER_CLICK_REGION_ACTIONS, READER_CLICK_REGION_DEFAULTS
} from '../data/ReaderSettingsRepository';

type ReaderInfoSlot = 'headerLeft' | 'headerMiddle' | 'headerRight' | 'footerLeft' | 'footerMiddle' | 'footerRight';

const READ_INFO_TIP_VALUES: number[] = [0, 7, 1, 12, 17, 2, 3, 15, 13, 14, 10, 4, 5, 11, 6, 8, 16, 9, 19, 20, 18];
const READER_INFO_COLOR_VALUES: number[] = [0, -1, -16777216, -8355712, -65536, -16711936, -16776961];
const READER_INFO_COLOR_CHOICES: string[] = ['跟随正文', '白色', '黑色', '灰色', '红色', '绿色', '蓝色'];
const CLICK_REGION_NAMES: string[] = ['左上', '上中', '右上', '左中', '中间', '右中', '左下', '下中', '右下'];
interface ReaderTextMenuEntry {
  id: string;
  title: string;
  group: number;
}
const READER_TEXT_MENU_DEFAULTS: ReaderTextMenuEntry[] = [
  { id: 'menu_copy', title: '复制', group: 0 },
  { id: 'menu_share_str', title: '分享', group: 0 },
  { id: 'menu_browser', title: '浏览器', group: 0 },
  { id: 'menu_aloud', title: '朗读', group: 0 },
  { id: 'menu_bookmark', title: '书签', group: 0 },
  { id: 'menu_mark', title: '笔记', group: 0 },
  { id: 'menu_dict', title: '字典', group: 0 },
  { id: 'menu_replace', title: '替换', group: 0 },
  { id: 'menu_edit', title: '编辑', group: 0 },
  { id: 'menu_ai_clean', title: 'AI 净化', group: 0 },
  { id: 'menu_ai_rewrite', title: 'AI 改写', group: 0 },
  { id: 'menu_search_content', title: '全文搜索', group: 0 },
  { id: 'menu_insert_bgm_before', title: '插入(前)', group: 0 },
  { id: 'menu_insert_bgm_after', title: '插入(后)', group: 0 }
];

interface ReaderMenuSettingsEntry {
  title: string;
  detail: string;
  section?: boolean;
}

interface ReaderUiSection {
  title: string;
  items: ReaderMenuSettingsEntry[];
}

@Component
export struct ReaderSettingsPage {
  @Prop fontSize: number = 19;
  @Prop paperIndex: number = 2;
  @Prop shareLayout: boolean = false;
  @Prop readerNightMode: boolean = true;
  @Prop eyeProtectionActive: boolean = false;
  @Prop eyeProtectionEnabled: boolean = false;
  @Prop eyeProtectionAutoNight: boolean = false;
  @Prop eyeProtectionSchedule: boolean = false;
  @Prop eyeProtectionIntensity: number = 50;
  @Prop eyeProtectionStartTime: string = '22:00';
  @Prop eyeProtectionEndTime: string = '07:00';
  @Prop showBottomActionText: boolean = true;
  @Prop bottomIconStyle: number = 1;
  @Prop bottomItemsPerRow: number = 5;
  @Prop bottomRowCount: number = 1;
  @Prop bottomActions: ReaderBottomActionConfig[] = READER_LOCAL_BOTTOM_ACTION_DEFAULTS;
  @Prop topActions: ReaderBottomActionConfig[] = READER_LOCAL_TOP_ACTION_DEFAULTS;
  @Prop progressBehavior: string = 'page';
  @Prop screenOrientation: string = '0';
  @Prop keepLight: string = '0';
  @Prop volumeKeyPage: boolean = true;
  @Prop keyPageOnLongPress: boolean = false;
  @Prop noAnimScrollPage: boolean = false;
  @Prop readingAnchorEnabled: boolean = true;
  @Prop swipeToAddBookmark: boolean = false;
  @Prop maxLengthWithNoToc: number = 3000;
  @Prop clickImageBehavior: string = '2';
  @Prop clickRegionActions: string[] = READER_CLICK_REGION_DEFAULTS;
  @Prop hideStatusBar: boolean = false;
  @Prop hideNavigationBar: boolean = false;
  @Prop infoSettings: ReaderInfoSettings = DEFAULT_READER_INFO_SETTINGS;
  @Prop paddingSettings: ReaderPaddingSettings = DEFAULT_READER_PADDING_SETTINGS;
  @Prop showQuickActions: boolean = false;
  @Prop asSheet: boolean = false;
  @Prop openBottomActionConfigOnAppear: boolean = false;
  @State selectedSettingsTab: number = 0;
  @State previousMainSettingsTab: number = 0;
  @State selectedMenuSettingsTab: number = 0;
  @State bottomActionConfigVisible: boolean = false;
  @State topActionConfigVisible: boolean = false;
  @State detailSheetVisible: boolean = false;
  @State detailSheetTitle: string = '';
  @State detailSheetDescription: string = '';
  @State detailSelectedOption: string = '';
  @State detailCustomText: string = '';
  @State selectedClickRegionIndex: number = 4;
  @State previousPageKeys: string = '';
  @State nextPageKeys: string = '';
  @State bookmarkBadgeCustomPreview: boolean = false;
  @State bookmarkBadgeSizePreview: number = 24;
  @State expandTextMenuPreview: boolean = false;
  @State showTextMenuIconsPreview: boolean = true;
  @State primaryTextMenuExpanded: boolean = true;
  @State collapsedTextMenuExpanded: boolean = true;
  @State hiddenTextMenuExpanded: boolean = false;
  @State textMenuEntries: ReaderTextMenuEntry[] = READER_TEXT_MENU_DEFAULTS.map(
    (item: ReaderTextMenuEntry): ReaderTextMenuEntry => ({ id: item.id, title: item.title, group: item.group })
  );
  private detailInfoSlot: ReaderInfoSlot | undefined = undefined;
  @Prop pageAnimationIndex: number = 0;
  @Prop animationSpeedIndex: number = 2;
  @State infoSubTab: number = 0;
  @State moreSubTab: number = 0;
  @State draftBottomActions: ReaderBottomActionConfig[] = READER_LOCAL_BOTTOM_ACTION_DEFAULTS.map(
    (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
  );
  @State draftTopActions: ReaderBottomActionConfig[] = READER_LOCAL_TOP_ACTION_DEFAULTS.map(
    (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
  );
  private backgroundScroller: Scroller = new Scroller();
  private menuSettingsScroller: Scroller = new Scroller();
  @State menuBarStyleMode: number = 1;
  @State menuColorMode: number = 0;
  @State menuPaletteStyleIndex: number = 0;
  @State menuBorderEnabled: boolean = true;
  @State menuTitleIconsVisible: boolean = true;
  @State brightnessViewMode: number = 0;

  aboutToAppear(): void {
    if (this.openBottomActionConfigOnAppear) {
      this.selectedSettingsTab = 1;
      this.selectedMenuSettingsTab = 1;
      this.draftBottomActions = this.bottomActions.map(
        (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
      );
      this.bottomActionConfigVisible = true;
    }
  }

  onBack: () => void = () => {};
  onFontSizeChange: (fontSize: number) => void = () => {};
  onPaperChange: (paperIndex: number) => void = () => {};
  onShareLayoutChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onToggleNightMode: () => void = () => {};
  onEyeProtectionToggle: () => void = () => {};
  onEyeProtectionEnabledChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onEyeProtectionAutoNightChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onEyeProtectionScheduleChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onEyeProtectionIntensityChange: (value: number) => void = (_value: number) => {};
  onEyeProtectionStartTimeChange: (value: string) => void = (_value: string) => {};
  onEyeProtectionEndTimeChange: (value: string) => void = (_value: string) => {};
  onBottomActionTextChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onBottomIconStyleChange: (style: number) => void = (_style: number) => {};
  onBottomItemsPerRowChange: (count: number) => void = (_count: number) => {};
  onBottomRowCountChange: (count: number) => void = (_count: number) => {};
  onBottomActionsChange: (actions: ReaderBottomActionConfig[]) => void = (_actions: ReaderBottomActionConfig[]) => {};
  onTopActionsChange: (actions: ReaderBottomActionConfig[]) => void = (_actions: ReaderBottomActionConfig[]) => {};
  onProgressBehaviorChange: (value: string) => void = (_value: string) => {};
  onScreenOrientationChange: (value: string) => void = (_value: string) => {};
  onKeepLightChange: (value: string) => void = (_value: string) => {};
  onVolumeKeyPageChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onKeyPageOnLongPressChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onNoAnimScrollPageChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onReadingAnchorEnabledChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onSwipeToAddBookmarkChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onMaxLengthWithNoTocChange: (value: number) => void = (_value: number) => {};
  onClickImageBehaviorChange: (value: string) => void = (_value: string) => {};
  onClickRegionActionsChange: (actions: string[]) => void = (_actions: string[]) => {};
  onHideStatusBarChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onHideNavigationBarChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onPageAnimationChange: (animation: number) => void = (_animation: number) => {};
  onAnimationSpeedChange: (speed: number) => void = (_speed: number) => {};
  onInfoSettingsChange: (settings: ReaderInfoSettings) => void = (_settings: ReaderInfoSettings) => {};
  onPaddingSettingsChange: (settings: ReaderPaddingSettings) => void = (_settings: ReaderPaddingSettings) => {};
  onQuickActionsChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  @Builder
  private settingsContent(showHandle: boolean) {
    Column() {
      if (showHandle) {
        Row().width(32).height(4).backgroundColor('#C5C6CD').borderRadius(4).margin({ top: 10, bottom: 14 })
      }
      Row() {
        Row() {
          Image($r('app.media.reader_back')).width(22).height(22).fillColor('#E5E6EB')
        }.width(38).height(38).justifyContent(FlexAlign.Center)
          .backgroundColor('#292A31').borderRadius(19).onClick(() => {
            if (this.selectedSettingsTab >= 2) { this.selectedSettingsTab = this.previousMainSettingsTab; }
            else { this.onBack(); }
          })
        Text(this.selectedSettingsTab === 2 ? '信息' : this.selectedSettingsTab === 3 ? '更多设置' : '阅读界面')
          .fontSize(17).fontColor('#E5E6EB').margin({ left: 10 })
        Blank()
      }.padding({ left: 16, right: 16, bottom: 14 })

      if (this.selectedSettingsTab < 2) {
        Swiper() {
          this.globalSettingsPage()
          this.menuSettingsContent()
        }
        .index(this.selectedSettingsTab)
        .loop(false)
        .indicator(false)
        .onChange((index: number) => this.selectSettingsTab(index))
        .layoutWeight(1)
        .width('100%')
      } else if (this.selectedSettingsTab === 2) {
        this.informationSettingsContent()
      } else {
        this.moreSettingsContent()
      }

      if (this.selectedSettingsTab < 2) {
        Row() {
          Text('全局').fontSize(10).fontColor('#E7E8ED').layoutWeight(1).textAlign(TextAlign.Center)
            .backgroundColor(this.selectedSettingsTab === 0 ? '#454B62' : '#1E1F25')
            .borderRadius(15).padding(8).onClick(() => this.selectSettingsTab(0))
          Text('菜单').fontSize(10).fontColor('#C1C2CA').layoutWeight(1).textAlign(TextAlign.Center)
            .backgroundColor(this.selectedSettingsTab === 1 ? '#454B62' : '#1E1F25')
            .borderRadius(15).padding(8).onClick(() => this.selectSettingsTab(1))
          Text('信息').fontSize(10).fontColor('#C1C2CA').layoutWeight(1).textAlign(TextAlign.Center)
            .backgroundColor('#1E1F25').borderRadius(15).padding(8).onClick(() => this.selectSettingsTab(2))
          Text('更多').fontSize(10).fontColor('#C1C2CA').layoutWeight(1).textAlign(TextAlign.Center)
            .backgroundColor('#1E1F25').borderRadius(15).padding(8).onClick(() => this.selectSettingsTab(3))
        }.padding({ left: 14, right: 14, top: 10, bottom: 16 })
      }
    }.width('100%').height('100%')
      .backgroundColor(this.asSheet ? '#D91A1B21' : '#1A1B21')
      .borderRadius(this.asSheet ? 22 : 0).clip(this.asSheet)
  }

  @Builder
  private globalSettingsPage() {
    Column() {
      Column() {
        Row() {
          Column() {
            Row() {
              Text('字号').fontSize(14).fontColor('#D9DAE0').layoutWeight(1)
              Text(this.fontSize.toString()).fontSize(12).fontColor('#E5E6EB')
            }
            Slider({
              value: this.fontSize,
              min: 5,
              max: 50,
              step: 1,
              style: SliderStyle.OutSet
            })
              .selectedColor('#B9C6FF')
              .trackColor('#4B4D59')
              .blockColor('#B9C6FF')
              .onChange((value: number, mode: SliderChangeMode) => {
                if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click ||
                  mode === SliderChangeMode.End) {
                  this.onFontSizeChange(Math.round(value))
                }
              })
          }
          .layoutWeight(1)
          Stack({ alignContent: Alignment.Center }) {
            Image($r('app.media.reader_info_text_fields'))
              .width(22)
              .height(22)
              .fillColor('#E5E6EB')
          }
          .width(56)
          .height(56)
          .backgroundColor('#292A31')
          .borderRadius(12)
          .margin({ left: 10 })
          .onClick(() => this.openDetailSheet('排版设置', '正文、标题、页眉页脚与边距设置'))
        }
        .padding(12)
        .backgroundColor('#202127')
        .borderRadius(13)

        Row() {
          Text('背景').fontSize(14).fontColor('#D9DAE0').layoutWeight(1)
          Text('长按自定义').fontSize(10).fontColor('#8F929D')
            .onClick(() => this.openDetailSheet('自定义阅读背景', '背景图片、背景颜色与文字颜色设置'))
          Image($r('app.media.app_visibility')).width(18).height(18)
            .fillColor(this.eyeProtectionActive ? '#C6D3FF' : '#D9DAE0').margin({ left: 10 })
            .onClick(() => this.onEyeProtectionToggle())
            .gesture(LongPressGesture({ duration: 500 }).onAction(() => {
              this.openDetailSheet('护眼设置', '护眼模式与色温参数');
            }))
          Image(this.readerNightMode ? $r('app.media.app_moon') : $r('app.media.app_daynight'))
            .width(18).height(18).fillColor('#D9DAE0').margin({ left: 9 })
            .onClick(() => this.onToggleNightMode())
        }.margin({ top: 13, bottom: 8 })

        Scroll(this.backgroundScroller) {
          Row() {
            BackgroundShareOption({ selected: this.shareLayout })
              .margin({ right: 8 }).onClick(() => this.onShareLayoutChange(!this.shareLayout))
            ForEach(READER_BACKGROUND_STYLES, (style: ReaderBackgroundStyle, styleIndex: number) => {
              BackgroundOption({
                label: style.name,
                color: this.readerNightMode ? style.nightColor : style.dayColor,
                selected: this.paperIndex === styleIndex
              }).margin({ right: 8 }).onClick(() => this.onPaperChange(styleIndex))
            }, (style: ReaderBackgroundStyle) => style.name)
          }.height(56)
        }.width('100%').height(56).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)

        Row() {
          Text('翻页动画').fontSize(12).fontColor('#D9DAE0').layoutWeight(1)
          Text(this.getPageAnimationLabel()).fontSize(11).fontColor('#D9DAE0').padding(8)
            .backgroundColor('#292A31').borderRadius(8)
            .onClick(() => this.openDetailSheet('翻页动画', '覆盖、滑动、仿真、滚动、淡入淡出、无动画'))
          Image($r('app.media.app_anim_speed')).width(20).height(20).fillColor('#D9DAE0').margin({ left: 12 })
          .onClick(() => this.openDetailSheet('翻页动画速度', `当前：${this.getAnimationSpeedLabel()}；可选极速、快速、适中、优雅`))
          Image($r('app.media.app_padding')).width(20).height(20).fillColor('#D9DAE0').margin({ left: 14 })
            .onClick(() => this.openDetailSheet('页边距', '页面内边距与正文留白设置'))
        }.padding(13).backgroundColor('#202127').borderRadius(13).margin({ top: 13 })
      }.padding({ left: 14, right: 14 })

      Blank().layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  private selectSettingsTab(index: number): void {
    if (index >= 2 && this.selectedSettingsTab < 2) {
      this.previousMainSettingsTab = this.selectedSettingsTab;
    }
    this.selectedSettingsTab = index;
  }

  @Builder
  private menuSettingsContent() {
    Column() {
      Row() {
        Text('菜单栏').fontSize(11).fontColor(this.selectedMenuSettingsTab === 0 ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center)
          .backgroundColor(this.selectedMenuSettingsTab === 0 ? '#454B62' : '#202127')
          .borderRadius(15).padding(8).onClick(() => this.selectedMenuSettingsTab = 0)
        Text('底栏布局').fontSize(11).fontColor(this.selectedMenuSettingsTab === 1 ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center)
          .backgroundColor(this.selectedMenuSettingsTab === 1 ? '#454B62' : '#202127')
          .borderRadius(15).padding(8).onClick(() => this.selectedMenuSettingsTab = 1)
        Text('顶栏布局').fontSize(11).fontColor(this.selectedMenuSettingsTab === 2 ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center)
          .backgroundColor(this.selectedMenuSettingsTab === 2 ? '#454B62' : '#202127')
          .borderRadius(15).padding(8).onClick(() => this.selectedMenuSettingsTab = 2)
      }.width('100%').padding({ left: 14, right: 14, bottom: 8 })

      Scroll(this.menuSettingsScroller) {
        Column() {
          if (this.selectedMenuSettingsTab === 1) {
            MenuSettingChoice({
              title: '进度条模式',
              value: this.progressBehavior,
              onChange: (value: string) => this.onProgressBehaviorChange(value)
            }).margin({ left: 14, right: 14, bottom: 8 })
            MenuSettingSwitch({
              title: '显示底栏图标名称',
              detail: '在阅读操作图标下显示文字',
              checked: this.showBottomActionText,
              onChange: (enabled: boolean) => this.onBottomActionTextChange(enabled)
            }).margin({ left: 14, right: 14, bottom: 8 })
            MenuSettingIconStyle({
              value: this.bottomIconStyle,
              onChange: (style: number) => this.onBottomIconStyleChange(style)
            }).margin({ left: 14, right: 14, bottom: 8 })
            MenuSettingSlider({
              title: '每行图标数',
              value: this.bottomItemsPerRow,
              minValue: 2,
              maxValue: 8,
              onChange: (count: number) => this.onBottomItemsPerRowChange(count)
            }).margin({ left: 14, right: 14, bottom: 8 })
            MenuSettingSlider({
              title: '底栏图标行数',
              value: this.bottomRowCount,
              minValue: 1,
              maxValue: 2,
              onChange: (count: number) => this.onBottomRowCountChange(count)
            }).margin({ left: 14, right: 14, bottom: 8 })
          } else if (this.selectedMenuSettingsTab === 2) {
            MenuSettingSwitch({
              title: '快捷图标行',
              detail: '在标题栏下方显示快捷阅读操作',
              checked: this.showQuickActions,
              onChange: (enabled: boolean) => this.onQuickActionsChange(enabled)
            }).margin({ left: 14, right: 14, bottom: 8 })
          }
          ForEach(this.getMenuSettingsEntries(), (entry: ReaderMenuSettingsEntry) => {
            this.menuSettingsEntry(entry)
          }, (entry: ReaderMenuSettingsEntry) => `${this.selectedMenuSettingsTab}-${entry.title}`)
        }.width('100%').padding({ top: 4, bottom: 8 })
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').layoutWeight(1)
  }

  @Builder
  private menuSettingsEntry(entry: ReaderMenuSettingsEntry) {
    if (entry.section === true) {
      MenuSettingSection({ title: entry.title })
    } else if (!this.isMenuSettingsEntryVisible(entry.title)) {
      Blank().height(0)
    } else if (entry.title === '底栏按钮配置' || entry.title === '标题栏操作按钮' || entry.title === '标题栏悬浮图标配置') {
      MenuSettingOption({ title: entry.title, detail: entry.detail, migrated: true })
        .onClick(() => this.handleMenuSettingsEntryClick(entry))
    } else if (this.isMenuToggle(entry.title)) {
      MenuSettingSwitch({
        title: entry.title,
        detail: entry.detail,
        checked: entry.title === '菜单栏边框'
          ? this.menuBorderEnabled
          : entry.title === '显示标题栏图标'
            ? this.menuTitleIconsVisible
            : entry.title === '标题栏胶囊' || entry.title === '标题栏紧凑',
        onChange: (enabled: boolean) => {
          if (entry.title === '菜单栏边框') { this.menuBorderEnabled = enabled; }
          else if (entry.title === '显示标题栏图标') { this.menuTitleIconsVisible = enabled; }
          else { this.showNotMigrated(entry.title); }
        }
      })
    } else if (this.isMenuSlider(entry.title)) {
      MenuSettingSlider({
        title: entry.title,
        value: this.menuSliderValue(entry.title),
        minValue: this.menuSliderMinimum(entry.title),
        maxValue: this.menuSliderMaximum(entry.title)
      }).onClick(() => this.showNotMigrated(entry.title))
    } else if (this.getMenuChoices(entry.title).length > 0) {
      MenuSettingSegments({
        title: entry.title,
        choices: this.getMenuChoices(entry.title),
        selectedIndex: this.getMenuSelectedIndex(entry.title),
        onSelect: (index: number) => {
          if (entry.title === '工具栏样式') { this.menuBarStyleMode = index; }
          if (entry.title === '菜单颜色来源') { this.menuColorMode = index; }
          if (entry.title === '调色板风格') { this.menuPaletteStyleIndex = index; }
          if (entry.title === '显示亮度视图') { this.brightnessViewMode = index; }
          this.openDetailSheet(entry.title, entry.detail);
        }
      })
    } else if (this.isMenuColor(entry.title)) {
      MenuSettingColor({ title: entry.title, detail: entry.detail })
        .onClick(() => this.openDetailSheet(entry.title, entry.detail))
    } else {
      MenuSettingOption({ title: entry.title, detail: entry.detail })
        .onClick(() => this.openDetailSheet(entry.title, entry.detail))
    }
  }

  private handleMenuSettingsEntryClick(entry: ReaderMenuSettingsEntry): void {
    if (entry.title === '底栏按钮配置') {
      this.draftBottomActions = this.bottomActions.map(
        (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
      );
      this.bottomActionConfigVisible = true;
    } else if (entry.title === '标题栏操作按钮') {
      this.draftTopActions = this.topActions.map(
        (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
      );
      this.topActionConfigVisible = true;
    } else {
      this.openDetailSheet('标题栏悬浮图标配置', '显示位置、操作图标及按钮背景样式');
    }
  }

  private isMenuToggle(title: string): boolean {
    return ['显示标题栏图标', '标题栏胶囊', '标题栏紧凑', '顶栏液态玻璃按钮', '合并标题栏按钮',
      '显示图标文字', '底栏悬浮', '底栏模糊', '顶栏模糊', '底栏液态玻璃', '底栏按钮液态玻璃', '菜单栏边框'].includes(title);
  }

  private isMenuSlider(title: string): boolean {
    return title.includes('透明度') || title.includes('半径') || title.includes('边框宽度') || title.includes('圆角');
  }

  private isMenuColor(title: string): boolean {
    return title.includes('颜色') || title.includes('色');
  }

  private menuSliderValue(title: string): number {
    if (title.includes('透明度')) { return 70; }
    if (title.includes('圆角')) { return 20; }
    if (title.includes('宽度')) { return 1; }
    return 8;
  }

  private menuSliderMaximum(title: string): number {
    if (title.includes('透明度')) { return 100; }
    if (title.includes('边框宽度')) { return 4; }
    if (title.includes('宽度')) { return 10; }
    return 32;
  }

  private menuSliderMinimum(title: string): number {
    return title.includes('边框宽度') ? 1 : 0;
  }

  private getMenuChoices(title: string): string[] {
    if (title === '工具栏样式') { return ['系统', '跟随阅读背景', '自定义']; }
    if (title === '调色板风格') { return ['跟随系统', '柔和', '中性', '鲜艳', '表现力', '彩虹', '水果拼盘', '单色', '仿真', '内容取色']; }
    if (title === '菜单颜色来源') { return ['种子色', '自定义主题色']; }
    if (title === '显示亮度视图') { return ['关闭', '横排', '竖排']; }
    if (title === '亮度条位置') { return ['左侧', '右侧']; }
    if (title === '标题栏模式') { return ['完整信息', '仅标题', '标题与章节']; }
    if (title.includes('图标样式')) { return ['纯色', '色调', '描边']; }
    if (title.includes('模糊样式')) { return ['纯色', '渐变']; }
    return [];
  }

  private getMenuSelectedIndex(title: string): number {
    if (title === '工具栏样式') { return this.menuBarStyleMode; }
    if (title === '菜单颜色来源') { return this.menuColorMode; }
    if (title === '调色板风格') { return this.menuPaletteStyleIndex; }
    if (title === '显示亮度视图') { return this.brightnessViewMode; }
    return 0;
  }

  private applyDetailChoicePreview(choice: string): void {
    this.detailSelectedOption = choice;
    const choices = this.getDetailChoices(this.detailSheetTitle);
    const choiceIndex = choices.indexOf(choice);
    if (this.detailSheetTitle === '显示模式' && choiceIndex >= 0) {
      this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, {
        headerMode: this.infoSubTab === 0 ? choiceIndex : this.infoSettings.headerMode,
        footerMode: this.infoSubTab === 1 ? (choiceIndex === 1 ? 1 : 0) : this.infoSettings.footerMode
      }));
    }
    if (this.detailInfoSlot !== undefined && this.detailSheetTitle.endsWith('显示内容') && choiceIndex >= 0) {
      const tipValue = READ_INFO_TIP_VALUES[choiceIndex] ?? 0;
      if (tipValue === 18) {
        this.detailCustomText = this.getInfoTipTemplate(this.detailInfoSlot);
      } else {
        this.saveInfoTip(this.detailInfoSlot, tipValue);
      }
    }
    if (this.detailSheetTitle === '工具栏样式' && choiceIndex >= 0) { this.menuBarStyleMode = choiceIndex; }
    if (this.detailSheetTitle === '菜单颜色来源' && choiceIndex >= 0) { this.menuColorMode = choiceIndex; }
    if (this.detailSheetTitle === '调色板风格' && choiceIndex >= 0) { this.menuPaletteStyleIndex = choiceIndex; }
    if (this.detailSheetTitle === '显示亮度视图' && choiceIndex >= 0) { this.brightnessViewMode = choiceIndex; }
    if (this.detailSheetTitle === '翻页动画' && choiceIndex >= 0) { this.onPageAnimationChange(choiceIndex); }
    if (this.detailSheetTitle === '翻页动画速度' && choiceIndex >= 0) { this.onAnimationSpeedChange(choiceIndex); }
    if (this.detailSheetTitle === '屏幕方向' && choiceIndex >= 0) { this.onScreenOrientationChange(choiceIndex.toString()); }
    if (this.detailSheetTitle === '保持屏幕常亮' && choiceIndex >= 0) {
      this.onKeepLightChange(['0', '60', '300', '600', '-1'][choiceIndex] ?? '0');
    }
    if (this.detailSheetTitle === '进度条行为' && choiceIndex >= 0) {
      this.onProgressBehaviorChange(choiceIndex === 1 ? 'chapter' : 'page');
    }
    if (this.detailSheetTitle === '点击图片行为' && choiceIndex >= 0) {
      this.onClickImageBehaviorChange(choiceIndex.toString());
    }
    if (choiceIndex >= 0 && this.detailSheetTitle === '页眉日间文字颜色') {
      this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, {
        tipHeaderColor: READER_INFO_COLOR_VALUES[choiceIndex] ?? 0
      }));
    }
    if (choiceIndex >= 0 && this.detailSheetTitle === '页眉夜间文字颜色') {
      this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, {
        tipHeaderColorNight: READER_INFO_COLOR_VALUES[choiceIndex] ?? 0
      }));
    }
    if (choiceIndex >= 0 && this.detailSheetTitle === '页脚日间文字颜色') {
      this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, {
        tipFooterColor: READER_INFO_COLOR_VALUES[choiceIndex] ?? 0
      }));
    }
    if (choiceIndex >= 0 && this.detailSheetTitle === '页脚夜间文字颜色') {
      this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, {
        tipFooterColorNight: READER_INFO_COLOR_VALUES[choiceIndex] ?? 0
      }));
    }
    if (choiceIndex >= 0 && this.detailSheetTitle === '分割线颜色') {
      const dividerColors: number[] = [-1, 0, -16777216, -8355712, -1, -65536, -16711936, -16776961];
      this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, {
        tipDividerColor: dividerColors[choiceIndex] ?? -1
      }));
    }
  }

  private isMenuSettingsEntryVisible(title: string): boolean {
    if (this.selectedMenuSettingsTab !== 0) { return true; }
    if (title === '调色板风格') {
      return this.menuBarStyleMode === 1 || (this.menuBarStyleMode === 2 && this.menuColorMode === 0);
    }
    if (title === '菜单颜色来源') { return this.menuBarStyleMode === 2; }
    if (title === '亮度条位置') { return this.brightnessViewMode === 2; }
    if (title === '种子色') { return this.menuBarStyleMode === 2 && this.menuColorMode === 0; }
    if (title === '菜单背景颜色' || title === '菜单容器颜色' || title === '菜单强调颜色') {
      return this.menuBarStyleMode === 2 && this.menuColorMode === 1;
    }
    if (title === '标题栏悬浮图标配置' || title === '标题栏悬浮图标位置' || title === '悬浮图标液态玻璃按钮') {
      return this.menuTitleIconsVisible;
    }
    if (title === '菜单栏边框宽度' || title === '菜单栏边框颜色') { return this.menuBorderEnabled; }
    return true;
  }

  private getInfoTipValue(slot: ReaderInfoSlot): number {
    if (slot === 'headerLeft') { return this.infoSettings.tipHeaderLeft; }
    if (slot === 'headerMiddle') { return this.infoSettings.tipHeaderMiddle; }
    if (slot === 'headerRight') { return this.infoSettings.tipHeaderRight; }
    if (slot === 'footerLeft') { return this.infoSettings.tipFooterLeft; }
    if (slot === 'footerMiddle') { return this.infoSettings.tipFooterMiddle; }
    return this.infoSettings.tipFooterRight;
  }

  private getInfoTipTemplate(slot: ReaderInfoSlot): string {
    if (slot === 'headerLeft') { return this.infoSettings.customTipHeaderLeft; }
    if (slot === 'headerMiddle') { return this.infoSettings.customTipHeaderMiddle; }
    if (slot === 'headerRight') { return this.infoSettings.customTipHeaderRight; }
    if (slot === 'footerLeft') { return this.infoSettings.customTipFooterLeft; }
    if (slot === 'footerMiddle') { return this.infoSettings.customTipFooterMiddle; }
    return this.infoSettings.customTipFooterRight;
  }

  private setInfoTipValue(settings: ReaderInfoSettings, slot: ReaderInfoSlot, value: number): ReaderInfoSettings {
    if (slot === 'headerLeft') { return updateReaderInfoSettings(settings, { tipHeaderLeft: value }); }
    if (slot === 'headerMiddle') { return updateReaderInfoSettings(settings, { tipHeaderMiddle: value }); }
    if (slot === 'headerRight') { return updateReaderInfoSettings(settings, { tipHeaderRight: value }); }
    if (slot === 'footerLeft') { return updateReaderInfoSettings(settings, { tipFooterLeft: value }); }
    if (slot === 'footerMiddle') { return updateReaderInfoSettings(settings, { tipFooterMiddle: value }); }
    return updateReaderInfoSettings(settings, { tipFooterRight: value });
  }

  private setInfoTipTemplate(settings: ReaderInfoSettings, slot: ReaderInfoSlot, value: string): ReaderInfoSettings {
    if (slot === 'headerLeft') { return updateReaderInfoSettings(settings, { customTipHeaderLeft: value }); }
    if (slot === 'headerMiddle') { return updateReaderInfoSettings(settings, { customTipHeaderMiddle: value }); }
    if (slot === 'headerRight') { return updateReaderInfoSettings(settings, { customTipHeaderRight: value }); }
    if (slot === 'footerLeft') { return updateReaderInfoSettings(settings, { customTipFooterLeft: value }); }
    if (slot === 'footerMiddle') { return updateReaderInfoSettings(settings, { customTipFooterMiddle: value }); }
    return updateReaderInfoSettings(settings, { customTipFooterRight: value });
  }

  private saveInfoTip(slot: ReaderInfoSlot, value: number, template: string = ''): void {
    let next: ReaderInfoSettings = this.infoSettings;
    const slots: ReaderInfoSlot[] = ['headerLeft', 'headerMiddle', 'headerRight', 'footerLeft', 'footerMiddle', 'footerRight'];
    if (value !== 0) {
      for (let index = 0; index < slots.length; index++) {
        const other = slots[index];
        if (other !== undefined && other !== slot && this.getInfoTipValue(other) === value) {
          next = this.setInfoTipValue(next, other, 0);
        }
      }
    }
    next = this.setInfoTipValue(next, slot, value);
    if (value === 18) { next = this.setInfoTipTemplate(next, slot, template); }
    this.onInfoSettingsChange(next);
  }

  private openInfoTipSheet(position: string): void {
    const isHeader = this.infoSubTab === 0;
    const slot: ReaderInfoSlot = isHeader
      ? (position === '左侧' ? 'headerLeft' : position === '中间' ? 'headerMiddle' : 'headerRight')
      : (position === '左侧' ? 'footerLeft' : position === '中间' ? 'footerMiddle' : 'footerRight');
    this.openDetailSheet(`${position}显示内容`, '选择此位置显示的信息类型');
    this.detailInfoSlot = slot;
    const value = this.getInfoTipValue(slot);
    const index = READ_INFO_TIP_VALUES.indexOf(value);
    this.detailSelectedOption = this.getInfoTipChoices()[index] ?? '无';
    this.detailCustomText = this.getInfoTipTemplate(slot);
  }

  private saveCustomInfoTip(): void {
    if (this.detailInfoSlot === undefined) { return; }
    this.saveInfoTip(this.detailInfoSlot, 18, this.detailCustomText);
    this.detailSheetVisible = false;
  }

  private getInfoModeLabel(): string {
    if (this.infoSubTab === 0) {
      return ['状态栏显示时隐藏', '显示', '隐藏'][this.infoSettings.headerMode] ?? '状态栏显示时隐藏';
    }
    return this.infoSettings.footerMode === 1 ? '隐藏' : '显示';
  }

  @Builder
  private informationSettingsContent() {
    Column() {
      Row() {
        Text('页眉').fontSize(11).fontColor(this.infoSubTab === 0 ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center).backgroundColor(this.infoSubTab === 0 ? '#454B62' : '#202127')
          .borderRadius(14).padding(8).onClick(() => this.infoSubTab = 0)
        Text('页脚').fontSize(11).fontColor(this.infoSubTab === 1 ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center).backgroundColor(this.infoSubTab === 1 ? '#454B62' : '#202127')
          .borderRadius(14).padding(8).margin({ left: 8 }).onClick(() => this.infoSubTab = 1)
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.app_padding')).width(18).height(18).fillColor('#D9DAE0')
        }.width(40).height(40).backgroundColor('#202127').borderRadius(10).margin({ left: 8 })
          .onClick(() => this.openDetailSheet('页边距', '页面内边距与正文留白设置'))
      }.width('100%').padding({ left: 14, right: 14, bottom: 8 })
      Scroll() {
        Column() {
          Text('内容').fontSize(12).fontColor('#AFC2FF').width('100%').padding({ left: 4, top: 6, bottom: 4 })
          ReaderInfoSettingRow({
            iconKind: 0,
            title: this.infoSubTab === 0 ? '页眉' : '页脚',
            choices: [this.getInfoModeLabel()],
            onSelect: (_index: number) => this.openDetailSheet('显示模式', '选择不显示、章节信息、阅读进度或自定义内容')
          })
          ForEach(['左侧', '中间', '右侧'], (position: string) => {
            ReaderInfoSettingRow({
              iconKind: position === '左侧' ? 1 : position === '中间' ? 2 : 3,
              title: position,
              choices: this.getInfoTipChoices(),
              selectedIndex: Math.max(0, READ_INFO_TIP_VALUES.indexOf(this.getInfoTipValue(
                this.infoSubTab === 0
                  ? (position === '左侧' ? 'headerLeft' : position === '中间' ? 'headerMiddle' : 'headerRight')
                  : (position === '左侧' ? 'footerLeft' : position === '中间' ? 'footerMiddle' : 'footerRight')
              ))),
              onSelect: (_index: number) => this.openInfoTipSheet(position)
            })
          }, (position: string) => position)
          Text('分隔线').fontSize(12).fontColor('#AFC2FF').width('100%').padding({ left: 4, top: 10, bottom: 4 })
          ReaderInfoSwitchRow({
            title: '显示分割线', detail: '显示页眉/页脚分隔线',
            checked: this.infoSubTab === 0 ? this.infoSettings.showHeaderLine : this.infoSettings.showFooterLine,
            onChange: (enabled: boolean) => this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, {
              showHeaderLine: this.infoSubTab === 0 ? enabled : this.infoSettings.showHeaderLine,
              showFooterLine: this.infoSubTab === 1 ? enabled : this.infoSettings.showFooterLine
            }))
          })
          ReaderInfoColorRow({ iconKind: 4, title: '分割线', detail: '页眉与页脚共用' })
            .onClick(() => this.openDetailSheet('分割线颜色', '选择页眉/页脚分割线颜色'))
          Text('文字字体').fontSize(12).fontColor('#AFC2FF')
            .width('100%').padding({ left: 4, top: 10, bottom: 4 })
          if (this.infoSubTab === 1) {
            MenuSettingSwitch({
              title: '应用页眉样式', detail: '页脚文字继承页眉样式', checked: this.infoSettings.applyHeaderStyle,
              onChange: (enabled: boolean) => this.onInfoSettingsChange(
                updateReaderInfoSettings(this.infoSettings, { applyHeaderStyle: enabled }))
            })
          }
          if (this.infoSubTab === 0 || !this.infoSettings.applyHeaderStyle) {
            ReaderInfoOptionRow({ iconKind: 5, title: '选择字体', detail: '选择字体' })
              .onClick(() => this.showNotMigrated('页眉/页脚字体选择'))
            ReaderInfoSliderRow({
              iconKind: 6, title: '字号',
              value: this.infoSubTab === 0 ? this.infoSettings.headerFontSize : this.infoSettings.footerFontSize,
              minValue: 0, maxValue: 100,
              onChange: (value: number) => this.onInfoSettingsChange(updateReaderInfoSettings(this.infoSettings, {
                headerFontSize: this.infoSubTab === 0 ? value : this.infoSettings.headerFontSize,
                footerFontSize: this.infoSubTab === 1 ? value : this.infoSettings.footerFontSize
              }))
            })
            ReaderInfoColorRow({ iconKind: 7, title: '日间文字颜色', detail: '阅读器日间样式' })
              .onClick(() => this.openDetailSheet(
                this.infoSubTab === 0 ? '页眉日间文字颜色' : '页脚日间文字颜色', '选择信息文字颜色'))
            ReaderInfoColorRow({ iconKind: 7, title: '夜间文字颜色', detail: '阅读器夜间样式' })
              .onClick(() => this.openDetailSheet(
                this.infoSubTab === 0 ? '页眉夜间文字颜色' : '页脚夜间文字颜色', '选择信息文字颜色'))
          }
          Text('页眉/页脚模式、提示内容、分隔线和字号会保存到阅读样式。字体文件选择与颜色取色器尚未迁移。')
            .fontSize(10).fontColor('#92949E').width('100%').textAlign(TextAlign.Center).padding(12)
        }.width('100%').padding({ left: 14, right: 14, bottom: 12 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').layoutWeight(1)
  }

  @Builder
  private moreSettingsContent() {
    Column() {
      Scroll() {
        Column() {
          Text('屏幕设置').fontSize(12).fontColor('#AFC2FF').width('100%').padding({ left: 4, top: 6, bottom: 4 })
          MenuSettingOption({ title: '屏幕方向', detail: '跟随系统 / 竖屏 / 横屏', migrated: true }).onClick(() => this.openDetailSheet('屏幕方向', '选择系统、竖屏或横屏'))
          MenuSettingOption({ title: '保持屏幕常亮', detail: this.getDetailChoices('保持屏幕常亮')[Math.max(0, ['0', '60', '300', '600', '-1'].indexOf(this.keepLight))] ?? '默认', migrated: true }).onClick(() => this.openDetailSheet('保持屏幕常亮', '设置阅读期间的屏幕超时'))
          MenuSettingSwitch({ title: '隐藏状态栏', detail: '沉浸式阅读', checked: this.hideStatusBar,
            onChange: (enabled: boolean) => this.onHideStatusBarChange(enabled) })
          MenuSettingSwitch({ title: '隐藏导航栏', detail: '沉浸式阅读', checked: this.hideNavigationBar,
            onChange: (enabled: boolean) => this.onHideNavigationBarChange(enabled) })
          MenuSettingSwitch({ title: '适配刘海屏', detail: '为显示缺口留出安全区域', checked: true }).onClick(() => this.showNotMigrated('适配刘海屏'))
          MenuSettingSwitch({ title: '正文行高适配', detail: '修正特殊排版行距', checked: true }).onClick(() => this.showNotMigrated('正文行高适配'))
          MenuSettingSwitch({ title: '适配特殊样式', detail: '保留书籍正文样式', checked: true }).onClick(() => this.showNotMigrated('适配特殊样式'))
          MenuSettingSwitch({ title: '中文排版', detail: '优化中文标点与排版', checked: true }).onClick(() => this.showNotMigrated('中文排版'))
          MenuSettingOption({ title: '护眼设置', detail: '护眼模式与色温', migrated: true })
            .onClick(() => this.openDetailSheet('护眼设置', '配置护眼模式、色温与日夜参数'))
          Text('翻页控制').fontSize(12).fontColor('#AFC2FF').width('100%').padding({ left: 4, top: 10, bottom: 4 })
          MenuSettingOption({ title: '横屏双页', detail: '关闭 / 左右双页' }).onClick(() => this.openDetailSheet('横屏双页', '单页或左右双页阅读'))
          MenuSettingOption({
            title: '进度条行为', detail: this.progressBehavior === 'chapter' ? '章节进度' : '页码进度', migrated: true
          }).onClick(() => this.openDetailSheet('进度条行为', '设置拖动进度条的定位方式'))
          MenuSettingSwitch({ title: '鼠标滚轮翻页', detail: '连接鼠标时用滚轮翻页', checked: false }).onClick(() => this.showNotMigrated('鼠标滚轮翻页'))
          MenuSettingSwitch({ title: '音量键翻页', detail: '按音量键切换页面', checked: this.volumeKeyPage,
            onChange: (enabled: boolean) => this.onVolumeKeyPageChange(enabled) })
          MenuSettingSwitch({ title: '朗读时允许音量键翻页', detail: '朗读期间使用音量键翻页', checked: false }).onClick(() => this.showNotMigrated('朗读时音量键翻页'))
          MenuSettingSwitch({ title: '长按按键翻页', detail: '长按音量键连续翻页', checked: this.keyPageOnLongPress,
            onChange: (enabled: boolean) => this.onKeyPageOnLongPressChange(enabled) })
          MenuSettingSwitch({ title: '下滑添加书签', detail: '下滑翻动当前页以添加或取消书签', checked: this.swipeToAddBookmark,
            onChange: (enabled: boolean) => this.onSwipeToAddBookmarkChange(enabled) })
          MenuSettingOption({ title: '书签标记', detail: this.bookmarkBadgeCustomPreview ? '自定义图片' : '默认' })
            .onClick(() => this.openDetailSheet('书签标记', '选择书签标记图片或恢复默认'))
          MenuSettingSlider({
            title: '书签标记大小', value: this.bookmarkBadgeSizePreview, minValue: 0, maxValue: 50,
            onChange: (value: number) => this.bookmarkBadgeSizePreview = value
          })
          Text('其他').fontSize(12).fontColor('#AFC2FF').width('100%').padding({ left: 4, top: 10, bottom: 4 })
          MenuSettingSwitch({ title: '进度条触感反馈', detail: '拖动时提供触觉反馈', checked: false }).onClick(() => this.showNotMigrated('进度条触感反馈'))
          MenuSettingSwitch({ title: '使用新版目录', detail: '使用新的目录面板', checked: true }).onClick(() => this.showNotMigrated('使用新版目录'))
          MenuSettingSlider({ title: '无目录书籍分段长度', value: this.maxLengthWithNoToc, minValue: 3000, maxValue: 100000, stepValue: 100,
            onChange: (value: number) => this.onMaxLengthWithNoTocChange(value) })
          MenuSettingSwitch({ title: '文字选择触感反馈', detail: '选择正文时提供触觉反馈', checked: false }).onClick(() => this.showNotMigrated('文字选择触感反馈'))
          MenuSettingSwitch({ title: '自动切换书源', detail: '当前书源失效时尝试其它书源', checked: false }).onClick(() => this.showNotMigrated('自动切换书源'))
          MenuSettingSwitch({ title: '换源结果应用于全部书籍', detail: '同步更新其它书籍的书源', checked: false }).onClick(() => this.showNotMigrated('换源结果应用于全部书籍'))
          MenuSettingSwitch({ title: '自动切换日夜模式提醒', detail: '提示切换阅读背景', checked: false }).onClick(() => this.showNotMigrated('自动切换日夜模式提醒'))
          MenuSettingSwitch({ title: '阅读位置锚点', detail: '跳转章节两次及以上后可返回原阅读位置', checked: this.readingAnchorEnabled,
            onChange: (enabled: boolean) => this.onReadingAnchorEnabledChange(enabled) })
          MenuSettingSwitch({ title: '朗读悬浮窗分离提醒', detail: '分离朗读控制时显示提醒', checked: true }).onClick(() => this.showNotMigrated('朗读悬浮窗分离提醒'))
          MenuSettingSwitch({ title: '允许选择正文', detail: '长按正文显示选择菜单', checked: true }).onClick(() => this.showNotMigrated('允许选择正文'))
          MenuSettingSwitch({ title: '滚动翻页无动画', detail: '关闭滚动翻页过渡动画',
            checked: this.noAnimScrollPage,
            onChange: (enabled: boolean) => this.onNoAnimScrollPageChange(enabled) })
          MenuSettingSwitch({ title: '优化正文渲染', detail: '使用优化渲染方式', checked: true }).onClick(() => this.showNotMigrated('优化正文渲染'))
          MenuSettingOption({ title: '点击图片行为', detail: this.getClickImageBehaviorLabel(), migrated: true })
            .onClick(() => this.openDetailSheet('点击图片行为', '选择正文图片的点击行为'))
          MenuSettingOption({ title: '点击区域配置', detail: '设置屏幕各区域的触摸动作', migrated: true }).onClick(() => this.openDetailSheet('点击区域配置', '配置九宫格点按动作，并应用到阅读界面。'))
          MenuSettingSwitch({ title: '禁用返回键', detail: '阻止阅读时返回键退出', checked: false }).onClick(() => this.showNotMigrated('禁用返回键'))
          MenuSettingOption({ title: '自定义翻页按键', detail: '配置键盘快捷键' }).onClick(() => this.openDetailSheet('自定义翻页按键', '按键映射面板尚未迁移'))
          MenuSettingOption({ title: '选中文字菜单', detail: '配置文本选择后的操作' }).onClick(() => this.openDetailSheet('选中文字菜单', '文本操作菜单配置尚未迁移'))
          MenuSettingSwitch({ title: '显示阅读标题补充信息', detail: '在阅读标题中显示附加信息', checked: false }).onClick(() => this.showNotMigrated('阅读标题补充信息'))
          MenuSettingSwitch({ title: '显示菜单图标', detail: '在阅读菜单中显示图标', checked: true }).onClick(() => this.showNotMigrated('显示菜单图标'))
          Text('未迁移项目保留原版设置入口；当前仅呈现设置界面，不执行对应业务。')
            .fontSize(10).fontColor('#92949E').width('100%').textAlign(TextAlign.Center).padding(12)
        }.width('100%').padding({ left: 14, right: 14, bottom: 12 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').layoutWeight(1)
  }

  private getTextMenuEntries(group: number): ReaderTextMenuEntry[] {
    return this.textMenuEntries.filter((item: ReaderTextMenuEntry) => item.group === group);
  }

  private moveTextMenuEntry(id: string, targetGroup: number): void {
    this.textMenuEntries = this.textMenuEntries.map((item: ReaderTextMenuEntry) =>
      item.id === id ? { id: item.id, title: item.title, group: targetGroup } : item
    );
  }

  private reorderTextMenuEntry(id: string, direction: number, group: number): void {
    const groupItems = this.getTextMenuEntries(group);
    const currentGroupIndex = groupItems.findIndex((item: ReaderTextMenuEntry) => item.id === id);
    const targetGroupIndex = currentGroupIndex + direction;
    if (currentGroupIndex < 0 || targetGroupIndex < 0 || targetGroupIndex >= groupItems.length) { return; }
    const currentIndex = this.textMenuEntries.findIndex((item: ReaderTextMenuEntry) => item.id === id);
    const targetItem = groupItems[targetGroupIndex];
    if (currentIndex < 0 || targetItem === undefined) { return; }
    const targetIndex = this.textMenuEntries.findIndex((item: ReaderTextMenuEntry) => item.id === targetItem.id);
    if (targetIndex < 0) { return; }
    const nextEntries = this.textMenuEntries.slice();
    const currentItem = nextEntries[currentIndex];
    const displacedItem = nextEntries[targetIndex];
    if (currentItem === undefined || displacedItem === undefined) { return; }
    nextEntries[currentIndex] = displacedItem;
    nextEntries[targetIndex] = currentItem;
    this.textMenuEntries = nextEntries;
  }

  private isTextMenuGroupExpanded(group: number): boolean {
    if (group === 0) { return this.primaryTextMenuExpanded; }
    if (group === 1) { return this.collapsedTextMenuExpanded; }
    return this.hiddenTextMenuExpanded;
  }

  private toggleTextMenuGroup(group: number): void {
    if (group === 0) { this.primaryTextMenuExpanded = !this.primaryTextMenuExpanded; }
    else if (group === 1) { this.collapsedTextMenuExpanded = !this.collapsedTextMenuExpanded; }
    else { this.hiddenTextMenuExpanded = !this.hiddenTextMenuExpanded; }
  }

  @Builder
  private readerTextMenuIcon(id: string) {
    if (id === 'menu_copy') {
      Image($r('app.media.reader_menu_copy')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_share_str') {
      Image($r('app.media.reader_menu_share')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_browser') {
      Image($r('app.media.reader_menu_language')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_aloud') {
      Image($r('app.media.reader_menu_volume_up')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_bookmark') {
      Image($r('app.media.reader_menu_bookmark')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_mark') {
      Image($r('app.media.reader_menu_border_color')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_dict') {
      Image($r('app.media.reader_menu_book')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_replace') {
      Image($r('app.media.reader_menu_find_replace')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_edit') {
      Image($r('app.media.reader_menu_edit')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_ai_clean' || id === 'menu_ai_rewrite') {
      Image($r('app.media.reader_menu_smart_toy')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_search_content') {
      Image($r('app.media.reader_menu_search')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_insert_bgm_before') {
      Image($r('app.media.reader_menu_queue_music')).width(18).height(18).fillColor('#D9DAE0')
    } else if (id === 'menu_insert_bgm_after') {
      Image($r('app.media.reader_menu_playlist_add')).width(18).height(18).fillColor('#D9DAE0')
    } else {
      Blank().width(18).height(18)
    }
  }

  private openDetailSheet(title: string, description: string): void {
    this.detailSheetTitle = title;
    this.detailSheetDescription = description;
    this.detailInfoSlot = undefined;
    const choices = this.getDetailChoices(title);
    if (title === '页边距') {
      this.detailSelectedOption = '正文';
    } else if (title === '显示模式') {
      this.detailSelectedOption = this.infoSubTab === 0
        ? (choices[this.infoSettings.headerMode] ?? choices[0] ?? '')
        : (this.infoSettings.footerMode === 1 ? choices[1] ?? '' : choices[0] ?? '');
    } else if (title === '翻页动画') {
      this.detailSelectedOption = choices[this.pageAnimationIndex] ?? choices[0] ?? '';
    } else if (title === '翻页动画速度') {
      this.detailSelectedOption = choices[this.animationSpeedIndex] ?? choices[2] ?? '';
    } else if (title === '进度条行为') {
      this.detailSelectedOption = this.progressBehavior === 'chapter'
        ? (choices[1] ?? choices[0] ?? '') : (choices[0] ?? '');
    } else if (title === '屏幕方向') {
      const orientationIndex = Math.max(0, Math.min(5, Number.parseInt(this.screenOrientation, 10)));
      this.detailSelectedOption = choices[orientationIndex] ?? choices[0] ?? '';
    } else if (title === '保持屏幕常亮') {
      this.detailSelectedOption = choices[Math.max(0, ['0', '60', '300', '600', '-1'].indexOf(this.keepLight))] ?? choices[0] ?? '';
    } else if (title === '点击图片行为') {
      const behaviorIndex = Math.max(0, ['0', '1', '2', '3', '4'].indexOf(this.clickImageBehavior));
      this.detailSelectedOption = choices[behaviorIndex] ?? choices[0] ?? '';
    } else if (title === '分割线颜色' || title.endsWith('文字颜色')) {
      const values: number[] = title === '分割线颜色'
        ? [-1, 0, -16777216, -8355712, -1, -65536, -16711936, -16776961]
        : READER_INFO_COLOR_VALUES;
      const configuredValue = this.getReaderInfoColorValue(title);
      const selectedIndex = values.indexOf(configuredValue);
      this.detailSelectedOption = choices[selectedIndex >= 0 ? selectedIndex : 0] ?? choices[0] ?? '';
    } else {
      this.detailSelectedOption = choices[0] ?? '';
    }
    this.detailSheetVisible = true;
  }

  private showEyeProtectionTimePicker(isStart: boolean): void {
    const current = isStart ? this.eyeProtectionStartTime : this.eyeProtectionEndTime;
    const parts: string[] = current.split(':');
    const hour: number = Number(parts[0]);
    const minute: number = Number(parts[1]);
    const selected: Date = new Date();
    selected.setHours(hour, minute, 0, 0);
    this.getUIContext().showTimePickerDialog({
      selected: selected,
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult): void => {
        const hourText = value.hour < 10 ? `0${value.hour}` : `${value.hour}`;
        const minuteText = value.minute < 10 ? `0${value.minute}` : `${value.minute}`;
        const time = `${hourText}:${minuteText}`;
        if (isStart) {
          this.onEyeProtectionStartTimeChange(time);
        } else {
          this.onEyeProtectionEndTimeChange(time);
        }
      }
    });
  }

  private getPageAnimationLabel(): string {
    const choices = this.getDetailChoices('翻页动画');
    return choices[this.pageAnimationIndex] ?? choices[0] ?? '覆盖';
  }

  private getAnimationSpeedLabel(): string {
    const choices = this.getDetailChoices('翻页动画速度');
    return choices[this.animationSpeedIndex] ?? choices[2] ?? '适中';
  }

  private getDetailChoices(title: string): string[] {
    if (title === '工具栏样式') { return ['系统', '跟随阅读背景', '自定义']; }
    if (title === '调色板风格') { return ['跟随系统', '柔和', '中性', '鲜艳', '表现力', '彩虹', '水果拼盘', '单色', '仿真', '内容取色']; }
    if (title === '菜单颜色来源') { return ['种子色', '自定义主题色']; }
    if (title === '显示亮度视图') { return ['关闭', '横排', '竖排']; }
    if (title === '亮度条位置') { return ['左侧', '右侧']; }
    if (title === '标题栏模式') { return ['完整信息', '仅标题', '标题与章节']; }
    if (title.includes('图标样式')) { return ['纯色', '色调', '描边']; }
    if (title.includes('模糊样式')) { return ['纯色', '渐变']; }
    if (title === '翻页动画') { return ['覆盖', '滑动', '仿真', '滚动', '淡入淡出', '无动画']; }
    if (title === '翻页动画速度') { return ['极速', '快速', '适中', '优雅']; }
    if (title === '显示模式') {
      return this.infoSubTab === 0 ? ['状态栏显示时隐藏', '显示', '隐藏'] : ['显示', '隐藏'];
    }
    if (title === '页眉日间文字颜色' || title === '页眉夜间文字颜色' ||
      title === '页脚日间文字颜色' || title === '页脚夜间文字颜色') {
      return READER_INFO_COLOR_CHOICES;
    }
    if (title === '分割线颜色') {
      return ['默认分隔线', '跟随正文', '黑色', '灰色', '白色', '红色', '绿色', '蓝色'];
    }
    if (title === '左侧显示内容' || title === '中间显示内容' || title === '右侧显示内容') {
      return this.getInfoTipChoices();
    }
    if (title === '屏幕方向') { return ['跟随系统', '竖屏', '横屏', '传感器自动', '反向竖屏', '反向横屏']; }
    if (title === '保持屏幕常亮') { return ['默认', '1分钟', '5分钟', '10分钟', '常亮']; }
    if (title === '横屏双页') { return ['关闭', '左右双页']; }
    if (title === '进度条行为') { return ['页码进度', '章节进度']; }
    if (title === '点击图片行为') { return ['新版行为', '预览图片', '经典', '禁用点击', '双击']; }
    if (title === '信息字体' || title === '选择字体') { return ['默认字体', '系统字体', '选择本地字体']; }
    if (title === '分割线颜色' || title === '文字颜色' || title === '信息颜色') {
      return ['跟随正文', '默认颜色', '自定义颜色'];
    }
    if (title === '自定义提示') { return ['书名', '章节名', '页码', '时间', '自定义文本']; }
    return [];
  }

  private getClickImageBehaviorLabel(): string {
    const choices = this.getDetailChoices('点击图片行为');
    const behaviorIndex = Math.max(0, ['0', '1', '2', '3', '4'].indexOf(this.clickImageBehavior));
    return choices[behaviorIndex] ?? choices[2] ?? '经典';
  }

  private getReaderInfoColorValue(title: string): number {
    if (title === '页眉日间文字颜色') { return this.infoSettings.tipHeaderColor; }
    if (title === '页眉夜间文字颜色') { return this.infoSettings.tipHeaderColorNight; }
    if (title === '页脚日间文字颜色') { return this.infoSettings.tipFooterColor; }
    if (title === '页脚夜间文字颜色') { return this.infoSettings.tipFooterColorNight; }
    return this.infoSettings.tipDividerColor;
  }

  private getPaddingValue(side: string): number {
    if (this.detailSelectedOption === '页眉') {
      if (side === '上') { return this.paddingSettings.headerPaddingTop; }
      if (side === '下') { return this.paddingSettings.headerPaddingBottom; }
      if (side === '左') { return this.paddingSettings.headerPaddingLeft; }
      return this.paddingSettings.headerPaddingRight;
    }
    if (this.detailSelectedOption === '页脚') {
      if (side === '上') { return this.paddingSettings.footerPaddingTop; }
      if (side === '下') { return this.paddingSettings.footerPaddingBottom; }
      if (side === '左') { return this.paddingSettings.footerPaddingLeft; }
      return this.paddingSettings.footerPaddingRight;
    }
    if (side === '上') { return this.paddingSettings.paddingTop; }
    if (side === '下') { return this.paddingSettings.paddingBottom; }
    if (side === '左') { return this.paddingSettings.paddingLeft; }
    return this.paddingSettings.paddingRight;
  }

  private updatePadding(side: string, value: number): void {
    const next: ReaderPaddingSettings = copyReaderPaddingSettings(this.paddingSettings);
    if (this.detailSelectedOption === '页眉') {
      if (side === '上') { next.headerPaddingTop = value; }
      else if (side === '下') { next.headerPaddingBottom = value; }
      else if (side === '左') { next.headerPaddingLeft = value; }
      else { next.headerPaddingRight = value; }
    } else if (this.detailSelectedOption === '页脚') {
      if (side === '上') { next.footerPaddingTop = value; }
      else if (side === '下') { next.footerPaddingBottom = value; }
      else if (side === '左') { next.footerPaddingLeft = value; }
      else { next.footerPaddingRight = value; }
    } else {
      if (side === '上') { next.paddingTop = value; }
      else if (side === '下') { next.paddingBottom = value; }
      else if (side === '左') { next.paddingLeft = value; }
      else { next.paddingRight = value; }
    }
    this.onPaddingSettingsChange(next);
  }

  private getInfoTipChoices(): string[] {
    return ['无', '书名', '标题', '带箭头的标题（系统字体）', '带箭头的标题', '时间', '电量', '经典电量',
      '电量内显', '仅电量图标', '电量%', '页数', '进度(%)', '进度(xx/yyy)', '页数及进度', '时间及电量',
      '经典电量及时间', '时间及电量%', '全文页数', '全文页数及进度', '自定义'];
  }

  private showNotMigrated(title: string): void {
    this.openDetailSheet(title, '此选项的原版 UI 已呈现；实际设置逻辑尚未迁移。');
  }

  private settingsSheetHeight(): string {
    if (this.selectedSettingsTab === 0) { return '46%'; }
    if (this.selectedSettingsTab === 1) { return '68%'; }
    if (this.selectedSettingsTab === 2) { return '70%'; }
    return '86%';
  }

  private settingsSheetWidth(): string {
    return this.selectedSettingsTab === 3 ? '100%' : '88%';
  }

  @Builder
  private detailSheet() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#99000000').onClick(() => this.detailSheetVisible = false)
      Column() {
        Row().width(32).height(4).backgroundColor('#C5C6CD').borderRadius(4).margin({ top: 10, bottom: 14 })
        Row() {
          Text(this.detailSheetTitle).fontSize(17).fontColor('#E5E6EB').layoutWeight(1)
          Text('关闭').fontSize(13).fontColor('#C6D3FF').onClick(() => this.detailSheetVisible = false)
        }.width('100%').padding({ left: 18, right: 18, bottom: 12 })
        Text(this.detailSheetDescription).fontSize(13).fontColor('#D3D4DC').width('100%').padding({ left: 18, right: 18, top: 10, bottom: 18 })
        if (this.detailSheetTitle === '自定义阅读背景') {
          Scroll() {
            Column() {
              Row() {
                ForEach(['编辑', '删除', '恢复', '导入', '导出'], (label: string) => {
                  Text(label).fontSize(10).fontColor('#D9DAE0').layoutWeight(1).textAlign(TextAlign.Center)
                    .padding({ top: 10, bottom: 10 }).backgroundColor('#292A31').borderRadius(8)
                    .margin({ right: 4 }).onClick(() => this.openDetailSheet(label, `${label}背景功能尚未迁移`))
                }, (label: string) => label)
              }.width('100%').padding({ bottom: 8 })
              MenuSettingSwitch({ title: '深色状态栏图标', detail: '调整系统状态栏图标颜色', checked: false })
              MenuSettingOption({ title: '背景颜色', detail: '日间颜色 / 夜间颜色' })
                .onClick(() => this.openDetailSheet('背景颜色', '选择日间或夜间背景颜色'))
              MenuSettingOption({ title: '背景图片', detail: '选择日间图片 / 夜间图片 / 清除' })
                .onClick(() => this.openDetailSheet('背景图片', '选择或清除日间、夜间背景图片'))
              MenuSettingSlider({ title: '背景透明度', value: 100, minValue: 0, maxValue: 100 })
              Text('文件选择与样式保存尚未迁移。').fontSize(10).fontColor('#92949E').width('100%').padding(10)
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.height(360).scrollBar(BarState.Off)
        } else if (this.detailSheetTitle === '排版设置') {
          Column() {
            Row() {
              ForEach(['正文', '标题', '页眉', '页脚'], (label: string) => {
                Text(label).fontSize(11).fontColor('#D9DAE0').layoutWeight(1).textAlign(TextAlign.Center)
                  .padding(9).backgroundColor('#292A31').borderRadius(8).margin({ right: 4 })
                  .onClick(() => this.detailSelectedOption = label)
              }, (label: string) => label)
            }.width('100%').padding({ left: 18, right: 18, bottom: 8 })
            MenuSettingOption({ title: '字体', detail: '选择字体' }).onClick(() => this.openDetailSheet('选择字体', '选择阅读文字字体'))
            MenuSettingSlider({ title: '字号', value: this.fontSize, minValue: 5, maxValue: 50 })
            MenuSettingOption({ title: '颜色', detail: '日间 / 夜间' }).onClick(() => this.openDetailSheet('信息颜色', '选择文字颜色'))
            MenuSettingOption({ title: '效果', detail: '阴影 / 下划线 / 高亮规则' }).onClick(() => this.openDetailSheet('文字效果', '配置文字效果'))
            MenuSettingOption({ title: '间距', detail: '缩进 / 字距 / 行高 / 段距' }).onClick(() => this.openDetailSheet('正文间距', '配置正文间距'))
            MenuSettingOption({ title: '文字对齐', detail: '两端对齐 / 底部对齐' }).onClick(() => this.openDetailSheet('文字对齐', '选择正文对齐方式'))
            Text('除当前字号外，其余排版设置尚未接入。').fontSize(10).fontColor('#92949E').width('100%').padding(12)
          }.width('100%').padding({ bottom: 16 })
        } else if (this.detailSheetTitle === '选中文字菜单') {
          Scroll() {
            Column() {
              MenuSettingSwitch({
                title: '展开文字菜单', detail: '折叠菜单项是否多行展开',
                checked: this.expandTextMenuPreview,
                onChange: (enabled: boolean) => this.expandTextMenuPreview = enabled
              })
              MenuSettingSwitch({
                title: '显示菜单图标', detail: '在文字菜单操作项旁显示图标',
                checked: this.showTextMenuIconsPreview,
                onChange: (enabled: boolean) => this.showTextMenuIconsPreview = enabled
              })
              Row() {
                Text('主菜单').fontSize(13).fontColor('#E5E6EB').layoutWeight(1)
                Text(`${this.getTextMenuEntries(0).length}`).fontSize(11).fontColor('#AEB0B9')
                Image($r('app.media.profile_expand_more')).width(18).height(18).fillColor('#AEB0B9')
                  .rotate({ angle: this.primaryTextMenuExpanded ? 180 : 0 }).margin({ left: 8 })
              }.width('100%').padding(12).backgroundColor('#292A31').borderRadius(10).margin({ top: 8, bottom: 5 })
                .onClick(() => this.toggleTextMenuGroup(0))
              if (this.primaryTextMenuExpanded) {
                ForEach(this.getTextMenuEntries(0), (item: ReaderTextMenuEntry) => {
                  Row() {
                    if (this.showTextMenuIconsPreview) { this.readerTextMenuIcon(item.id) }
                    Text(item.title).fontSize(12).fontColor('#E5E6EB').layoutWeight(1).margin({ left: 8 })
                    Image($r('app.media.reader_reorder_up')).width(16).height(16).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.reorderTextMenuEntry(item.id, -1, 0))
                    Image($r('app.media.reader_reorder_down')).width(16).height(16).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.reorderTextMenuEntry(item.id, 1, 0))
                    Image($r('app.media.app_reduce')).width(17).height(17).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.moveTextMenuEntry(item.id, 1))
                    Image($r('app.media.reader_visibility_off')).width(17).height(17).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.moveTextMenuEntry(item.id, 2))
                  }.width('100%').padding({ left: 10, right: 5, top: 5, bottom: 5 })
                    .backgroundColor('#202127').borderRadius(9).margin({ bottom: 4 })
                }, (item: ReaderTextMenuEntry) => item.id)
              }
              Row() {
                Text('折叠菜单').fontSize(13).fontColor('#E5E6EB').layoutWeight(1)
                Text(`${this.getTextMenuEntries(1).length}`).fontSize(11).fontColor('#AEB0B9')
                Image($r('app.media.profile_expand_more')).width(18).height(18).fillColor('#AEB0B9')
                  .rotate({ angle: this.collapsedTextMenuExpanded ? 180 : 0 }).margin({ left: 8 })
              }.width('100%').padding(12).backgroundColor('#292A31').borderRadius(10).margin({ top: 5, bottom: 5 })
                .onClick(() => this.toggleTextMenuGroup(1))
              if (this.collapsedTextMenuExpanded) {
                ForEach(this.getTextMenuEntries(1), (item: ReaderTextMenuEntry) => {
                  Row() {
                    if (this.showTextMenuIconsPreview) { this.readerTextMenuIcon(item.id) }
                    Text(item.title).fontSize(12).fontColor('#E5E6EB').layoutWeight(1).margin({ left: 8 })
                    Image($r('app.media.reader_reorder_up')).width(16).height(16).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.reorderTextMenuEntry(item.id, -1, 1))
                    Image($r('app.media.reader_reorder_down')).width(16).height(16).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.reorderTextMenuEntry(item.id, 1, 1))
                    Image($r('app.media.app_add')).width(17).height(17).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.moveTextMenuEntry(item.id, 0))
                    Image($r('app.media.reader_visibility_off')).width(17).height(17).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.moveTextMenuEntry(item.id, 2))
                  }.width('100%').padding({ left: 10, right: 5, top: 5, bottom: 5 })
                    .backgroundColor('#202127').borderRadius(9).margin({ bottom: 4 })
                }, (item: ReaderTextMenuEntry) => item.id)
              }
              Row() {
                Text('隐藏项目').fontSize(13).fontColor('#E5E6EB').layoutWeight(1)
                Text(`${this.getTextMenuEntries(2).length}`).fontSize(11).fontColor('#AEB0B9')
                Image($r('app.media.profile_expand_more')).width(18).height(18).fillColor('#AEB0B9')
                  .rotate({ angle: this.hiddenTextMenuExpanded ? 180 : 0 }).margin({ left: 8 })
              }.width('100%').padding(12).backgroundColor('#292A31').borderRadius(10).margin({ top: 5, bottom: 5 })
                .onClick(() => this.toggleTextMenuGroup(2))
              if (this.hiddenTextMenuExpanded) {
                ForEach(this.getTextMenuEntries(2), (item: ReaderTextMenuEntry) => {
                  Row() {
                    if (this.showTextMenuIconsPreview) { this.readerTextMenuIcon(item.id) }
                    Text(item.title).fontSize(12).fontColor('#E5E6EB').layoutWeight(1).margin({ left: 8 })
                    Image($r('app.media.app_add')).width(17).height(17).fillColor('#C8CAD2')
                      .padding(5).onClick(() => this.moveTextMenuEntry(item.id, 0))
                  }.width('100%').padding({ left: 10, right: 5, top: 5, bottom: 5 })
                    .backgroundColor('#202127').borderRadius(9).margin({ bottom: 4 })
                }, (item: ReaderTextMenuEntry) => item.id)
              }
              Column() {
                Text('Android 系统提供的文字处理应用项暂未迁移。')
                  .fontSize(11).fontColor('#AEB0B9').width('100%')
                Text('当前列表顺序、分组与开关均为预览，保存功能尚未迁移。')
                  .fontSize(10).fontColor('#92949E').width('100%').margin({ top: 5 })
              }.padding(12).backgroundColor('#202127').borderRadius(10).margin({ top: 8 })
              Row() {
                Blank()
                Text('保存').fontSize(13).fontColor('#101116')
                  .padding({ left: 20, right: 20, top: 10, bottom: 10 })
                  .backgroundColor('#C6D3FF').borderRadius(18)
                  .onClick(() => this.onUnavailableAction('选中文字菜单配置尚未保存'))
              }.width('100%').padding({ top: 10 })
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.layoutWeight(1).scrollBar(BarState.Off)
        } else if (this.detailSheetTitle === '点击区域配置') {
          Scroll() {
            Column() {
              Text('点击阅读页面的分区，再选择该区域的动作。')
                .fontSize(12).fontColor('#AEB0B9').width('100%').padding({ top: 4, bottom: 10 })
              ForEach([0, 1, 2], (rowIndex: number) => {
                Row() {
                  ForEach([0, 1, 2], (columnIndex: number) => {
                    Column() {
                      Text(CLICK_REGION_NAMES[rowIndex * 3 + columnIndex] ?? '')
                        .fontSize(10).fontColor('#AEB0B9').margin({ bottom: 4 })
                      Text(this.clickRegionActions[rowIndex * 3 + columnIndex] ?? '无操作')
                        .fontSize(12).fontColor('#E5E6EB').textAlign(TextAlign.Center)
                    }.layoutWeight(1).height(58).justifyContent(FlexAlign.Center)
                      .backgroundColor(this.selectedClickRegionIndex === rowIndex * 3 + columnIndex ? '#454B62' : '#292A31')
                      .borderRadius(10).margin({ right: columnIndex < 2 ? 6 : 0, bottom: 6 })
                      .onClick(() => this.selectedClickRegionIndex = rowIndex * 3 + columnIndex)
                  }, (columnIndex: number) => `column-${columnIndex}`)
                }.width('100%')
              }, (rowIndex: number) => `row-${rowIndex}`)
              Text(`设置${CLICK_REGION_NAMES[this.selectedClickRegionIndex] ?? ''}区域动作`)
                .fontSize(12).fontColor('#AFC2FF').width('100%').padding({ top: 8, bottom: 6 })
              ForEach(READER_CLICK_REGION_ACTIONS, (action: string) => {
                Row() {
                  Text(action).fontSize(13).fontColor('#E5E6EB').layoutWeight(1)
                  if ((this.clickRegionActions[this.selectedClickRegionIndex] ?? '') === action) {
                    Image($r('app.media.app_check')).width(18).height(18).fillColor('#AFC2FF')
                  }
                }.width('100%').padding(10).backgroundColor(
                  (this.clickRegionActions[this.selectedClickRegionIndex] ?? '') === action ? '#34394C' : '#202127'
                ).borderRadius(9).margin({ bottom: 5 }).onClick(() => {
                  const nextActions: string[] = this.clickRegionActions.map((current: string, index: number) =>
                    index === this.selectedClickRegionIndex ? action : current
                  );
                  this.onClickRegionActionsChange(nextActions);
                })
              }, (action: string) => action)
              Text('动作会立即保存，并应用到阅读页对应分区。未迁移的动作会明确提示。')
                .fontSize(10).fontColor('#92949E').width('100%').textAlign(TextAlign.Center).padding(12)
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.layoutWeight(1).scrollBar(BarState.Off)
        } else if (this.detailSheetTitle === '自定义翻页按键') {
          Scroll() {
            Column() {
              TextInput({ text: this.previousPageKeys, placeholder: '输入上一页按键码，多个按键用逗号分隔' })
                .fontSize(13).fontColor('#E5E6EB').placeholderColor('#92949E')
                .backgroundColor('#292A31').borderRadius(10).padding(12)
                .onChange((value: string) => this.previousPageKeys = value)
              TextInput({ text: this.nextPageKeys, placeholder: '输入下一页按键码，多个按键用逗号分隔' })
                .fontSize(13).fontColor('#E5E6EB').placeholderColor('#92949E')
                .backgroundColor('#292A31').borderRadius(10).padding(12).margin({ top: 10 })
                .onChange((value: string) => this.nextPageKeys = value)
              Text('按键设置支持输入按键码；确定后会应用上一页和下一页快捷键。')
                .fontSize(11).fontColor('#AEB0B9').width('100%').padding({ top: 10, bottom: 14 })
              Row() {
                Text('重置').fontSize(13).fontColor('#D3D4DC').padding({ left: 18, right: 18, top: 10, bottom: 10 })
                  .backgroundColor('#292A31').borderRadius(18)
                  .onClick(() => { this.previousPageKeys = ''; this.nextPageKeys = ''; })
                Blank()
                Text('确定').fontSize(13).fontColor('#101116').padding({ left: 20, right: 20, top: 10, bottom: 10 })
                  .backgroundColor('#C6D3FF').borderRadius(18)
                  .onClick(() => this.onUnavailableAction('翻页按键设置尚未保存'))
              }.width('100%')
              Text('当前字段仅供界面预览，设置尚未保存或接入物理按键事件。')
                .fontSize(10).fontColor('#92949E').width('100%').textAlign(TextAlign.Center).padding(12)
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.layoutWeight(1).scrollBar(BarState.Off)
        } else if (this.detailSheetTitle === '护眼设置') {
          Scroll() {
            Column() {
              MenuSettingSwitch({
                title: '启用护眼模式', detail: '使用暖色调降低蓝光',
                checked: this.eyeProtectionEnabled,
                onChange: (enabled: boolean) => this.onEyeProtectionEnabledChange(enabled)
              })
              MenuSettingSwitch({
                title: '深色模式时自动开启', detail: '跟随阅读界面的深色/浅色模式自动切换',
                checked: this.eyeProtectionAutoNight,
                onChange: (enabled: boolean) => this.onEyeProtectionAutoNightChange(enabled)
              })
              if (this.eyeProtectionEnabled || this.eyeProtectionAutoNight) {
                MenuSettingSlider({
                  title: '护眼强度', value: this.eyeProtectionIntensity, minValue: 0, maxValue: 100,
                  onChange: (value: number) => this.onEyeProtectionIntensityChange(value)
                })
                MenuSettingSwitch({
                  title: '定时开启', detail: '仅在设定的时间段内生效',
                  checked: this.eyeProtectionSchedule,
                  onChange: (enabled: boolean) => this.onEyeProtectionScheduleChange(enabled)
                })
                if (this.eyeProtectionSchedule) {
                  Row() {
                    Text('开始时间').fontSize(12).fontColor('#D9DAE0')
                    Blank()
                    Text(this.eyeProtectionStartTime).fontSize(12).fontColor('#C6D3FF')
                    Text('›').fontSize(20).fontColor('#92949E').margin({ left: 8 })
                  }.width('100%').padding({ top: 10, bottom: 6 }).onClick(() => this.showEyeProtectionTimePicker(true))
                  Row() {
                    Text('结束时间').fontSize(12).fontColor('#D9DAE0')
                    Blank()
                    Text(this.eyeProtectionEndTime).fontSize(12).fontColor('#C6D3FF')
                    Text('›').fontSize(20).fontColor('#92949E').margin({ left: 8 })
                  }.width('100%').padding({ top: 6, bottom: 8 }).onClick(() => this.showEyeProtectionTimePicker(false))
                }
              }
              Text('设置会立即保存并应用到阅读页面；定时支持跨越午夜。')
                .fontSize(10).fontColor('#92949E').width('100%').textAlign(TextAlign.Center).padding(12)
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.layoutWeight(1).scrollBar(BarState.Off)
        } else if (this.detailSheetTitle === '书签标记') {
          Column() {
            Text('当前标记').fontSize(12).fontColor('#AFC2FF').width('100%').padding({ top: 4, bottom: 8 })
            Row() {
              Stack({ alignContent: Alignment.Center }) {
                Image($r('app.media.app_bookmark')).width(Math.max(8, this.bookmarkBadgeSizePreview))
                  .height(Math.max(8, this.bookmarkBadgeSizePreview)).fillColor('#C6D3FF')
              }.width(62).height(62).backgroundColor('#292A31').borderRadius(12)
              Column() {
                Text(this.bookmarkBadgeCustomPreview ? '自定义图片' : '默认')
                  .fontSize(14).fontColor('#E5E6EB')
                Text('角标大小：' + this.bookmarkBadgeSizePreview.toString() + 'dp')
                  .fontSize(11).fontColor('#AEB0B9').margin({ top: 5 })
              }.alignItems(HorizontalAlign.Start).margin({ left: 12 })
              Blank()
            }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
            MenuSettingOption({ title: '选择书签标记图片', detail: '使用本地图片作为阅读页角标' })
              .onClick(() => this.onUnavailableAction('图片选择与角标保存尚未迁移'))
            if (this.bookmarkBadgeCustomPreview) {
              MenuSettingOption({ title: '恢复默认', detail: '移除自定义角标图片' })
                .onClick(() => this.bookmarkBadgeCustomPreview = false)
            }
            MenuSettingSlider({
              title: '角标大小（dp）', value: this.bookmarkBadgeSizePreview, minValue: 0, maxValue: 50,
              onChange: (value: number) => this.bookmarkBadgeSizePreview = value
            })
            Text('图片选择、恢复和角标大小保存尚未迁移；当前只预览默认标记及大小。')
              .fontSize(10).fontColor('#92949E').width('100%').padding(12)
          }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
        } else if (this.detailSheetTitle === '页边距') {
          Column() {
            Row() {
              ForEach(['正文', '页眉', '页脚'], (label: string) => {
                Text(label).fontSize(11).fontColor('#D9DAE0').layoutWeight(1).textAlign(TextAlign.Center)
                  .padding(9).backgroundColor('#292A31').borderRadius(8).margin({ right: 4 })
                  .onClick(() => this.detailSelectedOption = label)
              }, (label: string) => label)
            }.width('100%').padding({ bottom: 8 })
            MenuSettingSlider({ title: '上边距', value: this.getPaddingValue('上'), minValue: 0,
              maxValue: this.detailSelectedOption === '正文' ? 200 : 300,
              onChange: (value: number) => this.updatePadding('上', value) })
            MenuSettingSlider({ title: '下边距', value: this.getPaddingValue('下'), minValue: 0,
              maxValue: this.detailSelectedOption === '正文' ? 200 : 300,
              onChange: (value: number) => this.updatePadding('下', value) })
            MenuSettingSlider({ title: '左边距', value: this.getPaddingValue('左'), minValue: 0,
              maxValue: this.detailSelectedOption === '正文' ? 200 : 300,
              onChange: (value: number) => this.updatePadding('左', value) })
            MenuSettingSlider({ title: '右边距', value: this.getPaddingValue('右'), minValue: 0,
              maxValue: this.detailSelectedOption === '正文' ? 200 : 300,
              onChange: (value: number) => this.updatePadding('右', value) })
            Text('边距会立即保存并应用到阅读页。').fontSize(10).fontColor('#92949E').width('100%').padding(12)
          }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
        } else {
          Scroll() {
            Column() {
              ForEach(this.getDetailChoices(this.detailSheetTitle), (choice: string) => {
                Row() {
                  Text(choice).fontSize(13).fontColor('#E5E6EB').layoutWeight(1)
                  if (this.detailSelectedOption === choice) {
                    Image($r('app.media.app_check')).width(18).height(18).fillColor('#AFC2FF')
                  }
                }.width('100%').padding(12).backgroundColor(
                  this.detailSelectedOption === choice ? '#34394C' : '#202127'
                ).borderRadius(10).margin({ bottom: 6 }).onClick(() => this.applyDetailChoicePreview(choice))
              }, (choice: string) => choice)
              if (this.detailInfoSlot !== undefined && this.detailSelectedOption === '自定义') {
                TextInput({ text: this.detailCustomText, placeholder: '输入自定义提示内容' })
                  .fontSize(13).fontColor('#E5E6EB').placeholderColor('#92949E')
                  .backgroundColor('#292A31').borderRadius(10).padding(12)
                  .onChange((value: string) => this.detailCustomText = value)
                Text('可用变量：{BookName}、{ChapterTitle}、{Time}、{BatteryPercent}、{ChapterIndex}、{ChapterSize}、{PageIndex}、{PageSize}、{PageRemaining}、{ReadProgress}、{FullPageIndex}、{FullPageSize}')
                  .fontSize(10).fontColor('#92949E').width('100%').padding({ top: 8, bottom: 8 })
                Text('保存').fontSize(13).fontColor('#101116').padding({ left: 18, right: 18, top: 9, bottom: 9 })
                  .backgroundColor('#C6D3FF').borderRadius(18).alignSelf(ItemAlign.End)
                  .onClick(() => this.saveCustomInfoTip())
              }
              if (this.getDetailChoices(this.detailSheetTitle).length === 0) {
                Text('此配置项的实际操作尚未迁移。').fontSize(12).fontColor('#A9ABB5').width('100%').padding(12)
              }
              Text(this.detailSheetTitle === '翻页动画' || this.detailSheetTitle === '翻页动画速度' ||
                this.detailSheetTitle === '进度条行为' || this.detailSheetTitle === '点击图片行为' ||
                this.detailSheetTitle === '屏幕方向' ||
                this.detailSheetTitle === '显示模式' ||
                this.detailInfoSlot !== undefined
                ? '选择后立即应用并保存；自定义内容需点击保存。' : '仅展示选择预览，不保存设置。')
                .fontSize(10).fontColor('#92949E')
                .width('100%').textAlign(TextAlign.Center).padding(12)
            }.width('100%').padding({ left: 18, right: 18, bottom: 16 })
          }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
        }
      }.width('88%').height('86%').backgroundColor('#F21A1B21').borderRadius(22)
    }.width('100%').height('100%')
  }

  private getMenuSettingsEntries(): ReaderMenuSettingsEntry[] {
    if (this.selectedMenuSettingsTab === 0) {
      return [
        { title: '工具栏样式', detail: '系统 / 跟随阅读背景 / 自定义' },
        { title: '调色板风格', detail: '跟随系统颜色 / 固定风格' },
        { title: '菜单颜色来源', detail: '种子色 / 自定义主题色' },
        { title: '种子色', detail: '日间强调色 / 夜间强调色' },
        { title: '菜单背景颜色', detail: '日间与夜间背景色' },
        { title: '菜单容器颜色', detail: '日间与夜间容器色' },
        { title: '菜单强调颜色', detail: '日间与夜间强调色' },
        { title: '显示亮度调节控件', detail: '', section: true },
        { title: '显示亮度视图', detail: '关闭 / 横向 / 竖向' },
        { title: '亮度条位置', detail: '顶栏 / 底栏' },
        { title: '菜单边框', detail: '', section: true },
        { title: '菜单栏边框', detail: '显示菜单栏边框' },
        { title: '菜单栏边框宽度', detail: '1–4 dp' },
        { title: '菜单栏边框颜色', detail: '日间 / 夜间' },
        { title: '模糊和颜色', detail: '', section: true },
        { title: '菜单模糊半径', detail: '0–32 dp' },
        { title: '菜单模糊透明度', detail: '0–100%' },
        { title: '菜单文字颜色', detail: '日间 / 夜间' },
        { title: '菜单模糊颜色', detail: '日间 / 夜间' },
        { title: '悬浮图标设置', detail: '', section: true },
        { title: '显示标题栏图标', detail: '显示/隐藏悬浮操作图标' },
        { title: '标题栏悬浮图标配置', detail: '图标内容与显示位置' },
        { title: '标题栏悬浮图标位置', detail: '顶栏左侧 / 右侧 / 底栏左侧 / 右侧' },
        { title: '悬浮图标液态玻璃按钮', detail: '开 / 关' }
      ];
    }
    if (this.selectedMenuSettingsTab === 1) {
      return [
        { title: '底栏按钮配置', detail: '排序、显示与长按动作' },
        { title: '底栏布局', detail: '', section: true },
        { title: '底栏圆角', detail: '设置底栏卡片圆角' },
        { title: '底栏悬浮', detail: '悬浮显示与位置' },
        { title: '底栏模糊', detail: '关闭 / 纯色 / 渐变' },
        { title: '底栏模糊透明度', detail: '调整背景透明程度' },
        { title: '底栏液态玻璃', detail: '悬浮底栏背景效果' },
        { title: '底栏按钮液态玻璃', detail: '按钮表面效果' }
      ];
    }
    return [
      { title: '标题栏胶囊', detail: '合并标题与章节信息' },
      { title: '标题栏模式', detail: '标题与正文信息展示' },
      { title: '标题栏操作按钮', detail: '按钮配置与排序' },
      { title: '标题栏紧凑', detail: '开 / 关' },
      { title: '标题栏图标样式', detail: '纯色 / 色调 / 描边' },
        { title: '顶栏模糊', detail: '开启 / 关闭' },
        { title: '顶栏模糊样式', detail: '纯色 / 渐变' },
        { title: '顶栏液态玻璃按钮', detail: '开 / 关' },
      { title: '合并标题栏按钮', detail: '开 / 关' }
    ];
  }

  private getBottomActionLabel(id: string): string {
    const option = READER_ACTION_OPTIONS.find((item: ReaderActionOption) => item.id === id);
    return option?.label ?? id;
  }

  private getBottomActionOption(id: string): ReaderActionOption | undefined {
    return READER_ACTION_OPTIONS.find((item: ReaderActionOption) => item.id === id);
  }

  private moveBottomAction(index: number, delta: number): void {
    const target = index + delta;
    if (target < 0 || target >= this.draftBottomActions.length) { return; }
    const updated = this.draftBottomActions.map(
      (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
    );
    const current = updated[index];
    const neighbor = updated[target];
    if (current === undefined || neighbor === undefined) { return; }
    updated[index] = neighbor;
    updated[target] = current;
    this.draftBottomActions = updated;
  }

  private toggleBottomAction(id: string, enabled: boolean): void {
    this.draftBottomActions = this.draftBottomActions.map((item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({
      id: item.id,
      enabled: item.id === id ? enabled : item.enabled
    }));
  }

  private getTopActionLabel(id: string): string {
    return this.getBottomActionLabel(id);
  }

  private moveTopAction(index: number, delta: number): void {
    const target = index + delta;
    if (target < 0 || target >= this.draftTopActions.length) { return; }
    const updated = this.draftTopActions.map(
      (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
    );
    const current = updated[index];
    const neighbor = updated[target];
    if (current === undefined || neighbor === undefined) { return; }
    updated[index] = neighbor;
    updated[target] = current;
    this.draftTopActions = updated;
  }

  private toggleTopAction(id: string, enabled: boolean): void {
    this.draftTopActions = this.draftTopActions.map((item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({
      id: item.id,
      enabled: item.id === id ? enabled : item.enabled
    }));
  }

  @Builder
  private bottomActionConfigurationSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor('#99000000')
        .onClick(() => this.bottomActionConfigVisible = false)
      Column() {
        Row().width(32).height(4).backgroundColor('#C5C6CD').borderRadius(4).margin({ top: 10, bottom: 14 })
        Row() {
          Text('底栏按钮配置').fontSize(17).fontColor('#E5E6EB').layoutWeight(1)
          Text('取消').fontSize(13).fontColor('#C7C9D1').margin({ right: 18 })
            .onClick(() => this.bottomActionConfigVisible = false)
          Text('保存').fontSize(13).fontColor('#C6D3FF')
            .onClick(() => {
              this.onBottomActionsChange(this.draftBottomActions.map(
                (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
              ));
              this.bottomActionConfigVisible = false;
            })
        }.width('100%').padding({ left: 18, right: 18, bottom: 12 })
        Scroll() {
          Column() {
            ForEach(this.draftBottomActions, (item: ReaderBottomActionConfig, index: number) => {
              Row() {
                this.BottomActionConfigIcon(item.id, item.enabled)
                Column() {
                  Text(this.getBottomActionLabel(item.id)).fontSize(14)
                    .fontColor(item.enabled ? '#E5E6EB' : '#777984')
                  if (this.getBottomActionOption(item.id)?.scopeLabel) {
                    Text(this.getBottomActionOption(item.id)?.scopeLabel ?? '')
                      .fontSize(10).fontColor('#92949E').margin({ top: 2 })
                  }
                  if (this.getBottomActionOption(item.id)?.migrated === false) {
                    Text('未迁移').fontSize(10).fontColor('#92949E').margin({ top: 2 })
                  }
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Stack({ alignContent: Alignment.Center }) {
                  Image(item.enabled ? $r('app.media.app_visibility') : $r('app.media.reader_visibility_off'))
                    .width(20).height(20).fillColor(item.enabled ? '#D5C2C6' : '#777984')
                }.width(36).height(36).borderRadius(18).backgroundColor('#292A31')
                  .onClick(() => this.toggleBottomAction(item.id, !item.enabled))
                Column() {
                  Image($r('app.media.reader_reorder_up')).width(16).height(16)
                    .fillColor(index === 0 ? '#555761' : '#B9BBC4')
                    .onClick(() => this.moveBottomAction(index, -1))
                  Image($r('app.media.reader_reorder_down')).width(16).height(16)
                    .fillColor(index === this.draftBottomActions.length - 1 ? '#555761' : '#B9BBC4')
                    .onClick(() => this.moveBottomAction(index, 1))
                }.width(24).height(36).justifyContent(FlexAlign.SpaceBetween).margin({ left: 4 })
                Stack({ alignContent: Alignment.Center }) {
                  Image($r('app.media.reader_drag_handle')).width(20).height(20).fillColor('#B9BBC4')
                }.width(32).height(36)
              }.width('100%').padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .backgroundColor('#202127').borderRadius(12).margin({ bottom: 8 })
            }, (item: ReaderBottomActionConfig) => item.id)
          }.width('100%').padding({ left: 14, right: 14, bottom: 12 })
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
      }.width('100%').height('62%').backgroundColor('#D91A1B21')
        .borderRadius({ topLeft: 24, topRight: 24 })
    }.width('100%').height('100%')
  }

  @Builder
  private BottomActionConfigIcon(id: string, enabled: boolean) {
    if (id === 'search') {
      Image($r('app.media.reader_search')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'autoPage') {
      Image($r('app.media.reader_play')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'catalog') {
      Image($r('app.media.reader_toc')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'voice') {
      Image($r('app.media.reader_voice')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'settings') {
      Image($r('app.media.reader_settings')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'addBookmark') {
      Image($r('app.media.app_bookmark')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'theme') {
      Image($r('app.media.app_daynight')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'eye_protection') {
      Image($r('app.media.app_visibility')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'prev_chapter') {
      Image($r('app.media.app_previous')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'next_chapter') {
      Image($r('app.media.reader_arrow_forward')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'replace' || id === 'replace_badge') {
      Image($r('app.media.profile_find_replace')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'translate' || id === 'charset') {
      Image($r('app.media.reader_translate')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'refresh_current' || id === 'refresh') {
      Image($r('app.media.app_refresh')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'change_source') {
      Image($r('app.media.app_swap')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'download' || id === 'audio_download') {
      Image($r('app.media.app_download')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'toc_rule') {
      Image($r('app.media.profile_rule')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'source_custom_button' || id === 'more_actions') {
      Image($r('app.media.reader_more')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'ai_summary' || id === 'ai_cast') {
      Image($r('app.media.profile_auto_awesome')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'ai_rewrite') {
      Image($r('app.media.app_edit')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'multi_role_read' || id === 'multi_role_cast') {
      Image($r('app.media.app_group')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else if (id === 'cast_table') {
      Image($r('app.media.app_list')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    } else {
      Image($r('app.media.reader_more')).width(20).height(20).fillColor(enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
    }
  }

  @Builder
  private topActionConfigurationSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor('#99000000')
        .onClick(() => this.topActionConfigVisible = false)
      Column() {
        Row().width(32).height(4).backgroundColor('#C5C6CD').borderRadius(4).margin({ top: 10, bottom: 14 })
        Row() {
          Text('顶栏按钮配置').fontSize(17).fontColor('#E5E6EB').layoutWeight(1)
          Text('取消').fontSize(13).fontColor('#C7C9D1').margin({ right: 18 })
            .onClick(() => this.topActionConfigVisible = false)
          Text('保存').fontSize(13).fontColor('#C6D3FF')
            .onClick(() => {
              this.onTopActionsChange(this.draftTopActions.map(
                (item: ReaderBottomActionConfig): ReaderBottomActionConfig => ({ id: item.id, enabled: item.enabled })
              ));
              this.topActionConfigVisible = false;
            })
        }.width('100%').padding({ left: 18, right: 18, bottom: 12 })
        Scroll() {
          Column() {
          ForEach(this.draftTopActions, (item: ReaderBottomActionConfig, index: number) => {
            Row() {
              this.BottomActionConfigIcon(item.id, item.enabled)
              Column() {
                Text(this.getTopActionLabel(item.id)).fontSize(14)
                  .fontColor(item.enabled ? '#E5E6EB' : '#777984')
                if (this.getBottomActionOption(item.id)?.scopeLabel) {
                  Text(this.getBottomActionOption(item.id)?.scopeLabel ?? '')
                    .fontSize(10).fontColor('#92949E').margin({ top: 2 })
                }
                if (this.getBottomActionOption(item.id)?.migrated === false) {
                  Text('未迁移').fontSize(10).fontColor('#92949E').margin({ top: 2 })
                }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Stack({ alignContent: Alignment.Center }) {
                Image(item.enabled ? $r('app.media.app_visibility') : $r('app.media.reader_visibility_off'))
                  .width(20).height(20).fillColor(item.enabled ? '#D5C2C6' : '#777984')
              }.width(36).height(36).borderRadius(18).backgroundColor('#292A31')
                .onClick(() => this.toggleTopAction(item.id, !item.enabled))
              Column() {
                Image($r('app.media.reader_reorder_up')).width(16).height(16)
                  .fillColor(index === 0 ? '#555761' : '#B9BBC4')
                  .onClick(() => this.moveTopAction(index, -1))
                Image($r('app.media.reader_reorder_down')).width(16).height(16)
                  .fillColor(index === this.draftTopActions.length - 1 ? '#555761' : '#B9BBC4')
                  .onClick(() => this.moveTopAction(index, 1))
              }.width(24).height(36).justifyContent(FlexAlign.SpaceBetween).margin({ left: 4 })
              Image($r('app.media.reader_drag_handle')).width(20).height(20).fillColor('#B9BBC4')
                .width(32).height(36).margin({ left: 4 })
            }.width('100%').padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor('#202127').borderRadius(12).margin({ bottom: 8 })
          }, (item: ReaderBottomActionConfig) => item.id)
          }.width('100%').padding({ left: 14, right: 14, bottom: 12 })
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
      }.width('100%').height('62%').backgroundColor('#D91A1B21')
        .borderRadius({ topLeft: 24, topRight: 24 })
    }.width('100%').height('100%')
  }

  build() {
    if (this.asSheet) {
      Stack({ alignContent: this.selectedSettingsTab === 2 ? Alignment.Center : Alignment.Bottom }) {
        Column().width('100%').height('100%').backgroundColor('#88000000').onClick(() => this.onBack())
        Column() {
          this.settingsContent(true)
        }.width(this.settingsSheetWidth()).height(this.settingsSheetHeight()).alignSelf(ItemAlign.Center)
          .backgroundColor('#D91A1B21').borderRadius(22)
          .margin({ left: 8, right: 8, bottom: this.selectedSettingsTab === 2 ? 0 : 16 })
          .offset({ x: 0, y: this.selectedSettingsTab === 2 ? -18 : 0 })
        if (this.bottomActionConfigVisible) {
          this.bottomActionConfigurationSheet()
        }
        if (this.topActionConfigVisible) {
          this.topActionConfigurationSheet()
        }
        if (this.detailSheetVisible) {
          this.detailSheet()
        }
      }.width('100%').height('100%')
    } else {
      Stack({ alignContent: Alignment.Center }) {
        Column() {
          this.settingsContent(false)
        }.width('100%').height('100%')
        if (this.bottomActionConfigVisible) {
          this.bottomActionConfigurationSheet()
        }
        if (this.topActionConfigVisible) {
          this.topActionConfigurationSheet()
        }
        if (this.detailSheetVisible) {
          this.detailSheet()
        }
      }.width('100%').height('100%')
    }
  }
}

@Component
struct BackgroundShareOption {
  @Prop selected: boolean = false;

  build() {
    Column() {
      Image($r('app.media.menu_grid')).width(20).height(20).fillColor('#E4E5EA')
    }.width(40).height(56).justifyContent(FlexAlign.Center)
      .backgroundColor(this.selected ? '#34394C' : '#15161B')
      .borderRadius(9)
      .border({ width: this.selected ? 2 : 1, color: this.selected ? '#AFC2FF' : '#33343C' })
  }
}

@Component
struct MenuSettingIconStyle {
  @Prop value: number = 1;
  onChange: (style: number) => void = (_style: number) => {};

  build() {
    Column() {
      Text('底栏图标样式').fontSize(13).fontColor('#E2E3E8').width('100%').margin({ bottom: 10 })
      Row() {
        ForEach(['纯色', '色调', '描边'], (label: string, index: number) => {
          Text(label).fontSize(11).fontColor(this.value === index ? '#ECECF0' : '#B7B8C1')
            .layoutWeight(1).textAlign(TextAlign.Center)
            .backgroundColor(this.value === index ? '#454B62' : '#15161B')
            .borderRadius(11).padding(9).margin({ left: index === 0 ? 0 : 6 })
            .onClick(() => this.onChange(index))
        }, (label: string) => label)
      }.width('100%')
    }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct MenuSettingSlider {
  @Prop title: string = '';
  @Prop value: number = 5;
  @Prop minValue: number = 1;
  @Prop maxValue: number = 8;
  @Prop stepValue: number = 1;
  onChange: (value: number) => void = (_value: number) => {};

  build() {
    Column() {
      Row() {
        Text(this.title).fontSize(13).fontColor('#E2E3E8').layoutWeight(1)
        Text(`${this.value}`).fontSize(12).fontColor('#D3D4DC')
      }.width('100%')
      Slider({ value: this.value, min: this.minValue, max: this.maxValue, step: this.stepValue, style: SliderStyle.InSet })
        .width('100%').selectedColor('#AFC2FF').trackColor('#454751').blockColor('#AFC2FF')
        .showSteps(true).stepColor('#AFC2FF').stepSize(3)
        .onChange((value: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click || mode === SliderChangeMode.End) {
            this.onChange(Math.max(this.minValue, Math.min(this.maxValue, Math.round(value))));
          }
        })
    }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct MenuSettingChoice {
  @Prop title: string = '';
  @Prop value: string = 'page';
  onChange: (value: string) => void = (_value: string) => {};

  build() {
    Column() {
      Text(this.title).fontSize(13).fontColor('#E2E3E8').width('100%').margin({ bottom: 10 })
      Row() {
        Text('页码').fontSize(11).fontColor(this.value === 'page' ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center)
          .backgroundColor(this.value === 'page' ? '#454B62' : '#15161B')
          .borderRadius(11).padding(9).onClick(() => this.onChange('page'))
        Text('章节').fontSize(11).fontColor(this.value === 'chapter' ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center)
          .backgroundColor(this.value === 'chapter' ? '#454B62' : '#15161B')
          .borderRadius(11).padding(9).margin({ left: 8 }).onClick(() => this.onChange('chapter'))
      }.width('100%')
    }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct MenuSettingSwitch {
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop checked: boolean = false;
  onChange: (enabled: boolean) => void = (_enabled: boolean) => {};

  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(13).fontColor('#E2E3E8')
        Text(this.detail).fontSize(10).fontColor('#9A9CA5').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .onChange((enabled: boolean) => this.onChange(enabled))
    }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct MenuSettingSection {
  @Prop title: string = '';

  build() {
    Text(this.title).fontSize(12).fontColor('#AFC2FF').width('100%')
      .padding({ left: 4, top: 10, bottom: 4 })
  }
}

@Component
struct MenuSettingSegments {
  @Prop title: string = '';
  @Prop choices: string[] = [];
  @Prop selectedIndex: number = 0;
  onSelect: (index: number) => void = (_index: number) => {};

  build() {
    Row() {
      Text(this.title).fontSize(13).fontColor('#E2E3E8').layoutWeight(1).maxLines(1)
      Text(this.choices[this.selectedIndex] ?? this.choices[0] ?? '')
        .fontSize(11).fontColor('#D3D4DC').padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor('#292A31').borderRadius(8)
      Text('⌄').fontSize(15).fontColor('#A7A9B3').margin({ left: 4 })
    }.width('100%').height(46).padding(8).backgroundColor('#202127').borderRadius(12)
      .onClick(() => this.onSelect(this.selectedIndex))
  }
}

@Component
struct ReaderInfoSettingRow {
  @Prop iconKind: number = 0;
  @Prop title: string = '';
  @Prop choices: string[] = [];
  @Prop selectedIndex: number = 0;
  onSelect: (index: number) => void = (_index: number) => {};

  build() {
    Row() {
      if (this.iconKind === 0) {
        Image($r('app.media.reader_info_heading')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
      } else if (this.iconKind === 1) {
        Image($r('app.media.reader_info_align_left')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
      } else if (this.iconKind === 2) {
        Image($r('app.media.reader_info_align_center')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
      } else {
        Image($r('app.media.reader_info_align_right')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
      }
      Text(this.title).fontSize(13).fontColor('#E2E3E8').layoutWeight(1).maxLines(1)
      Text(this.choices[this.selectedIndex] ?? this.choices[0] ?? '')
        .fontSize(11).fontColor('#D3D4DC').padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor('#292A31').borderRadius(8)
      Text('⌄').fontSize(15).fontColor('#A7A9B3').margin({ left: 4 })
    }.width('100%').height(50).padding(10).backgroundColor('#202127').borderRadius(12)
      .onClick(() => this.onSelect(this.selectedIndex))
  }
}

@Component
struct ReaderInfoColorRow {
  @Prop iconKind: number = 4;
  @Prop title: string = '';
  @Prop detail: string = '';

  build() {
    Row() {
      if (this.iconKind === 4) {
        Image($r('app.media.reader_info_palette')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
      } else {
        Image($r('app.media.reader_info_color_text')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
      }
      Column() {
        Text(this.title).fontSize(13).fontColor('#E2E3E8')
        Text(this.detail).fontSize(10).fontColor('#9A9CA5').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Row() {
        Column().width(22).height(22).backgroundColor('#E6E1E7').borderRadius(11)
        Column().width(22).height(22).backgroundColor('#3D3D46').borderRadius(11).margin({ left: 5 })
      }
      Text('›').fontSize(20).fontColor('#A7A9B3').margin({ left: 8 })
    }.width('100%').padding(10).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct ReaderInfoSwitchRow {
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop checked: boolean = false;
  onChange: (enabled: boolean) => void = (_enabled: boolean) => {};

  build() {
    Row() {
      Image($r('app.media.reader_info_minimize')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
      Column() {
        Text(this.title).fontSize(13).fontColor('#E2E3E8')
        Text(this.detail).fontSize(10).fontColor('#9A9CA5').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .onChange((enabled: boolean) => this.onChange(enabled))
    }.width('100%').padding(10).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct ReaderInfoOptionRow {
  @Prop iconKind: number = 5;
  @Prop title: string = '';
  @Prop detail: string = '';

  build() {
    Row() {
      Image($r('app.media.reader_info_text_fields')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
      Column() {
        Text(this.title).fontSize(13).fontColor('#E2E3E8')
        Text(this.detail).fontSize(10).fontColor('#9A9CA5').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('›').fontSize(20).fontColor('#A7A9B3')
    }.width('100%').padding(10).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct ReaderInfoSliderRow {
  @Prop iconKind: number = 6;
  @Prop title: string = '';
  @Prop value: number = 16;
  @Prop minValue: number = 0;
  @Prop maxValue: number = 100;
  onChange: (value: number) => void = (_value: number) => {};

  build() {
    Column() {
      Row() {
        Image($r('app.media.reader_info_format_size')).width(20).height(20).fillColor('#D9DAE0').margin({ right: 14 })
        Text(this.title).fontSize(13).fontColor('#E2E3E8').layoutWeight(1)
        Text(`${this.value}`).fontSize(12).fontColor('#D3D4DC')
      }.width('100%')
      Slider({ value: this.value, min: this.minValue, max: this.maxValue, step: 1, style: SliderStyle.InSet })
        .width('100%').selectedColor('#AFC2FF').trackColor('#454751').blockColor('#AFC2FF')
        .onChange((value: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click || mode === SliderChangeMode.End) {
            this.onChange(Math.max(this.minValue, Math.min(this.maxValue, Math.round(value))));
          }
        })
    }.width('100%').padding(10).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct MenuSettingColor {
  @Prop title: string = '';
  @Prop detail: string = '';

  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(13).fontColor('#E2E3E8')
        Text(this.detail).fontSize(10).fontColor('#9A9CA5').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Row() {
        Column().width(22).height(22).backgroundColor('#E6E1E7').borderRadius(11)
        Column().width(22).height(22).backgroundColor('#3D3D46').borderRadius(11).margin({ left: 5 })
      }
      Text('›').fontSize(20).fontColor('#A7A9B3').margin({ left: 8 })
    }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct MenuSettingOption {
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop migrated: boolean = false;

  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(13).fontColor('#E2E3E8')
        Text(this.detail).fontSize(10).fontColor('#9A9CA5').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (!this.migrated) {
        Text('尚未迁移').fontSize(9).fontColor('#898B95').margin({ right: 8 })
      }
      Text('›').fontSize(20).fontColor('#A7A9B3')
    }.width('100%').padding(12).backgroundColor('#202127').borderRadius(12)
  }
}

@Component
struct BackgroundOption {
  @Prop label: string = '';
  @Prop color: string = '#000000';
  @Prop selected: boolean = false;

  build() {
    Column() {
      Text(this.label).fontSize(10).fontColor(
        this.color.toLowerCase() === '#000000' || this.color.toLowerCase() === '#3c3f43'
          ? '#E4E5EA' : '#585963')
      if (this.selected) {
        Image($r('app.media.app_check')).width(12).height(12).fillColor('#C6D3FF').margin({ top: 6 })
      }
    }.width(44).height(56).justifyContent(FlexAlign.Center).backgroundColor(this.color)
      .borderRadius(11).border({ width: this.selected ? 2 : 1, color: this.selected ? '#AFC2FF' : '#33343C' })
  }
}
