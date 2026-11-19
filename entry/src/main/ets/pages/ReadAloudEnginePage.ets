import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import { HttpTts } from '../model/HttpTts';
import { ReadAloudVoice, READ_ALOUD_VOICE_ENGINE_HTTP,
  READ_ALOUD_VOICE_MANAGED_BY_HTTP_SOURCE_CATALOG } from '../model/ReadAloudVoice';

/**
 * 批8：朗读引擎与音色页，对齐上游 CloudTtsScreen.kt 的视觉骨架：
 * 标题「朗读引擎与音色」+ 音色/引擎两 tab + 右下 FAB + 列表行（行尾编辑/删除/拉取 tonal 按钮）
 * + 编辑底部 sheet。
 *
 * 平台边界：上游的 analyzeUrl 模板/JS、loginCheckJs、jsLib 依赖 Rhino，鸿蒙无 JS 引擎，
 * 这几项只做字段保留不执行；用户源必须是纯 URL 源。音色目录走 {url}?catalog=1。
 */
interface VoiceItemUi {
  id: string;
  title: string;
  summary: string;
  sourceId: string;
  speakerId: string;
  excluded: boolean;
}

@Component
export struct ReadAloudEnginePage {
  @StorageProp('themeColorSurfacePrimary') surfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceSecondary') surfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorSurfaceTertiary') surfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorTextPrimary') textPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') textSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') textTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') accent: string = '#3F5BD9';
  @StorageProp('themeAppBackground') appBackground: string = '';
  @StorageProp('themePureBlack') pureBlack: boolean = false;
  @StorageProp('themeCardRadius') cardRadius: number = 16;
  @StorageProp('appTopInset') topInset: number = 0;

  @Prop sources: HttpTts[] = [];
  @Prop voices: ReadAloudVoice[] = [];
  @Prop selectedSourceId: string = '';
  @Prop selectedSpeakerId: string = '';

  onBack: () => void = () => {};
  onSaveSource: (source: HttpTts) => void = (_source: HttpTts) => {};
  onDeleteSource: (id: number) => void = (_id: number) => {};
  onSelectSource: (id: number) => void = (_id: number) => {};
  onFetchCatalog: (source: HttpTts) => void = (_source: HttpTts) => {};
  onToggleVoiceExcluded: (voice: ReadAloudVoice) => void = (_voice: ReadAloudVoice) => {};
  onSelectVoice: (voice: ReadAloudVoice) => void = (_voice: ReadAloudVoice) => {};
  onMessage: (message: string) => void = (_message: string) => {};

  @State activeTab: number = 1;
  @State showEditor: boolean = false;
  @State editingId: number = 0;
  @State formName: string = '';
  @State formUrl: string = '';
  @State formContentType: string = '';
  @State formSpeed: number = 5;
  @State formTextParam: string = 'text';
  @State formSpeedParam: string = 'speed';
  @State formToneParam: string = 'tone';
  private scroller: Scroller = new Scroller();

  /** 按当前 tab 的引擎过滤音色；这里只列 http 引擎（系统 TTS 音色另在听书页选）。 */
  private voiceItems(): VoiceItemUi[] {
    const items: VoiceItemUi[] = [];
    this.voices.forEach((voice: ReadAloudVoice): void => {
      if (voice.engineType !== READ_ALOUD_VOICE_ENGINE_HTTP) { return; }
      const source = this.sources.find((s: HttpTts): boolean => String(s.id) === voice.engineId);
      const title = voice.displayName.length > 0 ? voice.displayName : voice.speakerId;
      const summary = source === undefined ? voice.speakerId : `${source.name} · ${voice.speakerId}`;
      items.push({
        id: voice.id, title: title, summary: summary, sourceId: voice.engineId,
        speakerId: voice.speakerId, excluded: voice.excluded
      });
    });
    return items;
  }

  private openEditor(source: HttpTts | null): void {
    if (source === null) {
      this.editingId = 0;
      this.formName = '';
      this.formUrl = '';
      this.formContentType = '';
      this.formSpeed = 5;
      this.formTextParam = 'text';
      this.formSpeedParam = 'speed';
      this.formToneParam = 'tone';
    } else {
      this.editingId = source.id;
      this.formName = source.name;
      this.formUrl = source.url;
      this.formContentType = source.contentType ?? '';
      this.formSpeed = source.speed === undefined ? 5 : source.speed;
      this.formTextParam = source.textParam === undefined ? 'text' : source.textParam;
      this.formSpeedParam = source.speedParam === undefined ? 'speed' : source.speedParam;
      this.formToneParam = source.toneParam === undefined ? 'tone' : source.toneParam;
    }
    this.showEditor = true;
  }

  private saveSource(): void {
    if (this.formName.trim().length === 0 || this.formUrl.trim().length === 0) {
      this.onMessage('名称与 URL 不能为空');
      return;
    }
    const source: HttpTts = {
      id: this.editingId === 0 ? Date.now() : this.editingId,
      name: this.formName.trim(),
      url: this.formUrl.trim(),
      contentType: this.formContentType.trim().length > 0 ? this.formContentType.trim() : undefined,
      speed: this.formSpeed,
      synthesisThreadCount: 1,
      lastUpdateTime: Date.now(),
      textParam: this.formTextParam,
      speedParam: this.formSpeedParam,
      toneParam: this.formToneParam
    };
    this.onSaveSource(source);
    this.showEditor = false;
  }

  @Builder
  sourceList() {
    Column() {
      if (this.sources.length === 0) {
        Text('暂无朗读引擎，点右下角 + 添加').fontSize(15).fontColor(this.textTertiary)
          .padding({ top: 40, bottom: 40 });
      }
      ForEach(this.sources, (source: HttpTts): void => {
        Column() {
          Row() {
            Column() {
              Text(source.name).fontSize(16).fontColor(this.textPrimary).maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
              Text(`${String(source.id) === this.selectedSourceId ? '当前 · ' : ''}${source.url}`)
                .fontSize(13).fontColor(this.textTertiary).maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 });
            }.layoutWeight(1).alignItems(HorizontalAlign.Start);
            if (String(source.id) === this.selectedSourceId) {
              Text('使用中').fontSize(12).fontColor(this.accent).margin({ left: 8 });
            }
          }.width('100%');
          Row({ space: 8 }) {
            Button('设为当前').fontSize(12).height(32)
              .backgroundColor(this.surfaceTertiary).fontColor(this.textSecondary)
              .onClick(() => this.onSelectSource(source.id));
            Button('拉取音色').fontSize(12).height(32)
              .backgroundColor(this.surfaceTertiary).fontColor(this.textSecondary)
              .onClick(() => this.onFetchCatalog(source));
            Button('编辑').fontSize(12).height(32)
              .backgroundColor(this.surfaceTertiary).fontColor(this.textSecondary)
              .onClick(() => this.openEditor(source));
            Button('删除').fontSize(12).height(32)
              .backgroundColor(this.surfaceTertiary).fontColor('#C62828')
              .onClick(() => this.onDeleteSource(source.id));
          }.margin({ top: 12 });
        }.width('100%').padding(16).backgroundColor(this.surfaceSecondary)
          .borderRadius(this.cardRadius).margin({ bottom: 12 })
          .onClick(() => this.onSelectSource(source.id));
      }, (source: HttpTts): string => String(source.id));
    }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 80 });
  }

  @Builder
  voiceList() {
    Column() {
      if (this.voiceItems().length === 0) {
        Text('暂无音色，切到「引擎」页拉取').fontSize(15).fontColor(this.textTertiary)
          .padding({ top: 40, bottom: 40 });
      }
      ForEach(this.voiceItems(), (item: VoiceItemUi): void => {
        Row() {
          Column() {
            Text(item.title).fontSize(16).fontColor(item.excluded ? this.textTertiary : this.textPrimary)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
            Text(item.excluded ? `${item.summary} · 已排除` : item.summary)
              .fontSize(13).fontColor(this.textTertiary).maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 });
          }.layoutWeight(1).alignItems(HorizontalAlign.Start);
          Button(item.excluded ? '恢复' : '排除').fontSize(12).height(32)
            .backgroundColor(this.surfaceTertiary).fontColor(this.textSecondary)
            .onClick(() => {
              const voice = this.voices.find((v: ReadAloudVoice): boolean => v.id === item.id);
              if (voice !== undefined) { this.onToggleVoiceExcluded(voice); }
            });
        }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
          .backgroundColor(this.surfaceSecondary).borderRadius(this.cardRadius)
          .margin({ bottom: 10 })
          .onClick(() => {
            const voice = this.voices.find((v: ReadAloudVoice): boolean => v.id === item.id);
            if (voice !== undefined && !voice.excluded) { this.onSelectVoice(voice); }
          });
      }, (item: VoiceItemUi): string => item.id);
    }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 80 });
  }

  @Builder
  editorSheet() {
    if (this.showEditor) {
      Column() {
        Row() {
          Text(this.editingId === 0 ? '新增朗读引擎' : '编辑朗读引擎')
            .fontSize(20).fontColor(this.textPrimary).fontWeight(FontWeight.Medium);
          Blank();
          Text('保存').fontSize(16).fontColor(this.accent).onClick(() => this.saveSource());
        }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 12 });

        Scroll(this.scroller) {
          Column({ space: 12 }) {
            this.fieldInput('名称', this.formName, (v: string) => { this.formName = v; });
            this.fieldInput('URL（纯 URL 源，不支持 JS 模板）', this.formUrl,
              (v: string) => { this.formUrl = v; });
            this.fieldInput('Content-Type', this.formContentType,
              (v: string) => { this.formContentType = v; });
            this.fieldInput('正文参数名（默认 text）', this.formTextParam,
              (v: string) => { this.formTextParam = v; });
            this.fieldInput('语速参数名（默认 speed，留空不发）', this.formSpeedParam,
              (v: string) => { this.formSpeedParam = v; });
            this.fieldInput('音色参数名（默认 tone，留空不发）', this.formToneParam,
              (v: string) => { this.formToneParam = v; });
            Row() {
              Text('源语速').fontSize(15).fontColor(this.textSecondary);
              Slider({ value: this.formSpeed, min: 0, max: 80, step: 1 })
                .layoutWeight(1).margin({ left: 12, right: 12 })
                .onChange((value: number, _mode: SliderChangeMode): void => {
                  this.formSpeed = Math.round(value);
                });
              Text(`${this.formSpeed}`).fontSize(15).fontColor(this.textPrimary).width(30);
            }.width('100%');
            Text('说明：登录脚本 / jsLib / AnalyzeUrl 模板依赖 JS 引擎，鸿蒙不支持，字段保留但不执行。')
              .fontSize(12).fontColor(this.textTertiary).width('100%');
          }.padding({ left: 20, right: 20, bottom: 24 });
        }.layoutWeight(1).scrollBar(BarState.Off);
      }
      .width('100%').height('72%')
      .backgroundColor(this.surfacePrimary)
      .borderRadius({ topLeft: 20, topRight: 20 })
      .shadow({ radius: 20, color: '#33000000', offsetY: -4 })
      .position({ x: 0, y: '28%' })
      .zIndex(20);
    }
  }

  @Builder
  fieldInput(label: string, value: string, onChange: (value: string) => void) {
    Column() {
      Text(label).fontSize(13).fontColor(this.textTertiary).margin({ bottom: 4 });
      TextInput({ text: value, placeholder: label })
        .fontSize(15).fontColor(this.textPrimary)
        .backgroundColor(this.surfaceTertiary).height(48).borderRadius(8)
        .onChange((v: string): void => onChange(v));
    }.width('100%');
  }

  build() {
    Stack() {
      Column() {
        CollapsingSettingsHeader({ title: '朗读引擎与音色', collapsed: false, onBack: () => this.onBack() });
        Row() {
          ForEach(['音色', '引擎'], (label: string, index: number): void => {
            Column() {
              Text(label).fontSize(15)
                .fontColor(this.activeTab === index ? this.accent : this.textTertiary)
                .fontWeight(this.activeTab === index ? FontWeight.Medium : FontWeight.Normal);
              Row().width(24).height(2).backgroundColor(this.activeTab === index ? this.accent : Color.Transparent)
                .margin({ top: 6 });
            }.layoutWeight(1).onClick(() => { this.activeTab = index; });
          }, (label: string): string => label);
        }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 });

        if (this.activeTab === 1) {
          this.sourceList();
        } else {
          this.voiceList();
        }

      }
      .width('100%').height('100%')
      .backgroundColor(this.appBackground.length > 0 ? Color.Transparent :
        (this.pureBlack ? '#000000' : this.surfacePrimary))
      .padding({ top: this.topInset });

      // FAB 用 Stack 覆盖层 + BottomEnd 定位（position 的 calc 百分比在 ArkUI 不可靠）。
      Stack({ alignContent: Alignment.BottomEnd }) {
        Button('+', { type: ButtonType.Circle }).fontSize(28)
          .width(56).height(56).backgroundColor(this.accent).fontColor('#FFFFFF')
          .margin({ right: 20, bottom: 28 })
          .onClick(() => {
            if (this.activeTab === 1) {
              this.openEditor(null);
            } else {
              this.onMessage('切到「引擎」页添加源后再拉取音色');
            }
          });
      }
      .width('100%').height('100%')
      .hitTestBehavior(HitTestMode.Transparent);

      this.editorSheet();
    }
    .width('100%').height('100%')
    .hitTestBehavior(HitTestMode.Default);
  }
}
