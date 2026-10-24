import { AppGlyph } from '../components/AppGlyph';

@Component
export struct ThemeSettingsPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State selectedMode: number = 2;
  @State selectedPalette: number = 0;
  @State pureBlack: boolean = false;
  @State showRefactorTip: boolean = true;
  @State showStatusBar: boolean = true;
  @State swipeAnimation: boolean = true;
  @State predictiveBack: boolean = true;
  @State sharedElement: boolean = true;
  @State followCoverColor: boolean = true;
  @State eyeProtectionEnabled: boolean = false;
  @State eyeProtectionAutoNight: boolean = false;
  @State eyeProtectionSchedule: boolean = false;
  @State blurEnabled: boolean = false;
  @State progressiveBlurEnabled: boolean = false;
  @State containerBackgroundEnabled: boolean = false;
  @State disableGroupCorner: boolean = false;
  @State overrideCardCorner: boolean = false;
  @State overrideCardBorder: boolean = false;
  @State dividerEnabled: boolean = false;

  private paletteColor(index: number): string {
    if (index === 0) { return '#B9C8FF'; }
    if (index === 1) { return '#A6D28A'; }
    if (index === 2) { return '#F4D45E'; }
    if (index === 3) { return '#B7B8BC'; }
    return '#85B7FF';
  }

  private paletteDarkColor(index: number): string {
    if (index === 0) { return '#5C637F'; }
    if (index === 1) { return '#315449'; }
    if (index === 2) { return '#665C32'; }
    if (index === 3) { return '#55565A'; }
    return '#385C8A';
  }

  build() {
    Column() {
      Column() {
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
          }.width(32).height(32).backgroundColor('#1C1D23').borderRadius(16).onClick(() => this.onBack())
          Blank()
        }.width('100%')
        Text('外观').fontSize(24).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
          .alignSelf(ItemAlign.Start).margin({ top: 7 })
      }.width('100%').padding({ left: 16, right: 16, top: 4, bottom: 6 })

      Scroll() {
        Column() {
          Column() {
            Column() {
              Row().width(54).height(12).backgroundColor('#AEB0B8').borderRadius(6)
              Column() {
                Row().width(30).height(5).backgroundColor('#AFC2FF').borderRadius(3)
                Row().width(42).height(7).backgroundColor('#D8D9E0').borderRadius(4).margin({ top: 8 })
                Row().width(34).height(6).backgroundColor('#858792').borderRadius(3).margin({ top: 5 })
              }.width(62).height(95).padding(9).margin({ top: 8 }).backgroundColor('#454B62').borderRadius(8)
                .alignItems(HorizontalAlign.Start)
            }.width('100%').alignItems(HorizontalAlign.Start)
            Blank().layoutWeight(1)
            Row() {
              Row().width(28).height(8).backgroundColor(this.paletteColor(this.selectedPalette)).borderRadius(5)
              Blank()
              Row().width(14).height(14).backgroundColor(this.paletteColor(this.selectedPalette)).borderRadius(7)
            }.width('100%').padding({ left: 8, right: 8, top: 10, bottom: 10 })
              .backgroundColor('#1C1D23').borderRadius(10)
          }.width(112).height(224).padding(10).backgroundColor('#111217').borderRadius(22)
            .border({ width: 1, color: '#AFC2FF' })
            .alignSelf(ItemAlign.Center).margin({ top: 18, bottom: 16 })

          if (this.showRefactorTip) {
            Row() {
              Text('仍有部分界面未用Compose重构，这些界面会与大部分界面有较大差异。')
                .fontSize(14).fontColor('#D8D9E0').layoutWeight(1)
              AppGlyph({ name: 'profileClose', glyphSize: 18, tint: '#C5C7D0' })
                .onClick(() => this.showRefactorTip = false)
            }.width('calc(100% - 32vp)').padding(16).margin({ bottom: 24 })
              .backgroundColor('#1C1D23').borderRadius(16)
          }

          ThemeSectionTitle({ title: '主题模式' })
          Row() {
            ThemeModeItem({ title: '跟随系统', selected: this.selectedMode === 0, first: true,
              onSelect: () => this.selectedMode = 0 })
            ThemeModeItem({ title: '浅色', selected: this.selectedMode === 1,
              onSelect: () => this.selectedMode = 1 })
            ThemeModeItem({ title: '深色', selected: this.selectedMode === 2, last: true,
              onSelect: () => this.selectedMode = 2 })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16, bottom: 18 })
            .backgroundColor('#1A1B21').borderRadius(16)

          Row() {
            ForEach([0, 1, 2, 3, 4], (index: number) => {
              ThemePaletteItem({
                index: index,
                title: index === 0 ? '动态取色' : (index === 1 ? '草野' : (index === 2 ? '柠檬' : (index === 3 ? '黑白' : '晴空'))),
                lightColor: this.paletteColor(index),
                darkColor: this.paletteDarkColor(index),
                selected: this.selectedPalette === index,
                onSelect: () => this.selectedPalette = index
              })
            }, (index: number) => index.toString())
          }.width('100%').padding({ left: 16, right: 16, bottom: 20 })

          Column() {
            Row() {
              Column() {
                Text('纯黑深色模式').fontSize(16).fontColor('#D8D9E0')
                Text('使用纯黑阅读背景').fontSize(13).fontColor('#92949E').margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.pureBlack })
                .onChange((enabled: boolean) => this.pureBlack = enabled)
            }.padding({ left: 16, right: 16, top: 14, bottom: 14 })
            ThemeSettingsOption({ title: '字体设置', detail: '', onSelect: () => this.onUnavailableAction('字体设置尚未迁移') })
            ThemeSettingsOption({ title: '主题风格', detail: 'Material Design', onSelect: () => this.onUnavailableAction('主题风格切换尚未接入') })
            ThemeSettingsOption({ title: '切换图标', detail: '切换软件显示在桌面的图标', onSelect: () => this.onUnavailableAction('启动图标设置尚未迁移') })
            ThemeSwitchRow({ title: '预见性返回手势', detail: '启用系统预见性返回手势', checked: this.predictiveBack, onChange: (value: boolean) => { this.predictiveBack = value; this.onUnavailableAction('预见性返回设置暂未保存') } })
            ThemeSwitchRow({ title: '阅读界面共享元素动画', detail: '进入阅读界面时从封面展开，关闭后使用渐变过渡', checked: this.sharedElement, onChange: (value: boolean) => { this.sharedElement = value; this.onUnavailableAction('共享元素动画设置暂未保存') } })
            ThemeSettingsOption({ title: '字体大小', detail: '1.0x', onSelect: () => this.onUnavailableAction('字体缩放尚未迁移') })
            ThemeSettingsOption({ title: '主题管理', detail: '管理、导入导出完整主题包', onSelect: () => this.onUnavailableAction('主题包管理尚未迁移') })
            ThemeSettingsOption({ title: '背景图片', detail: '日间/夜间背景图与背景虚化', onSelect: () => this.onUnavailableAction('背景图片设置尚未迁移') })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor('#1A1B21').borderRadius(16)

          ThemeSectionTitle({ title: '主界面' }).margin({ top: 20 })
          Column() {
            ThemeSettingsOption({ title: '首页与导航', detail: '配置首页、发现、订阅、默认主页面和导航栏图标', onSelect: () => this.onUnavailableAction('首页与导航设置尚未迁移') })
            ThemeSwitchRow({ title: '显示状态栏', checked: this.showStatusBar, onChange: (value: boolean) => { this.showStatusBar = value; this.onUnavailableAction('状态栏设置暂未保存') } })
            ThemeSwitchRow({ title: '启用滑动时动画', checked: this.swipeAnimation, onChange: (value: boolean) => { this.swipeAnimation = value; this.onUnavailableAction('滑动动画设置暂未保存') } })
            ThemeSettingsOption({ title: '顶栏与底栏', detail: '配置顶栏按钮与底部导航栏', onSelect: () => this.onUnavailableAction('顶栏与底栏设置尚未迁移') })
            ThemeSettingsOption({ title: '导航布局', detail: '', onSelect: () => this.onUnavailableAction('导航布局设置尚未迁移') })
            ThemeSettingsOption({ title: '多窗布局', detail: '', onSelect: () => this.onUnavailableAction('多窗布局设置尚未迁移') })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor('#1A1B21').borderRadius(16)

          ThemeSectionTitle({ title: '书籍详情页' }).margin({ top: 20 })
          Column() {
            ThemeSwitchRow({ title: '界面颜色跟随封面取色', detail: '仅在显示背景封面时生效', checked: this.followCoverColor, onChange: (value: boolean) => { this.followCoverColor = value; this.onUnavailableAction('封面取色设置暂未保存') } })
            ThemeSettingsOption({ title: '网络封面背景设置', detail: '', onSelect: () => this.onUnavailableAction('网络封面背景设置尚未迁移') })
            ThemeSettingsOption({ title: '默认封面背景设置', detail: '', onSelect: () => this.onUnavailableAction('默认封面背景设置尚未迁移') })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor('#1A1B21').borderRadius(16)

          ThemeSectionTitle({ title: '护眼模式' }).margin({ top: 20 })
          Column() {
            ThemeSwitchRow({ title: '启用护眼模式', detail: '使用暖色调降低蓝光', checked: this.eyeProtectionEnabled, onChange: (value: boolean) => { this.eyeProtectionEnabled = value; this.onUnavailableAction('护眼模式设置暂未保存') } })
            ThemeSwitchRow({ title: '深色模式时自动开启', detail: '跟随阅读界面的深色/浅色模式自动切换', checked: this.eyeProtectionAutoNight, onChange: (value: boolean) => { this.eyeProtectionAutoNight = value; this.onUnavailableAction('护眼模式设置暂未保存') } })
            if (this.eyeProtectionEnabled) {
              ThemeSettingsOption({ title: '色温', detail: '', onSelect: () => this.onUnavailableAction('色温调节尚未迁移') })
              ThemeSwitchRow({ title: '定时开启', detail: '仅在设定的时间段内生效', checked: this.eyeProtectionSchedule, onChange: (value: boolean) => { this.eyeProtectionSchedule = value; this.onUnavailableAction('护眼定时尚未保存') } })
              if (this.eyeProtectionSchedule) {
                ThemeSettingsOption({ title: '开始时间', detail: '', onSelect: () => this.onUnavailableAction('时间选择尚未迁移') })
                ThemeSettingsOption({ title: '结束时间', detail: '', onSelect: () => this.onUnavailableAction('时间选择尚未迁移') })
              }
            }
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor('#1A1B21').borderRadius(16)

          ThemeSectionTitle({ title: '模糊效果' }).margin({ top: 20 })
          Column() {
            ThemeSwitchRow({ title: '启用控件模糊', checked: this.blurEnabled, onChange: (value: boolean) => { this.blurEnabled = value; this.onUnavailableAction('模糊效果设置暂未保存') } })
            if (this.blurEnabled) {
              ThemeSwitchRow({ title: '启用渐变模糊', checked: this.progressiveBlurEnabled, onChange: (value: boolean) => { this.progressiveBlurEnabled = value; this.onUnavailableAction('渐变模糊设置暂未保存') } })
            }
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor('#1A1B21').borderRadius(16)

          ThemeSectionTitle({ title: '容器设置' }).margin({ top: 20 })
          Column() {
            ThemeSwitchRow({ title: '容器背景图', detail: '大容器和项目分别使用独立的日间/夜间图片', checked: this.containerBackgroundEnabled, onChange: (value: boolean) => { this.containerBackgroundEnabled = value; this.onUnavailableAction('容器背景图片设置暂未保存') } })
            if (this.containerBackgroundEnabled) {
              ThemeSettingsOption({ title: '大容器背景图片', detail: '', onSelect: () => this.onUnavailableAction('背景图片选择尚未迁移') })
              ThemeSettingsOption({ title: '项目背景图片', detail: '', onSelect: () => this.onUnavailableAction('背景图片选择尚未迁移') })
            }
            ThemeSettingsOption({ title: '容器背景不透明度', detail: '', onSelect: () => this.onUnavailableAction('容器不透明度尚未迁移') })
            ThemeSwitchRow({ title: '关闭设置分组圆角', detail: '让设置分组使用直角外轮廓', checked: this.disableGroupCorner, onChange: (value: boolean) => { this.disableGroupCorner = value; this.onUnavailableAction('设置分组圆角暂未保存') } })
            ThemeSwitchRow({ title: '覆盖卡片圆角', detail: '关闭时保留各卡片的默认值', checked: this.overrideCardCorner, onChange: (value: boolean) => { this.overrideCardCorner = value; this.onUnavailableAction('卡片圆角设置暂未保存') } })
            if (this.overrideCardCorner) { ThemeSettingsOption({ title: '卡片圆角', detail: '', onSelect: () => this.onUnavailableAction('卡片圆角调节尚未迁移') }) }
            ThemeSwitchRow({ title: '覆盖卡片边框', detail: '关闭时保留各卡片的默认值', checked: this.overrideCardBorder, onChange: (value: boolean) => { this.overrideCardBorder = value; this.onUnavailableAction('卡片边框设置暂未保存') } })
            if (this.overrideCardBorder) {
              ThemeSettingsOption({ title: '边框宽度', detail: '', onSelect: () => this.onUnavailableAction('边框宽度设置尚未迁移') })
              ThemeSettingsOption({ title: '日间边框颜色', detail: '', onSelect: () => this.onUnavailableAction('边框颜色选择尚未迁移') })
              ThemeSettingsOption({ title: '夜间边框颜色', detail: '', onSelect: () => this.onUnavailableAction('边框颜色选择尚未迁移') })
            }
            ThemeSwitchRow({ title: '显示分隔线', checked: this.dividerEnabled, onChange: (value: boolean) => { this.dividerEnabled = value; this.onUnavailableAction('分隔线设置暂未保存') } })
            if (this.dividerEnabled) {
              ThemeSettingsOption({ title: '分隔线宽度', detail: '', onSelect: () => this.onUnavailableAction('分隔线宽度设置尚未迁移') })
              ThemeSettingsOption({ title: '分隔线长度', detail: '', onSelect: () => this.onUnavailableAction('分隔线长度设置尚未迁移') })
              ThemeSettingsOption({ title: '分隔线颜色', detail: '', onSelect: () => this.onUnavailableAction('分隔线颜色选择尚未迁移') })
            }
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16 }).backgroundColor('#1A1B21').borderRadius(16)
          Column() {
            ThemeSettingsOption({ title: '恢复默认主题配置', detail: '恢复外观页设置，不影响已保存主题和封面', onSelect: () => this.onUnavailableAction('恢复默认配置尚未迁移') })
          }.width('calc(100% - 32vp)').margin({ left: 16, right: 16, top: 20 }).backgroundColor('#1A1B21').borderRadius(16)
        }.width('100%').padding({ top: 4, bottom: 18 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct ThemeSectionTitle {
  @Prop title: string = '';
  build() {
    Text(this.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#AFC2FF')
      .alignSelf(ItemAlign.Start).margin({ left: 18, bottom: 9 })
  }
}

@Component
struct ThemeModeItem {
  @Prop title: string = '';
  @Prop selected: boolean = false;
  @Prop first: boolean = false;
  @Prop last: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Text(this.title).fontSize(14).fontColor(this.selected ? '#F0F1F5' : '#AEB0B9')
      .textAlign(TextAlign.Center).layoutWeight(1).padding({ top: 12, bottom: 12 })
      .backgroundColor(this.selected ? '#454B62' : Color.Transparent)
      .borderRadius({ topLeft: this.first ? 14 : 0, bottomLeft: this.first ? 14 : 0,
        topRight: this.last ? 14 : 0, bottomRight: this.last ? 14 : 0 })
      .onClick(() => this.onSelect())
  }
}

@Component
struct ThemePaletteItem {
  @Prop index: number = 0;
  @Prop title: string = '';
  @Prop lightColor: string = '#B9C8FF';
  @Prop darkColor: string = '#5C637F';
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Row() {
          Column().layoutWeight(1).height(42).backgroundColor(this.lightColor)
          Column().layoutWeight(1).height(42).backgroundColor(this.darkColor)
        }.width(42).height(42).borderRadius(21)
        Column().width(20).height(20).backgroundColor(this.lightColor).borderRadius(10)
        if (this.selected) {
          Text('✓').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#20212A')
            .width(34).height(34).textAlign(TextAlign.Center).backgroundColor('#AFC2FF').borderRadius(17)
        }
      }.width(56).height(56).backgroundColor('#1A1B21').borderRadius(14)
        .border({ width: this.selected ? 2 : 0, color: '#AFC2FF' }).onClick(() => this.onSelect())
      Text(this.title).fontSize(11).fontColor(this.selected ? '#AFC2FF' : '#C5C7D0')
        .textAlign(TextAlign.Center).margin({ top: 8 })
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }
}

@Component
struct ThemeSettingsOption {
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(16).fontColor('#D8D9E0')
        if (this.detail.length > 0) {
          Text(this.detail).fontSize(12).fontColor('#92949E').margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(16).height(16).fillColor('#92949E')
    }.padding({ left: 16, right: 16, top: 14, bottom: 14 }).onClick(() => this.onSelect())
  }
}

@Component
struct ThemeSwitchRow {
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop checked: boolean = false;
  onChange: (enabled: boolean) => void = (_enabled: boolean) => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(16).fontColor('#D8D9E0')
        if (this.detail.length > 0) {
          Text(this.detail).fontSize(12).fontColor('#92949E').margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .onChange((enabled: boolean) => this.onChange(enabled))
    }.padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}
