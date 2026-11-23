// 听书界面（player）：对照上游 ReadAloudPlayerScreen.kt 的本地实现。
// 全屏浮层，三页 Swiper（目录/封面/正文）+ 顶栏 + 底栏；所有操作回调给 Index，
// 作用于已有的 SystemTtsPlayer 单例，不持有第二份播放状态。
// 视觉对齐上游：状态栏/底栏安全区让位（appTopInset/appBottomInset）、
// 默认模糊封面背景、三档背景模式（实色/封面模糊/浅色）、封面 52%×5:7、
// Transport 三档按钮样式（普通/tonal/主播放键）、细刻度进度条。
// 平台边界：系统 TTS 无调速 API，语速滑杆只存值并如实标注；音色只有系统 3 条。

import { ReaderSheetShell } from '../components/ReaderSheetShell';
import { CoverBlurBackdrop } from '../components/CoverBlurBackdrop';
import { ImageSeedColorExtractor } from '../data/ImageSeedColorExtractor';
import { resolveGlassBlurRadius } from '../data/GlassColor';
import { BODY_MEDIUM, BODY_SMALL, HEADLINE_LARGE, LABEL_LARGE, LABEL_LARGE_LINE_HEIGHT, LABEL_SMALL, TITLE_LARGE, TITLE_LARGE_LINE_HEIGHT, TITLE_MEDIUM, TITLE_SMALL } from '../components/typography/TypographyTokens';

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
  // 默认 Blur(1)。背景档由设置 readAloudPlayerBgMode 持久化，切换经 onBgModeChange 回写。
  @Prop bgIndex: number = 1;
  @State speedPreview: number = 5;
  /**
   * 封面取色得到的主色 `#RRGGBB`，供 `CoverBlurBackdrop` 的第 2 层插值用。
   *
   * 上游 `PlayerBackground.kt` 的 `CoverBlurBackdrop` 里 `LegadoTheme.seedColor` 是当前主题的
   * seed —— 播放器场景下它来自 `PlayerThemeOverride.kt:56 rememberImageSeedColor(...)`，
   * 也就是从封面图量化出来的主色。本地在 `aboutToAppear` 里用同一套量化器取一次。
   */
  @State coverSeedColor: string = '';
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
  /** 背景档切换回写偏好（上游 readAloudPlayerBgMode）。 */
  onBgModeChange: (mode: number) => void = (_mode: number): void => {};

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
    this.loadCoverSeedColor();
  }

  /**
   * 取封面主色，喂给背景第 2 层。
   *
   * 上游 `PlayerThemeOverride.kt:56-64` 是 `rememberImageSeedColor(...)` 后 `rememberThemeOverride`，
   * 也就是播放器用自己的封面重算一套主题；本地播放器不换全局主题（换主题要走 Index 那套
   * 广播，且退出播放器还得还原），只把 seed 用在背景叠层上 —— 视觉结果与上游那层一致。
   */
  private loadCoverSeedColor(): void {
    if (this.coverUri.length === 0) {
      this.coverSeedColor = '';
      return;
    }
    ImageSeedColorExtractor.extract(this.coverUri).then((color: string) => {
      this.coverSeedColor = color;
    }).catch(() => {
      this.coverSeedColor = '';
    });
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

  // 底栏底色：上游 haze 半透明叠在背景上；鸿蒙 ArkUI 无 haze 跨组件采样，以半透明中性色呈现。
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
    this.onBgModeChange(this.bgIndex);
  }

  @Builder
  BackgroundLayer() {
    Stack() {
      if (this.bgIndex === 1 && this.coverUri.length > 0) {
        // Blur(1)：上游 `ui/widget/components/player/PlayerBackground.kt:32-38` → `CoverBlurBackdrop`，
        // 三层依次是「封面铺满 + 高斯模糊 48dp」「lerp(secondaryContainer, seedColor, 0.42) alpha 0.38」
        // 「surface alpha 0.52」。本地原来只有「封面模糊 + #B3000000 一层」，缺了后两层。
        CoverBlurBackdrop({ coverUri: this.coverUri, seedColor: this.coverSeedColor, blurRadius: 48 })
      } else if (this.bgIndex === 2) {
        // FlowingLight(2)：上游 `PlayerBackground.kt:40-64` 在设备支持运行时着色器时用
        // `CoverBlurBackdrop(blurRadius = 64.dp)` 打底再叠 `BgEffectBackground`；鸿蒙 SDK 无对应
        // 着色器能力（平台边界，已在 A31 登记），故按上游「不支持」那一支的 48dp 打底，
        // 再叠一层静态渐变补足流动光的观感。
        if (this.coverUri.length > 0) {
          CoverBlurBackdrop({ coverUri: this.coverUri, seedColor: this.coverSeedColor, blurRadius: 48 })
        }
        Column().width('100%').height('100%')
          .linearGradient({ angle: 135, colors: this.isDarkBg()
            ? [['#CC1A1A2E', 0], ['#CC2E1A3E', 0.5], ['#CC101820', 1]]
            : [['#CCB3C8FF', 0], ['#CCE8C8FF', 0.5], ['#CCFFD9C8', 1]] })
      } else if (this.bgIndex === 3) {
        // Transparent(3)：上游 `PlayerBackground.kt:66-68` 是空 Box，直接透出下层。
        // 本地浮层透出阅读页，仅叠极淡遮罩保证文字可读。
        Column().width('100%').height('100%').backgroundColor(this.isDarkBg() ? '#33000000' : '#33FFFFFF')
      } else {
        // Solid(0)：上游 `PlayerBackground.kt:70-77` 的 `surface` 实色。
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
        // 上游取 ReadAloudPlayerScreen.kt 顶栏返回
        .accessibilityText('返回')
      Column() {
        Text(this.bookName).fontSize(BODY_MEDIUM).fontWeight(FontWeight.Medium)
          .fontColor(this.fg())
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.chapterTitle).fontSize(LABEL_SMALL).fontColor(this.fgSub())
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 3 })
      }.layoutWeight(1).margin({ left: 14 })
      Image($r('app.media.reader_settings')).width(20).height(20)
        .fillColor(this.fg())
        .onClick(() => this.onOpenConfig())
        // 上游取 ReadAloudPlayerScreen.kt:217 setting
        .accessibilityText('设置')
    }
    .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
  }

  @Builder
  TocPage() {
    Column() {
      Text(`目录 · 共 ${this.chapters.length} 章`)
        .fontSize(BODY_SMALL).fontColor(this.fgTert()).width('100%')
        .padding({ left: 24, top: 12, bottom: 10 })
      List() {
        ForEach(this.chapters, (title: string, index: number) => {
          ListItem() {
            Row() {
              Text(title).fontSize(LABEL_LARGE)
                .fontColor(index === this.currentChapterIndex ? this.accent : this.fg())
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              if (index === this.currentChapterIndex) {
                Text('正在播放').fontSize(LABEL_SMALL).fontColor(this.accent).margin({ left: 8 })
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
      // 上游 PlayerMorphCover.kt:36-68：52% 屏宽、5:7 比例、圆角 8dp（:62 RoundedCornerShape(8.dp)）、无投影。
      if (this.coverUri.length > 0) {
        Image(this.coverUri)
          .width('52%').aspectRatio(5 / 7).objectFit(ImageFit.Cover)
          .borderRadius(8)
      } else {
        Column() {
          Text(this.bookName.length > 0 ? this.bookName.charAt(0) : '书')
            .fontSize(HEADLINE_LARGE).fontColor('#FFFFFF')
        }
        .width('52%').aspectRatio(5 / 7).borderRadius(8)
        .backgroundColor(this.accent)
        .justifyContent(FlexAlign.Center)
      }

      Column() {
        Text(this.currentText.length > 0 ? this.currentText : '准备朗读内容…')
          .fontSize(TITLE_LARGE).fontColor(this.fg()).maxLines(3).fontWeight(FontWeight.Medium)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%').lineHeight(TITLE_LARGE_LINE_HEIGHT).textAlign(TextAlign.Start)
        if (this.nextText.length > 0) {
          Text(this.nextText).fontSize(LABEL_LARGE).fontColor(this.fgSub()).maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%').lineHeight(LABEL_LARGE_LINE_HEIGHT).margin({ top: 10 }).textAlign(TextAlign.Start)
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
          Text(text).fontSize(TITLE_LARGE)
            .fontColor(index === this.unitIndex ? this.fg() : this.fgTert())
            .fontWeight(index === this.unitIndex ? FontWeight.Medium : FontWeight.Normal)
            .width('100%').padding({ left: 14, right: 14, top: 12, bottom: 12 })
            .lineHeight(TITLE_LARGE_LINE_HEIGHT)
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
        Text(`第 ${this.unitIndex + 1} / ${this.unitTotal} 句`).fontSize(LABEL_SMALL).fontColor(this.fgSub())
        Text(this.unitTotal > 0 ? `${Math.round(this.unitIndex * 100 / this.unitTotal)}%` : '0%')
          .fontSize(LABEL_SMALL).fontColor(this.fgSub())
      }.width('92%').justifyContent(FlexAlign.SpaceBetween)

      // 五个 Transport：上一句(普通)/上一章(tonal)/播放暂停(主)/下一章(tonal)/下一句(普通)。
      Row() {
        PlayerIconBtn({ res: 'app.media.app_previous', desc: '上一句', dark: this.isDarkBg(), style: 0, onAction: () => this.onPrevious() })
        PlayerIconBtn({ res: 'app.media.reader_reorder_up', desc: '上一章', dark: this.isDarkBg(), style: 1, onAction: () => this.onPreviousChapter() })
        PlayerIconBtn({ res: this.isPlaying ? 'app.media.reader_pause' : 'app.media.reader_play', desc: this.isPlaying ? '暂停' : '播放', dark: this.isDarkBg(), style: 2, isPlaying: this.isPlaying, onAction: () => this.onTogglePause() })
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
    .backdropBlur(resolveGlassBlurRadius(20))
  }

  @Builder
  VoiceSheet() {
    PlayerSheet({ show: this.showVoiceSheet, title: '音色', dark: this.isDarkBg(), onDismiss: () => { this.showVoiceSheet = false; } }) {
      Column() {
        ForEach(this.systemVoices, (v: VoiceOption) => {
          Row() {
            Column() {
              Text(v.name).fontSize(TITLE_MEDIUM).fontColor(this.fg())
              Text(v.lang).fontSize(LABEL_SMALL).fontColor(this.fgTert()).margin({ top: 2 })
            }.layoutWeight(1)
            if (v.name === this.voiceName) {
              Text('✓').fontSize(TITLE_MEDIUM).fontColor(this.accent)
            }
          }
          .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            this.onSelectVoice(v.person);
            this.showVoiceSheet = false;
          })
        }, (v: VoiceOption) => `${v.person}`)
        Text('系统朗读仅提供以上音色；HTTP 朗读源音色在后续版本提供。')
          .fontSize(LABEL_SMALL).fontColor(this.fgTert()).padding({ left: 16, right: 16, top: 4, bottom: 12 })
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
        Text(`${this.speedPreview}x`).fontSize(TITLE_MEDIUM).fontColor(this.fg()).margin({ top: 6 })
        Text('系统朗读不支持调速，此设置用于 HTTP 朗读源。')
          .fontSize(LABEL_SMALL).fontColor(this.fgTert()).padding({ left: 16, right: 16, top: 12, bottom: 16 })
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
            Text(label).fontSize(LABEL_LARGE).fontColor(this.fg()).layoutWeight(1)
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
    Text(this.label).fontSize(BODY_SMALL).fontColor(this.dark ? '#E8E8EA' : '#494C59')
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor(this.dark ? '#33FFFFFF' : '#E8E9ED').borderRadius(16)
      .margin({ left: 5, right: 5, bottom: 8 })
  }
}

/**
 * 播放/暂停键的容器与图标形变，对齐上游
 * `ui/widget/components/player/AnimatedPlayPauseButton.kt:96-166`：
 * 容器是「圆 ↔ 八瓣软爆裂」（128 点，`baseRadius = r*(1-0.055p)`、
 * `lobeAmplitude = r*0.055p`、转 30°），图标是 play 三角 ↔ pause 双横条的
 * 逐顶点插值（两段子路径各 5 点），容器色 `primaryContainer` ↔ `secondaryContainer`。
 *
 * ArkUI 这边用 `@AnimatableExtend` + `AnimatableArithmetic<PointVector>` 让引擎在
 * 两个端点形状之间逐帧插值（探针实测 118–240 次/秒，见 docs/KNOWN-ISSUES.md
 * 「组件级形变」一节），所以这里只给端点形状，不自己算 progress。
 */
class MorphPoint extends Array<number> {
  constructor(x: number, y: number) {
    super();
    this.push(x);
    this.push(y);
  }
}

class PointVector extends Array<MorphPoint> implements AnimatableArithmetic<PointVector> {
  constructor(points: MorphPoint[]) {
    super();
    for (let i = 0; i < points.length; i++) {
      this.push(points[i]);
    }
  }

  plus(rhs: PointVector): PointVector {
    const n: number = Math.min(this.length, rhs.length);
    const out: MorphPoint[] = [];
    for (let i = 0; i < n; i++) {
      out.push(new MorphPoint(this[i][0] + rhs[i][0], this[i][1] + rhs[i][1]));
    }
    return new PointVector(out);
  }

  subtract(rhs: PointVector): PointVector {
    const n: number = Math.min(this.length, rhs.length);
    const out: MorphPoint[] = [];
    for (let i = 0; i < n; i++) {
      out.push(new MorphPoint(this[i][0] - rhs[i][0], this[i][1] - rhs[i][1]));
    }
    return new PointVector(out);
  }

  multiply(scale: number): PointVector {
    const out: MorphPoint[] = [];
    for (let i = 0; i < this.length; i++) {
      out.push(new MorphPoint(this[i][0] * scale, this[i][1] * scale));
    }
    return new PointVector(out);
  }

  equals(rhs: PointVector): boolean {
    if (this.length !== rhs.length) {
      return false;
    }
    for (let i = 0; i < this.length; i++) {
      if (this[i][0] !== rhs[i][0] || this[i][1] !== rhs[i][1]) {
        return false;
      }
    }
    return true;
  }
}

/** 容器顶点数，对齐上游 `BUTTON_PATH_SAMPLES = 128`。 */
const PLAY_BUTTON_PATH_SAMPLES: number = 128;
/** 主播放键直径（vp）：沿用本地 Transport 行原有 54vp，上游是 72dp。 */
const PLAY_BUTTON_SIZE: number = 54;
/** 图标尺寸（vp）：沿用本地原有 26vp。 */
const PLAY_ICON_VP: number = 26;
/** 图标坐标系边长，对齐上游 `size.minDimension / 24f`。 */
const PLAY_ICON_UNIT: number = 24;

/** 圆：`progress = 0` 的端点。 */
function playButtonCirclePoints(): PointVector {
  const center: number = PLAY_BUTTON_SIZE / 2;
  const radius: number = center;
  const pts: MorphPoint[] = [];
  for (let i = 0; i < PLAY_BUTTON_PATH_SAMPLES; i++) {
    const angle: number = Math.PI * 2 * i / PLAY_BUTTON_PATH_SAMPLES - Math.PI / 2;
    pts.push(new MorphPoint(center + radius * Math.cos(angle), center + radius * Math.sin(angle)));
  }
  return new PointVector(pts);
}

/** 八瓣软爆裂：`progress = 1` 的端点，公式照上游 `playerButtonContainerPath`。 */
function playButtonBurstPoints(): PointVector {
  const center: number = PLAY_BUTTON_SIZE / 2;
  const radius: number = center;
  const progress: number = 1;
  const baseRadius: number = radius * (1 - 0.055 * progress);
  const lobeAmplitude: number = radius * 0.055 * progress;
  const rotation: number = 30 * progress / 180 * Math.PI;
  const pts: MorphPoint[] = [];
  for (let i = 0; i < PLAY_BUTTON_PATH_SAMPLES; i++) {
    const sourceAngle: number = Math.PI * 2 * i / PLAY_BUTTON_PATH_SAMPLES - Math.PI / 2;
    const angle: number = sourceAngle + rotation;
    const animatedRadius: number = baseRadius + lobeAmplitude * Math.cos(8 * sourceAngle);
    pts.push(new MorphPoint(center + animatedRadius * Math.cos(angle),
      center + animatedRadius * Math.sin(angle)));
  }
  return new PointVector(pts);
}

/** 24 单位坐标 → vp 绝对坐标（`Polygon.points` 不吃相对坐标）。 */
function playIconPoints(points: number[][]): PointVector {
  const k: number = PLAY_ICON_VP / PLAY_ICON_UNIT;
  const pts: MorphPoint[] = [];
  for (let i = 0; i < points.length; i++) {
    pts.push(new MorphPoint(points[i][0] * k, points[i][1] * k));
  }
  return new PointVector(pts);
}

/** play 三角上半段，对齐上游 `PLAY_ICON_POINTS[0]`。 */
const PLAY_ICON_UPPER: number[][] = [[8, 5], [8, 12], [19, 12], [19, 12], [8, 5]];
/** play 三角下半段，对齐上游 `PLAY_ICON_POINTS[1]`。 */
const PLAY_ICON_LOWER: number[][] = [[8, 12], [8, 19], [19, 12], [19, 12], [8, 12]];
/** pause 双横条上半段，对齐上游 `PAUSE_ICON_POINTS[0]`。 */
const PAUSE_ICON_UPPER: number[][] = [[5, 6], [5, 10], [19, 10], [19, 6], [5, 6]];
/** pause 双横条下半段，对齐上游 `PAUSE_ICON_POINTS[1]`。 */
const PAUSE_ICON_LOWER: number[][] = [[5, 14], [5, 18], [19, 18], [19, 14], [5, 14]];

// `@AnimatableExtend` 的函数表是文件级的（ets-loader 按当前文件重建 Map），
// 所以这三个函数必须与使用它们的 `build()` 在同一个 .ets 文件里，不能抽到 components/。
@AnimatableExtend(Polygon)
function playButtonShape(points: PointVector) {
  .points(points);
}

@AnimatableExtend(Polygon)
function playIconUpperShape(points: PointVector) {
  .points(points);
}

@AnimatableExtend(Polygon)
function playIconLowerShape(points: PointVector) {
  .points(points);
}

@Component
struct PlayerIconBtn {
  @StorageProp('themeColorTextPrimary') textPrimary: string = '#1B1C22';
  @StorageProp('themeColorPrimaryContainer') primaryContainer: string = '#DCE1FF';
  @StorageProp('themeColorOnPrimaryContainer') onPrimaryContainer: string = '#00174B';
  @StorageProp('themeColorSecondaryContainer') secondaryContainer: string = '#DCE7C8';
  @StorageProp('themeColorOnSecondaryContainer') onSecondaryContainer: string = '#2A3311';
  @Prop res: string = 'app.media.reader_play';
  @Prop desc: string = '';
  @Prop dark: boolean = false;
  // 0=普通(透明) 1=tonal(半透明底) 2=主播放键(形变按钮)。
  @Prop style: number = 0;
  @Prop @Watch('onPlayingChanged') isPlaying: boolean = false;
  onAction: () => void = () => {};

  // 端点形状与颜色：`isPlaying` 一变就换成另一端，引擎在两端之间逐帧插值。
  @State containerVec: PointVector = playButtonCirclePoints();
  @State iconUpperVec: PointVector = playIconPoints(PLAY_ICON_UPPER);
  @State iconLowerVec: PointVector = playIconPoints(PLAY_ICON_LOWER);
  @State containerFill: string = '#DCE1FF';
  @State iconFill: string = '#00174B';

  aboutToAppear(): void {
    this.applyPlaying(this.isPlaying);
  }

  onPlayingChanged(): void {
    this.applyPlaying(this.isPlaying);
  }

  /**
   * 切换端点。上游 `AnimatedPlayPauseButton.kt:44-68` 的过渡是
   * `tween(300, FastOutSlowIn)`，容器色 `secondaryContainer → primaryContainer`、
   * 图标色 `onSecondaryContainer → onPrimaryContainer`。
   */
  private applyPlaying(playing: boolean): void {
    this.containerVec = playing ? playButtonBurstPoints() : playButtonCirclePoints();
    this.iconUpperVec = playIconPoints(playing ? PAUSE_ICON_UPPER : PLAY_ICON_UPPER);
    this.iconLowerVec = playIconPoints(playing ? PAUSE_ICON_LOWER : PLAY_ICON_LOWER);
    this.containerFill = playing ? this.primaryContainer : this.secondaryContainer;
    this.iconFill = playing ? this.onPrimaryContainer : this.onSecondaryContainer;
  }

  build() {
    if (this.style === 2) {
      Stack({ alignContent: Alignment.Center }) {
        Polygon()
          .width(PLAY_BUTTON_SIZE).height(PLAY_BUTTON_SIZE)
          .playButtonShape(this.containerVec)
          .fill(this.containerFill)
          .animation({ duration: 300, curve: Curve.FastOutSlowIn })
        Stack({ alignContent: Alignment.Center }) {
          Polygon()
            .width(PLAY_ICON_VP).height(PLAY_ICON_VP)
            .playIconUpperShape(this.iconUpperVec)
            .fill(this.iconFill)
            .animation({ duration: 300, curve: Curve.FastOutSlowIn })
          Polygon()
            .width(PLAY_ICON_VP).height(PLAY_ICON_VP)
            .playIconLowerShape(this.iconLowerVec)
            .fill(this.iconFill)
            .animation({ duration: 300, curve: Curve.FastOutSlowIn })
        }
        .width(PLAY_ICON_VP).height(PLAY_ICON_VP)
        // 上游 `Canvas { rotate(degrees = 90f * morphProgress) }`：图标随形变同步转 90°。
        .rotate({ angle: this.isPlaying ? 90 : 0 })
        .animation({ duration: 300, curve: Curve.FastOutSlowIn })
      }
      .width(PLAY_BUTTON_SIZE).height(PLAY_BUTTON_SIZE)
      .onClick(() => this.onAction())
      .accessibilityText(this.desc)
    } else {
      Stack({ alignContent: Alignment.Center }) {
        Image($r(this.res)).width(20).height(20)
          .fillColor(this.dark ? '#F0F0F2' : this.textPrimary)
      }
      .width(44).height(44)
      .borderRadius(22)
      .backgroundColor(this.style === 1 ? (this.dark ? '#33FFFFFF' : '#E8E9ED') : Color.Transparent)
      .onClick(() => this.onAction())
      .accessibilityText(this.desc)
    }
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
      Text(this.label).fontSize(LABEL_SMALL).fontColor(this.dark ? '#D0D0D4' : this.textSecondary)
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
      // 上游 AppModalBottomSheet：外壳圆角 28、scrim 平台默认、抓手统一；底色按深/浅差异传入。
      // 本面板原本内容驱动（不固定高度），panelHeight 传 auto。
      ReaderSheetShell({
        scrimColor: '#66000000',
        panelColor: this.dark ? '#1C1D22' : this.surface,
        panelHeight: 'auto',
        showHandle: false,
        onDismiss: () => this.onDismiss()
      }) {
        Row() {
          Text(this.title).fontSize(TITLE_MEDIUM).fontWeight(FontWeight.Medium)
            .fontColor(this.dark ? '#FFFFFF' : this.textPrimaryDark())
          Blank()
          Text('关闭').fontSize(LABEL_LARGE).fontColor(this.accentColor()).onClick(() => this.onDismiss())
        }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 12 })
        this.content()
      }
    }
  }

  private textPrimaryDark(): string {
    return '#1B1C22';
  }

  private accentColor(): string {
    return '#CF3E40';
  }
}
