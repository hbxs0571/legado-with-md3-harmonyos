import { AppGlyph } from '../components/AppGlyph';

interface DiscoverSourceDemo {
  name: string;
  group: string;
}

@Component
export struct DiscoverPage {
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  private readonly sources: DiscoverSourceDemo[] = [];
  private readonly groups: string[] = ['全部'];
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State showExploreContent: boolean = false;
  @State expandedSourceName: string = '';
  @State selectedGroup: string = '';
  @State currentEmptyFace: string = '(つ﹏⊂)';
  private readonly emptyFaces: string[] = [
    "(；′⌒`)", '(つ﹏⊂)', '(•̀ᴗ•́)و', '(๑•́ ₃ •̀๑)', '(눈‸눈)', '(ಥ﹏ಥ)', '(｡•́︿•̀｡)'
  ];

  aboutToAppear(): void {
    this.currentEmptyFace = this.pickEmptyFace();
  }

  private pickEmptyFace(): string {
    const faceIndex = Math.floor(Math.random() * this.emptyFaces.length);
    return this.emptyFaces[faceIndex] ?? this.emptyFaces[0];
  }

  @Builder
  private GroupMenu() {
    Menu() {
      if (!this.showExploreContent) {
        ForEach(this.groups, (group: string) => {
          MenuItem({
            startIcon: group === '全部' ? $r('app.media.app_group') : $r('app.media.app_label'),
            content: group
          })
            .selected((group === '全部' && this.selectedGroup.length === 0) || this.selectedGroup === group)
            .onClick(() => {
              this.selectedGroup = group === '全部' ? '' : group;
              this.expandedSourceName = '';
            })
        }, (group: string) => group)
      }
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  private getVisibleSources(): DiscoverSourceDemo[] {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    return this.sources.filter((source: DiscoverSourceDemo) => {
      const groupMatches = this.selectedGroup.length === 0 || source.group === this.selectedGroup;
      if (!groupMatches) { return false; }
      if (query.length === 0) { return true; }
      return source.name.toLocaleLowerCase().includes(query) || source.group.toLocaleLowerCase().includes(query);
    });
  }

  build() {
    Column() {
      Row() {
        Blank()
        if (!this.showExploreContent) {
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'search', glyphSize: 19 })
          }.width(32).height(32).backgroundColor('#1C1D23').borderRadius(18)
            .onClick(() => {
              this.showSearch = !this.showSearch;
              if (!this.showSearch) {
                this.searchQuery = '';
              }
            })
        }
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'swap', glyphSize: 19 })
        }.width(32).height(32).backgroundColor('#1C1D23').borderRadius(18).margin({ left: 8 })
          .onClick(() => {
            this.showExploreContent = !this.showExploreContent;
            this.expandedSourceName = '';
            this.showSearch = false;
            this.searchQuery = '';
          })
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'more', glyphSize: 18 })
        }.width(32).height(32).backgroundColor('#1C1D23').borderRadius(18).margin({ left: 8 })
          .bindMenu(this.GroupMenu, { placement: Placement.BottomRight })
      }.width('100%').height(40).padding({ left: 18, right: 18 })

      Column() {
        Text('发现').fontSize(24).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
        if (!this.showExploreContent) {
          Text('全部').fontSize(14).fontColor('#B6B8C2').margin({ top: 3 })
        }
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 18, right: 18 })

      if (this.showSearch) {
        Row() {
          Row() {
            AppGlyph({ name: 'search', glyphSize: 17 }).margin({ right: 9 })
            TextInput({
              placeholder: '搜索',
              text: this.searchQuery
            })
              .height(48).fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
              .backgroundColor(Color.Transparent).layoutWeight(1)
              .id('discover_search_input')
              .onAppear(() => focusControl.requestFocus('discover_search_input'))
              .onChange((value: string) => this.searchQuery = value)
          }.layoutWeight(1).height(48).padding({ left: 14, right: 14 })
            .backgroundColor('#1C1D23').borderRadius(24)
        }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
      }

      if (this.showExploreContent) {
        Column() {
          Text(this.currentEmptyFace).fontSize(26).fontColor('#D8D9E0').margin({ bottom: 8 })
            .onClick(() => this.currentEmptyFace = this.pickEmptyFace())
          Text('当前没有发现源！').fontSize(14).fontColor('#D8D9E0').maxLines(2)
            .textAlign(TextAlign.Center)
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
          .offset({ y: 0 })
      } else if (this.getVisibleSources().length === 0) {
        Column() {
          Text(this.currentEmptyFace).fontSize(26).fontColor('#D8D9E0').margin({ bottom: 8 })
            .onClick(() => this.currentEmptyFace = this.pickEmptyFace())
          Text('当前没有发现源！').fontSize(14).fontColor('#D8D9E0').maxLines(2)
            .textAlign(TextAlign.Center)
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
          .offset({ y: this.showSearch ? -35 : 0 })
      } else {
        Scroll() {
          Column() {
            ForEach(this.getVisibleSources(), (source: DiscoverSourceDemo) => {
              Column() {
                Row() {
                  Text(source.name).fontSize(16).fontColor('#D8D9E0').maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                  Image($r('app.media.reader_next')).width(16).height(16).fillColor('#C5C7D0')
                    .rotate({ angle: this.expandedSourceName === source.name ? 90 : 0 })
                }.width('100%').padding({ left: 14, right: 12, top: 14, bottom: 14 })
                  .onClick(() => {
                    this.expandedSourceName = this.expandedSourceName === source.name ? '' : source.name;
                    this.showSearch = false;
                  })
                if (this.expandedSourceName === source.name) {
                  Row() {
                    AppGlyph({ name: 'list', glyphSize: 17, tint: '#AFC2FF' }).margin({ right: 8 })
                    Text('来源分类由书源规则提供，尚未接入')
                      .fontSize(14).fontColor('#92949E').layoutWeight(1)
                  }.width('100%').padding({ left: 14, right: 14, top: 11, bottom: 13 })
                }
              }.width('100%').backgroundColor('#1C1D23').borderRadius(13).margin({ bottom: 8 })
            }, (source: DiscoverSourceDemo) => source.name)
            if (this.getVisibleSources().length === 0) {
              Column() {
                Text('没有匹配的书源').fontSize(16).fontColor('#D8D9E0')
                Text('调整搜索内容后重试').fontSize(14).fontColor('#858792').margin({ top: 8 })
              }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
            }
          }.padding({ left: 16, right: 16, bottom: 16 }).constraintSize({ minHeight: '100%' })
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }.width('100%').height('100%').backgroundColor('#111217')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
