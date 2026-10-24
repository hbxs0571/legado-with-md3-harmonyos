import { AppGlyph } from '../components/AppGlyph';

@Component
export struct SubscriptionPage {
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  onOpenRules: () => void = () => {};
  onOpenFavorites: () => void = () => {};
  private readonly items: string[] = [];
  private subscriptionScroller: Scroller = new Scroller();
  @State touchStartY: number = 0;
  @State collapsedHeader: boolean = false;
  @State showSearch: boolean = false;
  @State searchQuery: string = '';

  @Builder
  private MoreMenu() {
    Menu() {
      MenuItem({ content: '订阅源管理' })
        .onClick(() => this.onUnavailableAction('订阅源管理页面尚未迁移'))
      MenuItem({ content: '全部' })
        .onClick(() => this.onUnavailableAction('当前已显示全部订阅源'))
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(18)
  }

  private getVisibleItems(): string[] {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    if (query.length === 0) { return this.items; }
    return this.items.filter((item: string) => item.toLocaleLowerCase().includes(query));
  }

  private getItemRows(): string[][] {
    const visibleItems = this.getVisibleItems();
    const rows: string[][] = [];
    for (let index = 0; index < visibleItems.length; index += 5) {
      const row: string[] = visibleItems.slice(index, index + 5);
      while (row.length < 5) { row.push(''); }
      rows.push(row);
    }
    return rows;
  }

  build() {
    Column() {
      if (this.collapsedHeader) {
        Column() {
          Row() {
            Text('订阅').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
            Blank().layoutWeight(1)
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'search', glyphSize: 19 })
            }.width(32).height(32).backgroundColor('#1C1D23').borderRadius(18)
              .onClick(() => {
                this.showSearch = !this.showSearch;
                if (!this.showSearch) { this.searchQuery = ''; }
              })
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'more', glyphSize: 18 })
            }.width(32).height(32).backgroundColor('#1C1D23').borderRadius(18).margin({ left: 8 })
              .bindMenu(this.MoreMenu, { placement: Placement.BottomRight })
          }.width('100%').height(38).alignItems(VerticalAlign.Top)
            .padding({ left: 18, right: 18 })
        }.width('100%').padding({ top: 20 }).backgroundColor('#111217')
      } else {
        Column() {
          Row() {
            Blank()
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'search', glyphSize: 19 })
            }.width(32).height(32).backgroundColor('#1C1D23').borderRadius(18)
              .onClick(() => {
                this.showSearch = !this.showSearch;
                if (!this.showSearch) { this.searchQuery = ''; }
              })
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'more', glyphSize: 18 })
            }.width(32).height(32).backgroundColor('#1C1D23').borderRadius(18).margin({ left: 8 })
              .bindMenu(this.MoreMenu, { placement: Placement.BottomRight })
          }.width('100%').height(40).padding({ left: 18, right: 18 })
          Column() {
            Text('订阅').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
            Text('全部').fontSize(14).fontColor('#B6B8C2').margin({ top: 3 })
          }.width('100%').alignItems(HorizontalAlign.Start)
            .padding({ left: 18, right: 18, top: 12, bottom: 18 }).offset({ y: -5 })
        }.width('100%').padding({ top: 20 }).backgroundColor('#111217')
      }

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 17 }).margin({ right: 9 })
          TextInput({ placeholder: '搜索订阅源…', text: this.searchQuery })
            .fontSize(16).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .onChange((value: string) => this.searchQuery = value)
        }.width('100%').padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .margin({ left: 16, right: 16, bottom: 10 }).backgroundColor('#1C1D23').borderRadius(22)
      }

      Scroll(this.subscriptionScroller) {
        Column() {
          Row() {
            Row() {
              AppGlyph({ name: 'ruleSubscription', glyphSize: 18, tint: '#C5C7D0' })
              Text('规则').fontSize(14).fontColor('#D8D9E0').margin({ left: 10 })
            }.layoutWeight(1).justifyContent(FlexAlign.Center).padding(12)
              .backgroundColor('#1C1D23').borderRadius(13)
              .onClick(() => this.onOpenRules())
            Row() {
              AppGlyph({ name: 'favoriteStar', glyphSize: 18, tint: '#C5C7D0' })
              Text('收藏').fontSize(14).fontColor('#D8D9E0').margin({ left: 10 })
            }.layoutWeight(1).justifyContent(FlexAlign.Center).padding(12)
              .backgroundColor('#1C1D23').borderRadius(13).margin({ left: 10 })
              .onClick(() => this.onOpenFavorites())
          }.width('100%').padding({ left: 16, right: 16, top: this.collapsedHeader ? 16 : 1, bottom: 14 })

          if (this.getVisibleItems().length > 0) {
            ForEach(this.getItemRows(), (row: string[], rowIndex: number) => {
              Row() {
                ForEach(row, (item: string, itemIndex: number) => {
                  if (item.length > 0) {
                    Column() {
                      Stack({ alignContent: Alignment.Center }) {
                        AppGlyph({ name: 'subscription', tint: '#AFC2FF', glyphSize: 25 })
                      }.width(42).height(42).backgroundColor('#1C1D23').borderRadius(14)
                      Text(item).fontSize(12).fontColor('#C5C7D0').textAlign(TextAlign.Center)
                        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).height(36).margin({ top: 6 })
                    }.width('100%').padding({ top: 8, bottom: 8 })
                      .onClick(() => this.onUnavailableAction('订阅源数据尚未接入'))
                  } else {
                    Blank()
                  }
                }, (item: string, itemIndex: number) => `subscription-cell-${rowIndex}-${itemIndex}`)
              }.width('100%')
            }, (row: string[], rowIndex: number) => `subscription-row-${rowIndex}`)
          } else if (this.showSearch && this.searchQuery.trim().length > 0) {
            Column() {
              AppGlyph({ name: 'search', glyphSize: 32, tint: '#AFC2FF' }).margin({ bottom: 14 })
              Text('没有匹配的订阅源').fontSize(16).fontColor('#D8D9E0')
              Text('调整搜索内容后重试').fontSize(14).fontColor('#858792').margin({ top: 8 })
            }.width('100%').height(240).justifyContent(FlexAlign.Center)
          }
        }.width('100%').padding({ bottom: 120 }).constraintSize({ minHeight: '100%' })
          .alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Start)
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => {
        const scrollOffset = this.subscriptionScroller.currentOffset().yOffset;
        if (scrollOffset > 20 && !this.collapsedHeader) {
          this.collapsedHeader = true;
        } else if (scrollOffset < -20 && this.collapsedHeader) {
          this.collapsedHeader = false;
        }
      })
    }.width('100%').height('100%').backgroundColor('#111217')
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down && event.touches.length > 0) {
          this.touchStartY = event.touches[0].screenY;
        } else if (event.type === TouchType.Up && event.changedTouches.length > 0 && this.items.length === 0) {
          const touchEndY = event.changedTouches[0].screenY;
          if (touchEndY < this.touchStartY - 40 && !this.collapsedHeader) { this.collapsedHeader = true; }
          if (touchEndY > this.touchStartY + 40 && this.collapsedHeader) { this.collapsedHeader = false; }
        }
      })
  }
}
