import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';

@Component
export struct AppReadAloudSettingsPage {
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
      CollapsingSettingsHeader({ title: '朗读设置', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Scroll(this.settingsScroller) {
        Column() {
          Column() {
            AppReadAloudLinkRow({ title: '角色声音池', detail: '管理角色声音池以及池内启用的音色', onSelect: () => this.onUnavailableAction('角色声音池页面尚未迁移') })
            Row().height(1).width('100%').backgroundColor('#111217')
            AppReadAloudLinkRow({ title: '背景音乐池', detail: '导入配乐文件，朗读时作为背景音乐播放', onSelect: () => this.onUnavailableAction('背景音乐池页面尚未迁移') })
            Row().height(1).width('100%').backgroundColor('#111217')
            AppReadAloudLinkRow({ title: '变声器', detail: '管理音高、语速、混响与金属感预设', onSelect: () => this.onUnavailableAction('变声器页面尚未迁移') })
            Row().height(1).width('100%').backgroundColor('#111217')
            AppReadAloudLinkRow({ title: '朗读胶囊设置', detail: '设置正文胶囊的圆角、背景与头像形状位置', onSelect: () => this.onUnavailableAction('朗读胶囊设置尚未迁移') })
            Row().height(1).width('100%').backgroundColor('#111217')
            AppReadAloudLinkRow({ title: '朗读引擎与音色', detail: '配置朗读引擎并导入音色', onSelect: () => this.onUnavailableAction('朗读引擎与音色页面尚未迁移') })
            Row().height(1).width('100%').backgroundColor('#111217')
            AppReadAloudLinkRow({ title: '多角色识别', detail: '配置角色标记与声音池分隔符', onSelect: () => this.onUnavailableAction('多角色识别页面尚未迁移') })
            Row().height(1).width('100%').backgroundColor('#111217')
            AppReadAloudLinkRow({ title: '正则角色管理', detail: '按正文匹配更换音色或播放音效', onSelect: () => this.onUnavailableAction('正则角色管理页面尚未迁移') })
          }.margin({ left: 16, right: 16, top: 12 }).backgroundColor('#1A1B21').borderRadius(16)
        }
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct AppReadAloudLinkRow {
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(16).fontColor('#D8D9E0')
        Text(this.detail).fontSize(14).fontColor('#92949E').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(16).height(16).fillColor('#92949E')
    }.padding({ left: 16, right: 14, top: 15, bottom: 15 }).onClick(() => this.onSelect())
  }
}
