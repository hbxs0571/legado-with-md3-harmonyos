@Component
export struct AppDownloadCacheSettingsPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  build() {
    Column() {
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
          .width(40).height(40).onClick(() => this.onBack())
        Column() {
          Text('下载与缓存').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
          Text('下载并发、预加载与缓存管理').fontSize(15).fontColor('#92949E').margin({ top: 3 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.padding({ left: 12, right: 16, top: 8, bottom: 10 })

      Scroll() {
        Column() {
          CacheSettingsSection({ title: 'HTTP 缓存' }) {
            CacheSettingsAction({ title: '封面缓存', detail: '0 MB', onSelect: () => this.onUnavailableAction('封面缓存清理尚未迁移') })
            CacheSettingsAction({ title: '漫画缓存', detail: '0 MB', onSelect: () => this.onUnavailableAction('漫画缓存清理尚未迁移') })
          }
          CacheSettingsSection({ title: '下载设置' }) {
            CacheSettingsSlider({ title: '更新和搜索线程', detail: '控制请求并发数量', value: 16, min: 1, max: 256 })
            CacheSettingsSlider({ title: '书籍缓存下载线程', detail: '并发越高越不稳定', value: 8, min: 1, max: 8 })
            CacheSettingsSlider({ title: '向后预下载', detail: '预先下载后续章节', value: 10, min: 0, max: 100 })
            CacheSettingsSlider({ title: '向前预下载', detail: '预先下载前面的章节', value: 0, min: 0, max: 100 })
          }
          CacheSettingsSection({ title: '图片缓存' }) {
            CacheSettingsSlider({ title: '图片绘制缓存', detail: '最大缓存大小（MB）', value: 50, min: 1, max: 2047 })
            CacheSettingsSlider({ title: '漫画保留数量', detail: '保留已读章节数量', value: 0, min: 0, max: 100 })
          }
          CacheSettingsSection({ title: '网络' }) {
            CacheSettingsInput({ title: '用户代理', value: '' })
            CacheSettingsSwitch({ title: 'Cronet', detail: '使用 Cronet 网络组件' })
          }
          CacheSettingsSection({ title: '其它' }) {
            CacheSettingsAction({ title: '清理缓存', detail: '清除已下载书籍和字体缓存', onSelect: () => this.onUnavailableAction('书籍缓存清理尚未迁移') })
            CacheSettingsAction({ title: '压缩数据库', detail: '整理本地数据库空间', onSelect: () => this.onUnavailableAction('数据库维护尚未迁移') })
          }
          Text('此页数值目前仅用于界面预览；偏好保存、缓存统计和清理操作尚未接入。')
            .fontSize(15).fontColor('#858792').margin({ left: 18, right: 18, top: 6, bottom: 22 })
        }.width('100%').padding({ top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct CacheSettingsSection {
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
struct CacheSettingsAction {
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      Text(this.title).fontSize(18).fontColor('#D8D9E0').layoutWeight(1)
      if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor('#92949E').margin({ right: 8 }) }
      Image($r('app.media.reader_next')).width(15).height(15).fillColor('#92949E')
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 }).onClick(() => this.onSelect())
  }
}

@Component
struct CacheSettingsSlider {
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop value: number = 0;
  @Prop min: number = 0;
  @Prop max: number = 100;
  @State currentValue: number = 0;
  aboutToAppear(): void { this.currentValue = this.value; }
  build() {
    Column() {
      Row() {
        Column() {
          Text(this.title).fontSize(18).fontColor('#D8D9E0')
          if (this.detail.length > 0) { Text(this.detail).fontSize(15).fontColor('#92949E').margin({ top: 3 }) }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text(`${Math.round(this.currentValue)}`).fontSize(12).fontColor('#AFC2FF')
      }
      Slider({ value: this.currentValue, min: this.min, max: this.max, step: 1 })
        .selectedColor('#AFC2FF').trackColor('#454750')
        .onChange((value: number) => this.currentValue = value)
    }.padding({ left: 14, right: 14, top: 9, bottom: 9 })
  }
}

@Component
struct CacheSettingsInput {
  @Prop title: string = '';
  @Prop value: string = '';
  @State currentValue: string = '';
  aboutToAppear(): void { this.currentValue = this.value; }
  build() {
    Row() {
      Text(this.title).fontSize(18).fontColor('#D8D9E0').layoutWeight(1)
      TextInput({ text: this.currentValue, placeholder: '默认' })
        .fontSize(12).fontColor('#D8D9E0').textAlign(TextAlign.End)
        .backgroundColor('#111217').width(130).borderRadius(8)
        .onChange((value: string) => this.currentValue = value)
    }.padding({ left: 14, right: 14, top: 10, bottom: 10 })
  }
}

@Component
struct CacheSettingsSwitch {
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