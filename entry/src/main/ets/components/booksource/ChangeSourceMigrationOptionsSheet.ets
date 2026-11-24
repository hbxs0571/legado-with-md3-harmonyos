// 换源迁移选项面板（第十表 G-6）：逐项对齐上游
// `ui/book/changesource/ChangeSourceMigrationOptionsSheet.kt`（124 行）。
//
// 为什么抽成公共组件：上游这一个 composable 被三处调用 ——
//   · `ui/widget/components/changeSource/ChangeSourceSheet.kt:575`（单本换源的「换源选项」）
//   · `ui/widget/components/conflict/BookshelfConflictSheet.kt:182`（书架冲突的「要携带的数据」，`showDeleteDownloaded = false`）
//   · `ui/book/manage/BookshelfManageScreen.kt:801`（批量换源的「批量换源选项」，带 subtitle）
// 本地原先三个面板各写一份「迁移阅读进度 / 迁移封面与简介」两个开关，字段只有两项，
// 与上游八个维度对不上；且三处字面量都要跟着 `ChangeSourceMigrationOptions` 的字段变化改。
// 抽成一个组件后：字段口径只有一处，三个调用点只传 title/subtitle/初始值。
//
// 与上游的对应关系：
//   · 八个勾选项顺序：阅读进度 →（勾选时提示文案）→ 分组和排序 → 自定义封面 → 分类与标签
//     → 备注和自定义简介 → 作者 → 阅读设置 →（`showDeleteDownloaded` 时）删除已下载章节。
//   · `migrateChapters` 上游恒为 true 且不出现在 UI 上（`ChangeSourceMigrationOptionsSheet.kt:106`），
//     本组件同样不透出，确认时固定写 true。
//   · 每行是 `CheckboxItem`：`GlassCard(cornerRadius = 12.dp, containerColor = if (checked) secondaryContainer else onSheetContent)`
//     + 整行 `toggleable` + 左侧 `AppCheckbox` + 标题 `bodyMediumEmphasized`。
//   · 底部 `ConfirmDismissButtonsRow`：取消（Outlined）+ 确认（filled），各 `widthIn(min = 88.dp)`，
//     间距 12、右对齐（非 miuix 分支）。
import {
  ChangeSourceMigrationOptions, defaultMigrationOptions
} from '../../bookSource/ChangeSourceCoordinator';
import { BODY_SMALL, LABEL_LARGE, LABEL_SMALL } from '../typography/TypographyTokens';

/** 面板内一行复选框的外边距：上游 `Row.padding(vertical = 12.dp, horizontal = 12.dp)`。 */
const ROW_PADDING_H: number = 12;
const ROW_PADDING_V: number = 12;
/** 复选框与标题之间的间距：上游 `Column.padding(start = 12.dp)`。 */
const CHECK_TITLE_GAP: number = 12;
/** 卡片圆角：上游 `GlassCard(cornerRadius = 12.dp)`。 */
const CARD_RADIUS: number = 12;
/** 行间距：上游 `Column(verticalArrangement = Arrangement.spacedBy(4.dp))`。 */
const ROW_GAP: number = 4;
/** 复选框边长：Material3 `Checkbox` 默认 20dp 图标 + 2dp 内边距。 */
const CHECK_SIZE: number = 18;
/** 底部按钮最小宽度与高度：上游 `widthIn(min = 88.dp)` + M3 `Button` 默认 40dp。 */
const BUTTON_MIN_WIDTH: number = 88;
const BUTTON_HEIGHT: number = 40;
const BUTTON_RADIUS: number = 20;

@Component
export struct ChangeSourceMigrationOptionsSheet {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#FFFFFF';
  @StorageProp('themeColorOnSheetContent') themeColorOnSheetContent: string = '#F5F6F8';
  @StorageProp('themeColorSecondaryContainer') themeColorSecondaryContainer: string = '#DCE7C8';
  @StorageProp('themeColorOnSurfaceVariant') themeColorOnSurfaceVariant: string = '#2E3038';

  /** 面板标题。上游三处调用分别传「换源选项」「要携带的数据」「批量换源选项」。 */
  @Prop title: string = '换源选项';
  /** 标题下的说明文字；空串表示不渲染（上游 `subtitle?.takeIf { it.isNotBlank() }`）。 */
  @Prop subtitle: string = '';
  /**
   * 是否展示「删除已下载章节」。
   * 上游注释（`:31-32`）：共存场景两本书都留在书架，删缓存没有意义，故传 false。
   */
  @Prop showDeleteDownloaded: boolean = true;
  /**
   * 初始勾选状态。上游 `initialOptions` 只在面板打开时取一次（`rememberSaveable(show)`），
   * 本地同样在 `aboutToAppear` 与 `@Watch` 里按它重置草稿。
   */
  @Prop initialOptions: ChangeSourceMigrationOptions = defaultMigrationOptions();

  onDismissRequest: () => void = () => {};
  onConfirm: (options: ChangeSourceMigrationOptions) => void =
    (_options: ChangeSourceMigrationOptions) => {};

  // 八个勾选项的草稿（对齐上游八个 rememberSaveable(show)）。
  @State private migrateProgress: boolean = true;
  @State private migrateGroup: boolean = true;
  @State private migrateCover: boolean = true;
  @State private migrateCategory: boolean = true;
  @State private migrateRemark: boolean = true;
  @State private migrateAuthor: boolean = true;
  @State private migrateReadConfig: boolean = true;
  @State private deleteDownloadedChapters: boolean = false;

  aboutToAppear(): void {
    this.resetDraft();
  }

  /** 按 `initialOptions` 重置草稿；`initialOptions` 变化时同样重置。 */
  private resetDraft(): void {
    const options = this.initialOptions;
    this.migrateProgress = options.migrateProgress;
    this.migrateGroup = options.migrateGroup;
    this.migrateCover = options.migrateCover;
    this.migrateCategory = options.migrateCategory;
    this.migrateRemark = options.migrateRemark;
    this.migrateAuthor = options.migrateAuthor;
    this.migrateReadConfig = options.migrateReadConfig;
    this.deleteDownloadedChapters = options.deleteDownloadedChapters;
  }

  /** 确认时组装：`migrateChapters` 恒 true（上游 `:106`），其余取草稿。 */
  private buildOptions(): ChangeSourceMigrationOptions {
    return {
      migrateChapters: true,
      migrateProgress: this.migrateProgress,
      migrateGroup: this.migrateGroup,
      migrateCover: this.migrateCover,
      migrateCategory: this.migrateCategory,
      migrateRemark: this.migrateRemark,
      migrateAuthor: this.migrateAuthor,
      migrateReadConfig: this.migrateReadConfig,
      deleteDownloadedChapters: this.deleteDownloadedChapters,
    };
  }

  /**
   * 一行复选框：整行可点，左侧方框 + 标题。
   *
   * 对齐上游 `CheckboxItem`：`GlassCard(12dp, 选中 secondaryContainer / 未选 onSheetContent)`
   * 里 `Row.fillMaxWidth().toggleable(...).padding(12dp)`，左边 `AppCheckbox(checked, onCheckedChange = null)`，
   * 右边 `AppText(title, bodyMediumEmphasized, maxLines = 1)`。
   * 复选框自身关掉命中测试（`hitTestBehavior(HitTestMode.None)`），点击统一交给整行 ——
   * 否则 ArkUI 的 Checkbox 会自己翻转视觉、与外部状态打架（`AppBackupSettingsPage.ets:965-973` 同款踩坑）。
   */
  @Builder
  private CheckRow(label: string, checked: boolean, onToggle: (next: boolean) => void) {
    Row() {
      Checkbox({ name: label })
        .shape(CheckBoxShape.ROUNDED_SQUARE)
        .select(checked)
        .selectedColor(this.themeColorAccent)
        .width(CHECK_SIZE)
        .height(CHECK_SIZE)
        .hitTestBehavior(HitTestMode.None)
      Text(label)
        .fontSize(LABEL_LARGE)
        .fontColor(this.themeColorTextPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: CHECK_TITLE_GAP })
    }
    .width('100%')
    .padding({ left: ROW_PADDING_H, right: ROW_PADDING_H, top: ROW_PADDING_V, bottom: ROW_PADDING_V })
    .borderRadius(CARD_RADIUS)
    .backgroundColor(checked ? this.themeColorSecondaryContainer : this.themeColorOnSheetContent)
    .accessibilityText(label)
    .accessibilityChecked(checked)
    .onClick(() => { onToggle(!checked); })
  }

  @Builder
  private ButtonsRow() {
    Row({ space: 12 }) {
      // 上游 `SecondaryButton` = `OutlinedButton`（透明底 + 描边 + 强调色文字，labelLarge）。
      Button('取消')
        .type(ButtonType.Normal)
        .constraintSize({ minWidth: BUTTON_MIN_WIDTH })
        .height(BUTTON_HEIGHT)
        .fontSize(LABEL_LARGE)
        .fontColor(this.themeColorAccent)
        .backgroundColor(Color.Transparent)
        .borderRadius(BUTTON_RADIUS)
        .border({ width: 1.5, color: this.themeColorAccent })
        .onClick(() => { this.onDismissRequest(); })
      // 上游 `PrimaryButton` = `Button`（强调色填充，labelLarge）。
      Button('确认')
        .type(ButtonType.Normal)
        .constraintSize({ minWidth: BUTTON_MIN_WIDTH })
        .height(BUTTON_HEIGHT)
        .fontSize(LABEL_LARGE)
        .fontColor(this.themeColorSurfacePrimary)
        .backgroundColor(this.themeColorAccent)
        .borderRadius(BUTTON_RADIUS)
        .onClick(() => { this.onConfirm(this.buildOptions()); })
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
  }

  build() {
    Column() {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary)
        .width('100%')
        .margin({ bottom: 12 })

      Column({ space: ROW_GAP }) {
        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(BODY_SMALL)
            .fontColor(this.themeColorOnSurfaceVariant)
            .width('100%')
            .margin({ bottom: 8 })
        }
        this.CheckRow('阅读进度', this.migrateProgress, (next: boolean) => {
          this.migrateProgress = next;
        });
        // 上游 `:81-88`：勾了阅读进度才提示「章节不够会退到最后一章」。
        if (this.migrateProgress) {
          Text('若新源总章节比进度更少，阅读进度将调整至最后一章。')
            .fontSize(BODY_SMALL)
            .fontColor(this.themeColorOnSurfaceVariant)
            .width('100%')
            .padding({ left: ROW_PADDING_H, right: ROW_PADDING_H })
        }
        this.CheckRow('分组和排序', this.migrateGroup, (next: boolean) => {
          this.migrateGroup = next;
        });
        this.CheckRow('自定义封面', this.migrateCover, (next: boolean) => {
          this.migrateCover = next;
        });
        this.CheckRow('分类与标签', this.migrateCategory, (next: boolean) => {
          this.migrateCategory = next;
        });
        this.CheckRow('备注和自定义简介', this.migrateRemark, (next: boolean) => {
          this.migrateRemark = next;
        });
        this.CheckRow('作者', this.migrateAuthor, (next: boolean) => {
          this.migrateAuthor = next;
        });
        this.CheckRow('阅读设置', this.migrateReadConfig, (next: boolean) => {
          this.migrateReadConfig = next;
        });
        if (this.showDeleteDownloaded) {
          this.CheckRow('删除已下载章节', this.deleteDownloadedChapters, (next: boolean) => {
            this.deleteDownloadedChapters = next;
          });
        }
      }
      .width('100%')

      Blank().height(8)
      this.ButtonsRow()
      Blank().height(12)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8 })
    .alignItems(HorizontalAlign.Start)
  }
}
