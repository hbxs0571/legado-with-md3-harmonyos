import { ReaderBackgroundStyle, READER_BACKGROUND_STYLES } from '../data/ReaderSettingsRepository';
import {
  ReaderBottomActionConfig, READER_LOCAL_BOTTOM_ACTION_DEFAULTS, READER_LOCAL_TOP_ACTION_DEFAULTS
} from '../data/ReaderSettingsRepository';

interface ReaderMenuSettingsEntry {
  title: string;
  detail: string;
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
  @Prop showBottomActionText: boolean = true;
  @Prop bottomIconStyle: number = 1;
  @Prop bottomItemsPerRow: number = 5;
  @Prop bottomRowCount: number = 1;
  @Prop bottomActions: ReaderBottomActionConfig[] = READER_LOCAL_BOTTOM_ACTION_DEFAULTS;
  @Prop topActions: ReaderBottomActionConfig[] = READER_LOCAL_TOP_ACTION_DEFAULTS;
  @Prop progressBehavior: string = 'page';
  @Prop showQuickActions: boolean = false;
  @Prop asSheet: boolean = false;
  @State selectedSettingsTab: number = 0;
  @State selectedMenuSettingsTab: number = 0;
  @State bottomActionConfigVisible: boolean = false;
  @State topActionConfigVisible: boolean = false;
  @State detailSheetVisible: boolean = false;
  @State detailSheetTitle: string = '';
  @State detailSheetDescription: string = '';
  @State pageAnimation: string = '滚动';
  @State animationSpeed: string = '适中';
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
  onBack: () => void = () => {};
  onFontSizeChange: (fontSize: number) => void = () => {};
  onPaperChange: (paperIndex: number) => void = () => {};
  onShareLayoutChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onToggleNightMode: () => void = () => {};
  onBottomActionTextChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  onBottomIconStyleChange: (style: number) => void = (_style: number) => {};
  onBottomItemsPerRowChange: (count: number) => void = (_count: number) => {};
  onBottomRowCountChange: (count: number) => void = (_count: number) => {};
  onBottomActionsChange: (actions: ReaderBottomActionConfig[]) => void = (_actions: ReaderBottomActionConfig[]) => {};
  onTopActionsChange: (actions: ReaderBottomActionConfig[]) => void = (_actions: ReaderBottomActionConfig[]) => {};
  onProgressBehaviorChange: (value: string) => void = (_value: string) => {};
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
          .backgroundColor('#292A31').borderRadius(19).onClick(() => this.onBack())
        Text('阅读界面').fontSize(17).fontColor('#E5E6EB').margin({ left: 10 })
        Blank()
      }.padding({ left: 16, right: 16, bottom: 14 })

      if (this.selectedSettingsTab === 0) {
      Column() {
        Row() {
          Text('字号').fontSize(14).fontColor('#D9DAE0').layoutWeight(1)
          Image($r('app.media.app_reduce')).width(16).height(16).fillColor('#E5E6EB').width(36).height(36)
            .backgroundColor('#292A31').borderRadius(18)
            .onClick(() => this.onFontSizeChange(Math.max(15, this.fontSize - 1)))
          Text(`${this.fontSize}`).fontSize(14).fontColor('#E5E6EB').width(42).textAlign(TextAlign.Center)
          Image($r('app.media.app_add')).width(18).height(18).fillColor('#E5E6EB').width(36).height(36)
            .backgroundColor('#292A31').borderRadius(18)
            .onClick(() => this.onFontSizeChange(Math.min(30, this.fontSize + 1)))
          Text('Tт').fontSize(17).fontColor('#E5E6EB').padding({ left: 13, right: 13, top: 8, bottom: 8 })
            .backgroundColor('#292A31').borderRadius(10).margin({ left: 10 })
            .onClick(() => this.openDetailSheet('排版设置', '正文、标题、页眉页脚与边距设置'))
        }.padding(12).backgroundColor('#202127').borderRadius(13)

        Row() {
          Text('背景').fontSize(14).fontColor('#D9DAE0').layoutWeight(1)
          Text('长按自定义').fontSize(10).fontColor('#8F929D')
            .onClick(() => this.openDetailSheet('自定义阅读背景', '背景图片、背景颜色与文字颜色设置'))
          Image($r('app.media.app_visibility')).width(18).height(18).fillColor('#D9DAE0').margin({ left: 10 })
            .onClick(() => this.openDetailSheet('护眼设置', '护眼模式与色温参数'))
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
          }.height(100)
        }.width('100%').height(100).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)

        Row() {
          Text('翻页动画').fontSize(12).fontColor('#D9DAE0').layoutWeight(1)
          Text(this.pageAnimation).fontSize(11).fontColor('#D9DAE0').padding(8)
            .backgroundColor('#292A31').borderRadius(8)
            .onClick(() => this.openDetailSheet('翻页动画', '覆盖、滑动、仿真、滚动、淡入淡出、无动画'))
          Image($r('app.media.app_anim_speed')).width(20).height(20).fillColor('#D9DAE0').margin({ left: 12 })
            .onClick(() => this.openDetailSheet('翻页动画速度', `当前：${this.animationSpeed}；可选极速、快速、适中、优雅`))
          Image($r('app.media.app_padding')).width(20).height(20).fillColor('#D9DAE0').margin({ left: 14 })
            .onClick(() => this.openDetailSheet('页边距', '页面内边距与正文留白设置'))
        }.padding(13).backgroundColor('#202127').borderRadius(13).margin({ top: 13 })
      }.padding({ left: 14, right: 14 })

      Blank().layoutWeight(1)
      } else if (this.selectedSettingsTab === 1) {
        this.menuSettingsContent()
      } else if (this.selectedSettingsTab === 2) {
        this.informationSettingsContent()
      } else {
        this.moreSettingsContent()
      }

      Row() {
        Text('全局').fontSize(10).fontColor('#E7E8ED').layoutWeight(1).textAlign(TextAlign.Center)
          .backgroundColor(this.selectedSettingsTab === 0 ? '#454B62' : '#1E1F25')
          .borderRadius(15).padding(8).onClick(() => this.selectedSettingsTab = 0)
        Text('菜单').fontSize(10).fontColor('#C1C2CA').layoutWeight(1).textAlign(TextAlign.Center)
          .backgroundColor(this.selectedSettingsTab === 1 ? '#454B62' : '#1E1F25')
          .borderRadius(15).padding(8).onClick(() => this.selectedSettingsTab = 1)
        Text('信息').fontSize(10).fontColor('#C1C2CA').layoutWeight(1).textAlign(TextAlign.Center)
          .backgroundColor(this.selectedSettingsTab === 2 ? '#454B62' : '#1E1F25')
          .borderRadius(15).padding(8).onClick(() => this.selectedSettingsTab = 2)
        Text('更多').fontSize(10).fontColor('#C1C2CA').layoutWeight(1).textAlign(TextAlign.Center)
          .backgroundColor(this.selectedSettingsTab === 3 ? '#454B62' : '#1E1F25')
          .borderRadius(15).padding(8).onClick(() => this.selectedSettingsTab = 3)
      }.padding({ left: 14, right: 14, top: 10, bottom: 16 })
    }.width('100%').height('100%')
      .backgroundColor(this.asSheet ? '#D91A1B21' : '#1A1B21')
      .borderRadius(this.asSheet ? 22 : 0).clip(this.asSheet)
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
            MenuSettingOption({
              title: entry.title,
              detail: entry.detail,
              migrated: entry.title === '底栏按钮配置' || entry.title === '标题栏操作按钮'
            })
              .margin({ left: 14, right: 14, bottom: 8 })
              .onClick(() => {
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
                } else if (entry.title === '标题栏悬浮图标配置') {
                  this.openDetailSheet('标题栏悬浮图标配置', '显示位置、操作图标及按钮背景样式');
                } else {
                  this.onUnavailableAction(`${entry.title}设置逻辑尚未迁移`);
                }
              })
          }, (entry: ReaderMenuSettingsEntry) => `${this.selectedMenuSettingsTab}-${entry.title}`)
        }.width('100%').padding({ top: 4, bottom: 8 })
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').layoutWeight(1)
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
      }.width('100%').padding({ left: 14, right: 14, bottom: 8 })
      Scroll() {
        Column() {
          MenuSettingSwitch({ title: '显示页眉/页脚', detail: '在阅读页面显示章节与进度信息', checked: true })
            .onClick(() => this.openDetailSheet('显示信息', '点击切换显示状态；此设置项尚未迁移到阅读渲染逻辑'))
          MenuSettingOption({ title: '信息显示模式', detail: '章节信息 / 阅读进度 / 自定义' })
            .onClick(() => this.openDetailSheet('信息显示模式', '选择显示模式：章节标题、阅读进度或自定义提示'))
          MenuSettingOption({ title: this.infoSubTab === 0 ? '页眉左侧内容' : '页脚左侧内容', detail: '点击编辑自定义显示内容' })
            .onClick(() => this.openDetailSheet('自定义提示', '支持书名、章节名、页码、时间等信息变量'))
          MenuSettingOption({ title: this.infoSubTab === 0 ? '页眉中间内容' : '页脚中间内容', detail: '自定义提示文本' })
            .onClick(() => this.openDetailSheet('自定义提示', '编辑中间位置的阅读信息'))
          MenuSettingOption({ title: this.infoSubTab === 0 ? '页眉右侧内容' : '页脚右侧内容', detail: '自定义提示文本' })
            .onClick(() => this.openDetailSheet('自定义提示', '编辑右侧位置的阅读信息'))
          MenuSettingOption({ title: '信息字体', detail: '字体、字号与字重' })
            .onClick(() => this.openDetailSheet('信息字体', '默认字体 / 系统字体 / 自定义字体'))
          MenuSettingOption({ title: '信息颜色', detail: '日间与夜间颜色' })
            .onClick(() => this.openDetailSheet('信息颜色', '选择颜色并分别预览日间与夜间效果'))
          MenuSettingSwitch({ title: '显示分割线', detail: '在正文与信息区域之间显示细线', checked: false })
            .onClick(() => this.openDetailSheet('分割线', '切换页眉/页脚分割线；业务逻辑尚未迁移'))
          Text('部分信息显示项尚未迁移').fontSize(10).fontColor('#92949E').width('100%').textAlign(TextAlign.Center).padding(12)
        }.width('100%').padding({ left: 14, right: 14, bottom: 12 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').layoutWeight(1)
  }

  @Builder
  private moreSettingsContent() {
    Column() {
      Row() {
        Text('屏幕').fontSize(11).fontColor(this.moreSubTab === 0 ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center).backgroundColor(this.moreSubTab === 0 ? '#454B62' : '#202127')
          .borderRadius(14).padding(8).onClick(() => this.moreSubTab = 0)
        Text('翻页').fontSize(11).fontColor(this.moreSubTab === 1 ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center).backgroundColor(this.moreSubTab === 1 ? '#454B62' : '#202127')
          .borderRadius(14).padding(8).margin({ left: 6 }).onClick(() => this.moreSubTab = 1)
        Text('其他').fontSize(11).fontColor(this.moreSubTab === 2 ? '#ECECF0' : '#B7B8C1')
          .layoutWeight(1).textAlign(TextAlign.Center).backgroundColor(this.moreSubTab === 2 ? '#454B62' : '#202127')
          .borderRadius(14).padding(8).margin({ left: 6 }).onClick(() => this.moreSubTab = 2)
      }.width('100%').padding({ left: 14, right: 14, bottom: 8 })
      Scroll() {
        Column() {
          if (this.moreSubTab === 0) {
            Text('屏幕设置').fontSize(12).fontColor('#AFC2FF').width('100%').padding({ left: 4, top: 6, bottom: 4 })
            MenuSettingOption({ title: '屏幕方向', detail: '跟随系统 / 竖屏 / 横屏' }).onClick(() => this.openDetailSheet('屏幕方向', '选择系统、竖屏或横屏'))
            MenuSettingOption({ title: '保持屏幕常亮', detail: '永不 / 5分钟 / 10分钟 / 跟随系统' }).onClick(() => this.openDetailSheet('保持屏幕常亮', '设置阅读期间的屏幕超时'))
            MenuSettingSwitch({ title: '隐藏状态栏', detail: '沉浸式阅读', checked: false }).onClick(() => this.showNotMigrated('隐藏状态栏'))
            MenuSettingSwitch({ title: '隐藏导航栏', detail: '沉浸式阅读', checked: false }).onClick(() => this.showNotMigrated('隐藏导航栏'))
            MenuSettingSwitch({ title: '适配刘海屏', detail: '为显示缺口留出安全区域', checked: true }).onClick(() => this.showNotMigrated('适配刘海屏'))
            MenuSettingSwitch({ title: '正文行高适配', detail: '修正特殊排版行距', checked: true }).onClick(() => this.showNotMigrated('正文行高适配'))
            MenuSettingSwitch({ title: '适配特殊样式', detail: '保留书籍正文样式', checked: true }).onClick(() => this.showNotMigrated('适配特殊样式'))
            MenuSettingSwitch({ title: '中文排版', detail: '优化中文标点与排版', checked: true }).onClick(() => this.showNotMigrated('中文排版'))
            MenuSettingOption({ title: '护眼设置', detail: '护眼模式与色温' }).onClick(() => this.openDetailSheet('护眼设置', '配置护眼模式、色温与日夜参数'))
          } else if (this.moreSubTab === 1) {
            Text('翻页控制').fontSize(12).fontColor('#AFC2FF').width('100%').padding({ left: 4, top: 6, bottom: 4 })
            MenuSettingOption({ title: '横屏双页', detail: '关闭 / 左右双页' }).onClick(() => this.openDetailSheet('横屏双页', '单页或左右双页阅读'))
            MenuSettingOption({ title: '进度条行为', detail: '页码进度 / 章节进度' }).onClick(() => this.openDetailSheet('进度条行为', '设置拖动进度条的定位方式'))
            MenuSettingSwitch({ title: '音量键翻页', detail: '按音量键切换页面', checked: false }).onClick(() => this.showNotMigrated('音量键翻页'))
            MenuSettingSwitch({ title: '音量键长按翻页', detail: '长按连续翻页', checked: false }).onClick(() => this.showNotMigrated('音量键长按翻页'))
            MenuSettingSwitch({ title: '鼠标滚轮翻页', detail: '连接鼠标时用滚轮翻页', checked: false }).onClick(() => this.showNotMigrated('鼠标滚轮翻页'))
            MenuSettingSwitch({ title: '滑动添加书签', detail: '在页面边缘滑动添加书签', checked: false }).onClick(() => this.showNotMigrated('滑动添加书签'))
            MenuSettingOption({ title: '书签标记', detail: '选择或恢复默认书签徽标' }).onClick(() => this.openDetailSheet('书签标记', '选择书签徽标图片；图片选择能力尚未迁移'))
            MenuSettingSlider({ title: '书签标记大小', value: 24, minValue: 0, maxValue: 50 })
          } else {
            Text('其他设置').fontSize(12).fontColor('#AFC2FF').width('100%').padding({ left: 4, top: 6, bottom: 4 })
            MenuSettingSwitch({ title: '进度条触感反馈', detail: '拖动时提供触觉反馈', checked: false }).onClick(() => this.showNotMigrated('进度条触感反馈'))
            MenuSettingSwitch({ title: '文字选择触感反馈', detail: '选择正文时提供触觉反馈', checked: false }).onClick(() => this.showNotMigrated('文字选择触感反馈'))
            MenuSettingSwitch({ title: '使用新版目录', detail: '使用新的目录面板', checked: true }).onClick(() => this.showNotMigrated('使用新版目录'))
            MenuSettingSlider({ title: '无目录书籍分段长度', value: 20000, minValue: 3000, maxValue: 100000 })
            MenuSettingSwitch({ title: '自动切换书源', detail: '当前书源失效时尝试其它书源', checked: false }).onClick(() => this.showNotMigrated('自动切换书源'))
            MenuSettingSwitch({ title: '换源后应用于全部书籍', detail: '换源结果同步应用到其它书籍', checked: false }).onClick(() => this.showNotMigrated('换源后应用于全部书籍'))
            MenuSettingSwitch({ title: '跟随日夜模式提醒', detail: '提示切换阅读背景', checked: false }).onClick(() => this.showNotMigrated('跟随日夜模式提醒'))
            MenuSettingSwitch({ title: '阅读位置锚点', detail: '保存与恢复阅读位置', checked: true }).onClick(() => this.showNotMigrated('阅读位置锚点'))
            MenuSettingSwitch({ title: '朗读悬浮窗分离提醒', detail: '分离朗读控制时显示提醒', checked: true }).onClick(() => this.showNotMigrated('朗读悬浮窗分离提醒'))
            MenuSettingSwitch({ title: '允许选择正文', detail: '长按正文显示选择菜单', checked: true }).onClick(() => this.showNotMigrated('允许选择正文'))
            MenuSettingSwitch({ title: '优化正文渲染', detail: '使用优化渲染方式', checked: true }).onClick(() => this.showNotMigrated('优化正文渲染'))
            MenuSettingSwitch({ title: '滚动翻页无动画', detail: '关闭滚动翻页过渡动画', checked: false }).onClick(() => this.showNotMigrated('滚动翻页无动画'))
            MenuSettingOption({ title: '点击图片行为', detail: '查看图片 / 无操作' }).onClick(() => this.openDetailSheet('点击图片行为', '选择正文图片的点击行为'))
            MenuSettingOption({ title: '点击区域配置', detail: '设置屏幕各区域的触摸动作' }).onClick(() => this.openDetailSheet('点击区域配置', '点击区域映射面板尚未迁移'))
            MenuSettingOption({ title: '自定义翻页按键', detail: '配置键盘快捷键' }).onClick(() => this.openDetailSheet('自定义翻页按键', '按键映射面板尚未迁移'))
            MenuSettingOption({ title: '选中文字菜单', detail: '配置文本选择后的操作' }).onClick(() => this.openDetailSheet('选中文字菜单', '文本操作菜单配置尚未迁移'))
            MenuSettingSwitch({ title: '禁用返回键', detail: '阻止阅读时返回键退出', checked: false }).onClick(() => this.showNotMigrated('禁用返回键'))
            MenuSettingSwitch({ title: '显示阅读标题补充信息', detail: '在阅读标题中显示附加信息', checked: false }).onClick(() => this.showNotMigrated('阅读标题补充信息'))
            MenuSettingSwitch({ title: '显示菜单图标', detail: '在阅读菜单中显示图标', checked: true }).onClick(() => this.showNotMigrated('显示菜单图标'))
          }
          Text('未迁移项目保留原版设置入口；当前仅呈现设置界面，不执行对应业务。')
            .fontSize(10).fontColor('#92949E').width('100%').textAlign(TextAlign.Center).padding(12)
        }.width('100%').padding({ left: 14, right: 14, bottom: 12 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').layoutWeight(1)
  }

  private openDetailSheet(title: string, description: string): void {
    this.detailSheetTitle = title;
    this.detailSheetDescription = description;
    this.detailSheetVisible = true;
  }

  private showNotMigrated(title: string): void {
    this.openDetailSheet(title, '此选项的原版 UI 已呈现；实际设置逻辑尚未迁移。');
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
        Row() {
          Text('默认').fontSize(12).fontColor('#D9DAE0').layoutWeight(1).textAlign(TextAlign.Center)
            .padding(10).backgroundColor('#292A31').borderRadius(10).onClick(() => this.detailSheetVisible = false)
          Text('尚未迁移').fontSize(12).fontColor('#D9DAE0').layoutWeight(1).textAlign(TextAlign.Center)
            .padding(10).backgroundColor('#454B62').borderRadius(10).margin({ left: 8 }).onClick(() => this.detailSheetVisible = false)
        }.width('100%').padding({ left: 18, right: 18, bottom: 18 })
      }.width('88%').backgroundColor('#F21A1B21').borderRadius(22)
    }.width('100%').height('100%')
  }

  private getMenuSettingsEntries(): ReaderMenuSettingsEntry[] {
    if (this.selectedMenuSettingsTab === 0) {
      return [
        { title: '工具栏样式', detail: '系统 / 跟随阅读背景 / 自定义' },
        { title: '调色板风格', detail: '跟随系统颜色 / 固定风格' },
        { title: '菜单颜色来源', detail: '种子色 / 自定义主题色' },
        { title: '菜单背景颜色', detail: '日间与夜间背景色' },
        { title: '菜单强调颜色', detail: '日间与夜间强调色' },
        { title: '菜单容器颜色', detail: '日间与夜间容器色' },
        { title: '显示亮度视图', detail: '关闭 / 横向 / 竖向' },
        { title: '亮度条位置', detail: '顶栏 / 底栏' },
        { title: '菜单栏边框宽度', detail: '设置边框粗细' },
        { title: '菜单栏边框颜色', detail: '日间 / 夜间' },
        { title: '菜单模糊半径', detail: '0–32 dp' },
        { title: '菜单模糊透明度', detail: '0–100%' },
        { title: '菜单文字颜色', detail: '日间 / 夜间' },
        { title: '菜单模糊颜色', detail: '日间 / 夜间' },
        { title: '显示标题栏图标', detail: '显示/隐藏悬浮操作图标' },
        { title: '标题栏悬浮图标配置', detail: '图标内容与显示位置' }
      ];
    }
    if (this.selectedMenuSettingsTab === 1) {
      return [
        { title: '进度条模式', detail: '页码 / 章节' },
        { title: '显示图标文字', detail: '显示或隐藏底栏文字标签' },
        { title: '底栏图标样式', detail: '纯色 / 色调 / 描边' },
        { title: '每行图标数', detail: '2–8 项' },
        { title: '底栏图标行数', detail: '单行 / 双行' },
        { title: '底栏按钮配置', detail: '排序、显示与长按动作' },
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
    if (id === 'search') { return '全文搜索'; }
    if (id === 'autoPage') { return '自动翻页'; }
    if (id === 'catalog') { return '目录'; }
    if (id === 'voice') { return '朗读'; }
    return '设置';
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
    return id === 'charset' ? '设置编码' : '更多操作';
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
                if (item.id === 'search') {
                  Image($r('app.media.reader_search')).width(20).height(20).fillColor('#D5C2C6').margin({ right: 12 })
                } else if (item.id === 'autoPage') {
                  Image($r('app.media.reader_play')).width(20).height(20).fillColor('#D5C2C6').margin({ right: 12 })
                } else if (item.id === 'catalog') {
                  Image($r('app.media.reader_toc')).width(20).height(20).fillColor('#D5C2C6').margin({ right: 12 })
                } else if (item.id === 'voice') {
                  Image($r('app.media.reader_voice')).width(20).height(20).fillColor('#D5C2C6').margin({ right: 12 })
                } else {
                  Image($r('app.media.reader_settings')).width(20).height(20).fillColor('#D5C2C6').margin({ right: 12 })
                }
                Text(this.getBottomActionLabel(item.id)).fontSize(14)
                  .fontColor(item.enabled ? '#E5E6EB' : '#777984').layoutWeight(1)
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
        Column() {
          ForEach(this.draftTopActions, (item: ReaderBottomActionConfig, index: number) => {
            Row() {
              Image(item.id === 'charset' ? $r('app.media.reader_translate') : $r('app.media.reader_more'))
                .width(24).height(24).fillColor(item.enabled ? '#D5C2C6' : '#777984').margin({ right: 12 })
              Text(this.getTopActionLabel(item.id)).fontSize(14)
                .fontColor(item.enabled ? '#E5E6EB' : '#777984').layoutWeight(1)
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
      }.width('100%').height('34%').backgroundColor('#D91A1B21')
        .borderRadius({ topLeft: 24, topRight: 24 })
    }.width('100%').height('100%')
  }

  build() {
    if (this.asSheet) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column().width('100%').height('100%').backgroundColor('#88000000').onClick(() => this.onBack())
        Column() {
          this.settingsContent(true)
        }.width('92%').height('68%').alignSelf(ItemAlign.Center)
          .backgroundColor('#D91A1B21').borderRadius(22)
          .margin({ left: 8, right: 8, bottom: 16 })
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
  onChange: (value: number) => void = (_value: number) => {};

  build() {
    Column() {
      Row() {
        Text(this.title).fontSize(13).fontColor('#E2E3E8').layoutWeight(1)
        Text(`${this.value}`).fontSize(12).fontColor('#D3D4DC')
      }.width('100%')
      Slider({ value: this.value, min: this.minValue, max: this.maxValue, step: 1, style: SliderStyle.InSet })
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
    }.width(68).height(96).justifyContent(FlexAlign.Center).backgroundColor(this.color)
      .borderRadius(11).border({ width: this.selected ? 2 : 1, color: this.selected ? '#AFC2FF' : '#33343C' })
  }
}
