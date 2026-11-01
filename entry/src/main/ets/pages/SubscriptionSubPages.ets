import { AppGlyph } from '../components/AppGlyph';

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

  @Builder
  private MoreMenu() {
    Menu() {
      if (this.title === '规则') {
        MenuItem({ content: '排序' }).onClick(() => this.onUnavailableAction('订阅规则排序尚未接入'))
      } else {
        MenuItem({ content: '全部' }).onClick(() => this.onUnavailableAction('收藏分组尚未接入'))
        MenuItem({ content: '添加到分组' }).onClick(() => this.activeSheet = 'addGroup')
        MenuItem({ content: '从分组移除' }).onClick(() => this.activeSheet = 'removeGroup')
        MenuItem({ content: '删除所选分组' }).onClick(() => this.onUnavailableAction('收藏分组尚未接入'))
        MenuItem({ content: '删除全部' }).onClick(() => this.onUnavailableAction('收藏数据尚未接入'))
      }
    }.backgroundColor(this.themePureBlack ? '#121212' : $r('app.color.theme_surface_elevated')).fontColor($r('app.color.theme_text_primary')).radius(20)
  }

  @StorageProp('themeItemBackground') themeItemBackground: string = '';
  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.reader_back')).width(20).height(20).fillColor($r('app.color.theme_text_secondary'))
        }.width(36).height(36).backgroundColor(this.themePureBlack ? '#121212' : $r('app.color.theme_surface_elevated')).borderRadius(18).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'search', glyphSize: 20, tint: $r('app.color.theme_text_secondary') })
        }.width(36).height(36).backgroundColor(this.themePureBlack ? '#121212' : $r('app.color.theme_surface_elevated')).borderRadius(18)
          .onClick(() => this.searchVisible = !this.searchVisible)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'more', glyphSize: 20, tint: $r('app.color.theme_text_secondary') })
        }.width(36).height(36).backgroundColor(this.themePureBlack ? '#121212' : $r('app.color.theme_surface_elevated')).borderRadius(18).margin({ left: 8 })
          .bindMenu(this.MoreMenu, { placement: Placement.BottomRight })
      }.width('100%').padding({ left: 16, right: 16, top: 4, bottom: 2 })

      Column() {
        Text(this.title).fontSize(28).fontWeight(FontWeight.Medium).fontColor($r('app.color.theme_text_primary'))
        if (this.subtitle.length > 0) {
          Text(this.subtitle).fontSize(14).fontColor('#B6B8C2').margin({ top: 3 })
        }
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 5, bottom: 12 })

      if (this.searchVisible) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索…', text: this.searchText })
            .fontSize(14).fontColor($r('app.color.theme_text_secondary')).placeholderColor($r('app.color.theme_text_tertiary'))
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .onChange((value: string) => this.searchText = value)
        }.width('100%').padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .margin({ left: 16, right: 16, bottom: 8 }).backgroundColor(this.themePureBlack ? '#121212' : $r('app.color.theme_surface_elevated')).borderRadius(22).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
          .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
      }

      Column() {
        Text(SUBSCRIPTION_EMPTY_FACES[this.faceIndex]).fontSize(22).fontColor($r('app.color.theme_text_primary'))
          .margin({ bottom: 8 }).onClick(() => this.changeFace())
        Text(this.emptyMessage).fontSize(13).fontColor($r('app.color.theme_text_primary')).textAlign(TextAlign.Center)
      }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .offset({ y: this.subtitle.length > 0 ? 0 : 34 })

      if (this.showAdd) {
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'add', glyphSize: 24, tint: '#DDE3FF' })
          }.width(56).height(56).backgroundColor('#4D5C8D').borderRadius(18)
            .onClick(() => this.activeSheet = 'ruleEditor')
            .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
        }.width('100%').justifyContent(FlexAlign.End).padding({ right: 16, top: 8, bottom: 8 })
      }
    }.width('100%').height('100%').backgroundColor(this.themePureBlack ? '#000000' : $r('app.color.theme_surface_primary'))
      .bindSheet(this.activeSheet.length > 0, this.subscriptionSheet(), {
        height: this.activeSheet === 'ruleEditor' ? 460 : 320,
        dragBar: true,
        showClose: false,
        backgroundColor: $r('app.color.theme_surface_secondary'),
        onDisappear: () => this.activeSheet = ''
      })
  }

  @Builder
  private subscriptionSheet() {
    Column() {
      Row() {
        Text(this.activeSheet === 'ruleEditor' ? '规则订阅' : this.activeSheet === 'addGroup' ?
          '添加到分组' : '从分组移除')
          .fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('app.color.theme_text_primary')).layoutWeight(1)
        Text('取消').fontSize(14).fontColor($r('app.color.theme_accent')).onClick(() => this.activeSheet = '')
      }.width('100%').padding({ left: 18, right: 18, top: 12, bottom: 16 })
      TextInput({ placeholder: this.activeSheet === 'ruleEditor' ? '名称' : '分组名称', text: this.draftName })
        .fontSize(16).fontColor($r('app.color.theme_text_primary')).backgroundColor('#292B33').borderRadius(12)
        .margin({ left: 18, right: 18, bottom: 12 }).onChange((value: string) => this.draftName = value)
      if (this.activeSheet === 'ruleEditor') {
        TextInput({ placeholder: 'URL', text: this.draftUrl })
          .fontSize(16).fontColor($r('app.color.theme_text_primary')).backgroundColor('#292B33').borderRadius(12)
          .margin({ left: 18, right: 18, bottom: 12 }).onChange((value: string) => this.draftUrl = value)
        Text('订阅类型').fontSize(14).fontColor('#B6B8C2').alignSelf(ItemAlign.Start)
          .margin({ left: 18, top: 6, bottom: 8 })
        Row() {
          ForEach(['书源', '订阅源', '替换规则', '自动识别'], (label: string, index: number) => {
            Text(label).fontSize(14).fontColor(this.draftType === index ? $r('app.color.theme_accent') : $r('app.color.theme_text_secondary'))
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .backgroundColor(this.draftType === index ? '#41485D' : '#292B33').borderRadius(18)
              .margin({ right: 8 }).onClick(() => this.draftType = index)
          }, (label: string) => label)
        }.width('100%').padding({ left: 18, right: 18 })
      }
      Button('保存').fontSize(14).fontColor($r('app.color.theme_surface_primary')).backgroundColor($r('app.color.theme_accent')).borderRadius(22)
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
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State searchVisible: boolean = false;
  @State searchText: string = '';

  @Builder
  private MoreMenu() {
    Menu() {
      MenuItem({ content: '分组管理' }).onClick(() => this.onUnavailableAction('订阅源分组管理尚未迁移'))
      MenuItem({ content: '导入订阅源' }).onClick(() => this.onUnavailableAction('订阅源导入尚未迁移'))
      MenuItem({ content: '全部' }).onClick(() => this.onUnavailableAction('当前已显示全部订阅源'))
      MenuItem({ content: '已启用' }).onClick(() => this.onUnavailableAction('订阅源筛选尚未迁移'))
      MenuItem({ content: '已禁用' }).onClick(() => this.onUnavailableAction('订阅源筛选尚未迁移'))
      MenuItem({ content: '需登录' }).onClick(() => this.onUnavailableAction('订阅源筛选尚未迁移'))
      MenuItem({ content: '未分组' }).onClick(() => this.onUnavailableAction('订阅源筛选尚未迁移'))
    }.backgroundColor(this.themePureBlack ? '#121212' : $r('app.color.theme_surface_elevated')).fontColor($r('app.color.theme_text_primary')).radius(20)
  }

  @StorageProp('themeItemBackground') themeItemBackground: string = '';
  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.reader_back')).width(20).height(20).fillColor($r('app.color.theme_text_secondary'))
        }.width(36).height(36).backgroundColor(this.themePureBlack ? '#121212' : $r('app.color.theme_surface_elevated')).borderRadius(18).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'search', glyphSize: 20, tint: $r('app.color.theme_text_secondary') })
        }.width(36).height(36).backgroundColor(this.themePureBlack ? '#121212' : $r('app.color.theme_surface_elevated')).borderRadius(18)
          .onClick(() => this.searchVisible = !this.searchVisible)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'more', glyphSize: 20, tint: $r('app.color.theme_text_secondary') })
        }.width(36).height(36).backgroundColor(this.themePureBlack ? '#121212' : $r('app.color.theme_surface_elevated')).borderRadius(18).margin({ left: 8 })
          .bindMenu(this.MoreMenu, { placement: Placement.BottomRight })
      }.width('100%').padding({ left: 16, right: 16, top: 4, bottom: 2 })

      Column() {
        Text('订阅源').fontSize(28).fontWeight(FontWeight.Medium).fontColor($r('app.color.theme_text_primary'))
        Text('全部').fontSize(14).fontColor('#B6B8C2').margin({ top: 3 })
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 5, bottom: 12 })

      if (this.searchVisible) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索订阅源…', text: this.searchText })
            .fontSize(14).fontColor($r('app.color.theme_text_secondary')).placeholderColor($r('app.color.theme_text_tertiary'))
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .onChange((value: string) => this.searchText = value)
        }.width('100%').padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .margin({ left: 16, right: 16, bottom: 8 }).backgroundColor(this.themePureBlack ? '#121212' : $r('app.color.theme_surface_elevated')).borderRadius(22).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
          .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
      }

      Blank().layoutWeight(1)
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'add', glyphSize: 24, tint: '#DDE3FF' })
        }.width(50).height(50).backgroundColor('#4D5C8D').borderRadius(16)
          .onClick(() => this.onUnavailableAction('订阅源编辑页尚未迁移'))
      }.width('100%').justifyContent(FlexAlign.End).padding({ right: 16, bottom: 16 })
    }.width('100%').height('100%').backgroundColor(this.themePureBlack ? '#000000' : $r('app.color.theme_surface_primary'))
  }
}
