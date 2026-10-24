@Component
export struct AppCoverSettingsPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  build() {
    Column() {
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
          .width(40).height(40).onClick(() => this.onBack())
        Column() {
          Text('封面设置').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
          Text('通用规则与默认封面样式').fontSize(15).fontColor('#92949E').margin({ top: 3 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.padding({ left: 12, right: 16, top: 8, bottom: 10 })

      Scroll() {
        Column() {
          CoverSettingsSection({ title: '通用' }) {
            CoverSettingsSwitch({ title: '仅在 Wi-Fi 下加载网络封面', detail: '仅在 Wi-Fi 下加载网络封面' })
            CoverSettingsAction({ title: '封面规则', detail: '进入详情页时按规则重新获取封面', onSelect: () => this.onUnavailableAction('封面规则编辑尚未迁移') })
            CoverSettingsSwitch({ title: '总是使用默认封面', detail: '不显示网络封面' })
            CoverSettingsAction({ title: '默认封面', detail: '未选择封面相册', onSelect: () => this.onUnavailableAction('默认封面相册选择尚未迁移') })
            CoverSettingsSwitch({ title: '显示字体阴影' })
            CoverSettingsSwitch({ title: '显示字体描边' })
            CoverSettingsSwitch({ title: '使用默认颜色' })
          }

          CoverSettingsSection({ title: '书架显示' }) {
            CoverSettingsChoice({ title: '封面信息方向', options: ['竖向', '横向'] })
            CoverSettingsChoice({ title: '网络书籍角标', options: ['全部显示', '隐藏已加入书架', '隐藏同名同作者', '只显示未加入书架'] })
          }

          CoverSettingsSection({ title: '日间封面' }) {
            CoverSettingsColor({ title: '文字颜色', color: '#E7E8ED' })
            CoverSettingsColor({ title: '文字阴影颜色', color: '#17181E' })
            CoverSettingsSwitch({ title: '显示书名' })
            CoverSettingsSwitch({ title: '显示作者', detail: '关闭书名显示时不生效' })
          }

          CoverSettingsSection({ title: '夜间封面' }) {
            CoverSettingsColor({ title: '文字颜色', color: '#E7E8ED' })
            CoverSettingsColor({ title: '文字阴影颜色', color: '#17181E' })
            CoverSettingsSwitch({ title: '显示书名' })
            CoverSettingsSwitch({ title: '显示作者', detail: '关闭书名显示时不生效' })
          }
          Text('此页控件目前用于界面预览；封面规则、相册选择和偏好保存尚未接入。')
            .fontSize(15).fontColor('#858792').margin({ left: 18, right: 18, top: 6, bottom: 22 })
        }.width('100%').padding({ top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct CoverSettingsSection {
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
struct CoverSettingsSwitch {
  @Prop title: string = '';
  @Prop detail: string = '';
  @State toggleValue: boolean = false;
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(18).fontColor('#D8D9E0')
        if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor('#92949E').margin({ top: 3 }) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.toggleValue })
        .onChange((value: boolean) => this.toggleValue = value)
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }
}

@Component
struct CoverSettingsAction {
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(18).fontColor('#D8D9E0')
        if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor('#92949E').margin({ top: 3 }) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(16).height(16).fillColor('#92949E')
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 }).onClick(() => this.onSelect())
  }
}

@Component
struct CoverSettingsChoice {
  @Prop title: string = '';
  @Prop options: string[] = [];
  @State selectedIndex: number = 0;
  private getSelectedLabel(): string {
    if (this.options.length === 0) { return ''; }
    return this.options[Math.min(this.selectedIndex, this.options.length - 1)];
  }
  build() {
    Row() {
      Text(this.title).fontSize(18).fontColor('#D8D9E0').layoutWeight(1)
      Text(this.getSelectedLabel()).fontSize(12).fontColor('#AFC2FF')
      Image($r('app.media.reader_next')).width(15).height(15).fillColor('#92949E').margin({ left: 6 })
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 }).onClick(() => {
      if (this.options.length > 0) {
        this.selectedIndex = (this.selectedIndex + 1) % this.options.length;
      }
    })
  }
}

@Component
struct CoverSettingsColor {
  @Prop title: string = '';
  @Prop color: string = '#E7E8ED';
  @State selectedIndex: number = 0;
  private getColor(): string {
    if (this.selectedIndex === 0) { return this.color; }
    if (this.selectedIndex === 1) { return '#AFC2FF'; }
    if (this.selectedIndex === 2) { return '#E8B77B'; }
    return '#9AD0B7';
  }
  build() {
    Row() {
      Text(this.title).fontSize(18).fontColor('#D8D9E0').layoutWeight(1)
      Stack().width(26).height(26).backgroundColor(this.getColor()).borderRadius(13)
        .border({ width: 1, color: '#676A75' })
    }.padding({ left: 14, right: 14, top: 10, bottom: 10 }).onClick(() => this.selectedIndex = (this.selectedIndex + 1) % 4)
  }
}