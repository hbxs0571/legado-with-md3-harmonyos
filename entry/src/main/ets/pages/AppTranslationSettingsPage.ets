import { UiSection } from '../components/settings/UiSection';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';

@Component
export struct AppTranslationSettingsPage {
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  onBack: () => void = () => {};
  onOpenAiSettings: () => void = () => {};
  @State providerIndex: number = 0;
  @State languageIndex: number = 0;
  @State maxChars: number = 10000;
  @State collapsedHeader: boolean = false;
  private settingsScroller: Scroller = new Scroller();
  private readonly providers: string[] = ['Google Translate', '应用 AI 接口'];
  private readonly languages: string[] = ['简体中文', 'English', '日本語', '한국어', 'Français', 'Deutsch', 'Español', 'Русский', 'العربية'];

  private updateHeader(): void {
    const offset = this.settingsScroller.currentOffset().yOffset;
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      animateTo({ duration: 220, curve: Curve.EaseInOut }, () => this.collapsedHeader = shouldCollapse);
    }
  }

  build() {
    Column() {
      CollapsingSettingsHeader({ title: '翻译设置', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Scroll(this.settingsScroller) {
        Column() {
          UiSection({ title: '翻译提供商' }) {
            TranslationSettingsChoice({ title: '提供商', options: this.providers, selected: this.providerIndex, onSelect: (index: number) => this.providerIndex = index })
          }

          UiSection({ title: '翻译选项' }) {
            TranslationSettingsChoice({ title: '目标语言', options: this.languages, selected: this.languageIndex, onSelect: (index: number) => this.languageIndex = index })
            Column() {
              Row() {
                Text('每块最大字符数').fontSize(18).fontColor(this.themeColorTextSecondary).layoutWeight(1)
                Text(`${Math.round(this.maxChars)}`).fontSize(12).fontColor(this.themeColorAccent)
              }
              Slider({ value: this.maxChars, min: 1000, max: 10000, step: 500 })
                .selectedColor(this.themeColorAccent).trackColor('#454750')
                .onChange((value: number) => this.maxChars = value)
            }.padding({ left: 14, right: 14, top: 9, bottom: 9 })
          }

          if (this.providerIndex === 1) {
            Column() {
              UiSection({ title: '应用 AI 接口' }) {
                Row() {
                  Column() {
                    Text('使用应用 AI 接口').fontSize(18).fontColor(this.themeColorTextSecondary)
                    Text('模型、API Key 和协议在 AI 设置中配置。').fontSize(15).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Image($r('app.media.reader_next')).width(15).height(15).fillColor(this.themeColorTextTertiary)
                }.padding({ left: 14, right: 14, top: 13, bottom: 13 }).onClick(() => this.onOpenAiSettings())
              }
            }.transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
          }
          Text('此页选项目前仅用于界面预览；不会发起翻译请求或保存设置。')
            .fontSize(15).fontColor('#858792').margin({ left: 18, right: 18, top: 6, bottom: 22 })
        }.width('100%').padding({ top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}

@Component
struct TranslationSettingsChoice {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @Prop title: string = '';
  @Prop options: string[] = [];
  @Prop selected: number = 0;
  @State showOptions: boolean = false;
  onSelect: (index: number) => void = (_index: number) => {};
  private getSelectedLabel(): string {
    if (this.options.length === 0) { return ''; }
    return this.options[Math.min(this.selected, this.options.length - 1)];
  }

  @Builder
  private ChoiceSheet() {
    Column() {
      Text(this.title).fontSize(20).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').padding({ left: 18, right: 18, top: 12, bottom: 14 })
      Scroll() {
        Column() {
          ForEach(this.options, (option: string, index: number) => {
            Row() {
              Text(option).fontSize(16).fontColor(this.themeColorTextSecondary).layoutWeight(1)
              if (this.selected === index) {
                Image($r('app.media.app_check')).width(18).height(18).fillColor(this.themeColorAccent)
              }
            }.width('100%').padding({ left: 18, right: 18, top: 13, bottom: 13 })
              .onClick(() => { this.onSelect(index); this.showOptions = false; })
          }, (option: string, index: number) => `${index}-${option}`)
        }
      }.constraintSize({ maxHeight: 440 }).scrollBar(BarState.Off)
    }.width('100%').padding({ bottom: 16 })
  }
  build() {
    Row() {
      Text(this.title).fontSize(18).fontColor(this.themeColorTextSecondary).layoutWeight(1)
      Text(this.getSelectedLabel()).fontSize(12).fontColor(this.themeColorAccent)
      Image($r('app.media.reader_next')).width(15).height(15).fillColor(this.themeColorTextTertiary).margin({ left: 6 })
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 }).onClick(() => this.showOptions = true)
      .bindSheet(this.showOptions, this.ChoiceSheet(), {
        height: SheetSize.FIT_CONTENT,
        dragBar: true, showClose: false, backgroundColor: this.themeColorSurfaceSecondary,
        onDisappear: () => this.showOptions = false
      })
  }
}
