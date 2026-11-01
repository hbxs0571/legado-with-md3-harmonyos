import { AppGlyph } from '../components/AppGlyph';

@Component
export struct SubscriptionPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @StorageProp('themeItemBackground') themeItemBackground: string = '';
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  onOpenRules: () => void = () => {};
  onOpenFavorites: () => void = () => {};
  onOpenSourceManage: () => void = () => {};
  private readonly items: string[] = [];
  private subscriptionScroller: Scroller = new Scroller();
  @State touchStartY: number = 0;
  @State collapsedHeader: boolean = false;
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State gridColumnCount: number = 5;

  @Builder
  private MoreMenu() {
    Menu() {
      MenuItem({ content: '订阅源管理' })
        .onClick(() => this.onOpenSourceManage())
      MenuItem({ content: '全部' })
        .onClick(() => this.onUnavailableAction('当前已显示全部订阅源'))
    }.backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).fontColor(this.themeColorTextPrimary).radius(18)
  }

  private getVisibleItems(): string[] {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    if (query.length === 0) { return this.items; }
    return this.items.filter((item: string) => item.toLocaleLowerCase().includes(query));
  }

  private getGridColumnsTemplate(): string {
    let columns = '';
    for (let index = 0; index < this.gridColumnCount; index++) {
      columns += index === 0 ? '1fr' : ' 1fr';
    }
    return columns;
  }

  private setCollapsedHeader(collapsed: boolean): void {
    if (this.collapsedHeader === collapsed) { return; }
    animateTo({ duration: 220, curve: Curve.EaseInOut }, () => {
      this.collapsedHeader = collapsed;
    });
  }

  build() {
    Column() {
      if (this.collapsedHeader) {
        Column() {
          Row() {
            Text('订阅').fontSize(20).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
            Blank().layoutWeight(1)
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'search', glyphSize: 20 })
            }.width(36).height(36).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(18)
              .onClick(() => {
                this.showSearch = !this.showSearch;
                if (!this.showSearch) { this.searchQuery = ''; }
              })
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'more', glyphSize: 20 })
            }.width(36).height(36).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(18).margin({ left: 8 })
              .bindMenu(this.MoreMenu, { placement: Placement.BottomRight })
          }.width('100%').height(48).alignItems(VerticalAlign.Top)
            .padding({ left: 18, right: 18 })
        }.width('100%').padding({ top: 20 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
          .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
      } else {
        Column() {
          Row() {
            Blank()
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'search', glyphSize: 20 })
            }.width(36).height(36).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(18)
              .onClick(() => {
                this.showSearch = !this.showSearch;
                if (!this.showSearch) { this.searchQuery = ''; }
              })
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'more', glyphSize: 20 })
            }.width(36).height(36).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(18).margin({ left: 8 })
              .bindMenu(this.MoreMenu, { placement: Placement.BottomRight })
          }.width('100%').height(48).padding({ left: 18, right: 18 })
          Column() {
            Text('订阅').fontSize(28).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
            Text('全部').fontSize(14).fontColor('#B6B8C2').margin({ top: 3 })
          }.width('100%').alignItems(HorizontalAlign.Start)
            .padding({ left: 18, right: 18, top: 12, bottom: 18 }).offset({ y: -5 })
        }.width('100%').padding({ top: 20 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
          .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
      }

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 17 }).margin({ right: 9 })
          TextInput({ placeholder: '搜索订阅源…', text: this.searchQuery })
            .fontSize(16).fontColor(this.themeColorTextSecondary).placeholderColor(this.themeColorTextTertiary)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .onChange((value: string) => this.searchQuery = value)
        }.width('100%').padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .margin({ left: 16, right: 16, bottom: 10 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(22).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
      }

      Scroll(this.subscriptionScroller) {
        Column() {
          Row() {
            Row() {
              AppGlyph({ name: 'ruleSubscription', glyphSize: 18, tint: '#C5C7D0' })
              Text('规则').fontSize(14).fontColor(this.themeColorTextSecondary).margin({ left: 10 })
            }.layoutWeight(1).justifyContent(FlexAlign.Center).padding(12)
              .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(13).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
              .onClick(() => this.onOpenRules())
            Row() {
              AppGlyph({ name: 'favoriteStar', glyphSize: 18, tint: '#C5C7D0' })
              Text('收藏').fontSize(14).fontColor(this.themeColorTextSecondary).margin({ left: 10 })
            }.layoutWeight(1).justifyContent(FlexAlign.Center).padding(12)
              .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(13).margin({ left: 10 }).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
              .onClick(() => this.onOpenFavorites())
          }.width('100%').padding({ left: 16, right: 16, top: this.collapsedHeader ? 16 : 1, bottom: 14 })

          if (this.getVisibleItems().length > 0) {
            Grid() {
              ForEach(this.getVisibleItems(), (item: string, index: number) => {
                GridItem() {
                  Column() {
                    Stack({ alignContent: Alignment.Center }) {
                      AppGlyph({ name: 'subscription', tint: this.themeColorAccent, glyphSize: 28 })
                    }.width(48).height(48).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#121212' : this.themeColorSurfaceElevated)).borderRadius(14).backgroundImage(this.themeItemBackground.length > 0 ? `file://${this.themeItemBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
                    Text(item).fontSize(12).fontColor('#C5C7D0').textAlign(TextAlign.Center)
                      .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).height(36).margin({ top: 8 })
                  }.width('100%').padding({ top: 8, bottom: 8 })
                    .onClick(() => this.onUnavailableAction('订阅源数据尚未接入'))
                }
              }, (item: string, index: number) => `subscription-cell-${index}-${item}`)
            }.columnsTemplate(this.getGridColumnsTemplate()).columnsGap(12).rowsGap(12)
              .width('100%').height(Math.ceil(this.getVisibleItems().length / this.gridColumnCount) * 112)
              .scrollBar(BarState.Off)
          } else if (this.showSearch && this.searchQuery.trim().length > 0) {
            Column() {
              AppGlyph({ name: 'search', glyphSize: 32, tint: this.themeColorAccent }).margin({ bottom: 14 })
              Text('没有匹配的订阅源').fontSize(16).fontColor(this.themeColorTextSecondary)
              Text('调整搜索内容后重试').fontSize(14).fontColor('#858792').margin({ top: 8 })
            }.width('100%').height(240).justifyContent(FlexAlign.Center)
          }
        }.width('100%').padding({ bottom: 120 }).constraintSize({ minHeight: '100%' })
          .alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Start)
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            const width = parseFloat(String(newArea.width));
            if (Number.isFinite(width)) {
              const availableWidth = width - 32;
              const nextCount = Math.max(1, Math.floor((availableWidth + 12) / 84));
              if (this.gridColumnCount !== nextCount) { this.gridColumnCount = nextCount; }
            }
          })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => {
        const scrollOffset = this.subscriptionScroller.currentOffset().yOffset;
        if (scrollOffset > 20 && !this.collapsedHeader) {
          this.setCollapsedHeader(true);
        } else if (scrollOffset < -20 && this.collapsedHeader) {
          this.setCollapsedHeader(false);
        }
      })
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down && event.touches.length > 0) {
          this.touchStartY = event.touches[0].screenY;
        } else if (event.type === TouchType.Up && event.changedTouches.length > 0 && this.items.length === 0) {
          const touchEndY = event.changedTouches[0].screenY;
          if (touchEndY < this.touchStartY - 40 && !this.collapsedHeader) { this.setCollapsedHeader(true); }
          if (touchEndY > this.touchStartY + 40 && this.collapsedHeader) { this.setCollapsedHeader(false); }
        }
      })
  }
}
