import { DURATION_FADE } from '../components/UiTokens';
import { UiMenuItem, UiMenuPanel } from '../components/UiMenu';
import { AppGlyph } from '../components/AppGlyph';
import { AppTopBar, TopBarButton, TopBarBackButton } from '../components/TopBar';
import { HEADLINE_MEDIUM, HEADLINE_SMALL, LABEL_LARGE, LABEL_MEDIUM, TITLE_MEDIUM, TITLE_SMALL } from '../components/typography/TypographyTokens';

/** 卡片式菜单的统一宽度，与书架页、详情页同口径。 */
const SUB_PAGES_MENU_WIDTH: number = 260;

const SUBSCRIPTION_EMPTY_FACES: string[] = [
  '(；′⌒`)', '(つ﹏⊂)', '(•̀ᴗ•́)و', '(๑•́ ₃ •̀๑)', '(눈‸눈)', '(ಥ﹏ಥ)', '(｡•́︿•̀｡)'
];

@Component
export struct SubscriptionRulesPage {
  @StorageProp('themeItemBackground') themeItemBackground: string = '';
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  build() {
    SubscriptionListPage({
      title: '规则', emptyMessage: '还没有规则订阅！', showAdd: true,
      onBack: () => this.onBack(),
      onUnavailableAction: (message: string) => this.onUnavailableAction(message)
    })
  }
}

@Component
export struct SubscriptionFavoritesPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  build() {
    SubscriptionListPage({
      title: '收藏', subtitle: '全部', emptyMessage: '还没有收藏订阅！', showAdd: false,
      onBack: () => this.onBack(),
      onUnavailableAction: (message: string) => this.onUnavailableAction(message)
    })
  }
}

@Component
struct SubscriptionListPage {
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop emptyMessage: string = '';
  @Prop showAdd: boolean = false;
  @State searchVisible: boolean = false;
  @State searchText: string = '';
  @State faceIndex: number = Math.floor(Math.random() * SUBSCRIPTION_EMPTY_FACES.length);
  @State activeSheet: string = '';
  @State draftName: string = '';
  @State draftUrl: string = '';
  @State draftType: number = 0;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  private changeFace(): void {
    this.faceIndex = (this.faceIndex + 1) % SUBSCRIPTION_EMPTY_FACES.length;
  }

  private moreMenuItems(): UiMenuItem[] {
    if (this.title === '规则') {
      return [{ key: 'sort', title: '排序' }];
    }
    return [
      { key: 'all', title: '全部' },
      { key: 'add_group', title: '添加到分组' },
      { key: 'remove_group', title: '从分组移除' },
      { key: 'delete_selected_group', title: '删除所选分组' },
      { key: 'delete_all', title: '删除全部' }
    ];
  }

  @Builder
  private MoreMenu() {
    UiMenuPanel({
      items: this.moreMenuItems(),
      panelWidth: SUB_PAGES_MENU_WIDTH,
      onSelect: (key: string) => {
        this.moreMenuVisible = false;
        if (key === 'sort') {
          this.onUnavailableAction('订阅规则排序尚未接入');
        } else if (key === 'all') {
          this.onUnavailableAction('收藏分组尚未接入');
        } else if (key === 'add_group') {
          this.activeSheet = 'addGroup';
        } else if (key === 'remove_group') {
          this.activeSheet = 'removeGroup';
        } else if (key === 'delete_selected_group') {
          this.onUnavailableAction('收藏分组尚未接入');
        } else if (key === 'delete_all') {
          this.onUnavailableAction('收藏数据尚未接入');
        }
      }
    })
  }

  @StorageProp('themeItemBackground') themeItemBackground: string = '';
  @State collapsedHeader: boolean = false;
  @State moreMenuVisible: boolean = false;

  @Builder subNavSlot() {
    TopBarBackButton({ onSelect: () => this.onBack() })
  }

  @Builder subTopActions() {
    // 上游 RSS 页（`ui/main/rss/RssScreen.kt:166`）走 `ListScaffold` → `DynamicTopAppBar`，
    // 顶栏动作的文案在 `ui/widget/components/topbar/DynamicTopAppBar.kt`：搜索取
    // `R.string.search`（`:99-102`）、溢出菜单取 `R.string.more_menu`（`:110-113`）。
    TopBarButton({
      icon: 'search',
      showDivider: false,
      accessibilityLabel: '搜索',
      onSelect: () => { this.searchVisible = !this.searchVisible; }
    })
    TopBarButton({ icon: 'more', menuMode: true, accessibilityLabel: '更多菜单' })
      .onClick(() => { this.moreMenuVisible = !this.moreMenuVisible; })
      .bindPopup(this.moreMenuVisible, {
        builder: this.MoreMenu,
        placement: Placement.BottomRight,
        popupColor: '#00000000',
        enableArrow: false,
        autoCancel: true,
        width: SUB_PAGES_MENU_WIDTH,
        onStateChange: (event: PopupStateChangeParam) => { this.moreMenuVisible = event.isVisible; }
      })
  }

  build() {
    Column() {
      AppTopBar({
        title: this.title,
        subtitle: this.subtitle,
        collapsed: this.collapsedHeader,
        hasNavigation: true,
        navigationIcon: () => { this.subNavSlot() },
        actions: () => { this.subTopActions() }
      })

      if (this.searchVisible) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索…', text: this.searchText })
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .onChange((value: string) => this.searchText = value)
        }.width('100%').padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .margin({ left: 16, right: 16, bottom: 8 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(22).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
          .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE, curve: Curve.EaseInOut }))
      }

      Column() {
        Text(SUBSCRIPTION_EMPTY_FACES[this.faceIndex]).fontSize(HEADLINE_MEDIUM).fontColor(this.themeColorTextPrimary)
          .margin({ bottom: 8 }).onClick(() => this.changeFace())
        Text(this.emptyMessage).fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextPrimary).textAlign(TextAlign.Center)
      }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .offset({ y: this.subtitle.length > 0 ? 0 : 34 })

      if (this.showAdd) {
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'add', glyphSize: 24, tint: '#DDE3FF' })
          }.width(56).height(56).backgroundColor('#4D5C8D').borderRadius(18)
            .onClick(() => this.activeSheet = 'ruleEditor')
            // 上游取 RssSourceScreen.kt:249 RuleListScaffold 默认 FAB add
            .accessibilityText('添加')
            .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE, curve: Curve.EaseInOut }))
        }.width('100%').justifyContent(FlexAlign.End).padding({ right: 16, top: 8, bottom: 8 })
      }
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .bindSheet(this.activeSheet.length > 0, this.subscriptionSheet(), {
        height: SheetSize.FIT_CONTENT,
        dragBar: true,
        showClose: false,
        backgroundColor: this.themeColorSurfaceTertiary,
        onDisappear: () => this.activeSheet = ''
      })
  }

  @Builder
  private subscriptionSheet() {
    Column() {
      Row() {
        Text(this.activeSheet === 'ruleEditor' ? '规则订阅' : this.activeSheet === 'addGroup' ?
          '添加到分组' : '从分组移除')
          .fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text('取消').fontSize(LABEL_LARGE).fontColor(this.themeColorAccent).onClick(() => this.activeSheet = '')
      }.width('100%').padding({ left: 18, right: 18, top: 12, bottom: 16 })
      TextInput({ placeholder: this.activeSheet === 'ruleEditor' ? '名称' : '分组名称', text: this.draftName })
        .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).backgroundColor('#292B33').borderRadius(12)
        .margin({ left: 18, right: 18, bottom: 12 }).onChange((value: string) => this.draftName = value)
      if (this.activeSheet === 'ruleEditor') {
        TextInput({ placeholder: 'URL', text: this.draftUrl })
          .fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextPrimary).backgroundColor('#292B33').borderRadius(12)
          .margin({ left: 18, right: 18, bottom: 12 }).onChange((value: string) => this.draftUrl = value)
        Text('订阅类型').fontSize(TITLE_SMALL).fontWeight(FontWeight.Bold).fontColor('#B6B8C2').alignSelf(ItemAlign.Start)
          .margin({ left: 18, top: 6, bottom: 8 })
        Row() {
          ForEach(['书源', '订阅源', '替换规则', '自动识别'], (label: string, index: number) => {
            Text(label).fontSize(TITLE_SMALL).fontColor(this.draftType === index ? this.themeColorAccent : this.themeColorTextSecondary)
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .backgroundColor(this.draftType === index ? '#41485D' : '#292B33').borderRadius(18)
              .margin({ right: 8 }).onClick(() => this.draftType = index)
          }, (label: string) => label)
        }.width('100%').padding({ left: 18, right: 18 })
      }
      Button('保存').fontSize(LABEL_LARGE).fontColor(this.themeColorSurfacePrimary).backgroundColor(this.themeColorAccent).borderRadius(22)
        .margin({ top: 18 }).onClick(() => {
          this.activeSheet = '';
          this.draftName = '';
          this.draftUrl = '';
          this.onUnavailableAction('订阅数据尚未迁移，输入未保存');
        })
    }.width('100%').padding({ bottom: 24 })
  }
}


@Component
export struct SubscriptionSourceManagePage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State searchVisible: boolean = false;
  @State searchText: string = '';

  private moreMenuItems(): UiMenuItem[] {
    return [
      { key: 'group_manage', title: '分组管理' },
      { key: 'import_source', title: '导入订阅源' },
      { key: 'all', title: '全部' },
      { key: 'enabled', title: '已启用' },
      { key: 'disabled', title: '已禁用' },
      { key: 'need_login', title: '需登录' },
      { key: 'ungrouped', title: '未分组' }
    ];
  }

  @Builder
  private MoreMenu() {
    UiMenuPanel({
      items: this.moreMenuItems(),
      panelWidth: SUB_PAGES_MENU_WIDTH,
      onSelect: (key: string) => {
        this.moreMenuVisible = false;
        if (key === 'group_manage') {
          this.onUnavailableAction('订阅源分组管理尚未迁移');
        } else if (key === 'import_source') {
          this.onUnavailableAction('订阅源导入尚未迁移');
        } else if (key === 'all') {
          this.onUnavailableAction('当前已显示全部订阅源');
        } else {
          this.onUnavailableAction('订阅源筛选尚未迁移');
        }
      }
    })
  }

  @StorageProp('themeItemBackground') themeItemBackground: string = '';
  @State collapsedHeader: boolean = false;
  @State moreMenuVisible: boolean = false;

  @Builder subNavSlot() {
    TopBarBackButton({ onSelect: () => this.onBack() })
  }

  @Builder subTopActions() {
    // 上游 RSS 页（`ui/main/rss/RssScreen.kt:166`）走 `ListScaffold` → `DynamicTopAppBar`，
    // 顶栏动作的文案在 `ui/widget/components/topbar/DynamicTopAppBar.kt`：搜索取
    // `R.string.search`（`:99-102`）、溢出菜单取 `R.string.more_menu`（`:110-113`）。
    TopBarButton({
      icon: 'search',
      showDivider: false,
      accessibilityLabel: '搜索',
      onSelect: () => { this.searchVisible = !this.searchVisible; }
    })
    TopBarButton({ icon: 'more', menuMode: true, accessibilityLabel: '更多菜单' })
      .onClick(() => { this.moreMenuVisible = !this.moreMenuVisible; })
      .bindPopup(this.moreMenuVisible, {
        builder: this.MoreMenu,
        placement: Placement.BottomRight,
        popupColor: '#00000000',
        enableArrow: false,
        autoCancel: true,
        width: SUB_PAGES_MENU_WIDTH,
        onStateChange: (event: PopupStateChangeParam) => { this.moreMenuVisible = event.isVisible; }
      })
  }

  build() {
    Column() {
      AppTopBar({
        title: '订阅源',
        subtitle: '全部',
        collapsed: this.collapsedHeader,
        hasNavigation: true,
        navigationIcon: () => { this.subNavSlot() },
        actions: () => { this.subTopActions() }
      })

      if (this.searchVisible) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索订阅源…', text: this.searchText })
            .fontSize(TITLE_SMALL).fontColor(this.themeColorTextSecondary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .onChange((value: string) => this.searchText = value)
        }.width('100%').padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .margin({ left: 16, right: 16, bottom: 8 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(22).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
          .transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE, curve: Curve.EaseInOut }))
      }

      Blank().layoutWeight(1)
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'add', glyphSize: 24, tint: '#DDE3FF' })
        }.width(50).height(50).backgroundColor('#4D5C8D').borderRadius(16)
          .onClick(() => this.onUnavailableAction('订阅源编辑页尚未迁移'))
          // 上游取 RssSourceScreen.kt:249 RuleListScaffold 默认 FAB add
          .accessibilityText('添加')
      }.width('100%').justifyContent(FlexAlign.End).padding({ right: 16, bottom: 16 })
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}
