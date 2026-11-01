@Component
export struct AppAiSettingsPage {
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State collapsedHeader: boolean = false;
  private settingsScroller: Scroller = new Scroller();

  build() {
    Column() {
      if (this.collapsedHeader) {
        Row() {
          Image($r('app.media.reader_back')).width(20).height(20).fillColor($r('app.color.theme_text_secondary'))
            .width(40).height(40).onClick(() => this.onBack())
          Text('AI 设置').fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('app.color.theme_text_primary')).margin({ left: 8 })
        }.width('100%').height(56).padding({ left: 12, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.themePureBlack ? '#000000' : $r('app.color.theme_surface_primary'))
      } else {
        Column() {
          Row() {
            Image($r('app.media.reader_back')).width(20).height(20).fillColor($r('app.color.theme_text_secondary'))
              .width(40).height(40).onClick(() => this.onBack())
            Blank()
          }.width('100%')
          Text('AI 设置').fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('app.color.theme_text_primary'))
            .alignSelf(ItemAlign.Start).margin({ top: 18, left: 8 })
        }.width('100%').padding({ left: 12, right: 16, top: 8, bottom: 10 })
      }

      Scroll(this.settingsScroller) {
        Column() {
          AiSettingsSection({ title: '供应商' }) {
            AiSettingsAction({ title: '新建供应商', onSelect: () => this.onUnavailableAction('AI 服务商配置尚未迁移') })
          }

          AiSettingsSection({ title: '模型' }) {
            AiSettingsAction({ title: '当前模型', detail: '未配置模型', onSelect: () => this.onUnavailableAction('AI 模型选择尚未迁移') })
          }

          AiSettingsSection({ title: '任务' }) {
            AiSettingsAction({ title: '翻译设置', onSelect: () => this.onUnavailableAction('AI 翻译服务设置尚未迁移') })
            Row().height(1).width('100%').backgroundColor(this.themePureBlack ? '#000000' : $r('app.color.theme_surface_primary'))
            AiSettingsAction({ title: '章节梗概', onSelect: () => this.onUnavailableAction('AI 章节梗概设置尚未迁移') })
            Row().height(1).width('100%').backgroundColor(this.themePureBlack ? '#000000' : $r('app.color.theme_surface_primary'))
            AiSettingsAction({ title: '提示词设置', detail: '编辑各 AI 工具的提示词', onSelect: () => this.onUnavailableAction('AI 提示词设置尚未迁移') })
          }

          AiSettingsSection({ title: 'Skills' }) {
            AiSettingsAction({ title: '新建 Skill', onSelect: () => this.onUnavailableAction('AI Skill 尚未迁移') })
          }
        }.width('100%').padding({ top: 6, bottom: 120 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => {
        const shouldCollapse = Math.abs(this.settingsScroller.currentOffset().yOffset) > 70;
        if (this.collapsedHeader !== shouldCollapse) { this.collapsedHeader = shouldCollapse; }
      })
    }.width('100%').height('100%').backgroundColor(this.themePureBlack ? '#000000' : $r('app.color.theme_surface_primary'))
  }
}

@Component
struct AiSettingsSection {
  @Prop title: string = '';
  @BuilderParam content: () => void = this.emptyContent;
  @Builder
  emptyContent() {
  }
  @StorageProp('themeCardRadius') themeCardRadius: number = 16;
  @StorageProp('themeCardBorderWidth') themeCardBorderWidth: number = 0;
  @StorageProp('themeCardBorderColor') themeCardBorderColor: string = '#6A6D77';
  @StorageProp('themeCardBackground') themeCardBackground: string = '';
  @StorageProp('themeContainerBackground') themeContainerBackground: string = '';
  build() {
    Column() {
      Text(this.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.theme_accent'))
        .alignSelf(ItemAlign.Start).padding({ left: 16, top: 8, bottom: 8 })
      Column() { this.content() }.margin({ left: 16, right: 16 }).backgroundColor(this.themeCardBackground.length > 0 ? this.themeCardBackground : $r('app.color.theme_surface_secondary')).borderRadius(this.themeCardRadius).border({ width: this.themeCardBorderWidth, color: this.themeCardBorderColor }).backgroundImage(this.themeContainerBackground.length > 0 ? `file://${this.themeContainerBackground}` : $r('app.media.transparent_pixel'), ImageRepeat.NoRepeat)
    }
  }
}

@Component
struct AiSettingsAction {
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(16).fontColor($r('app.color.theme_text_secondary'))
        if (this.detail.length > 0) { Text(this.detail).fontSize(12).fontColor($r('app.color.theme_text_tertiary')).margin({ top: 3 }) }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(15).height(15).fillColor($r('app.color.theme_text_tertiary'))
    }.padding({ left: 16, right: 16, top: 16, bottom: 16 }).onClick(() => this.onSelect())
  }
}
