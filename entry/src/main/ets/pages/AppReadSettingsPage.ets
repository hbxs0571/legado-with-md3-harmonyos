import curves from '@ohos.curves';
import { UiSection } from '../components/settings/UiSection';
import { UiSwitch } from '../components/settings/UiSwitch';
import { UiChoice } from '../components/settings/UiChoice';
import { UiSlider } from '../components/settings/UiSlider';
import { UiAction } from '../components/settings/UiAction';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';

@Component
export struct AppReadSettingsPage {
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State collapsedHeader: boolean = false;
  // 注意：阅读设置的取值尚未接 ReaderSettingsRepository（上游对应
  // app/src/main/java/io/legado/app/domain/model/settings/ReadSettings.kt 的
  // screenOrientation / keepScreenOn 等键）。本页暂时用本地 State 与 preview 模式
  // 保持「点了会变」，与改造前行为一致；落库是另一件事，不要在这个提交里顺手做。
  @State screenOrientationIndex: number = 0;
  @State screenKeepOnIndex: number = 1;
  @State titleBarModeIndex: number = 0;
  @State brightnessBarIndex: number = 0;
  @State progressBarModeIndex: number = 0;
  @State landscapeDoublePageIndex: number = 0;
  @State progressDragBehaviorIndex: number = 0;
  @State clickImageModeIndex: number = 0;
  @State menuAlpha: number = 85;
  @State touchSensitivity: number = 0;
  @State noTocChapterMaxLength: number = 3000;
  private settingsScroller: Scroller = new Scroller();

  private updateHeader(): void {
    const offset = this.settingsScroller.currentOffset().yOffset;
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      // 顶部折叠是位移，用弹簧收尾更自然；弹簧不吃 duration，删掉（写了也不生效）。
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
    }
  }

  build() {
    Column() {
      CollapsingSettingsHeader({ title: '阅读设置', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Scroll(this.settingsScroller) {
        Column() {
          UiSection({ title: '屏幕设置' }) {
            UiChoice({ title: '屏幕方向', options: ['跟随系统', '竖屏', '横屏', '传感器', '反向竖屏', '反向横屏'], selectedIndex: this.screenOrientationIndex, onSelect: (index: number) => { this.screenOrientationIndex = index; } })
            UiChoice({ title: '保持屏幕常亮', options: ['系统默认', '1 分钟', '5 分钟', '10 分钟', '始终'], selectedIndex: this.screenKeepOnIndex, onSelect: (index: number) => { this.screenKeepOnIndex = index; } })
            UiSwitch({ title: '隐藏状态栏', preview: true })
            UiSwitch({ title: '隐藏导航栏', preview: true })
            UiSwitch({ title: '为显示缺口留出空间', preview: true })
            UiChoice({ title: '标题栏显示方式', options: ['标题栏内', '单独一行', '仅章节名', '不显示'], selectedIndex: this.titleBarModeIndex, onSelect: (index: number) => { this.titleBarModeIndex = index; } })
            UiSlider({ title: '阅读菜单透明度', value: this.menuAlpha, maxValue: 100, minValue: 0, onChange: (value: number) => { this.menuAlpha = value; } })
            UiSwitch({ title: '正文行高调整', preview: true })
            UiSwitch({ title: '换源后自动切换整本书', preview: true })
            UiSwitch({ title: '正文两端对齐', preview: true })
            UiSwitch({ title: '段落末行对齐', preview: true })
            UiSwitch({ title: '适配特殊排版', preview: true })
            UiSwitch({ title: '中文排版优化', preview: true })
            UiAction({ title: '护眼模式', detail: '护眼与定时设置', onSelect: () => this.onUnavailableAction('护眼模式设置尚未接入') })
            UiChoice({ title: '亮度调节条', options: ['关闭', '横向', '纵向'], selectedIndex: this.brightnessBarIndex, onSelect: (index: number) => { this.brightnessBarIndex = index; } })
            UiSwitch({ title: '显示下划线', preview: true })
          }

          UiSection({ title: '翻页设置' }) {
            UiChoice({ title: '进度条显示方式', options: ['始终显示', '关闭'], selectedIndex: this.progressBarModeIndex, onSelect: (index: number) => { this.progressBarModeIndex = index; } })
            UiChoice({ title: '横屏双页', options: ['单页', '双页', '横屏双页', '平板或横屏双页'], selectedIndex: this.landscapeDoublePageIndex, onSelect: (index: number) => { this.landscapeDoublePageIndex = index; } })
            UiChoice({ title: '进度条拖动行为', options: ['调整章节内位置', '调整章节索引'], selectedIndex: this.progressDragBehaviorIndex, onSelect: (index: number) => { this.progressDragBehaviorIndex = index; } })
            UiSwitch({ title: '鼠标滚轮翻页', preview: true })
            UiSwitch({ title: '音量键翻页', preview: true })
            UiSwitch({ title: '朗读时音量键翻页', preview: true })
            UiSwitch({ title: '长按按键翻页', preview: true })
            UiSlider({ title: '翻页触摸灵敏度', value: this.touchSensitivity, maxValue: 1000, minValue: 0, onChange: (value: number) => { this.touchSensitivity = value; } })
          }

          UiSection({ title: '其它' }) {
            UiSwitch({ title: '滑动时震动', preview: true })
            UiSwitch({ title: '使用新版目录面板', preview: true })
            UiSlider({ title: '无目录章节最大长度', value: this.noTocChapterMaxLength, maxValue: 100000, minValue: 0, onChange: (value: number) => { this.noTocChapterMaxLength = value; } })
            UiSwitch({ title: '选中文本时震动', preview: true })
            UiSwitch({ title: '自动切换书源', preview: true })
            UiSwitch({ title: '提示切换日间/夜间主题', preview: true })
            UiSwitch({ title: '阅读位置锚点', preview: true })
            UiSwitch({ title: '朗读时提示分离控制', preview: true })
            UiSwitch({ title: '允许选择正文文本', preview: true })
            UiSwitch({ title: '关闭滚动动画', preview: true })
            UiChoice({ title: '点击图片方式', options: ['新版行为', '预览图片', '经典', '禁用点击', '双击'], selectedIndex: this.clickImageModeIndex, onSelect: (index: number) => { this.clickImageModeIndex = index; } })
            UiSwitch({ title: '优化渲染', preview: true })
            UiAction({ title: '点击区域设置', onSelect: () => this.onUnavailableAction('点击区域配置尚未接入') })
            UiSwitch({ title: '禁用返回键', preview: true })
            UiAction({ title: '自定义翻页按键', onSelect: () => this.onUnavailableAction('自定义按键设置尚未接入') })
            UiSwitch({ title: '标题栏显示附加信息', preview: true })
            UiSwitch({ title: '显示菜单图标', preview: true })
          }
          Text('此页控件目前用于界面预览；设置保存和护眼/按键子面板尚未接入。')
            .fontSize(15).fontColor('#858792').margin({ left: 18, right: 18, top: 6, bottom: 22 })
        }.width('100%').padding({ top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}
