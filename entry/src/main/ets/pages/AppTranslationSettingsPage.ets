import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';

@Component
export struct AppTranslationSettingsPage {
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
          TranslationSettingsSection({ title: '翻译提供商' }) {
            TranslationSettingsChoice({ title: '提供商', options: this.providers, selected: this.providerIndex, onSelect: (index: number) => this.providerIndex = index })
          }

          TranslationSettingsSection({ title: '翻译选项' }) {
            TranslationSettingsChoice({ title: '目标语言', options: this.languages, selected: this.languageIndex, onSelect: (index: number) => this.languageIndex = index })
            Column() {
              Row() {
                Text('每块最大字符数').fontSize(18).fontColor('#D8D9E0').layoutWeight(1)
                Text(`${Math.round(this.maxChars)}`).fontSize(12).fontColor('#AFC2FF')
              }
              Slider({ value: this.maxChars, min: 1000, max: 10000, step: 500 })
                .selectedColor('#AFC2FF').trackColor('#454750')
                .onChange((value: number) => this.maxChars = value)
            }.padding({ left: 14, right: 14, top: 9, bottom: 9 })
          }

          if (this.providerIndex === 1) {
            Column() {
              TranslationSettingsSection({ title: '应用 AI 接口' }) {
                Row() {
                  Column() {
                    Text('使用应用 AI 接口').fontSize(18).fontColor('#D8D9E0')
                    Text('模型、API Key 和协议在 AI 设置中配置。').fontSize(15).fontColor('#92949E').margin({ top: 3 })
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Image($r('app.media.reader_next')).width(15).height(15).fillColor('#92949E')
                }.padding({ left: 14, right: 14, top: 13, bottom: 13 }).onClick(() => this.onOpenAiSettings())
              }
            }.transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
          }
          Text('此页选项目前仅用于界面预览；不会发起翻译请求或保存设置。')
            .fontSize(15).fontColor('#858792').margin({ left: 18, right: 18, top: 6, bottom: 22 })
        }.width('100%').padding({ top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct TranslationSettingsSection {
  @Prop title: string = '';
  @BuilderParam content: () => void = this.emptyContent;
  @Builder
  emptyContent() {
  }
  build() {
    Column() {
      Text(this.title).fontSize(18).fontWeight(FontWeight.Medium).fontColor('#AFC2FF')
        .alignSelf(ItemAlign.Start).padding({ left: 18, top: 14, bottom: 8 })
      Column() { this.content() }.margin({ left: 16, right: 16 }).backgroundColor('#1A1B21').borderRadius(16)
    }
  }
}

@Component
struct TranslationSettingsChoice {
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
      Text(this.title).fontSize(20).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
        .width('100%').padding({ left: 18, right: 18, top: 12, bottom: 14 })
      Scroll() {
        Column() {
          ForEach(this.options, (option: string, index: number) => {
            Row() {
              Text(option).fontSize(16).fontColor('#D8D9E0').layoutWeight(1)
              if (this.selected === index) {
                Image($r('app.media.app_check')).width(18).height(18).fillColor('#AFC2FF')
              }
            }.width('100%').padding({ left: 18, right: 18, top: 13, bottom: 13 })
              .onClick(() => { this.onSelect(index); this.showOptions = false; })
          }, (option: string, index: number) => `${index}-${option}`)
        }
      }.height(440).scrollBar(BarState.Off)
    }.width('100%').padding({ bottom: 16 })
  }
  build() {
    Row() {
      Text(this.title).fontSize(18).fontColor('#D8D9E0').layoutWeight(1)
      Text(this.getSelectedLabel()).fontSize(12).fontColor('#AFC2FF')
      Image($r('app.media.reader_next')).width(15).height(15).fillColor('#92949E').margin({ left: 6 })
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 }).onClick(() => this.showOptions = true)
      .bindSheet(this.showOptions, this.ChoiceSheet(), {
        height: Math.min(520, 90 + this.options.length * 54),
        dragBar: true, showClose: false, backgroundColor: '#1A1B21',
        onDisappear: () => this.showOptions = false
      })
  }
}
