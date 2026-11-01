import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import { ThemeItemDivider } from '../components/ThemeItemDivider';

@Component
export struct AppReadAloudSettingsPage {
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
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

  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  @StorageProp('themeCardBorderWidth') themeCardBorderWidth: number = 0;
  @StorageProp('themeCardBorderColor') themeCardBorderColor: string = '#6A6D77';
  @StorageProp('themeCardBackground') themeCardBackground: string = '';
  @StorageProp('themeContainerBackground') themeContainerBackground: string = '';
  build() {
    Column() {
      CollapsingSettingsHeader({ title: '朗读设置', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Scroll(this.settingsScroller) {
        Column() {
          Column() {
            AppReadAloudLinkRow({ title: '角色声音池', detail: '管理角色声音池以及池内启用的音色', onSelect: () => this.onUnavailableAction('角色声音池页面尚未迁移') })
            ThemeItemDivider()
            Row().height(1).width('100%').backgroundColor(this.themePureBlack ? '#000000' : $r('app.color.theme_surface_primary'))
            ThemeItemDivider()
            AppReadAloudLinkRow({ title: '背景音乐池', detail: '导入配乐文件，朗读时作为背景音乐播放', onSelect: () => this.onUnavailableAction('背景音乐池页面尚未迁移') })
            ThemeItemDivider()
            Row().height(1).width('100%').backgroundColor(this.themePureBlack ? '#000000' : $r('app.color.theme_surface_primary'))
            ThemeItemDivider()
            AppReadAloudLinkRow({ title: '变声器', detail: '管理音高、语速、混响与金属感预设', onSelect: () => this.onUnavailableAction('变声器页面尚未迁移') })
            ThemeItemDivider()
            Row().height(1).width('100%').backgroundColor(this.themePureBlack ? '#000000' : $r('app.color.theme_surface_primary'))
            ThemeItemDivider()
            AppReadAloudLinkRow({ title: '朗读胶囊设置', detail: '设置正文胶囊的圆角、背景与头像形状位置', onSelect: () => this.onUnavailableAction('朗读胶囊设置尚未迁移') })
            ThemeItemDivider()
            Row().height(1).width('100%').backgroundColor(this.themePureBlack ? '#000000' : $r('app.color.theme_surface_primary'))
            ThemeItemDivider()
            AppReadAloudLinkRow({ title: '朗读引擎与音色', detail: '配置朗读引擎并导入音色', onSelect: () => this.onUnavailableAction('朗读引擎与音色页面尚未迁移') })
            ThemeItemDivider()
            Row().height(1).width('100%').backgroundColor(this.themePureBlack ? '#000000' : $r('app.color.theme_surface_primary'))
            ThemeItemDivider()
            AppReadAloudLinkRow({ title: '多角色识别', detail: '配置角色标记与声音池分隔符', onSelect: () => this.onUnavailableAction('多角色识别页面尚未迁移') })
            ThemeItemDivider()
            Row().height(1).width('100%').backgroundColor(this.themePureBlack ? '#000000' : $r('app.color.theme_surface_primary'))
            ThemeItemDivider()
            AppReadAloudLinkRow({ title: '正则角色管理', detail: '按正文匹配更换音色或播放音效', onSelect: () => this.onUnavailableAction('正则角色管理页面尚未迁移') })
          }.margin({ left: 16, right: 16, top: 12 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : $r('app.color.theme_surface_secondary')).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
        }
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themePureBlack ? '#000000' : $r('app.color.theme_surface_primary'))
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
        Text(this.title).fontSize(16).fontColor($r('app.color.theme_text_secondary'))
        Text(this.detail).fontSize(14).fontColor($r('app.color.theme_text_tertiary')).margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(16).height(16).fillColor($r('app.color.theme_text_tertiary'))
    }.padding({ left: 16, right: 14, top: 15, bottom: 15 }).onClick(() => this.onSelect())
  }
}
