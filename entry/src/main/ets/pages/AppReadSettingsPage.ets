import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';

@Component
export struct AppReadSettingsPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State collapsedHeader: boolean = false;
  private settingsScroller: Scroller = new Scroller();

  private updateHeader(): void {
    const offset = this.settingsScroller.currentOffset().yOffset;
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      animateTo({ duration: 220, curve: Curve.EaseInOut }, () => this.collapsedHeader = shouldCollapse);
    }
  }

  build() {
    Column() {
      CollapsingSettingsHeader({ title: '阅读设置', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Scroll(this.settingsScroller) {
        Column() {
          ReadSettingsSection({ title: '屏幕设置' }) {
            ReadSettingsChoice({ title: '屏幕方向', options: ['跟随系统', '竖屏', '横屏', '传感器', '反向竖屏', '反向横屏'] })
            ReadSettingsChoice({ title: '保持屏幕常亮', options: ['系统默认', '1 分钟', '5 分钟', '10 分钟', '始终'] })
            ReadSettingsSwitch({ title: '隐藏状态栏' })
            ReadSettingsSwitch({ title: '隐藏导航栏' })
            ReadSettingsSwitch({ title: '为显示缺口留出空间' })
            ReadSettingsChoice({ title: '标题栏显示方式', options: ['标题栏内', '单独一行', '仅章节名', '不显示'] })
            ReadSettingsSlider({ title: '阅读菜单透明度', value: 85, maxValue: 100 })
            ReadSettingsSwitch({ title: '正文行高调整' })
            ReadSettingsSwitch({ title: '换源后自动切换整本书' })
            ReadSettingsSwitch({ title: '正文两端对齐' })
            ReadSettingsSwitch({ title: '段落末行对齐' })
            ReadSettingsSwitch({ title: '适配特殊排版' })
            ReadSettingsSwitch({ title: '中文排版优化' })
            ReadSettingsAction({ title: '护眼模式', detail: '护眼与定时设置', onSelect: () => this.onUnavailableAction('护眼模式设置尚未接入') })
            ReadSettingsChoice({ title: '亮度调节条', options: ['关闭', '横向', '纵向'] })
            ReadSettingsSwitch({ title: '显示下划线' })
          }

          ReadSettingsSection({ title: '翻页设置' }) {
            ReadSettingsChoice({ title: '进度条显示方式', options: ['始终显示', '关闭'] })
            ReadSettingsChoice({ title: '横屏双页', options: ['单页', '双页', '横屏双页', '平板或横屏双页'] })
            ReadSettingsChoice({ title: '进度条拖动行为', options: ['调整章节内位置', '调整章节索引'] })
            ReadSettingsSwitch({ title: '鼠标滚轮翻页' })
            ReadSettingsSwitch({ title: '音量键翻页' })
            ReadSettingsSwitch({ title: '朗读时音量键翻页' })
            ReadSettingsSwitch({ title: '长按按键翻页' })
            ReadSettingsSlider({ title: '翻页触摸灵敏度', value: 0, maxValue: 1000 })
          }

          ReadSettingsSection({ title: '其它' }) {
            ReadSettingsSwitch({ title: '滑动时震动' })
            ReadSettingsSwitch({ title: '使用新版目录面板' })
            ReadSettingsSlider({ title: '无目录章节最大长度', value: 3000, maxValue: 100000 })
            ReadSettingsSwitch({ title: '选中文本时震动' })
            ReadSettingsSwitch({ title: '自动切换书源' })
            ReadSettingsSwitch({ title: '提示切换日间/夜间主题' })
            ReadSettingsSwitch({ title: '阅读位置锚点' })
            ReadSettingsSwitch({ title: '朗读时提示分离控制' })
            ReadSettingsSwitch({ title: '允许选择正文文本' })
            ReadSettingsSwitch({ title: '关闭滚动动画' })
            ReadSettingsChoice({ title: '点击图片方式', options: ['新版行为', '预览图片', '经典', '禁用点击', '双击'] })
            ReadSettingsSwitch({ title: '优化渲染' })
            ReadSettingsAction({ title: '点击区域设置', onSelect: () => this.onUnavailableAction('点击区域配置尚未接入') })
            ReadSettingsSwitch({ title: '禁用返回键' })
            ReadSettingsAction({ title: '自定义翻页按键', onSelect: () => this.onUnavailableAction('自定义按键设置尚未接入') })
            ReadSettingsSwitch({ title: '标题栏显示附加信息' })
            ReadSettingsSwitch({ title: '显示菜单图标' })
          }
          Text('此页控件目前用于界面预览；设置保存和护眼/按键子面板尚未接入。')
            .fontSize(15).fontColor('#858792').margin({ left: 18, right: 18, top: 6, bottom: 22 })
        }.width('100%').padding({ top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct ReadSettingsSection {
  @Prop title: string = '';
  @BuilderParam content: () => void = this.emptyContent;
  @Builder
  emptyContent() {
  }
  build() {
    Column() {
      Text(this.title).fontSize(18).fontWeight(FontWeight.Medium).fontColor('#AFC2FF')
        .alignSelf(ItemAlign.Start).padding({ left: 18, top: 14, bottom: 8 })
      Column() { this.content() }.margin({ left: 16, right: 16 }).backgroundColor('#1A1B21').borderRadius(16)
    }
  }
}

@Component
struct ReadSettingsSwitch {
  @Prop title: string = '';
  @State toggleValue: boolean = false;
  build() {
    Row() {
      Text(this.title).fontSize(18).fontColor('#D8D9E0').layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.toggleValue })
        .onChange((value: boolean) => this.toggleValue = value)
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }
}

@Component
struct ReadSettingsChoice {
  @Prop title: string = '';
  @Prop options: string[] = [];
  @State selectedIndex: number = 0;
  private getSelectedLabel(): string {
    if (this.options.length === 0) { return ''; }
    const index = Math.min(this.selectedIndex, this.options.length - 1);
    return this.options[index];
  }
  build() {
    Row() {
      Text(this.title).fontSize(18).fontColor('#D8D9E0').layoutWeight(1)
      Text(this.getSelectedLabel()).fontSize(12).fontColor('#AFC2FF')
      Image($r('app.media.reader_next')).width(15).height(15).fillColor('#92949E').margin({ left: 6 })
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .onClick(() => {
        if (this.options.length > 0) {
          this.selectedIndex = (this.selectedIndex + 1) % this.options.length;
        }
      })
  }
}

@Component
struct ReadSettingsSlider {
  @Prop title: string = '';
  @Prop value: number = 50;
  @Prop maxValue: number = 100;
  @State sliderValue: number = 50;
  aboutToAppear(): void {
    this.sliderValue = this.value;
  }
  build() {
    Column() {
      Row() {
        Text(this.title).fontSize(18).fontColor('#D8D9E0').layoutWeight(1)
        Text(`${Math.round(this.sliderValue)}`).fontSize(12).fontColor('#AFC2FF')
      }
      Slider({ value: this.sliderValue, min: 0, max: this.maxValue, step: 1 })
        .selectedColor('#AFC2FF').trackColor('#454750')
        .onChange((value: number) => this.sliderValue = value)
    }.padding({ left: 14, right: 14, top: 9, bottom: 9 })
  }
}

@Component
struct ReadSettingsAction {
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(18).fontColor('#D8D9E0')
        if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor('#92949E').margin({ top: 3 }) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(15).height(15).fillColor('#92949E')
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 }).onClick(() => this.onSelect())
  }
}
