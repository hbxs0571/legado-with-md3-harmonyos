@Component
export struct AppTranslationSettingsPage {
  onBack: () => void = () => {};
  onOpenAiSettings: () => void = () => {};
  @State providerIndex: number = 0;
  @State languageIndex: number = 0;
  @State maxChars: number = 10000;
  private readonly providers: string[] = ['Google Translate', '应用 AI 接口'];
  private readonly languages: string[] = ['简体中文', 'English', '日本語', '한국어', 'Français', 'Deutsch', 'Español', 'Русский', 'العربية'];

  build() {
    Column() {
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
          .width(40).height(40).onClick(() => this.onBack())
        Column() {
          Text('翻译设置').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
          Text('服务提供商与翻译选项').fontSize(15).fontColor('#92949E').margin({ top: 3 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.padding({ left: 12, right: 16, top: 8, bottom: 10 })

      Scroll() {
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
            TranslationSettingsSection({ title: '应用 AI 接口' }) {
              Row() {
                Column() {
                  Text('使用应用 AI 接口').fontSize(18).fontColor('#D8D9E0')
                  Text('模型、API Key 和协议在 AI 设置中配置。').fontSize(15).fontColor('#92949E').margin({ top: 3 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Image($r('app.media.reader_next')).width(15).height(15).fillColor('#92949E')
              }.padding({ left: 14, right: 14, top: 13, bottom: 13 }).onClick(() => this.onOpenAiSettings())
            }
          }
          Text('此页选项目前仅用于界面预览；不会发起翻译请求或保存设置。')
            .fontSize(15).fontColor('#858792').margin({ left: 18, right: 18, top: 6, bottom: 22 })
        }.width('100%').padding({ top: 6 })
      }.layoutWeight(1).scrollBar(BarState.Off)
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
  onSelect: (index: number) => void = (_index: number) => {};
  private getSelectedLabel(): string {
    if (this.options.length === 0) { return ''; }
    return this.options[Math.min(this.selected, this.options.length - 1)];
  }
  build() {
    Row() {
      Text(this.title).fontSize(18).fontColor('#D8D9E0').layoutWeight(1)
      Text(this.getSelectedLabel()).fontSize(12).fontColor('#AFC2FF')
      Image($r('app.media.reader_next')).width(15).height(15).fillColor('#92949E').margin({ left: 6 })
    }.padding({ left: 14, right: 14, top: 12, bottom: 12 }).onClick(() => {
      if (this.options.length > 0) {
        this.onSelect((this.selected + 1) % this.options.length);
      }
    })
  }
}