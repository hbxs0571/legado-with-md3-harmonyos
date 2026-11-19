// 听书界面（player）：对照上游 ReadAloudPlayerScreen.kt 的本地实现。
// 全屏浮层，三页 Swiper（目录/封面/正文）+ 顶栏 + 底栏；所有操作回调给 Index，
// 作用于已有的 SystemTtsPlayer 单例，不持有第二份播放状态。
// 视觉对齐上游：状态栏/底栏安全区让位（appTopInset/appBottomInset）、
// 默认模糊封面背景、三档背景模式（实色/封面模糊/浅色）、封面 52%×5:7、
// Transport 三档按钮样式（普通/tonal/主播放键）、细刻度进度条。
// 平台边界：系统 TTS 无调速 API，语速滑杆只存值并如实标注；音色只有系统 3 条。

@Extend(Text)
function playerText(size: number, color: string, weight: FontWeight): void {
  .fontSize(size)
  .fontColor(color)
  .fontWeight(weight)
}

@Component
export struct ReadAloudPlayerPage {
  @StorageProp('themeColorTextPrimary') textPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') textSecondary: string = '#494C59';
  @StorageProp('themeColorTextTertiary') textTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') accent: string = '#CF3E40';
  @StorageProp('themeColorSurfacePrimary') surfacePrimary: string = '#FFFFFF';
  @StorageProp('appTopInset') appTopInset: number = 0;
  @StorageProp('appBottomInset') appBottomInset: number = 0;

  @Prop bookName: string = '';
  @Prop author: string = '';
  @Prop chapterTitle: string = '';
  @Prop coverUri: string = '';
  @Prop isPlaying: boolean = false;
  @Prop @Watch('onUnitIndexChange') unitIndex: number = 0;
  @Prop unitTotal: number = 0;
  @Prop currentText: string = '';
  @Prop nextText: string = '';
  @Prop texts: string[] = [];
  @Prop chapters: string[] = [];
  @Prop currentChapterIndex: number = 0;
  @Prop speedLabel: string = '5x';
  @Prop timerLabel: string = '关闭';
  @Prop voiceName: string = '聆小珊';

  @State showVoiceSheet: boolean = false;
  @State showSpeedSheet: boolean = false;
  @State showTimerSheet: boolean = false;
  // 对齐上游 ReadAloudBgMode（PreferKey.kt:509-514）：0=Solid 1=Blur 2=FlowingLight 3=Transparent。
  // 默认 Blur(1)。流动光用静态渐变近似（Compose 专属 shader 本地做不到），透明档露出下层。
  @State bgIndex: number = 1;
  @State speedPreview: number = 5;
  @State timerModeSel: string = 'minute';
  @State timerMinutesSel: number = 10;
  @State timerChaptersSel: number = 1;
  private textScroller: Scroller = new Scroller();

  onBack: () => void = () => {};
  onPrevious: () => void = () => {};
  onPreviousChapter: () => void = () => {};
  onTogglePause: () => void = () => {};
  onNextChapter: () => void = () => {};
  onNext: () => void = () => {};
  onSeek: (index: number) => void = (_index: number): void => {};
  onSelectChapter: (index: number) => void = (_index: number): void => {};
  onSwitchToClassic: () => void = () => {};
  onSelectVoice: (person: number) => void = (_person: number): void => {};
  onRateChange: (rate: number) => void = (_rate: number): void => {};
  onTimerChange: (mode: string, minutes: number, chapters: number) => void =
    (_mode: string, _minutes: number, _chapters: number): void => {};
  onOpenConfig: () => void = () => {};

  // 上游字符串 read_aloud_bg_solid / blur / flowing_light / transparent。
  private readonly bgLabels: string[] = ['纯色', '封面模糊', '流动光', '透明'];
  // 系统 TTS 只有 3 个音色（SDK 实测），person 为 createEngine 的人声值。
  private readonly systemVoices: VoiceOption[] = [
    { person: 13, name: '聆小珊', lang: '中文' },
    { person: 21, name: '凌飞哲', lang: '中文' },
    { person: 8, name: '英语人声', lang: '英文' }
  ];

  aboutToAppear(): void {
    this.speedPreview = this.parseRate(this.speedLabel);
  }

  private parseRate(label: string): number {
    const n: number = Number.parseFloat(label);
    return Number.isFinite(n) ? Math.round(n) : 5;
  }

  // 背景实际明暗（决定前景文字色），与主题 textPrimary 解耦：
  // 封面模糊(1) 恒暗（封面叠暗遮罩）；纯色(0)/流动光(2) 跟随主题 surfacePrimary 明暗；
  // 透明(3) 露出下层阅读页，同样跟随主题。前景色按实际背景给固定值，不取主题 textPrimary
  // （夜间主题下它是浅色，浅底档会白字白底看不清）。
  private isDarkBg(): boolean {
    if (this.bgIndex === 1) { return true; }
    return !this.isLightColor(this.surfacePrimary);
  }

  private isLightColor(hex: string): boolean {
    const h: string = hex.replace('#', '');
    if (h.length < 6) { return false; }
    const r: number = parseInt(h.substring(0, 2), 16);
    const g: number = parseInt(h.substring(2, 4), 16);
    const b: number = parseInt(h.substring(4, 6), 16);
    return (r * 299 + g * 587 + b * 114) / 1000 > 128;
  }

  // 前景文字色按实际背景明暗给固定值，不取主题色——三种背景模式由 player 自己控制，
  // 与全局主题深浅是两回事（夜间主题的浅色档必须配深色字）。
  private fg(): string {
    return this.isDarkBg() ? '#FFFFFF' : '#1B1C22';
  }

  private fgSub(): string {
    return this.isDarkBg() ? '#B3B3B8' : '#494C59';
  }

  private fgTert(): string {
    return this.isDarkBg() ? '#8A8A90' : '#6A6D77';
  }

  // 底栏底色：上游 haze 半透明叠在背景上；本地用半透明中性色近似。
  private barBg(): string {
    return this.isDarkBg() ? '#99000000' : '#99F5F6F8';
  }

  private onUnitIndexChange(): void {
    if (this.unitIndex >= 0 && this.unitIndex < this.texts.length) {
      this.textScroller.scrollToIndex(this.unitIndex, true, ScrollAlign.CENTER);
    }
  }

  private cycleBg(): void {
    this.bgIndex = (this.bgIndex + 1) % this.bgLabels.length;
  }

  @Builder
  BackgroundLayer() {
    Stack() {
      if (this.bgIndex === 1 && this.coverUri.length > 0) {
        // Blur(1)：上游 CoverBlurBackdrop —— 封面拉伸铺满 + 高斯模糊 + 暗色遮罩。
        Image(this.coverUri)
          .width('100%').height('100%').objectFit(ImageFit.Cover)
          .blur(40).scale({ x: 1.2, y: 1.2 })
        Column().width('100%').height('100%').backgroundColor('#B3000000')
      } else if (this.bgIndex === 2) {
        // FlowingLight(2)：上游是封面模糊 + 流动光 shader；本地无该 shader，静态渐变近似。
        if (this.coverUri.length > 0) {
          Image(this.coverUri).width('100%').height('100%').objectFit(ImageFit.Cover).blur(48)
        }
        Column().width('100%').height('100%')
          .linearGradient({ angle: 135, colors: this.isDarkBg()
            ? [['#CC1A1A2E', 0], ['#CC2E1A3E', 0.5], ['#CC101820', 1]]
            : [['#CCB3C8FF', 0], ['#CCE8C8FF', 0.5], ['#CCFFD9C8', 1]] })
      } else if (this.bgIndex === 3) {
        // Transparent(3)：上游透出下层；本地浮层透出阅读页，仅叠极淡遮罩保证文字可读。
        Column().width('100%').height('100%').backgroundColor(this.isDarkBg() ? '#33000000' : '#33FFFFFF')
      } else {
        // Solid(0)：上游 surface 实色。
        Column().width('100%').height('100%')
          .backgroundColor(this.isLightColor(this.surfacePrimary) ? this.surfacePrimary : '#17181D')
      }
    }
    .width('100%').height('100%')
  }

  @Builder
  TopBar() {
    Row() {
      Image($r('app.media.reader_back')).width(22).height(22)
        .fillColor(this.fg())
        .onClick(() => this.onBack())
      Column() {
        Text(this.bookName).fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.fg())
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.chapterTitle).fontSize(11).fontColor(this.fgSub())
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 3 })
      }.layoutWeight(1).margin({ left: 14 })
      Image($r('app.media.reader_settings')).width(20).height(20)
        .fillColor(this.fg())
        .onClick(() => this.onOpenConfig())
    }
    .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
  }

  @Builder
  TocPage() {
    Column() {
      Text(`目录 · 共 ${this.chapters.length} 章`)
        .fontSize(12).fontColor(this.fgTert()).width('100%')
        .padding({ left: 24, top: 12, bottom: 10 })
      List() {
        ForEach(this.chapters, (title: string, index: number) => {
          ListItem() {
            Row() {
              Text(title).fontSize(14)
                .fontColor(index === this.currentChapterIndex ? this.accent : this.fg())
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              if (index === this.currentChapterIndex) {
                Text('正在播放').fontSize(10).fontColor(this.accent).margin({ left: 8 })
              }
            }
            .width('100%').padding({ left: 24, right: 24, top: 14, bottom: 14 })
          }
          .onClick(() => this.onSelectChapter(index))
        }, (title: string, index: number) => `${index}_${title}`)
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%')
  }

  @Builder
  CoverPage() {
    Column() {
      // 上游 PlayerMorphCover：52% 屏宽、5:7 比例。
      if (this.coverUri.length > 0) {
        Image(this.coverUri)
          .width('52%').aspectRatio(5 / 7).objectFit(ImageFit.Cover)
          .borderRadius(16).shadow({ radius: 24, color: '#66000000', offsetX: 0, offsetY: 12 })
      } else {
        Column() {
          Text(this.bookName.length > 0 ? this.bookName.charAt(0) : '书')
            .fontSize(48).fontColor('#FFFFFF')
        }
        .width('52%').aspectRatio(5 / 7).borderRadius(16)
        .backgroundColor(this.accent)
        .shadow({ radius: 24, color: '#66000000', offsetX: 0, offsetY: 12 })
        .justifyContent(FlexAlign.Center)
      }

      Column() {
        Text(this.currentText.length > 0 ? this.currentText : '准备朗读内容…')
          .fontSize(18).fontColor(this.fg()).maxLines(3).fontWeight(FontWeight.Medium)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%').lineHeight(29).textAlign(TextAlign.Start)
        if (this.nextText.length > 0) {
          Text(this.nextText).fontSize(14).fontColor(this.fgSub()).maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%').lineHeight(23).margin({ top: 10 }).textAlign(TextAlign.Start)
        }
      }
      .width('86%').layoutWeight(1).justifyContent(FlexAlign.Center)

      // 三张信息卡：音色 / 语速（非默认时）/ 定时（开启时）。
      Row() {
        TextCard({ label: `音色 ${this.voiceName}`, dark: this.isDarkBg() })
          .onClick(() => { this.showVoiceSheet = true; })
        if (this.speedLabel !== '5x' && this.speedLabel !== '5') {
          TextCard({ label: this.speedLabel, dark: this.isDarkBg() })
            .onClick(() => { this.showSpeedSheet = true; })
        }
        if (this.timerLabel !== '关闭') {
          TextCard({ label: this.timerLabel, dark: this.isDarkBg() })
            .onClick(() => { this.showTimerSheet = true; })
        }
      }.width('100%').justifyContent(FlexAlign.Center).padding({ bottom: 8 })
    }.width('100%').height('100%').padding({ left: 24, right: 24 })
  }

  @Builder
  TextPage() {
    List({ scroller: this.textScroller }) {
      ForEach(this.texts, (text: string, index: number) => {
        ListItem() {
          Text(text).fontSize(18)
            .fontColor(index === this.unitIndex ? this.fg() : this.fgTert())
            .fontWeight(index === this.unitIndex ? FontWeight.Medium : FontWeight.Normal)
            .width('100%').padding({ left: 14, right: 14, top: 12, bottom: 12 })
            .lineHeight(28)
            .borderRadius(16)
            .backgroundColor(index === this.unitIndex
              ? (this.isDarkBg() ? '#33FFFFFF' : '#1A000000') : Color.Transparent)
        }
        .onClick(() => this.onSeek(index))
      }, (text: string, index: number) => `${index}`)
    }
    .width('100%').height('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  BottomBar() {
    Column() {
      // 进度条：句序即进度（上游按 chapterPosition，本地按语义切段句序）。
      Slider({
        value: this.unitIndex,
        min: 0,
        max: Math.max(1, this.unitTotal - 1),
        step: 1,
        style: SliderStyle.OutSet
      })
        .width('92%')
        .selectedColor(this.fg())
        .trackColor(this.isDarkBg() ? '#66FFFFFF' : '#66000000')
        .onChange((value: number, _mode: SliderChangeMode): void => {
          this.onSeek(Math.round(value));
        })
      Row() {
        Text(`第 ${this.unitIndex + 1} / ${this.unitTotal} 句`).fontSize(11).fontColor(this.fgSub())
        Text(this.unitTotal > 0 ? `${Math.round(this.unitIndex * 100 / this.unitTotal)}%` : '0%')
          .fontSize(11).fontColor(this.fgSub())
      }.width('92%').justifyContent(FlexAlign.SpaceBetween)

      // 五个 Transport：上一句(普通)/上一章(tonal)/播放暂停(主)/下一章(tonal)/下一句(普通)。
      Row() {
        PlayerIconBtn({ res: 'app.media.app_previous', desc: '上一句', dark: this.isDarkBg(), style: 0, onAction: () => this.onPrevious() })
        PlayerIconBtn({ res: 'app.media.reader_reorder_up', desc: '上一章', dark: this.isDarkBg(), style: 1, onAction: () => this.onPreviousChapter() })
        PlayerIconBtn({ res: this.isPlaying ? 'app.media.reader_pause' : 'app.media.reader_play', desc: this.isPlaying ? '暂停' : '播放', dark: this.isDarkBg(), style: 2, onAction: () => this.onTogglePause() })
        PlayerIconBtn({ res: 'app.media.reader_reorder_down', desc: '下一章', dark: this.isDarkBg(), style: 1, onAction: () => this.onNextChapter() })
        PlayerIconBtn({ res: 'app.media.reader_next', desc: '下一句', dark: this.isDarkBg(), style: 0, onAction: () => this.onNext() })
      }.width('100%').justifyContent(FlexAlign.SpaceEvenly).margin({ top: 6 })

      // 五个功能：切换经典 / 背景模式 / 音色 / 语速 / 定时（透明底）。
      Row() {
        PlayerTextBtn({ label: '切换经典', dark: this.isDarkBg(), onAction: () => this.onSwitchToClassic() })
        PlayerTextBtn({ label: this.bgLabels[this.bgIndex], dark: this.isDarkBg(), onAction: () => this.cycleBg() })
        PlayerTextBtn({ label: '音色', dark: this.isDarkBg(), onAction: () => { this.showVoiceSheet = true; } })
        PlayerTextBtn({ label: '语速', dark: this.isDarkBg(), onAction: () => { this.showSpeedSheet = true; } })
        PlayerTextBtn({ label: '定时', dark: this.isDarkBg(), onAction: () => { this.showTimerSheet = true; } })
      }.width('100%').justifyContent(FlexAlign.SpaceEvenly).margin({ top: 8, bottom: 6 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 10, bottom: 10 + this.appBottomInset })
    .backgroundColor(this.barBg())
    .backdropBlur(20)
  }

  @Builder
  VoiceSheet() {
    PlayerSheet({ show: this.showVoiceSheet, title: '音色', dark: this.isDarkBg(), onDismiss: () => { this.showVoiceSheet = false; } }) {
      Column() {
        ForEach(this.systemVoices, (v: VoiceOption) => {
          Row() {
            Column() {
              Text(v.name).fontSize(15).fontColor(this.fg())
              Text(v.lang).fontSize(11).fontColor(this.fgTert()).margin({ top: 2 })
            }.layoutWeight(1)
            if (v.name === this.voiceName) {
              Text('✓').fontSize(16).fontColor(this.accent)
            }
          }
          .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            this.onSelectVoice(v.person);
            this.showVoiceSheet = false;
          })
        }, (v: VoiceOption) => `${v.person}`)
        Text('系统朗读仅提供以上音色；HTTP 朗读源音色在后续版本提供。')
          .fontSize(11).fontColor(this.fgTert()).padding({ left: 16, right: 16, top: 4, bottom: 12 })
      }
    }
  }

  @Builder
  SpeedSheet() {
    PlayerSheet({ show: this.showSpeedSheet, title: '调整语速', dark: this.isDarkBg(), onDismiss: () => { this.showSpeedSheet = false; } }) {
      Column() {
        Slider({ value: this.speedPreview, min: 1, max: 10, step: 1, style: SliderStyle.OutSet })
          .width('90%').margin({ top: 16 })
          .selectedColor(this.accent)
          .onChange((value: number, _mode: SliderChangeMode): void => { this.speedPreview = Math.round(value); })
        Text(`${this.speedPreview}x`).fontSize(15).fontColor(this.fg()).margin({ top: 6 })
        Text('系统朗读不支持调速，此设置用于 HTTP 朗读源。')
          .fontSize(11).fontColor(this.fgTert()).padding({ left: 16, right: 16, top: 12, bottom: 16 })
        Button('保存').width('90%').backgroundColor(this.accent).onClick(() => {
          this.onRateChange(this.speedPreview);
          this.showSpeedSheet = false;
        })
      }
    }
  }

  @Builder
  TimerSheet() {
    PlayerSheet({ show: this.showTimerSheet, title: '定时停止', dark: this.isDarkBg(), onDismiss: () => { this.showTimerSheet = false; } }) {
      Column() {
        ForEach(['关闭', '按分钟', '按章节'], (label: string, index: number) => {
          Row() {
            Text(label).fontSize(14).fontColor(this.fg()).layoutWeight(1)
          }
          .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
          .onClick(() => {
            if (index === 0) {
              this.onTimerChange('minute', 0, 0);
              this.showTimerSheet = false;
            } else if (index === 1) {
              this.timerModeSel = 'minute';
              this.onTimerChange('minute', Math.max(1, this.timerMinutesSel), 0);
              this.showTimerSheet = false;
            } else {
              this.timerModeSel = 'chapter';
              this.onTimerChange('chapter', 0, Math.max(1, this.timerChaptersSel));
              this.showTimerSheet = false;
            }
          })
        }, (label: string, index: number) => `${index}`)
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      this.BackgroundLayer()
      Column() {
        // 顶栏让开状态栏：全屏布局下内容画到状态栏底下，必须自己加 appTopInset。
        Row() {
          this.TopBar()
        }
        .width('100%').padding({ top: this.appTopInset })
        .backgroundColor(this.isDarkBg() ? '#33000000' : '#33FFFFFF')

        // 三页：目录 / 封面 / 正文。正文与顶栏/底栏的留白由各页内部负责。
        Swiper() {
          this.TocPage()
          this.CoverPage()
          this.TextPage()
        }
        .index(1)
        .loop(false)
        .width('100%').layoutWeight(1)

        this.BottomBar()
      }
      .width('100%').height('100%')

      this.VoiceSheet()
      this.SpeedSheet()
      this.TimerSheet()
    }
    .width('100%').height('100%')
  }
}

interface VoiceOption {
  person: number;
  name: string;
  lang: string;
}

@Component
struct TextCard {
  @Prop label: string = '';
  @Prop dark: boolean = false;
  build() {
    Text(this.label).fontSize(12).fontColor(this.dark ? '#E8E8EA' : '#494C59')
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor(this.dark ? '#33FFFFFF' : '#E8E9ED').borderRadius(16)
      .margin({ left: 5, right: 5, bottom: 8 })
  }
}

@Component
struct PlayerIconBtn {
  @StorageProp('themeColorTextPrimary') textPrimary: string = '#1B1C22';
  @Prop res: string = 'app.media.reader_play';
  @Prop desc: string = '';
  @Prop dark: boolean = false;
  // 0=普通(透明) 1=tonal(半透明底) 2=主播放键(accent 底)。
  @Prop style: number = 0;
  onAction: () => void = () => {};
  build() {
    Stack({ alignContent: Alignment.Center }) {
      Image($r(this.res)).width(this.style === 2 ? 26 : 20).height(this.style === 2 ? 26 : 20)
        .fillColor(this.style === 2 ? '#FFFFFF'
          : (this.dark ? '#F0F0F2' : this.textPrimary))
    }
    .width(this.style === 2 ? 54 : 44).height(this.style === 2 ? 54 : 44)
    .borderRadius(this.style === 2 ? 27 : 22)
    .backgroundColor(this.style === 2 ? '#CF3E40'
      : (this.style === 1 ? (this.dark ? '#33FFFFFF' : '#E8E9ED') : Color.Transparent))
    .onClick(() => this.onAction())
    .accessibilityText(this.desc)
  }
}

@Component
struct PlayerTextBtn {
  @StorageProp('themeColorTextSecondary') textSecondary: string = '#494C59';
  @Prop label: string = '';
  @Prop dark: boolean = false;
  onAction: () => void = () => {};
  build() {
    Column() {
      Text(this.label).fontSize(11).fontColor(this.dark ? '#D0D0D4' : this.textSecondary)
    }
    .width(60).height(48).justifyContent(FlexAlign.Center)
    .borderRadius(12).onClick(() => this.onAction())
  }
}

@Component
struct PlayerSheet {
  @StorageProp('themeColorSurfacePrimary') surface: string = '#FFFFFF';
  @Prop show: boolean = false;
  @Prop title: string = '';
  @Prop dark: boolean = false;
  onDismiss: () => void = () => {};
  @BuilderParam content: () => void = this.emptyContent;
  @Builder emptyContent() {}
  build() {
    if (this.show) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column().width('100%').height('100%').backgroundColor('#99000000').onClick(() => this.onDismiss())
        Column() {
          Row() {
            Text(this.title).fontSize(16).fontWeight(FontWeight.Medium)
              .fontColor(this.dark ? '#FFFFFF' : this.textPrimaryDark())
            Blank()
            Text('关闭').fontSize(14).fontColor(this.accentColor()).onClick(() => this.onDismiss())
          }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 12 })
          this.content()
        }
        .width('100%').backgroundColor(this.dark ? '#1C1D22' : this.surface)
        .borderRadius({ topLeft: 20, topRight: 20 })
        .padding({ bottom: 20 + 0 })
      }
      .width('100%').height('100%')
    }
  }

  private textPrimaryDark(): string {
    return '#1B1C22';
  }

  private accentColor(): string {
    return '#CF3E40';
  }
}
