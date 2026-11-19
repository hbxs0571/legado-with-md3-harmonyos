
import {
  ReadAloudSettingsRepository, ReadAloudSettingsSnapshot,
  DEFAULT_READ_ALOUD_SETTINGS, copyReadAloudSettings
} from '../data/ReadAloudSettingsRepository';

/**
 * 批5：朗读面板「设置」格打开的三开关小面板。
 * 上游 ReadAloudConfigContent.kt 有 34 个 title，本批只接任务书点名的三个：
 * showReadAloudCapsule / capsuleAutoCollapse / ttsParagraphInterval，其余不在这里铺占位。
 */
@Component
export struct ReadAloudConfigPanel {
  @StorageProp('themeColorSurfaceSecondary') themeColorSurfaceSecondary: string = '#FFFFFF';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#494C59';

  @Prop settings: ReadAloudSettingsSnapshot = DEFAULT_READ_ALOUD_SETTINGS;
  @State capsuleVisible: boolean = true;
  @State autoCollapse: boolean = true;
  @State paragraphInterval: number = 0;

  onBack: () => void = () => {};
  onSettingsChange: (settings: ReadAloudSettingsSnapshot) => void = (_settings: ReadAloudSettingsSnapshot) => {};
  /** 批6：复位胶囊位置（上游 ReadAloudConfigContent.kt:243 reset_read_aloud_capsule_position）。 */
  onResetCapsulePosition: () => void = () => {};

  aboutToAppear(): void {
    this.capsuleVisible = this.settings.showReadAloudCapsule;
    this.autoCollapse = this.settings.capsuleAutoCollapse;
    this.paragraphInterval = this.settings.ttsParagraphInterval;
  }

  private commit(): void {
    const updated: ReadAloudSettingsSnapshot = copyReadAloudSettings(this.settings);
    updated.showReadAloudCapsule = this.capsuleVisible;
    updated.capsuleAutoCollapse = this.autoCollapse;
    updated.ttsParagraphInterval = this.paragraphInterval;
    this.onSettingsChange(updated);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%').height('100%')
        .backgroundColor('#88000000')
        .onClick(() => this.onBack())

      Column() {
        Row() {
          Image($r('app.media.reader_back')).width(22).height(22)
            .fillColor(this.themeColorTextPrimary)
            .onClick(() => this.onBack())
          Text('朗读设置').fontSize(15).fontColor(this.themeColorTextPrimary).margin({ left: 10 })
          Blank()
        }.width('100%').padding({ left: 16, right: 16, bottom: 14 })

        ConfigSwitchRow({ label: '显示朗读胶囊', checked: this.capsuleVisible,
          onChange: (value: boolean): void => { this.capsuleVisible = value; this.commit(); } })
        ConfigSwitchRow({ label: '胶囊自动收起', checked: this.autoCollapse,
          onChange: (value: boolean): void => { this.autoCollapse = value; this.commit(); } })

        Column() {
          Row() {
            Text('段落间隔').fontSize(13).fontColor(this.themeColorTextPrimary)
            Blank()
            Text(`${this.paragraphInterval} 毫秒`).fontSize(11).fontColor(this.themeColorTextSecondary)
          }.width('100%')
          Slider({ value: this.paragraphInterval, min: 0, max: 2000, step: 50, style: SliderStyle.OutSet })
            .width('100%')
            .onChange((value: number, mode: SliderChangeMode): void => {
              this.paragraphInterval = Math.round(value);
              if (mode === SliderChangeMode.End) {
                this.commit();
              }
            })
        }
        .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 16 })
        .backgroundColor('#202127').borderRadius(14)
        .margin({ left: 14, right: 14, bottom: 10 })

        Text('复位朗读胶囊位置')
          .fontSize(13).fontColor(this.themeColorTextPrimary)
          .width('100%').textAlign(TextAlign.Center).padding({ top: 14, bottom: 14 })
          .backgroundColor('#202127').borderRadius(14)
          .margin({ left: 14, right: 14, bottom: 10 })
          .onClick(() => this.onResetCapsulePosition())
      }
      .width('100%').height('60%')
      .backgroundColor(this.themeColorSurfaceSecondary)
      .borderRadius(22)
    }
    .width('100%').height('100%')
  }
}

@Component
struct ConfigSwitchRow {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @Prop label: string = '';
  @Prop checked: boolean = false;
  onChange: (value: boolean) => void = (_value: boolean): void => {};

  build() {
    Row() {
      Text(this.label).fontSize(13).fontColor(this.themeColorTextPrimary).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .onChange((value: boolean): void => this.onChange(value))
    }
    .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor('#202127').borderRadius(14)
    .margin({ left: 14, right: 14, bottom: 10 })
  }
}
