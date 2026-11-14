import curves from '@ohos.curves';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import { UiSection } from '../components/settings/UiSection';
import { UiAction } from '../components/settings/UiAction';

@Component
export struct AppAiSettingsPage {
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State collapsedHeader: boolean = false;
  private settingsScroller: Scroller = new Scroller();

  private updateHeader(): void {
    const offset = this.settingsScroller.currentOffset().yOffset;
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
    }
  }

  build() {
    Column() {
      CollapsingSettingsHeader({ title: 'AI 设置', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Scroll(this.settingsScroller) {
        Column() {
          UiSection({ title: '供应商' }) {
            UiAction({showDivider: false, title: '新建供应商', onSelect: () => this.onUnavailableAction('AI 服务商配置尚未迁移') })
          }

          UiSection({ title: '模型' }) {
            UiAction({showDivider: false, title: '当前模型', detail: '未配置模型', onSelect: () => this.onUnavailableAction('AI 模型选择尚未迁移') })
          }

          UiSection({ title: '任务' }) {
            UiAction({ title: '翻译设置', onSelect: () => this.onUnavailableAction('AI 翻译服务设置尚未迁移') })
            UiAction({ title: '章节梗概', onSelect: () => this.onUnavailableAction('AI 章节梗概设置尚未迁移') })
            UiAction({showDivider: false, title: '提示词设置', detail: '编辑各 AI 工具的提示词', onSelect: () => this.onUnavailableAction('AI 提示词设置尚未迁移') })
          }

          UiSection({ title: 'Skills' }) {
            UiAction({showDivider: false, title: '新建 Skill', onSelect: () => this.onUnavailableAction('AI Skill 尚未迁移') })
          }
        }.width('100%').padding({ top: 6, bottom: 120 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}
