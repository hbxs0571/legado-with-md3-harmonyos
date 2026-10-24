import { AppGlyph } from '../components/AppGlyph';

const SUBSCRIPTION_EMPTY_FACES: string[] = [
  '(；′⌒`)', '(つ﹏⊂)', '(•̀ᴗ•́)و', '(๑•́ ₃ •̀๑)', '(눈‸눈)', '(ಥ﹏ಥ)', '(｡•́︿•̀｡)'
];

@Component
export struct SubscriptionRulesPage {
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
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop emptyMessage: string = '';
  @Prop showAdd: boolean = false;
  @State searchVisible: boolean = false;
  @State searchText: string = '';
  @State faceIndex: number = Math.floor(Math.random() * SUBSCRIPTION_EMPTY_FACES.length);
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
        MenuItem({ content: '删除所选分组' }).onClick(() => this.onUnavailableAction('收藏分组尚未接入'))
        MenuItem({ content: '删除全部' }).onClick(() => this.onUnavailableAction('收藏数据尚未接入'))
      }
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(32).height(32).backgroundColor('#1C1D23').borderRadius(18).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'search', glyphSize: 18, tint: '#D8D9E0' })
        }.width(32).height(32).backgroundColor('#1C1D23').borderRadius(18)
          .onClick(() => this.searchVisible = !this.searchVisible)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'more', glyphSize: 18, tint: '#D8D9E0' })
        }.width(32).height(32).backgroundColor('#1C1D23').borderRadius(18).margin({ left: 8 })
          .bindMenu(this.MoreMenu, { placement: Placement.BottomRight })
      }.width('100%').padding({ left: 16, right: 16, top: 4, bottom: 2 })

      Column() {
        Text(this.title).fontSize(24).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
        if (this.subtitle.length > 0) {
          Text(this.subtitle).fontSize(14).fontColor('#B6B8C2').margin({ top: 3 })
        }
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 5, bottom: 12 })

      if (this.searchVisible) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索…', text: this.searchText })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .onChange((value: string) => this.searchText = value)
        }.width('100%').padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .margin({ left: 16, right: 16, bottom: 8 }).backgroundColor('#1C1D23').borderRadius(22)
      }

      Column() {
        Text(SUBSCRIPTION_EMPTY_FACES[this.faceIndex]).fontSize(22).fontColor('#E3E4E8')
          .margin({ bottom: 8 }).onClick(() => this.changeFace())
        Text(this.emptyMessage).fontSize(13).fontColor('#E3E4E8').textAlign(TextAlign.Center)
      }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .offset({ y: this.subtitle.length > 0 ? 0 : 34 })

      if (this.showAdd) {
        Row() {
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'add', glyphSize: 24, tint: '#DDE3FF' })
          }.width(50).height(50).backgroundColor('#4D5C8D').borderRadius(14)
            .onClick(() => this.onUnavailableAction('规则添加表单尚未迁移，当前没有创建规则'))
        }.width('100%').justifyContent(FlexAlign.End).padding({ right: 16, top: 8, bottom: 8 })
      }
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}
