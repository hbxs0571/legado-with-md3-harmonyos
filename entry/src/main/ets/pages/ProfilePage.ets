import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import {
  PROFILE_PAGE_TITLE_SIZE,
  PROFILE_ROW_DETAIL_SIZE,
  PROFILE_ROW_TITLE_SIZE,
  PROFILE_SECTION_TITLE_SIZE,
  PROFILE_ROW_VERTICAL_PADDING
} from '../components/ProfileUiMetrics';
import { ProfileRoute } from '../model/Book';

@Component
export struct ProfilePage {
  onOpenDetail: (destination: ProfileRoute) => void = () => {};
  onExit: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State collapsedHeader: boolean = false;
  @State showWebPreview: boolean = false;
  private profileScroller: Scroller = new Scroller();

  build() {
    Column() {
      if (this.collapsedHeader) {
        Row() {
          Text('我的').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
        }.width('100%').height(56).alignItems(VerticalAlign.Center).padding({ left: 16, right: 16 })
          .backgroundColor('#111217')
          .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
      } else {
        Text('我的').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
          .alignSelf(ItemAlign.Start).padding({ left: 16, right: 16, top: 50, bottom: 38 })
          .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
      }
      Scroll(this.profileScroller) {
        Column() {
          Column() {
            Row() {
              Stack({ alignContent: Alignment.Center }) { AppGlyph({ name: 'profileWeb', tint: '#C5C7D0', glyphSize: 20 }) }.width(26).height(26)
              Column() {
                Text('Web 服务').fontSize(PROFILE_ROW_TITLE_SIZE).fontColor('#D8D9E0')
                Text('用浏览器看书源与书籍').fontSize(PROFILE_ROW_DETAIL_SIZE).fontColor('#AEB0BA').margin({ top: 4 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text(this.showWebPreview ? '收起' : '预览').fontSize(12).fontColor('#AFC2FF')
                .padding({ left: 8, right: 8, top: 8, bottom: 8 })
                .onClick(() => this.showWebPreview = !this.showWebPreview)
              Toggle({ type: ToggleType.Switch, isOn: false })
                .onChange((_enabled: boolean) => this.onUnavailableAction('Web 服务尚未迁移'))
            }.width('100%').padding(10)
            Column() {
              Text('Web 服务尚未迁移 · 以下为界面预览').fontSize(12).fontColor('#AEB0BA')
                .width('100%').textAlign(TextAlign.End)
              Row() {
                Row() {
                  AppGlyph({ name: 'profileContentPaste', glyphSize: 16, tint: '#C5C7D0' })
                  Text('复制网址').fontSize(12).fontColor('#C5C7D0').margin({ left: 6 })
                }.padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .onClick(() => this.onUnavailableAction('Web 服务尚未迁移'))
                Row() {
                  AppGlyph({ name: 'web', glyphSize: 16, tint: '#C5C7D0' })
                  Text('浏览器打开').fontSize(12).fontColor('#C5C7D0').margin({ left: 6 })
                }.padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .onClick(() => this.onUnavailableAction('Web 服务尚未迁移'))
              }.width('100%').justifyContent(FlexAlign.End)
            }.width('100%').padding({ left: 10, right: 10, bottom: 8 })
              .height(this.showWebPreview ? 70 : 0).opacity(this.showWebPreview ? 1 : 0)
              .clip(true).animation({ duration: 220, curve: Curve.EaseInOut })
          }.width('100%').backgroundColor('#1C1D23').borderRadius(14).margin({ bottom: 13 })
          Text('规则').fontSize(PROFILE_SECTION_TITLE_SIZE).fontColor('#AFC2FF').alignSelf(ItemAlign.Start).margin({ left: 12, bottom: 8 })
          Column() {
            ProfileRow({ title: '书源管理', detail: '新建 · 导入 · 编辑或管理书源', onSelect: () => this.onOpenDetail(ProfileRoute.BOOK_SOURCE_MANAGE) })
            ProfileRow({ title: '替换净化', detail: '', onSelect: () => this.onOpenDetail(ProfileRoute.REPLACE_RULES) })
            ProfileRow({ title: 'TXT 目录规则', detail: '', onSelect: () => this.onOpenDetail(ProfileRoute.TXT_TOC_RULES) })
            ProfileRow({ title: '字典规则', detail: '', onSelect: () => this.onOpenDetail(ProfileRoute.DICTIONARY_RULES) })
            ProfileRow({ title: '标签规则', detail: '', last: true, onSelect: () => this.onOpenDetail(ProfileRoute.HIGHLIGHT_TAG_RULES) })
          }.width('100%').padding({ top: 2, bottom: 2 }).backgroundColor('#1A1B21').borderRadius(14)
          Text('其它').fontSize(PROFILE_SECTION_TITLE_SIZE).fontColor('#AFC2FF').alignSelf(ItemAlign.Start).margin({ left: 12, top: 16, bottom: 8 })
          Column() {
            ProfileRow({ title: 'AI 对话', detail: '', onSelect: () => this.onOpenDetail(ProfileRoute.AI_CHAT) })
            ProfileRow({ title: '设置', detail: '', onSelect: () => this.onOpenDetail(ProfileRoute.APP_SETTINGS) })
            ProfileRow({ title: '书签', detail: '', onSelect: () => this.onOpenDetail(ProfileRoute.ALL_BOOKMARKS) })
            ProfileRow({ title: '阅读记录', detail: '', onSelect: () => this.onOpenDetail(ProfileRoute.READ_RECORDS) })
            ProfileRow({ title: '缓存管理', detail: '', onSelect: () => this.onOpenDetail(ProfileRoute.CACHE_MANAGEMENT) })
            ProfileRow({ title: '文件管理', detail: '', onSelect: () => this.onOpenDetail(ProfileRoute.FILE_MANAGER) })
            ProfileRow({ title: '关于', detail: '', onSelect: () => this.onOpenDetail(ProfileRoute.ABOUT) })
            ProfileRow({ title: '退出', detail: '', last: true, onSelect: () => this.onExit() })
          }.width('100%').padding({ top: 2, bottom: 2 }).backgroundColor('#1A1B21').borderRadius(14)
        }.padding({ left: 16, right: 16, bottom: 120 }).constraintSize({ minHeight: '100%' })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => {
        const shouldCollapse = Math.abs(this.profileScroller.currentOffset().yOffset) > 70;
        if (this.collapsedHeader !== shouldCollapse) {
          animateTo({ duration: 220, curve: Curve.EaseInOut }, () => {
            this.collapsedHeader = shouldCollapse;
          });
        }
      })
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct ProfileRow {
  @Prop icon: string = '';
  @Prop title: string = '';
  @Prop detail: string = '';
  @Prop last: boolean = false;
  onSelect: () => void = () => {};
  private getGlyphName(): AppGlyphName {
    if (this.title === '书源管理') { return 'profileSource'; }
    if (this.title === '文件管理') { return 'profileFolder'; }
    if (this.title === '替换净化') { return 'profileFindReplace'; }
    if (this.title === 'TXT 目录规则') { return 'profileRule'; }
    if (this.title === '字典规则') { return 'navBookshelfFilled'; }
    if (this.title === '标签规则') { return 'profileSell'; }
    if (this.title === '设置') { return 'profileSettings'; }
    if (this.title === '书签') { return 'profileBookmark'; }
    if (this.title === '阅读记录') { return 'profileHistory'; }
    if (this.title === '缓存管理') { return 'profileDownload'; }
    if (this.title === '关于') { return 'profileInfo'; }
    if (this.title === 'AI 对话') { return 'profileAutoAwesome'; }
    if (this.title === '退出') { return 'profileExitToApp'; }
    return 'book';
  }
  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) { AppGlyph({ name: this.getGlyphName(), tint: '#C5C7D0', glyphSize: 20 }) }.width(34).height(34)
        Column() {
          Text(this.title).fontSize(PROFILE_ROW_TITLE_SIZE).fontColor('#D8D9E0')
          if (this.detail.length > 0) { Text(this.detail).fontSize(PROFILE_ROW_DETAIL_SIZE).fontColor('#92949E').margin({ top: 4 }) }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Image($r('app.media.reader_next')).width(16).height(16).fillColor('#AEB0BA')
      }.width('100%').padding({ left: 14, right: 14, top: PROFILE_ROW_VERTICAL_PADDING, bottom: PROFILE_ROW_VERTICAL_PADDING })
      if (!this.last) { Row().height(1).width('100%').backgroundColor('#111217').margin({ left: 48, right: 14 }) }
    }.width('100%').onClick(() => this.onSelect())
  }
}



