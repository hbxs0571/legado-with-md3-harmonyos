/**
 * 内容质量检测面板。
 *
 * 逐项对齐上游 `SearchScreen.kt:834-917` 的 `ContentQualitySheet` 与 :919-949 的 `ContentQualityPipeline`：
 *   - `AppModalBottomSheet(title = content_quality_detection, endAction = SmallPlainButton(Check, content_quality_start,
 *      enabled = !isRunning && resultCount > 0))`
 *   - 三个 `TextField`：chapters / keywords / skip_chars，各带 supportingText
 *   - `AppText(content_quality_pipeline, labelMediumEmphasized, onSurfaceVariant)` + 四段流程条
 *   - 运行中 `AppCircularProgressIndicator(progress)` + `content_quality_progress(processed, total, currentBookName)`
 *   - 完成 `content_quality_result(results.size, excludedCount)`
 *
 * 流程条颜色（上游 `ContentQualityPipeline`）：
 *   `stage == Completed || stage == itemStage → primary`；
 *   `stage.ordinal > itemStage.ordinal → secondary`；
 *   否则 `onSurfaceVariant`；段间箭头用 `outline` 色。
 */
import { AppGlyph } from '../AppGlyph';
import { BODY_MEDIUM, BODY_SMALL, LABEL_MEDIUM, LABEL_MEDIUM_EMPHASIZED, TITLE_SMALL } from '../typography/TypographyTokens';
import { SPACE_12, SPACE_16, SPACE_4, SPACE_8 } from '../UiTokens';
import { ContentQualityStage } from '../../bookSource/SearchContract';

/** 流程条四段的展示名（上游 `content_quality_stage_*` 四条文案）。 */
const PIPELINE_LABELS: string[] = ['章节数', '清洗', '匹配', '排除'];

@Component
export struct ContentQualitySheet {
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#4A4C55';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceContainerLow') themeColorSurfaceContainerLow: string = '#F7F7FB';
  @StorageProp('themeColorOutlineVariant') themeColorOutlineVariant: string = '#C6C7D0';

  @Prop chapterSpec: string = '1,3,5';
  @Prop keywords: string = '主角';
  @Prop skipHeadChars: string = '300';
  @Prop isRunning: boolean = false;
  /** 当前阶段；未开始时调用方传 -1（上游 `ContentQualityStage?` 为 null）。 */
  @Prop stage: number = -1;
  @Prop processedBooks: number = 0;
  @Prop totalBooks: number = 0;
  @Prop currentBookName: string = '';
  /** 结果条数（已检测本数）与排除数。 */
  @Prop resultCount: number = 0;
  @Prop excludedCount: number = 0;

  onChapterSpecChange: (value: string) => void = (_value: string) => {};
  onKeywordsChange: (value: string) => void = (_value: string) => {};
  onSkipHeadCharsChange: (value: string) => void = (_value: string) => {};
  onStart: () => void = () => {};
  onDismissRequest: () => void = () => {};

  /** 流程条某段的颜色（上游三段式判据）。 */
  private stageColor(itemStage: number): string {
    if (this.stage < 0) {
      return this.themeColorTextTertiary;
    }
    if (this.stage === ContentQualityStage.Completed || this.stage === itemStage) {
      return this.themeColorAccent;
    }
    if (this.stage > itemStage) {
      return this.themeColorTextSecondary;
    }
    return this.themeColorTextTertiary;
  }

  @Builder
  private InputField(title: string, summary: string, value: string, onChange: (value: string) => void) {
    Column() {
      Text(title)
        .fontSize(TITLE_SMALL)
        .fontColor(this.themeColorTextPrimary)
        .width('100%')
        .textAlign(TextAlign.Start)
      TextInput({ text: value })
        .fontSize(BODY_MEDIUM)
        .fontColor(this.themeColorTextPrimary)
        .backgroundColor(this.themeColorSurfaceContainerLow)
        .borderRadius(8)
        .height(44)
        .margin({ top: SPACE_4 })
        .onChange((next: string) => { onChange(next); })
      Text(summary)
        .fontSize(BODY_SMALL)
        .fontColor(this.themeColorTextTertiary)
        .width('100%')
        .textAlign(TextAlign.Start)
        .margin({ top: 2 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      // 标题栏：标题 + 右侧「开始检测」（上游 endAction 的 SmallPlainButton(Check)）。
      Row() {
        Text('内容质量检测')
          .fontSize(TITLE_SMALL)
          .fontColor(this.themeColorTextPrimary)
          .layoutWeight(1)
        Row({ space: SPACE_4 }) {
          AppGlyph({
            name: 'profileCheck',
            glyphSize: 18,
            tint: (!this.isRunning && this.resultCount > 0) ? this.themeColorAccent : this.themeColorTextTertiary
          })
          Text('开始检测')
            .fontSize(LABEL_MEDIUM)
            .fontColor((!this.isRunning && this.resultCount > 0) ? this.themeColorAccent : this.themeColorTextTertiary)
        }
        .padding({ left: SPACE_8, right: SPACE_4, top: SPACE_4, bottom: SPACE_4 })
        .enabled(!this.isRunning && this.resultCount > 0)
        .onClick(() => {
          if (!this.isRunning && this.resultCount > 0) {
            this.onStart();
          }
        })
      }
      .width('100%')
      .padding({ left: SPACE_16, right: SPACE_16, top: SPACE_12, bottom: SPACE_8 })

      Column({ space: SPACE_8 }) {
        this.InputField(
          '指定检测章节',
          '例如：1,3,5 或 1-5；若书源章节数不足（少于指定的最大章节号），该书源将被自动排除',
          this.chapterSpec,
          (value: string) => { this.onChapterSpecChange(value); }
        )
        this.InputField(
          '主角名或关键词',
          '多个关键词可用逗号或空格分隔',
          this.keywords,
          (value: string) => { this.onKeywordsChange(value); }
        )
        this.InputField(
          '跳过章节头部字数',
          '忽略广告、版权声明等头部内容',
          this.skipHeadChars,
          (value: string) => { this.onSkipHeadCharsChange(value); }
        )

        // 上游 `AppText(content_quality_pipeline, labelMediumEmphasized, onSurfaceVariant)`。
        Text('章节数量 → 内容清洗 → 多关键词匹配 → 自动排除')
          .fontSize(LABEL_MEDIUM_EMPHASIZED)
          .fontColor(this.themeColorTextSecondary)
          .width('100%')
          .textAlign(TextAlign.Start)

        // 流程条：四段 + 段间箭头。
        Row({ space: SPACE_4 }) {
          ForEach(PIPELINE_LABELS, (label: string, index: number) => {
            Text(label)
              .fontSize(BODY_SMALL)
              .fontColor(this.stageColor(index))
              .padding({ left: SPACE_4, right: SPACE_4, top: 2, bottom: 2 })
            if (index < PIPELINE_LABELS.length - 1) {
              Text('→')
                .fontSize(BODY_SMALL)
                .fontColor(this.themeColorOutlineVariant)
            }
          }, (label: string) => label)
        }
        .width('100%')

        // 运行中：进度 + `已检测 %1$d/%2$d：%3$s`。
        if (this.isRunning) {
          Column({ space: SPACE_4 }) {
            Progress({
              value: this.totalBooks > 0 ? this.processedBooks : 0,
              total: this.totalBooks > 0 ? this.totalBooks : 1,
              type: ProgressType.Linear
            })
              .width('100%')
              .height(4)
              .color(this.themeColorAccent)
            Text(`已检测 ${this.processedBooks}/${this.totalBooks}：${this.currentBookName}`)
              .fontSize(BODY_SMALL)
              .fontColor(this.themeColorTextTertiary)
              .width('100%')
              .textAlign(TextAlign.Start)
          }
          .width('100%')
        } else if (this.resultCount > 0) {
          // 完成：`已检测 %1$d 本，排除 %2$d 个书源`。
          Text(`已检测 ${this.resultCount} 本，排除 ${this.excludedCount} 个书源`)
            .fontSize(BODY_SMALL)
            .fontColor(this.themeColorTextTertiary)
            .width('100%')
            .textAlign(TextAlign.Start)
        }
      }
      .width('100%')
      .padding({ left: SPACE_16, right: SPACE_16, bottom: SPACE_16 })
    }
    .width('100%')
    .backgroundColor(this.themeColorSurfaceTertiary)
  }
}
