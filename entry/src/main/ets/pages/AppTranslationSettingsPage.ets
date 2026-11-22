import { DURATION_FADE, HEADER_COLLAPSE_THRESHOLD, HEADER_EXPAND_THRESHOLD } from '../components/UiTokens';
import { ThemeItemDivider } from '../components/ThemeItemDivider';
import curves from '@ohos.curves';
import { UiSection } from '../components/settings/UiSection';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import { BODY_SMALL, HEADLINE_SMALL, LABEL_MEDIUM, TITLE_MEDIUM } from '../components/typography/TypographyTokens';

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
    const shouldCollapse = offset > HEADER_COLLAPSE_THRESHOLD ? true : offset < HEADER_EXPAND_THRESHOLD ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      // 顶部折叠是位移，用弹簧收尾更自然；弹簧不吃 duration，删掉（写了也不生效）。
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.86) }, () => {
        this.collapsedHeader = shouldCollapse;
      });
    }
  }

  build() {
    Column() {
      CollapsingSettingsHeader({ title: '翻译设置', collapsed: this.collapsedHeader, onBack: () => this.onBack() })

      Scroll(this.settingsScroller) {
        Column() {
          UiSection({ title: '翻译提供商' }) {
            TranslationSettingsChoice({ title: '提供商', options: this.providers, selected: this.providerIndex, disabled: true, onSelect: (index: number) => this.providerIndex = index })
          }

          UiSection({ title: '翻译选项' }) {
            TranslationSettingsChoice({ title: '目标语言', options: this.languages, selected: this.languageIndex, disabled: true, onSelect: (index: number) => this.languageIndex = index })
            ThemeItemDivider()
            Column() {
              Row() {
                Text('每块最大字符数').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextSecondary).layoutWeight(1)
                Text(`${Math.round(this.maxChars)}`).fontSize(BODY_SMALL).fontColor(this.themeColorAccent)
              }
              Slider({ value: this.maxChars, min: 1000, max: 10000, step: 500 })
                .selectedColor(this.themeColorAccent).trackColor('#454750').enabled(false)
                .onChange((value: number) => this.maxChars = value)
            }.padding({ left: 14, right: 14, top: 9, bottom: 9 })
          }

          if (this.providerIndex === 1) {
            Column() {
              UiSection({ title: '应用 AI 接口' }) {
                Row() {
                  Column() {
                    Text('使用应用 AI 接口').fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextSecondary)
                    Text('模型、API Key 和协议在 AI 设置中配置。').fontSize(LABEL_MEDIUM).fontColor(this.themeColorTextTertiary).margin({ top: 3 })
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Image($r('app.media.reader_next')).width(15).height(15).fillColor(this.themeColorTextTertiary)
                }.padding({ left: 14, right: 14, top: 13, bottom: 13 }).onClick(() => this.onOpenAiSettings())
              }
            }.transition(TransitionEffect.OPACITY.animation({ duration: DURATION_FADE, curve: Curve.EaseInOut }))
          }
        }.width('100%').padding({ top: 6 })
      }.edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false }).layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}

@Component
struct TranslationSettingsChoice {
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @Prop title: string = '';
  @Prop options: string[] = [];
  @Prop selected: number = 0;
  @Prop disabled: boolean = false;
  @State showOptions: boolean = false;
  onSelect: (index: number) => void = (_index: number) => {};
  private getSelectedLabel(): string {
    if (this.options.length === 0) { return ''; }
    return this.options[Math.min(this.selected, this.options.length - 1)];
  }

  @Builder
  private ChoiceSheet() {
    Column() {
      Text(this.title).fontSize(HEADLINE_SMALL).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').padding({ left: 18, right: 18, top: 12, bottom: 14 })
      Scroll() {
        Column() {
          ForEach(this.options, (option: string, index: number) => {
            Row() {
              Text(option).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextSecondary).layoutWeight(1)
              if (this.selected === index) {
                Image($r('app.media.app_check')).width(18).height(18).fillColor(this.themeColorAccent)
              }
            }.width('100%').padding({ left: 18, right: 18, top: 13, bottom: 13 })
              .onClick(() => { this.onSelect(index); this.showOptions = false; })
          }, (option: string, index: number) => `${index}-${option}`)
        }
      }.edgeEffect(EdgeEffect.None).constraintSize({ maxHeight: 440 }).scrollBar(BarState.Off)
    }.width('100%').padding({ bottom: 16 })
  }
  build() {
    Row() {
      Text(this.title).fontSize(TITLE_MEDIUM).fontColor(this.themeColorTextSecondary).layoutWeight(1)
      Text(this.getSelectedLabel()).fontSize(BODY_SMALL).fontColor(this.themeColorAccent)
      Image($r('app.media.reader_next')).width(15).height(15).fillColor(this.themeColorTextTertiary).margin({ left: 6 })
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .opacity(this.disabled ? 0.38 : 1)
      .onClick(() => { if (!this.disabled) { this.showOptions = true; } })
      .bindSheet(this.showOptions, this.ChoiceSheet(), {
        height: SheetSize.FIT_CONTENT,
        dragBar: true, showClose: false, backgroundColor: this.themeColorSurfaceTertiary,
        onDisappear: () => this.showOptions = false
      })
  }
}
