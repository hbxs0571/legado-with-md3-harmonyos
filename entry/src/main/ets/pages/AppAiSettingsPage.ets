import { UiSection } from '../components/settings/UiSection';
import { UiAction } from '../components/settings/UiAction';

@Component
export struct AppAiSettingsPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State collapsedHeader: boolean = false;
  private settingsScroller: Scroller = new Scroller();

  build() {
    Column() {
      if (this.collapsedHeader) {
        Row() {
          Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary)
            .width(40).height(40).onClick(() => this.onBack())
          Text('AI 设置').fontSize(20).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary).margin({ left: 8 })
        }.width('100%').height(56).padding({ left: 12, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
      } else {
        Column() {
          Row() {
            Image($r('app.media.reader_back')).width(20).height(20).fillColor(this.themeColorTextSecondary)
              .width(40).height(40).onClick(() => this.onBack())
            Blank()
          }.width('100%')
          Text('AI 设置').fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.themeColorTextPrimary)
            .alignSelf(ItemAlign.Start).margin({ top: 18, left: 8 })
        }.width('100%').padding({ left: 12, right: 16, top: 8, bottom: 10 })
      }

      Scroll(this.settingsScroller) {
        Column() {
          UiSection({ title: '供应商' }) {
            UiAction({ title: '新建供应商', onSelect: () => this.onUnavailableAction('AI 服务商配置尚未迁移') })
          }

          UiSection({ title: '模型' }) {
            UiAction({ title: '当前模型', detail: '未配置模型', onSelect: () => this.onUnavailableAction('AI 模型选择尚未迁移') })
          }

          UiSection({ title: '任务' }) {
            UiAction({ title: '翻译设置', onSelect: () => this.onUnavailableAction('AI 翻译服务设置尚未迁移') })
            Row().height(1).width('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
            UiAction({ title: '章节梗概', onSelect: () => this.onUnavailableAction('AI 章节梗概设置尚未迁移') })
            Row().height(1).width('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
            UiAction({ title: '提示词设置', detail: '编辑各 AI 工具的提示词', onSelect: () => this.onUnavailableAction('AI 提示词设置尚未迁移') })
          }

          UiSection({ title: 'Skills' }) {
            UiAction({ title: '新建 Skill', onSelect: () => this.onUnavailableAction('AI Skill 尚未迁移') })
          }
        }.width('100%').padding({ top: 6, bottom: 120 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => {
        const shouldCollapse = Math.abs(this.settingsScroller.currentOffset().yOffset) > 70;
        if (this.collapsedHeader !== shouldCollapse) { this.collapsedHeader = shouldCollapse; }
      })
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}
