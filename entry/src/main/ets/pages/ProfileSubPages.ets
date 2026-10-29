/** “我的”菜单下与 Android 页面结构对应的二级页面。 */
import { bundleManager } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { CollapsingSettingsHeader } from '../components/CollapsingSettingsHeader';
import {
  PROFILE_PAGE_SUBTITLE_SIZE,
  PROFILE_PAGE_TITLE_SIZE,
  PROFILE_ROW_DETAIL_SIZE,
  PROFILE_ROW_TITLE_SIZE,
  PROFILE_ROW_VERTICAL_PADDING
} from '../components/ProfileUiMetrics';
import { ProfileRoute } from '../model/Book';
import { ReplaceRule, replaceRuleRowKey } from '../model/ReplaceRule';
import { ReplaceRulePreviewLine, ReplaceRuleRepository } from '../data/ReplaceRuleRepository';
import { ReadRecordDetail, ReadRecordSummary, ReadTimeRecord } from '../model/ReadRecord';
import { ReadRecordRepository } from '../data/ReadRecordRepository';
import { TxtTocRule } from '../model/TxtTocRule';
import { TxtTocRuleRepository } from '../data/TxtTocRuleRepository';

@Component
export struct BookSourceManagePage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop groups: string[] = [];
  @State selectedGroup: string = '';
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State showGroupFilter: boolean = false;
  @State groupFilterQuery: string = '';
  @State groupByDomain: boolean = false;
  @State sortMode: string = '手动排序';
  @State sortDescending: boolean = false;

  private groupFilterOptions(): string[] {
    const options: string[] = ['全部', '启用', '禁用', '需要登录', '未分组', '发现已启用', '发现未启用'];
    this.groups.forEach((group: string) => options.push(group));
    return options.filter((option: string) => this.groupFilterQuery.length === 0 ||
      option.toLowerCase().includes(this.groupFilterQuery.toLowerCase()));
  }

  @Builder
  private MoreMenu() {
    Menu() {
      MenuItem({ content: '分组管理' }).onClick(() =>
        this.onUnavailableAction('书源分组管理尚未迁移，未修改分组'))
      MenuItem({ content: '本地导入' }).onClick(() =>
        this.onUnavailableAction('书源本地导入尚未迁移，未导入数据'))
      MenuItem({ content: '二维码导入' }).onClick(() =>
        this.onUnavailableAction('书源二维码导入尚未迁移，未导入数据'))
      MenuItem({ content: '在线导入' }).onClick(() =>
        this.onUnavailableAction('书源在线导入尚未迁移，未导入数据'))
      MenuItem({ content: this.groupByDomain ? '取消按域名分组' : '按域名分组' })
        .onClick(() => this.groupByDomain = !this.groupByDomain)
      MenuItem({ content: '手动排序' }).onClick(() => this.sortMode = '手动排序')
      MenuItem({ content: '权重排序' }).onClick(() => this.sortMode = '权重排序')
      MenuItem({ content: '名称排序' }).onClick(() => this.sortMode = '名称排序')
      MenuItem({ content: 'URL 排序' }).onClick(() => this.sortMode = 'URL 排序')
      MenuItem({ content: '按更新时间排序' }).onClick(() => this.sortMode = '按更新时间排序')
      MenuItem({ content: '按响应时间排序' }).onClick(() => this.sortMode = '按响应时间排序')
      MenuItem({ content: '按启用状态排序' }).onClick(() => this.sortMode = '按启用状态排序')
      MenuItem({ content: this.sortDescending ? '切换为升序' : '切换为降序' })
        .onClick(() => this.sortDescending = !this.sortDescending)
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  @Builder
  private GroupFilterSheet() {
    Column() {
      Row() {
        Text('分组筛选').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#E3E4E8').layoutWeight(1)
        Text('清除').fontSize(14).fontColor('#B9C8FF').padding({ left: 12, right: 8, top: 8, bottom: 8 })
          .onClick(() => { this.selectedGroup = ''; this.groupFilterQuery = ''; this.showGroupFilter = false; })
      }.width('100%').padding({ left: 20, right: 16, top: 20, bottom: 12 })
      Row() {
        AppGlyph({ name: 'search', glyphSize: 18, tint: '#C5C7D0' }).margin({ right: 9 })
        TextInput({ placeholder: '搜索分组', text: this.groupFilterQuery })
          .fontSize(15).fontColor('#E3E4E8').placeholderColor('#858792')
          .backgroundColor(Color.Transparent).layoutWeight(1)
          .onChange((value: string) => this.groupFilterQuery = value)
      }.margin({ left: 16, right: 16, bottom: 10 }).padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .backgroundColor('#25262D').borderRadius(22)
      Scroll() {
        Column() {
          ForEach(this.groupFilterOptions(), (option: string) => {
            Row() {
              Text(option).fontSize(15).fontColor(this.selectedGroup === option ? '#DCE3FF' : '#D8D9E0')
                .layoutWeight(1)
              if (this.selectedGroup === option) {
                AppGlyph({ name: 'profileCheck', glyphSize: 18, tint: '#B9C8FF' })
              }
            }.width('100%').padding({ left: 16, right: 16, top: 13, bottom: 13 })
              .backgroundColor(this.selectedGroup === option ? '#41485D' : '#1B1C22').borderRadius(12)
              .margin({ left: 16, right: 16, bottom: 7 })
              .onClick(() => {
                this.selectedGroup = option === '全部' ? '' : option;
                this.showGroupFilter = false;
              })
          }, (option: string) => option)
        }.width('100%').padding({ top: 4, bottom: 22 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(36).height(36).backgroundColor('#1B1C22').borderRadius(18)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.onBack())
        Column() {
          Text('书源').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
          Text(this.selectedGroup.length === 0 ? '全部' : this.selectedGroup)
            .fontSize(PROFILE_PAGE_SUBTITLE_SIZE).fontColor('#92949E').margin({ top: 3 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(36).height(36).backgroundColor('#1B1C22').borderRadius(18)
          AppGlyph({ name: 'profileFilterAlt', glyphSize: 19, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => { this.groupFilterQuery = ''; this.showGroupFilter = true; })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(36).height(36).backgroundColor('#1B1C22').borderRadius(18)
          AppGlyph({ name: 'search', glyphSize: 19, tint: '#D8D9E0' })
        }.width(40).height(40)
          .onClick(() => { this.showSearch = !this.showSearch; if (!this.showSearch) { this.searchQuery = ''; } })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(36).height(36).backgroundColor('#1B1C22').borderRadius(18)
          AppGlyph({ name: 'more', glyphSize: 18, tint: '#D8D9E0' })
        }.width(40).height(40).bindMenu(this.MoreMenu, { placement: Placement.BottomRight })
      }.width('100%').padding({ left: 12, right: 12, top: 11, bottom: 9 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索书源…', text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .onChange((value: string) => this.searchQuery = value)
        }.width('100%').padding({ left: 12, right: 14, top: 7, bottom: 7 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(22)
      }

      if (this.selectedGroup.length > 0 || this.searchQuery.length > 0 || this.sortMode !== '手动排序' || this.groupByDomain) {
        Row() {
          Text(this.selectedGroup.length > 0 ? this.selectedGroup : '全部')
            .fontSize(12).fontColor('#DCE3FF').padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor('#41485D').borderRadius(14)
          Text(this.sortMode).fontSize(12).fontColor('#92949E').margin({ left: 8 })
          if (this.groupByDomain) {
            Text('按域名分组').fontSize(12).fontColor('#92949E').margin({ left: 8 })
          }
        }.width('100%').padding({ left: 16, right: 16, top: 6, bottom: 5 })
      }

      ModuleEmpty({
        icon: 'web',
        title: this.searchQuery.length > 0 ? '没有匹配的书源' : '暂无书源',
        detail: this.searchQuery.length > 0 ? '调整关键词或筛选条件后重试' : '添加或导入书源后，会在这里显示书源名称、分组和启用状态'
      }).layoutWeight(1)
      Row() {
        Image($r('app.media.app_add')).width(18).height(18).fillColor('#151720')
        Text('添加书源').fontSize(15).fontColor('#151720').margin({ left: 7 })
      }.justifyContent(FlexAlign.Center).padding({ left: 20, right: 20, top: 13, bottom: 13 })
        .backgroundColor('#B9C8FF').borderRadius(28).margin({ right: 20, bottom: 18 }).alignSelf(ItemAlign.End)
        .onClick(() => this.onUnavailableAction('书源编辑和保存尚未迁移，未创建书源'))
    }.width('100%').height('100%').backgroundColor('#111217')
      .bindSheet(this.showGroupFilter, this.GroupFilterSheet(), {
        height: SheetSize.MEDIUM,
        dragBar: true,
        showClose: false,
        backgroundColor: '#17181E',
        onDisappear: () => this.showGroupFilter = false
      })
  }
}

@Component
export struct ReplaceRulesPage {
  onBack: () => void = () => {};
  onOpenEditor: () => void = () => {};
  onToggleRule: (id: number, enabled: boolean) => void = (_id: number, _enabled: boolean) => {};
  onRemoveRule: (id: number) => void = (_id: number) => {};
  /** 点击规则条目进入编辑。 */
  onEditRule: (id: number) => void = (_id: number) => {};
  /** 长按菜单里的置顶/置底。 */
  onMoveRule: (id: number, toTop: boolean) => void = (_id: number, _toTop: boolean) => {};
  /** 分组管理：新增 / 重命名 / 删除。返回 Promise 便于面板等落盘后刷新。 */
  onAddGroup: (name: string) => Promise<void> = async (_name: string) => {};
  onRenameGroup: (oldName: string, newName: string) => Promise<void> = async (_o: string, _n: string) => {};
  onRemoveGroup: (name: string) => Promise<void> = async (_name: string) => {};
  /** 排序模式持久化。 */
  onSortModeChange: (mode: string) => void = (_mode: string) => {};
  /** 从文件或剪贴板文本导入；返回是否成功，供面板关闭。 */
  onImportRules: (text: string, source: string) => void = (_text: string, _source: string) => {};
  /** 导出当前筛选结果；空数组表示没有可导出内容。 */
  onExportRules: (rules: ReplaceRule[]) => void = (_rules: ReplaceRule[]) => {};
  /** 选择模式下的批量启用/停用。 */
  onSetEnabledBatch: (ids: number[], enabled: boolean) => void = (_ids: number[], _enabled: boolean) => {};
  /** 选择模式下的批量删除。 */
  onRemoveBatch: (ids: number[]) => void = (_ids: number[]) => {};
  /** 选择模式下的批量置顶/置底。 */
  onMoveBatch: (ids: number[], toTop: boolean) => void = (_ids: number[], _toTop: boolean) => {};
  /** 拖拽排序：把 fromId 这条规则挪到 toId 的位置。 */
  onReorderRule: (fromId: number, toId: number) => void = (_f: number, _t: number) => {};
  @Prop rules: ReplaceRule[] = [];
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop groups: string[] = [];
  /** 由外部传入的持久化排序模式，切换时同步回写。 */
  @Prop sortMode: string = 'asc';
  @State selectedGroup: string = '';
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State ruleActionSheet: string = '';
  /** 手动输入面板里的规则文本。 */
  @State manualInput: string = '';
  /** 选择模式：进入后点击条目变为切换选中，底部出现批量操作条。 */
  @State selectionMode: boolean = false;
  @State selectedRuleIds: number[] = [];
  /**
   * 待确认删除的规则 id。批量删除与长按菜单的单条删除共用同一个确认面板，
   * 只在这里记下待删对象，确认后才真正回调删除。
   */
  @State pendingDeleteIds: number[] = [];

  /** 切换单条规则的选中状态。 */
  private toggleSelectedRule(id: number): void {
    this.selectedRuleIds = this.selectedRuleIds.includes(id)
      ? this.selectedRuleIds.filter((selectedId: number) => selectedId !== id)
      : [...this.selectedRuleIds, id];
  }

  /** 全选当前筛选结果，而不是全部规则：筛选态下「全选」应符合用户看到的列表。 */
  private selectAllVisible(): void {
    this.selectedRuleIds = this.filteredReplaceRules().map((rule: ReplaceRule) => rule.id);
  }

  /**
   * 反选：在当前筛选结果内取差集，与上游 invertSelection() 一致。
   * 用筛选结果而不是全部规则，保证「反选」与用户眼前的列表范围一致。
   */
  private invertSelection(): void {
    this.selectedRuleIds = this.filteredReplaceRules()
      .map((rule: ReplaceRule) => rule.id)
      .filter((id: number) => !this.selectedRuleIds.includes(id));
  }

  /** 退出选择模式并清空选中，避免下次进入时残留上一次的选择。 */
  private exitSelection(): void {
    this.selectionMode = false;
    this.selectedRuleIds = [];
  }


  @Builder
  private ReplaceRuleMenu() {
    Menu() {
      MenuItem({ content: '导入' })
        .onClick(() => this.ruleActionSheet = 'import')
      MenuItem({ content: '导出' })
        .onClick(() => this.onExportRules(this.filteredReplaceRules()))
      MenuItem({ content: '分组管理' })
        .onClick(() => this.ruleActionSheet = 'groups')
      MenuItem({ content: '选择模式' })
        .onClick(() => {
          if (this.selectionMode) {
            this.exitSelection();
          } else {
            this.selectionMode = true;
            this.selectedRuleIds = [];
          }
        })
      MenuItem({ content: '旧的在前' })
        .onClick(() => this.onSortModeChange('asc'))
      MenuItem({ content: '新的在前' })
        .onClick(() => this.onSortModeChange('desc'))
      MenuItem({ content: '名称升序' })
        .onClick(() => this.onSortModeChange('name_asc'))
      MenuItem({ content: '名称降序' })
        .onClick(() => this.onSortModeChange('name_desc'))
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  /** 规则条目长按菜单：置顶、置底、删除（与上游条目下拉的三项一致）。 */
  @Builder
  private RuleRowMenu(rule: ReplaceRule) {
    Menu() {
      MenuItem({ content: '置顶' })
        .onClick(() => this.onMoveRule(rule.id, true))
      MenuItem({ content: '置底' })
        .onClick(() => this.onMoveRule(rule.id, false))
      MenuItem({ content: '删除' })
        .onClick(() => this.requestDelete([rule.id]))
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  @Builder
  private RuleActionSheet() {
    if (this.ruleActionSheet === 'groups') {
      // 分组面板与编辑页共用同一份实现，避免同一功能出现两种行为。
      ReplaceRuleGroupSheet({
        groups: this.groups,
        onAddGroup: (name: string) => this.onAddGroup(name),
        onRenameGroup: (oldName: string, newName: string) => this.onRenameGroup(oldName, newName),
        onRemoveGroup: (name: string) => this.onRemoveGroup(name),
        onClose: () => this.ruleActionSheet = '',
        onUnavailableAction: (message: string) => this.onUnavailableAction(message)
      })
    } else if (this.ruleActionSheet === 'confirmDelete') {
      // 删除确认：批量删除与长按菜单的单条删除共用，确认前不动数据。
      Column() {
        Text('删除规则').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
          .width('100%').padding({ left: 18, right: 18, top: 16, bottom: 10 })
        Text(this.pendingDeleteIds.length > 1
          ? `确定删除选中的 ${this.pendingDeleteIds.length} 条替换规则？删除后可通过导入恢复。`
          : '确定删除这条替换规则？删除后可通过导入恢复。')
          .fontSize(14).fontColor('#92949E')
          .width('100%').padding({ left: 18, right: 18, bottom: 20 })
        Row() {
          Text('取消').fontSize(15).fontColor('#92949E').layoutWeight(1).textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .onClick(() => this.cancelDelete())
          Text('删除').fontSize(15).fontColor('#D99AA5').layoutWeight(1).textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .onClick(() => this.confirmDelete())
        }.width('100%').padding({ left: 8, right: 8, bottom: 12 })
      }.width('100%').alignItems(HorizontalAlign.Start).backgroundColor('#17181E')
    } else {
      Column() {
        Row() {
          Text(this.ruleActionSheet === 'manual' ? '手动输入规则' : '导入替换规则')
            .fontSize(20).fontWeight(FontWeight.Medium).fontColor('#E3E4E8').layoutWeight(1)
          Stack({ alignContent: Alignment.Center }) {
            AppGlyph({ name: 'profileClose', glyphSize: 20, tint: '#D8D9E0' })
          }.width(40).height(40).onClick(() => this.ruleActionSheet = '')
        }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 12 })
        if (this.ruleActionSheet === 'manual') {
          Column() {
            Text('粘贴规则文本').fontSize(13).fontColor('#92949E').margin({ bottom: 8 })
            TextArea({ placeholder: '粘贴 JSON 规则数组或单条规则对象', text: this.manualInput })
              .fontSize(14).fontColor('#E3E4E8').placeholderColor('#92949E')
              .backgroundColor('#22232A').borderRadius(12)
              .width('100%').height(220).padding(12)
              .onChange((value: string) => this.manualInput = value)
            Row() {
              Text('清空').fontSize(15).fontColor('#92949E').layoutWeight(1)
                .onClick(() => this.manualInput = '')
              Text('取消').fontSize(15).fontColor('#92949E').layoutWeight(1)
                .onClick(() => { this.manualInput = ''; this.ruleActionSheet = 'import'; })
              Text('导入').fontSize(15).fontColor(this.manualInput.trim().length > 0 ? '#B9C8FF' : '#5C5E68')
                .onClick(() => this.submitManualImport())
            }.width('100%').margin({ top: 12 })
          }.width('100%').padding({ left: 16, right: 16, bottom: 20 })
        } else {
          Column() {
            Row() {
              AppGlyph({ name: 'folder', glyphSize: 20, tint: '#AFC2FF' }).margin({ right: 12 })
              Column() {
                Text('选择本地文件').fontSize(15).fontColor('#E3E4E8')
                Text('支持 JSON、TXT 规则文件').fontSize(12).fontColor('#92949E').margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start)
            }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor('#22232A').borderRadius(12)
              .onClick(() => this.onImportRules('', 'file'))
            Row() {
              AppGlyph({ name: 'edit', glyphSize: 20, tint: '#AFC2FF' }).margin({ right: 12 })
              Column() {
                Text('手动输入').fontSize(15).fontColor('#E3E4E8')
                Text('粘贴规则文本或链接').fontSize(12).fontColor('#92949E').margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start)
            }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor('#22232A').borderRadius(12).margin({ top: 8, bottom: 18 })
              .onClick(() => { this.ruleActionSheet = 'manual'; })
          }.width('100%').padding({ left: 16, right: 16 })
        }
      }.width('100%').height('100%').backgroundColor('#17181E')
    }
  }

  /** 提交手动输入的规则文本。 */
  private submitManualImport(): void {
    const text = this.manualInput.trim();
    if (text.length === 0) {
      this.onUnavailableAction('规则文本为空');
      return;
    }
    this.onImportRules(text, 'manual');
    this.manualInput = '';
    this.ruleActionSheet = '';
  }

  /** 批量启用/停用：未选中时提示而不是静默无反应。 */
  private submitBatchEnabled(enabled: boolean): void {
    if (this.selectedRuleIds.length === 0) {
      this.onUnavailableAction('请先选择规则');
      return;
    }
    this.onSetEnabledBatch(this.selectedRuleIds, enabled);
  }

  /** 批量置顶/置底：与单条一致，退出选择模式，让用户看到移动结果。 */
  private submitBatchMove(toTop: boolean): void {
    if (this.selectedRuleIds.length === 0) {
      this.onUnavailableAction('请先选择规则');
      return;
    }
    this.onMoveBatch(this.selectedRuleIds, toTop);
    this.exitSelection();
  }

  /** 批量删除：先弹确认面板，确认后才真正删除。 */
  private submitBatchRemove(): void {
    if (this.selectedRuleIds.length === 0) {
      this.onUnavailableAction('请先选择规则');
      return;
    }
    this.requestDelete(this.selectedRuleIds);
  }

  /**
   * 请求删除：只记录待删对象并打开确认面板，不直接删。
   * 批量删除与长按菜单的单条删除都走这里，保证两条路径行为一致。
   */
  private requestDelete(ids: number[]): void {
    if (ids.length === 0) {
      return;
    }
    this.pendingDeleteIds = ids;
    this.ruleActionSheet = 'confirmDelete';
  }

  /** 确认面板里点「删除」：单条走单条回调，多条走批量回调，然后关闭面板。 */
  private confirmDelete(): void {
    const ids = this.pendingDeleteIds;
    this.pendingDeleteIds = [];
    this.ruleActionSheet = '';
    if (ids.length === 1) {
      this.onRemoveRule(ids[0]);
      // 单条删除后若仍在选择模式，把该条从选中集合里摘掉，避免底部条计数虚高。
      this.selectedRuleIds = this.selectedRuleIds.filter((id: number) => id !== ids[0]);
      return;
    }
    this.onRemoveBatch(ids);
    this.exitSelection();
  }

  /** 取消删除：只清空待删对象，不动选择模式。 */
  private cancelDelete(): void {
    this.pendingDeleteIds = [];
    this.ruleActionSheet = '';
  }

  /** 选择模式下导出：导出的应是选中的规则，而不是当前筛选结果的全部。 */
  private submitBatchExport(): void {
    if (this.selectedRuleIds.length === 0) {
      this.onUnavailableAction('请先选择规则');
      return;
    }
    const selected = this.rules.filter((rule: ReplaceRule) => this.selectedRuleIds.includes(rule.id));
    if (selected.length === 0) {
      this.onUnavailableAction('所选规则已不存在');
      return;
    }
    this.onExportRules(selected);
  }

  /**
   * 是否允许拖拽排序。
   * 与上游 ReplaceRuleScreen.kt:143 的 canReorder 一致：只有按顺序排序（旧的在前 / 新的在前）
   * 时拖拽才有意义；名称排序下顺序由名称决定，拖拽改了也不会体现在界面上。
   */
  private canReorder(): boolean {
    return this.sortMode === 'asc' || this.sortMode === 'desc';
  }

  /**
   * 处理拖拽换位。
   *
   * onMove 给的是「当前筛选列表」里的下标，而存储数组可能被搜索或分组筛选过，
   * 所以这里先换算成规则 id 再回调，由仓储按 id 定位真实位置，避免筛选态下改错规则。
   */
  private handleReorder(from: number, to: number): void {
    if (!this.canReorder()) {
      this.onUnavailableAction('名称排序下不能拖拽排序，请先切换到按顺序排序');
      return;
    }
    const visible = this.filteredReplaceRules();
    if (from < 0 || to < 0 || from >= visible.length || to >= visible.length || from === to) {
      return;
    }
    this.onReorderRule(visible[from].id, visible[to].id);
  }

  private filteredReplaceRules(): ReplaceRule[] {
    const query = this.searchQuery.trim().toLowerCase();
    const filtered = this.rules.filter((rule: ReplaceRule) => {
      const matchesGroup = this.selectedGroup.length === 0 || rule.group === this.selectedGroup;
      const matchesQuery = query.length === 0 || rule.name.toLowerCase().includes(query) ||
        rule.pattern.toLowerCase().includes(query) || rule.replacement.toLowerCase().includes(query);
      return matchesGroup && matchesQuery;
    });
    filtered.sort((left: ReplaceRule, right: ReplaceRule) => {
      if (this.sortMode === 'name_asc') {
        return left.name.localeCompare(right.name);
      }
      if (this.sortMode === 'name_desc') {
        return right.name.localeCompare(left.name);
      }
      return this.sortMode === 'desc' ? right.order - left.order : left.order - right.order;
    });
    return filtered;
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40)
          .onClick(() => { this.showSearch = !this.showSearch; if (!this.showSearch) { this.searchQuery = ''; } })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40)
          .bindMenu(this.ReplaceRuleMenu, { placement: Placement.BottomRight })
      }.width('100%').height(40).padding({ left: 11, right: 12 })
        .margin({ top: -8 })

      Text(this.selectionMode ? `已选择 ${this.selectedRuleIds.length} 项` : '替换净化')
        .fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
        .width('100%').padding({ left: 12, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索', text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_replace_rule_search')
            .onAppear(() => focusControl.requestFocus('my_replace_rule_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(24)
          .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
      }

      if (this.groups.length > 0) {
        Scroll() {
          Row() {
            ModuleTab({ label: '全部', selected: this.selectedGroup.length === 0, onSelect: () => this.selectedGroup = '' })
            ForEach(this.groups, (group: string) => {
              ModuleTab({ label: group, selected: this.selectedGroup === group, onSelect: () => this.selectedGroup = group })
            })
          }.width('100%').padding({ left: 16, right: 9, top: 8, bottom: 12 })
        }.scrollBar(BarState.Off)
      }

      if (this.filteredReplaceRules().length === 0) {
        ModuleEmpty({
          icon: 'profileFindReplace',
          title: this.rules.length === 0 ? '暂无替换净化规则' : '没有匹配的替换净化规则',
          detail: this.rules.length === 0 ? '添加规则后会按顺序应用到本地书籍正文' : '调整搜索词或分组筛选后重试'
        })
          .layoutWeight(1)
      } else {
        // 用 List 而不是 Scroll+Column：拖拽排序（ForEach.onMove）只在 List 内生效。
        List({ space: 8 }) {
          ForEach(this.filteredReplaceRules(), (rule: ReplaceRule) => {
            ListItem() {
              Row() {
                if (this.selectionMode) {
                  AppGlyph({
                    name: this.selectedRuleIds.includes(rule.id) ? 'profileCheck' : 'profileClose',
                    glyphSize: 20, tint: this.selectedRuleIds.includes(rule.id) ? '#AFC2FF' : '#92949E'
                  }).margin({ right: 12 })
                }
                Column() {
                  Text(rule.name.length > 0 ? rule.name : rule.pattern).fontSize(15).fontColor('#E3E4E8')
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${rule.group} · ${rule.scopeContent ? '正文' : ''}${rule.scopeTitle ? ' 标题' : ''}`)
                    .fontSize(12).fontColor('#92949E').margin({ top: 4 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                if (!this.selectionMode) {
                  Toggle({ type: ToggleType.Switch, isOn: rule.isEnabled })
                    .onChange((enabled: boolean) => this.onToggleRule(rule.id, enabled))
                  // 长按手势留给拖拽排序，条目操作改由「更多」图标触发，与上游条目右侧的更多按钮一致。
                  Stack({ alignContent: Alignment.Center }) {
                    AppGlyph({ name: 'more', glyphSize: 18, tint: '#92949E' })
                  }.width(32).height(32).margin({ left: 4 })
                    .bindMenu(this.RuleRowMenu(rule), { placement: Placement.BottomRight })
                }
              }.width('100%').padding({ left: 16, right: 16, top: 13, bottom: 13 })
                .backgroundColor('#1B1C22').borderRadius(14)
                .onClick(() => this.selectionMode ? this.toggleSelectedRule(rule.id) : this.onEditRule(rule.id))
            }
          }, (rule: ReplaceRule) => replaceRuleRowKey(rule))
            // 长按条目进入拖拽排序。名称排序下顺序由名称决定，与上游 canReorder 一致不挂载拖拽。
            .onMove(this.canReorder() ? (from: number, to: number) => this.handleReorder(from, to) : undefined)
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
          .padding({ left: 16, right: 16, top: 10, bottom: 80 })
      }
      if (this.selectionMode) {
        Row() {
          Text(this.selectedRuleIds.length === 0 ? '取消' : `已选择 ${this.selectedRuleIds.length} 项`)
            .fontSize(14).fontColor('#D8D9E0').layoutWeight(1)
            .onClick(() => this.exitSelection())
          Text('全选').fontSize(14).fontColor('#AFC2FF').padding({ left: 10, right: 10 })
            .onClick(() => this.selectAllVisible())
          Text('反选').fontSize(14).fontColor('#AFC2FF').padding({ left: 0, right: 10 })
            .onClick(() => this.invertSelection())
        }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 4 })
        Row() {
          Text('启用').fontSize(14)
            .fontColor(this.selectedRuleIds.length > 0 ? '#AFC2FF' : '#5C5E68')
            .onClick(() => this.submitBatchEnabled(true))
          Text('停用').fontSize(14).margin({ left: 18 })
            .fontColor(this.selectedRuleIds.length > 0 ? '#AFC2FF' : '#5C5E68')
            .onClick(() => this.submitBatchEnabled(false))
          Text('置顶').fontSize(14).margin({ left: 18 })
            .fontColor(this.selectedRuleIds.length > 0 ? '#AFC2FF' : '#5C5E68')
            .onClick(() => this.submitBatchMove(true))
          Text('置底').fontSize(14).margin({ left: 18 })
            .fontColor(this.selectedRuleIds.length > 0 ? '#AFC2FF' : '#5C5E68')
            .onClick(() => this.submitBatchMove(false))
          Text('导出').fontSize(14).margin({ left: 18 })
            .fontColor(this.selectedRuleIds.length > 0 ? '#AFC2FF' : '#5C5E68')
            .onClick(() => this.submitBatchExport())
          Blank().layoutWeight(1)
          Text('删除').fontSize(14)
            .fontColor(this.selectedRuleIds.length > 0 ? '#D99AA5' : '#5C5E68')
            .onClick(() => this.submitBatchRemove())
        }.width('100%').padding({ left: 16, right: 16, top: 2, bottom: 10 })
      }
      Stack({ alignContent: Alignment.Center }) {
        AppGlyph({ name: 'add', glyphSize: 22, tint: '#B9C8FF' })
      }.width(50).height(50).backgroundColor('#454F70').borderRadius(14)
        .visibility(this.selectionMode ? Visibility.None : Visibility.Visible)
        .onClick(() => this.onOpenEditor())
        .margin({ right: 16, bottom: 16 }).alignSelf(ItemAlign.End)
    }.width('100%').height('100%').backgroundColor('#111217')
      .bindSheet(this.ruleActionSheet.length > 0, this.RuleActionSheet(), {
        // 删除确认只有几行文字，用内容自适应高度，避免半屏空白。
        height: this.ruleActionSheet === 'confirmDelete' ? SheetSize.FIT_CONTENT : SheetSize.MEDIUM,
        dragBar: true,
        showClose: false,
        backgroundColor: '#17181E',
        onDisappear: () => this.ruleActionSheet = ''
      })
  }
}

@Component
export struct ReplaceRuleEditPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  onSaveRule: (rule: ReplaceRule) => void = (_rule: ReplaceRule) => {};
  /** 传入已有规则时进入编辑模式；为空表示新建。 */
  @Prop editingRule: ReplaceRule | undefined = undefined;
  @Prop groups: string[] = [];
  /** 分组管理：与列表页共用同一个面板，这里接的是同一批仓储方法。 */
  onAddGroup: (name: string) => Promise<void> = async (_name: string) => {};
  onRenameGroup: (oldName: string, newName: string) => Promise<void> = async (_o: string, _n: string) => {};
  onRemoveGroup: (name: string) => Promise<void> = async (_name: string) => {};
  @State name: string = '';
  @State group: string = '默认';
  @State pattern: string = '';
  @State replacement: string = '';
  @State scopeTitle: boolean = false;
  // 与上游 ReplaceRule 保持一致：新建规则默认作用于正文，
  // 否则保存后既不参与正文替换也不会出现在试跑结果里。
  @State scopeContent: boolean = true;
  @State isRegex: boolean = false;
  @State scope: string = '';
  @State excludeScope: string = '';
  @State timeout: string = '3000';
  @State keyboardVisible: boolean = false;
  @State showPasteAuthorization: boolean = false;
  /**
   * 当前打开的半模态面板：'' 表示关闭，'group' 为分组管理，'test' 为规则试跑。
   * ArkUI 一个组件只能绑定一个 bindSheet，后绑定的会覆盖先绑定的，
   * 因此两个面板合并成一个 bindSheet，用本字段切换内容。
   */
  @State activeSheet: string = '';
  @State activeField: string = 'pattern';
  @State isEnabled: boolean = true;
  /** 规则试跑：样例文本、结果与是否已跑过。 */
  @State testSource: string = '';
  @State testOutput: string = '';
  @State testError: string = '';
  @State testHasRun: boolean = false;
  /** 记录被编辑规则的 id 与 order，保存时原样带回，避免新建语义覆盖。 */
  @State editingId: number = 0;
  @State editingOrder: number = 0;
  @State initialized: boolean = false;

  aboutToAppear(): void {
    this.applyEditingRule();
  }

  /** @Prop 变化时（切换编辑目标）重新回填。 */
  onDidBuild(): void {
    if (!this.initialized) {
      this.applyEditingRule();
    }
  }

  private applyEditingRule(): void {
    const rule = this.editingRule;
    if (rule === undefined || rule === null) {
      this.initialized = true;
      return;
    }
    this.name = rule.name;
    this.group = typeof rule.group === 'string' && rule.group.length > 0 ? rule.group : '默认';
    this.pattern = rule.pattern;
    this.replacement = rule.replacement;
    this.scope = rule.scope;
    this.scopeTitle = rule.scopeTitle;
    this.scopeContent = rule.scopeContent;
    this.excludeScope = rule.excludeScope;
    this.isRegex = rule.isRegex;
    this.isEnabled = rule.isEnabled;
    this.timeout = `${rule.timeoutMillisecond}`;
    this.editingId = rule.id;
    this.editingOrder = rule.order;
    this.initialized = true;
  }

  private availableGroups(): string[] {
    const options: string[] = ['默认'];
    this.groups.forEach((group: string) => {
      if (group.length > 0 && group !== '默认' && !options.includes(group)) { options.push(group); }
    });
    return options;
  }

  @Builder
  private RuleActionsMenu() {
    Menu() {
      MenuItem({ content: '拷贝规则' })
        .onClick(() => this.copyRule())
      MenuItem({ content: '粘贴规则' })
        .onClick(() => this.showPasteAuthorization = true)
      MenuItem({ content: '测试规则' })
        .onClick(() => this.activeSheet = 'test')
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  /**
   * 用样例文本试跑已保存并启用的规则，展示每条规则是否真的改动了文本。
   * 只跑已保存的规则：编辑页里尚未保存的改动不在仓库缓存中，
   * 这里如实说明，避免用户以为改动已生效。
   */
  private runRuleTest(): void {
    if (this.testSource.trim().length === 0) {
      this.testError = '样例文本不能为空';
      this.testOutput = '';
      this.testHasRun = true;
      return;
    }
    const result = ReplaceRuleRepository.previewContent(this.testSource);
    this.testOutput = result.text;
    const changed = result.lines.filter((line: ReplaceRulePreviewLine) => line.changed).length;
    this.testError = result.lines.length === 0 ? '当前没有启用中的正文规则，样例文本未被改动'
      : `共 ${result.lines.length} 条正文规则，其中 ${changed} 条改动了样例文本`;
    this.testHasRun = true;
  }

  private clearRuleTest(): void {
    this.testOutput = '';
    this.testError = '';
    this.testHasRun = false;
  }

  @Builder
  private RuleTestSheet() {
    Column() {
      // 「清空」「试跑」放在标题栏里：键盘弹出时半模态面板被压到很矮，
      // 只有标题栏始终可见，放在底部或滚动区内都会被裁掉点不到。
      Row() {
        Text('测试规则').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#E3E4E8').layoutWeight(1)
        Text('清空').fontSize(15).fontColor('#92949E').margin({ right: 18 })
          .onClick(() => { this.testSource = ''; this.clearRuleTest(); })
        Text('试跑').fontSize(15).fontColor(this.testSource.trim().length > 0 ? '#B9C8FF' : '#5C5E68')
          .margin({ right: 8 })
          .onClick(() => this.runRuleTest())
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileClose', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => this.activeSheet = '')
      }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 8 })
      Text('只对已保存并启用的正文规则试跑，编辑中的改动需要先保存')
        .fontSize(12).fontColor('#92949E').width('100%').padding({ left: 18, right: 18, bottom: 10 })
      Scroll() {
        Column() {
          TextArea({ placeholder: '粘贴一段正文用于试跑', text: this.testSource })
            .fontSize(14).fontColor('#E3E4E8').placeholderColor('#92949E')
            .backgroundColor('#22232A').borderRadius(12)
            .width('100%').height(140).padding(12)
            .onChange((value: string) => { this.testSource = value; this.clearRuleTest(); })
          if (this.testHasRun) {
            Text(this.testError).fontSize(13)
              .fontColor(this.testError.startsWith('当前没有') ? '#92949E' : '#D8D9E0')
              .width('100%').textAlign(TextAlign.Start).margin({ top: 16 })
            if (this.testOutput.length > 0) {
              Text(this.testOutput).fontSize(14).fontColor('#E3E4E8')
                .width('100%').textAlign(TextAlign.Start).padding(12).margin({ top: 10 })
                .backgroundColor('#22232A').borderRadius(12)
            }
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 20 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  @Builder
  private GroupMenu() {
    Menu() {
      MenuItem({ content: '默认' }).onClick(() => this.group = '默认')
      ForEach(this.availableGroups(), (group: string) => {
        if (group !== '默认') {
          MenuItem({ content: group }).onClick(() => this.group = group)
        }
      }, (group: string) => group)
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  private clipboardJson(): string {
    return JSON.stringify({
      id: Date.now(), name: this.name, group: this.group, pattern: this.pattern,
      replacement: this.replacement, scope: this.scope, scopeTitle: this.scopeTitle,
      scopeContent: this.scopeContent, excludeScope: this.excludeScope,
      isEnabled: true, isRegex: this.isRegex,
      timeoutMillisecond: Number(this.timeout) || 3000, order: -2147483648
    });
  }

  private async copyRule(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.clipboardJson());
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制到剪贴板');
    } catch (_error) {
      this.onUnavailableAction('复制规则失败');
    }
  }

  private async pasteRule(result: PasteButtonOnClickResult): Promise<void> {
    this.showPasteAuthorization = false;
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得读取剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onUnavailableAction('剪贴板为空');
        return;
      }
      const parsed: ReplaceRuleClipboardData = JSON.parse(data.getRecord(0).toPlainText());
      if (typeof parsed.name !== 'string' || typeof parsed.pattern !== 'string' ||
        typeof parsed.replacement !== 'string') {
        this.onUnavailableAction('剪贴板规则格式无效');
        return;
      }
      this.name = parsed.name;
      this.group = typeof parsed.group === 'string' ? parsed.group : '默认';
      this.pattern = parsed.pattern;
      this.replacement = parsed.replacement;
      this.scope = typeof parsed.scope === 'string' ? parsed.scope : '';
      this.scopeTitle = parsed.scopeTitle === true;
      this.scopeContent = parsed.scopeContent !== false;
      this.excludeScope = typeof parsed.excludeScope === 'string' ? parsed.excludeScope : '';
      this.isRegex = parsed.isRegex !== false;
      this.timeout = typeof parsed.timeoutMillisecond === 'number' ? `${parsed.timeoutMillisecond}` : '3000';
      this.onUnavailableAction('规则已从剪贴板填入');
    } catch (_error) {
      this.onUnavailableAction('剪贴板规则格式无效');
    }
  }

  private insertQuickText(value: string): void {
    if (this.activeField === 'name') { this.name += value; }
    else if (this.activeField === 'replacement') { this.replacement += value; }
    else if (this.activeField === 'scope') { this.scope += value; }
    else if (this.activeField === 'excludeScope') { this.excludeScope += value; }
    else if (this.activeField === 'timeout') { this.timeout += value; }
    else { this.pattern += value; }
  }

  private saveRule(): void {
    if (this.pattern.trim().length === 0) {
      this.onUnavailableAction('替换规则为空或者不满足正则表达式要求');
      return;
    }
    if (this.isRegex) {
      try {
        new RegExp(this.pattern);
        if (this.pattern.endsWith('|') && !this.pattern.endsWith('\\|')) {
          this.onUnavailableAction('替换规则为空或者不满足正则表达式要求');
          return;
        }
      } catch (_error) {
        this.onUnavailableAction('替换规则为空或者不满足正则表达式要求');
        return;
      }
    }
    const rule: ReplaceRule = {
      id: this.editingId > 0 ? this.editingId : Date.now(), name: this.name.trim(), group: this.group,
      pattern: this.pattern, replacement: this.replacement, scope: this.scope, scopeTitle: this.scopeTitle,
      scopeContent: this.scopeContent, excludeScope: this.excludeScope, isEnabled: this.isEnabled,
      isRegex: this.isRegex, timeoutMillisecond: Math.max(1, Number(this.timeout) || 3000),
      order: this.editingId > 0 ? this.editingOrder : 0
    };
    this.onSaveRule(rule);
  }

  @Builder
  private RuleField(label: string, value: string, field: string, placeholder: string) {
    Column() {
      Text(label).fontSize(14).fontColor('#C3C5CD').margin({ left: 14, bottom: 3 })
      TextInput({ placeholder: placeholder, text: value })
        .fontSize(16).fontColor('#E3E4E8').placeholderColor('#92949E')
        .height(52).backgroundColor('#24252C').borderRadius(8).padding({ left: 14, right: 14 })
        .width('100%')
        .onFocus(() => { this.activeField = field; this.keyboardVisible = true; })
        .onBlur(() => this.keyboardVisible = false)
        .onChange((text: string) => {
          if (field === 'name') { this.name = text; }
          else if (field === 'pattern') { this.pattern = text; }
          else if (field === 'replacement') { this.replacement = text; }
          else if (field === 'scope') { this.scope = text; }
          else if (field === 'excludeScope') { this.excludeScope = text; }
          else if (field === 'timeout') { this.timeout = text; }
        })
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 4 })
  }

  /**
   * 半模态面板的统一入口。ArkUI 同一组件只能绑定一个 bindSheet，
   * 所以按 activeSheet 分支渲染，而不是叠加多个 bindSheet。
   */
  @Builder
  private EditPageSheet() {
    if (this.activeSheet === 'group') {
      this.GroupManagerSheet()
    } else if (this.activeSheet === 'test') {
      this.RuleTestSheet()
    }
  }

  @Builder
  private GroupManagerSheet() {
    // 与列表页共用同一份分组管理实现，这里只负责传回调。
    ReplaceRuleGroupSheet({
      groups: this.availableGroups(),
      onAddGroup: (name: string) => this.onAddGroup(name),
      onRenameGroup: (oldName: string, newName: string) => this.onRenameGroup(oldName, newName),
      onRemoveGroup: (name: string) => this.onRemoveGroup(name),
      onClose: () => this.activeSheet = '',
      onUnavailableAction: (message: string) => this.onUnavailableAction(message)
    })
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        if (this.keyboardVisible) {
          Stack({ alignContent: Alignment.Center }) {
            Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
            AppGlyph({ name: 'profileSave', glyphSize: 20, tint: '#D8D9E0' })
          }.width(40).height(40).margin({ right: 8 })
            .onClick(() => this.saveRule())
        }
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40)
          .bindMenu(this.RuleActionsMenu, { placement: Placement.BottomRight })
      }.width('100%').height(40).padding({ left: 11, right: 12 })
        .margin({ top: -8 })
      Text(this.editingId > 0 ? '编辑替换' : '新建替换').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
        .width('100%').padding({ left: 14, right: 0, top: 12, bottom: 0 })
      Scroll() {
        Column() {
          this.RuleField('规则名称', this.name, 'name', '')
          Row() {
            Column() {
              Row() {
                Blank().width(14)
                Text('分组').fontSize(14).fontColor('#C3C5CD').textAlign(TextAlign.Start)
              }.width('100%')
              Row() {
                Blank().width(14)
                Text(this.group).fontSize(15).fontColor('#E3E4E8').layoutWeight(1)
                AppGlyph({ name: 'profileExpandMore', glyphSize: 20, tint: '#D8D9E0' })
                Blank().width(14)
              }.width('100%')
              Row().width('calc(100% - 4vp)').height(1).backgroundColor('#898B94').margin({ left: 2, right: 2 })
            }.width('calc(100% - 40vp)').height(56).justifyContent(FlexAlign.Center)
              .backgroundColor('#24252C').borderRadius(8)
              .bindMenu(this.GroupMenu, { placement: Placement.BottomRight })
            Stack({ alignContent: Alignment.Center }) {
              AppGlyph({ name: 'profileSettings', glyphSize: 20, tint: '#D8D9E0' })
            }.width(48).height(56).onClick(() => { this.activeSheet = 'group'; })
          }.width('100%')
          Blank().height(12)
          this.RuleField('匹配规则', this.pattern, 'pattern', '输入正则表达式或关键字')
          this.RuleField('替换为', this.replacement, 'replacement', '输入替换内容或捕获组')
          Row() {
            ReplaceScopeChip({ label: '标题', selected: this.scopeTitle,
              onSelect: () => this.scopeTitle = !this.scopeTitle })
            ReplaceScopeChip({ label: '内容', selected: this.scopeContent,
              onSelect: () => this.scopeContent = !this.scopeContent })
            Blank().layoutWeight(1)
            ReplaceScopeChip({ label: '正则', selected: this.isRegex,
              onSelect: () => this.isRegex = !this.isRegex })
          }.width('100%').margin({ top: 12, bottom: 15 })
          this.RuleField('特定范围', this.scope, 'scope', '指定规则适用的范围')
          this.RuleField('排除范围', this.excludeScope, 'excludeScope', '指定规则不适用的范围')
          Column() {
            Text('超时 (ms)').fontSize(14).fontColor('#C3C5CD').width('100%').textAlign(TextAlign.Start)
            TextInput({ text: this.timeout, placeholder: '3000' })
              .fontSize(16).fontColor('#E3E4E8').backgroundColor(Color.Transparent)
              .height(30).padding({ left: 0, right: 0 }).width('100%')
              .onFocus(() => { this.activeField = 'timeout'; this.keyboardVisible = true; })
              .onBlur(() => this.keyboardVisible = false)
              .onChange((text: string) => this.timeout = text)
            Row().width('100%').height(1).backgroundColor('#898B94')
          }.width('100%').height(56).alignItems(HorizontalAlign.Start).justifyContent(FlexAlign.Center)
            .padding({ left: 14, right: 14 }).backgroundColor('#24252C').borderRadius(8)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 0, bottom: 140 })
          .layoutWeight(1)
      }.layoutWeight(1).scrollBar(BarState.Off)
      if (this.keyboardVisible) {
        Scroll() {
          Row() {
            ForEach(['.*', '\\d+', '\\w+', '[]', '()', '^', '$', '|', '{}', '<>'], (symbol: string) => {
              Text(symbol).fontSize(14).fontColor('#D8D9E0').padding({ left: 10, right: 10, top: 7, bottom: 7 })
                .backgroundColor('#303139').borderRadius(18).margin({ right: 7 })
                .onClick(() => this.insertQuickText(symbol))
            })
          }.padding({ left: 16, right: 16, top: 8, bottom: 8 })
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      }
      Row() {
        if (this.showPasteAuthorization) {
          PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
            .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) => await this.pasteRule(result))
        }
        Blank()
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileSave', glyphSize: 20, tint: '#B9C8FF' })
        }.width(50).height(50).backgroundColor('#454F70').borderRadius(14)
          .visibility(this.keyboardVisible ? Visibility.Hidden : Visibility.Visible)
          .onClick(() => this.saveRule())
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 16 })
    }.width('100%').height('100%').backgroundColor('#111217')
      .bindSheet(this.activeSheet.length > 0, this.EditPageSheet(), {
        height: SheetSize.MEDIUM,
        dragBar: true,
        showClose: false,
        backgroundColor: '#17181E',
        onDisappear: () => this.activeSheet = ''
      })
  }
}

/**
 * 替换规则的分组管理面板。
 * 规则列表页与规则编辑页共用这一份实现：此前两处各写一套，
 * 列表页能用而编辑页的「删除选中」仍是占位提示，同一功能出现两种行为。
 */
@Component
export struct ReplaceRuleGroupSheet {
  /**
   * 初始分组清单。面板是 bindSheet 的 builder 内容，打开期间不会随父级重新构建，
   * 因此不能只靠这个入参刷新，增删改之后由 reloadGroups() 从仓储重新取。
   */
  @Prop groups: string[] = [];
  /** 回调返回 Promise，面板等它落盘后再刷新列表，避免用固定延时猜时机。 */
  onAddGroup: (name: string) => Promise<void> = async (_name: string) => {};
  onRenameGroup: (oldName: string, newName: string) => Promise<void> = async (_o: string, _n: string) => {};
  onRemoveGroup: (name: string) => Promise<void> = async (_name: string) => {};
  onClose: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 面板内实际渲染的分组，操作后自行刷新，不等父级重建。 */
  @State localGroups: string[] = [];
  @State groupInput: string = '';
  /** 非空表示正在重命名该分组，为空表示新建。 */
  @State groupEditing: string = '';

  aboutToAppear(): void {
    this.reloadGroups();
  }

  /** 从仓储读最新分组；仓储已是内存缓存，直接读不会产生额外 IO。 */
  private reloadGroups(): void {
    this.localGroups = ReplaceRuleRepository.getGroups();
  }

  /** 除「默认」之外的分组；默认分组不允许重命名或删除。 */
  private customGroups(): string[] {
    return this.localGroups.filter((group: string) => group.length > 0 && group !== '默认');
  }

  /** 提交输入：编辑态调用重命名，新建态调用新增，落盘后刷新列表。 */
  private async submitGroup(): Promise<void> {
    const name = this.groupInput.trim();
    if (name.length === 0) {
      this.onUnavailableAction('分组名称不能为空');
      return;
    }
    if (this.groupEditing.length > 0) {
      if (name === this.groupEditing) {
        this.groupEditing = '';
        this.groupInput = '';
        return;
      }
      await this.onRenameGroup(this.groupEditing, name);
    } else {
      await this.onAddGroup(name);
    }
    this.groupEditing = '';
    this.groupInput = '';
    this.reloadGroups();
  }

  /** 删除分组：等落盘完成再刷新，保证列表与实际存储一致。 */
  private async removeGroup(name: string): Promise<void> {
    await this.onRemoveGroup(name);
    this.reloadGroups();
  }

  build() {
    Column() {
      Row() {
        Text('分组管理').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#E3E4E8').layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileClose', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => this.onClose())
      }.width('100%').padding({ left: 18, right: 12, top: 14, bottom: 12 })
      Scroll() {
        Column() {
          ForEach(this.customGroups(), (group: string) => {
            Row() {
              Text(group).fontSize(15).fontColor('#E3E4E8').layoutWeight(1)
              AppGlyph({ name: 'edit', glyphSize: 18, tint: '#B9C8FF' }).margin({ right: 18 })
                .onClick(() => { this.groupEditing = group; this.groupInput = group; })
              AppGlyph({ name: 'delete', glyphSize: 18, tint: '#D99AA5' })
                .onClick(() => this.removeGroup(group))
            }.width('100%').padding({ left: 16, right: 16, top: 13, bottom: 13 })
              .backgroundColor('#22232A').borderRadius(12).margin({ bottom: 7 })
          }, (group: string) => group)
          if (this.customGroups().length === 0) {
            Text('暂无其他分组').fontSize(15).fontColor('#92949E').width('100%').textAlign(TextAlign.Center)
              .padding({ top: 24, bottom: 24 })
          }
          Row() {
            TextInput({ placeholder: this.groupEditing.length > 0 ? '输入新的分组名称' : '输入分组名称',
              text: this.groupInput })
              .fontSize(15).fontColor('#E3E4E8').placeholderColor('#92949E')
              .backgroundColor(Color.Transparent).layoutWeight(1).height(44)
              .onChange((value: string) => this.groupInput = value)
            if (this.groupEditing.length > 0) {
              Text('取消').fontSize(13).fontColor('#92949E').padding({ left: 8, right: 8 })
                .onClick(() => { this.groupEditing = ''; this.groupInput = ''; })
            }
            Text(this.groupEditing.length > 0 ? '保存' : '添加')
              .fontSize(13).fontColor(this.groupInput.trim().length > 0 ? '#B9C8FF' : '#5C5E68')
              .padding({ left: 8 })
              .onClick(() => this.submitGroup())
          }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor('#22232A').borderRadius(12).margin({ top: 5, bottom: 20 })
        }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#17181E')
  }
}

@Component
struct ReplaceScopeChip {
  @Prop label: string = '';
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Row() {
      if (this.selected) {
        AppGlyph({ name: 'profileCheck', glyphSize: 16, tint: '#D8D9E0' }).margin({ right: 5 })
      }
      Text(this.label).fontSize(14).fontColor('#D8D9E0')
    }.padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor(this.selected ? '#3A4054' : Color.Transparent).borderRadius(12)
      .border({ width: 1, color: '#51535D' }).margin({ right: 8 }).onClick(() => this.onSelect())
  }
}

interface ReplaceRuleClipboardData {
  name?: string;
  group?: string | null;
  pattern?: string;
  replacement?: string;
  scope?: string | null;
  scopeTitle?: boolean;
  scopeContent?: boolean;
  excludeScope?: string | null;
  isRegex?: boolean;
  timeoutMillisecond?: number;
}

export interface RuleListEntry {
  id: string;
  title: string;
  detail: string;
  enabled: boolean;
}

@Component
struct RuleListBody {
  @Prop rules: RuleListEntry[] = [];
  @Prop query: string = '';
  @Prop selectedIds: string[] = [];
  @Prop selectionMode: boolean = false;
  @Prop sortMode: boolean = false;
  @Prop emptyMessage: string = '暂无规则';
  onOpen: (id: string) => void = (_id: string) => {};
  onToggle: (id: string) => void = (_id: string) => {};
  onLongSelect: (id: string) => void = (_id: string) => {};
  onMove: (id: string, direction: number) => void = (_id: string, _direction: number) => {};
  /** 条目右侧开关；不传时按不可用处理，避免点了没反应。 */
  onEnabledChange: (id: string, enabled: boolean) => void = (_id: string, _enabled: boolean) => {};
  /** 条目菜单的置顶/置底。 */
  onMoveToEdge: (id: string, toTop: boolean) => void = (_id: string, _toTop: boolean) => {};
  /** 条目菜单的删除；由父组件弹确认面板，这里只上报意图。 */
  onDelete: (id: string) => void = (_id: string) => {};

  /** 条目右侧「更多」菜单：置顶、置底、删除，与上游条目下拉三项一致。 */
  @Builder
  private RowMenu(rule: RuleListEntry) {
    Menu() {
      MenuItem({ content: '置顶' })
        .onClick(() => this.onMoveToEdge(rule.id, true))
      MenuItem({ content: '置底' })
        .onClick(() => this.onMoveToEdge(rule.id, false))
      MenuItem({ content: '删除' })
        .onClick(() => this.onDelete(rule.id))
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  private visibleRules(): RuleListEntry[] {
    const query = this.query.trim().toLocaleLowerCase();
    return query.length === 0 ? this.rules : this.rules.filter((rule: RuleListEntry) =>
      rule.title.toLocaleLowerCase().includes(query) || rule.detail.toLocaleLowerCase().includes(query));
  }

  build() {
    if (this.visibleRules().length === 0) {
      Column() {
        Text('(；′⌒`)').fontSize(32).fontColor('#E3E4E8')
        Text(this.query.length > 0 ? '没有匹配的规则' : this.emptyMessage)
          .fontSize(14).fontColor('#D8D9E0').margin({ top: 8 })
      }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    } else {
      Scroll() {
        Column() {
          ForEach(this.visibleRules(), (rule: RuleListEntry) => {
            Row() {
              if (this.selectionMode) {
                AppGlyph({ name: this.selectedIds.includes(rule.id) ? 'profileCheck' : 'profileClose',
                  glyphSize: 20, tint: this.selectedIds.includes(rule.id) ? '#AFC2FF' : '#92949E' })
                  .margin({ right: 12 })
              }
              Column() {
                Text(rule.title).fontSize(16).fontColor(rule.enabled ? '#E3E4E8' : '#92949E')
                Text(rule.detail).fontSize(13).fontColor('#92949E').margin({ top: 4 }).maxLines(2)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              if (this.sortMode) {
                Image($r('app.media.reader_reorder_up')).width(18).height(18).fillColor('#AFC2FF')
                  .margin({ right: 12 }).onClick(() => this.onMove(rule.id, -1))
                Image($r('app.media.reader_reorder_down')).width(18).height(18).fillColor('#AFC2FF')
                  .onClick(() => this.onMove(rule.id, 1))
              } else if (!this.selectionMode) {
                // 开关、编辑与更多图标并排；key 里带上 enabled，避免 ArkUI 复用节点导致开关不刷新。
                Toggle({ type: ToggleType.Switch, isOn: rule.enabled })
                  .onChange((enabled: boolean) => this.onEnabledChange(rule.id, enabled))
                AppGlyph({ name: 'edit', glyphSize: 18, tint: '#AFC2FF' }).margin({ left: 8 })
                Stack({ alignContent: Alignment.Center }) {
                  AppGlyph({ name: 'more', glyphSize: 18, tint: '#92949E' })
                }.width(32).height(32).margin({ left: 4 })
                  .bindMenu(this.RowMenu(rule), { placement: Placement.BottomRight })
              }
            }.width('100%').padding(16).backgroundColor('#1A1B21').borderRadius(14)
              .margin({ left: 16, right: 16, bottom: 8 })
              .onClick(() => this.selectionMode ? this.onToggle(rule.id) : this.onOpen(rule.id))
              .priorityGesture(LongPressGesture({ duration: 500 }).onAction(() => this.onLongSelect(rule.id)))
          }, (rule: RuleListEntry) => `${rule.id}_${rule.enabled ? 1 : 0}`)
        }.padding({ top: 8, bottom: 120 })
      }.width('100%').height('100%').scrollBar(BarState.Off)
    }
  }
}

@Component
export struct TxtTocRulesPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 当前规则列表，由 Index 持有并随仓储刷新。 */
  @Prop rules: RuleListEntry[] = [];
  /** 当前规则原始数据，供编辑时回填正则；与 rules 一一对应。 */
  @Prop sourceRules: TxtTocRule[] = [];
  onSaveRule: (rule: TxtTocRule) => Promise<void> = async (_rule: TxtTocRule) => {};
  onRemoveRule: (id: number) => Promise<void> = async (_id: number) => {};
  onRemoveBatch: (ids: number[]) => Promise<void> = async (_ids: number[]) => {};
  onToggleRule: (id: number, enabled: boolean) => Promise<void> = async (_id: number, _enabled: boolean) => {};
  onMoveRule: (id: number, direction: number) => Promise<void> = async (_id: number, _direction: number) => {};
  /** 条目菜单的置顶/置底：toTop 为 true 时移到最前。 */
  onMoveRuleToEdge: (id: number, toTop: boolean) => Promise<void> = async (_id: number, _toTop: boolean) => {};
  /** 选择模式下的批量启用/停用。 */
  onSetEnabledBatch: (ids: number[], enabled: boolean) => Promise<void> = async (_ids: number[], _enabled: boolean) => {};
  onImportBuiltin: () => Promise<void> = async () => {};
  /** 从用户选择的规则文件导入。 */
  onImportRules: () => Promise<void> = async () => {};
  /** 导出给定的规则；空数组表示没有可导出内容。 */
  onExportRules: (rules: TxtTocRule[]) => Promise<void> = async (_rules: TxtTocRule[]) => {};
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State selectionMode: boolean = false;
  @State selectedRuleIds: string[] = [];
  @State sortMode: boolean = false;
  @State showAddRule: boolean = false;
  /** 是否显示粘贴按钮；剪贴板读取需要 PasteButton 授权，不能直接调用。 */
  @State showPasteAuthorization: boolean = false;
  @State ruleName: string = '';
  @State chapterRegex: string = '';
  @State exampleText: string = '';
  @State volumeRegex: string = '';
  @State testError: string = '';
  @State testResults: TxtRuleTestLine[] = [];
  @State testHasRun: boolean = false;
  /** 正在编辑的规则 id；为空表示新建。 */
  @State editingRuleId: number = -1;
  /**
   * 是否处于编辑态。
   * 不能用 editingRuleId >= 0 判断：内置规则的 id 是负数（-1、-2…），
   * 用数值范围判断会把内置规则误认成新建。
   */
  @State editingExisting: boolean = false;
  /** 待确认删除的规则 id；与替换净化页一致，确认前不动数据。 */
  @State pendingDeleteIds: number[] = [];
  /** 当前打开的确认/编辑面板标识，空串表示未打开。 */
  @State confirmSheet: string = '';

  /** 切换单条规则的选中状态。 */
  private toggleSelectedRule(id: string): void {
    this.selectedRuleIds = this.selectedRuleIds.includes(id) ?
      this.selectedRuleIds.filter((selectedId: string) => selectedId !== id) : [...this.selectedRuleIds, id];
  }

  /** 全选当前筛选结果：筛选态下「全选」应与用户眼前的列表范围一致。 */
  private selectAllVisible(): void {
    this.selectedRuleIds = this.rules.map((rule: RuleListEntry) => rule.id);
  }

  /**
   * 反选：在当前筛选结果内取差集，与上游 invertSelection() 一致。
   * 用筛选结果而不是全部规则，保证「反选」与用户眼前的列表范围一致。
   */
  private invertSelection(): void {
    const visible = this.rules.map((rule: RuleListEntry) => rule.id);
    this.selectedRuleIds = visible.filter((id: string) => !this.selectedRuleIds.includes(id));
  }

  /** 退出选择模式并清空选中，避免下次进入时残留上一次的选择。 */
  private exitSelection(): void {
    this.selectionMode = false;
    this.selectedRuleIds = [];
  }

  /** 选中的 id 转成数字数组；非法 id 直接丢弃。 */
  private selectedNumericIds(): number[] {
    return this.selectedRuleIds.map((id: string) => Number(id))
      .filter((id: number) => Number.isInteger(id));
  }

  /** 请求删除：只记录待删对象并打开确认面板，不直接删。 */
  private requestDelete(ids: number[]): void {
    if (ids.length === 0) {
      return;
    }
    this.pendingDeleteIds = ids;
    this.confirmSheet = 'confirmDelete';
  }

  /** 确认删除：单条走单条回调，多条走批量回调，然后退出选择模式。 */
  private async confirmDelete(): Promise<void> {
    const ids = this.pendingDeleteIds;
    this.pendingDeleteIds = [];
    this.confirmSheet = '';
    if (ids.length === 1) {
      await this.onRemoveRule(ids[0]);
      this.selectedRuleIds = this.selectedRuleIds.filter((id: string) => Number(id) !== ids[0]);
      return;
    }
    await this.onRemoveBatch(ids);
    this.exitSelection();
  }

  /** 取消删除：只关面板，不动选择模式，用户可以继续操作已选规则。 */
  private cancelDelete(): void {
    this.pendingDeleteIds = [];
    this.confirmSheet = '';
  }

  /** 批量启用/停用：未选中时提示而不是静默无反应。 */
  private async submitBatchEnabled(enabled: boolean): Promise<void> {
    const ids = this.selectedNumericIds();
    if (ids.length === 0) {
      this.onUnavailableAction('请先选择规则');
      return;
    }
    await this.onSetEnabledBatch(ids, enabled);
  }

  /** 批量导出选中规则；空选中直接提示。 */
  private submitBatchExport(): void {
    const ids = this.selectedNumericIds();
    if (ids.length === 0) {
      this.onUnavailableAction('请先选择规则');
      return;
    }
    const selected = this.sourceRules.filter((rule: TxtTocRule) => ids.includes(rule.id));
    if (selected.length === 0) {
      this.onUnavailableAction('所选规则已不存在');
      return;
    }
    this.onExportRules(selected);
  }

  private buildClipboardRule(): string {
    return JSON.stringify({
      id: Date.now(),
      name: this.ruleName,
      chapterRule: this.chapterRegex,
      volumeRule: this.volumeRegex,
      example: this.exampleText,
      serialNumber: -1,
      enable: true
    });
  }

  private async copyRuleToClipboard(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.buildClipboardRule());
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制到剪贴板');
    } catch (_error) {
      this.onUnavailableAction('复制规则失败');
    }
  }

  private async pasteRuleFromClipboard(result: PasteButtonOnClickResult): Promise<void> {
    this.showPasteAuthorization = false;
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得读取剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onUnavailableAction('剪贴板为空');
        return;
      }
      const text = data.getRecord(0).toPlainText();
      const parsed: TxtRuleClipboardData = JSON.parse(text);
      const chapterRule = parsed.chapterRule ?? parsed.rule;
      if (typeof parsed.name !== 'string' || typeof chapterRule !== 'string' ||
        (typeof parsed.example !== 'string' && parsed.example !== null && parsed.example !== undefined) ||
        (typeof parsed.volumeRule !== 'string' && parsed.volumeRule !== undefined)) {
        this.onUnavailableAction('剪贴板规则格式无效');
        return;
      }
      this.ruleName = parsed.name;
      this.chapterRegex = chapterRule;
      this.exampleText = typeof parsed.example === 'string' ? parsed.example : '';
      this.volumeRegex = parsed.volumeRule ?? '';
      this.clearRuleTest();
      this.onUnavailableAction('规则已从剪贴板填入');
    } catch (_error) {
      this.onUnavailableAction('剪贴板规则格式无效');
    }
  }

  private clearRuleTest(): void {
    this.testError = '';
    this.testResults = [];
    this.testHasRun = false;
  }

  private runRuleTest(): void {
    const pattern = this.chapterRegex.trim();
    const normalized = this.exampleText.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
    if (pattern.length === 0) {
      this.testError = '章节正则不能为空';
      this.testResults = [];
      this.testHasRun = true;
      return;
    }
    if (normalized.trim().length === 0) {
      this.testError = '示例不能为空';
      this.testResults = [];
      this.testHasRun = true;
      return;
    }
    try {
      const regex = TxtTocRuleRepository.compileRegex(pattern, 'gm');
      const text = `\n${normalized}`;
      const ranges: TxtRuleMatchRange[] = [];
      let match = regex.exec(text);
      while (match !== null) {
        ranges.push({ start: match.index, end: match.index + match[0].length });
        if (match[0].length === 0) {
          regex.lastIndex += 1;
        }
        match = regex.exec(text);
      }
      const lines = normalized.split('\n');
      let offset = 1;
      this.testResults = lines.map((line: string): TxtRuleTestLine => {
        const lineStart = offset;
        const lineEnd = offset + line.length;
        const matched = ranges.some((range: TxtRuleMatchRange): boolean => {
          return range.start === range.end
            ? range.start >= lineStart && range.start <= lineEnd
            : range.start < lineEnd && range.end > lineStart;
        });
        offset = lineEnd + 1;
        return { line, matched };
      });
      this.testError = '';
      this.testHasRun = true;
    } catch (_error) {
      this.testError = '正则格式无效';
      this.testResults = [];
      this.testHasRun = true;
    }
  }

  @Builder
  private ImportMenu() {
    Menu() {
      MenuItem({ content: '排序' }).onClick(() => this.sortMode = !this.sortMode)
      MenuItem({ content: '选择模式' }).onClick(() => {
        this.selectionMode = !this.selectionMode;
        this.selectedRuleIds = [];
      })
      MenuItem({ content: '导入' })
        .onClick(() => this.onImportRules())
      MenuItem({ content: '导出' })
        .onClick(() => this.onExportRules(this.sourceRules))
      MenuItem({ content: '导入内置规则' })
        .onClick(async () => {
          await this.onImportBuiltin();
        })
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  @Builder
  private EditMoreMenu() {
    Menu() {
      MenuItem({ content: '复制规则' })
        .onClick(() => this.copyRuleToClipboard())
      MenuItem({ content: '粘贴规则' })
        .onClick(() => this.showPasteAuthorization = true)
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  @Builder
  private ruleEditorSheet() {
    Column() {
      Row() {
        AppGlyph({ name: 'profileClose', glyphSize: 20, tint: '#D8D9E0' }).padding({ right: 12 })
          .onClick(() => this.showAddRule = false)
        Text(this.editingExisting ? '编辑目录规则' : 'TXT 目录规则').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#E3E4E8').layoutWeight(1)
        AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
          .bindMenu(this.EditMoreMenu, { placement: Placement.BottomRight })
      }.width('100%').padding({ left: 18, right: 16, top: 8, bottom: 12 })
      Scroll() {
        Column() {
          Text('名称').fontSize(14).fontColor('#AEB0BA').width('100%').textAlign(TextAlign.Start)
          TextInput({ placeholder: '名称', text: this.ruleName })
            .fontSize(15).fontColor('#E3E4E8').placeholderColor('#92949E')
            .backgroundColor('#111217').borderRadius(12).padding(12).width('100%')
            .onChange((value: string) => { this.ruleName = value; this.clearRuleTest(); })
          Text('章节正则').fontSize(14).fontColor('#AEB0BA').width('100%').textAlign(TextAlign.Start).margin({ top: 12 })
          TextInput({ placeholder: '章节正则', text: this.chapterRegex })
            .fontSize(15).fontColor('#E3E4E8').placeholderColor('#92949E')
            .backgroundColor('#111217').borderRadius(12).padding(12).width('100%')
            .onChange((value: string) => { this.chapterRegex = value; this.clearRuleTest(); })
          Text('示例').fontSize(14).fontColor('#AEB0BA').width('100%').textAlign(TextAlign.Start).margin({ top: 12 })
          TextArea({ placeholder: '示例', text: this.exampleText })
            .fontSize(15).fontColor('#E3E4E8').placeholderColor('#92949E')
            .backgroundColor('#111217').borderRadius(12).height(96).padding(12).width('100%')
            .onChange((value: string) => { this.exampleText = value; this.clearRuleTest(); })
          Text('分卷正则').fontSize(14).fontColor('#AEB0BA').width('100%').textAlign(TextAlign.Start).margin({ top: 12 })
          TextInput({ placeholder: '分卷正则', text: this.volumeRegex })
            .fontSize(15).fontColor('#E3E4E8').placeholderColor('#92949E')
            .backgroundColor('#111217').borderRadius(12).padding(12).width('100%')
            .onChange((value: string) => { this.volumeRegex = value; this.clearRuleTest(); })
          if (this.testHasRun) {
            if (this.testError.length > 0) {
              Text(this.testError).fontSize(14).fontColor('#FF8A80').width('100%').textAlign(TextAlign.Start).margin({ top: 14 })
            } else {
              Text(`${this.testResults.filter((item: TxtRuleTestLine) => item.matched).length} / ${this.testResults.length}`)
                .fontSize(14).fontColor('#D8D9E0').width('100%').textAlign(TextAlign.Start).margin({ top: 14, bottom: 6 })
              ForEach(this.testResults, (item: TxtRuleTestLine, index: number) => {
                Row() {
                  AppGlyph({ name: item.matched ? 'profileCheck' : 'profileClose', glyphSize: 18,
                    tint: item.matched ? '#AFC2FF' : '#FF8A80' }).margin({ right: 8 })
                  Text(item.line.length > 0 ? item.line : '（空行）').fontSize(13)
                    .fontColor(item.matched ? '#D8D9E0' : '#92949E').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }.width('100%')
              }, (item: TxtRuleTestLine, index: number) => `txt_rule_test_${index}`)
            }
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 18 })
      }.layoutWeight(1).scrollBar(BarState.Off)
      Row() {
        Row() {
          AppGlyph({ name: 'profileRunningWithErrors', glyphSize: 20, tint: '#E3E4E8' })
          Text('测试').fontSize(14).fontColor('#E3E4E8').margin({ left: 7 })
        }.padding({ left: 14, right: 14, top: 10, bottom: 10 }).backgroundColor('#34353D').borderRadius(22)
          .onClick(() => this.runRuleTest())
        if (this.showPasteAuthorization) {
          PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
            .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) => {
              await this.pasteRuleFromClipboard(result);
            })
        }
        Blank()
        Row() {
          AppGlyph({ name: 'profileSave', glyphSize: 18, tint: '#151720' })
        }.width(44).height(44).justifyContent(FlexAlign.Center).backgroundColor('#B9C8FF').borderRadius(22)
          .onClick(async () => {
            const emptyDefaultRule = this.ruleName.trim() === '默认分章规则' && this.chapterRegex.trim().length === 0;
            if (this.ruleName.trim().length === 0 || (this.chapterRegex.trim().length === 0 && !emptyDefaultRule)) {
              this.onUnavailableAction('名称和章节正则不能为空');
            } else if (!this.isValidRegex(this.chapterRegex)) {
              this.onUnavailableAction('正则格式无效，规则未保存');
            } else if (this.volumeRegex.trim().length > 0 && !this.isValidRegex(this.volumeRegex)) {
              this.onUnavailableAction('分卷正则格式无效，规则未保存');
            } else {
              const existing: TxtTocRule | undefined = this.editingExisting
                ? this.sourceRules.find((rule: TxtTocRule) => rule.id === this.editingRuleId) : undefined;
              await this.onSaveRule({
                id: this.editingExisting ? this.editingRuleId : Date.now(),
                name: this.ruleName.trim(),
                chapterRule: this.chapterRegex.trim(),
                volumeRule: this.volumeRegex.trim(),
                example: this.exampleText.length > 0 ? this.exampleText : undefined,
                // 编辑已有规则时沿用原序号，新建的排在末尾由仓储重排。
                serialNumber: existing?.serialNumber ?? -1,
                enable: existing?.enable ?? true
              });
              this.showAddRule = false;
            }
          })
      }.width('100%').justifyContent(FlexAlign.End).padding({ left: 16, right: 16, top: 10, bottom: 18 })
    }.width('100%').height('100%')
  }

  /** 打开编辑面板并回填已有规则；id 无效时按新建处理。 */
  private openEditor(id: string): void {
    const numericId = Number(id);
    const rule: TxtTocRule | undefined = Number.isInteger(numericId)
      ? this.sourceRules.find((item: TxtTocRule) => item.id === numericId) : undefined;
    if (rule === undefined) {
      this.onUnavailableAction('该规则已不存在');
      return;
    }
    this.editingRuleId = rule.id;
    this.editingExisting = true;
    this.ruleName = rule.name;
    this.chapterRegex = rule.chapterRule;
    this.exampleText = rule.example ?? '';
    this.volumeRegex = rule.volumeRule;
    this.clearRuleTest();
    this.showAddRule = true;
  }

  /** 打开新建面板，清空编辑态。 */
  private openCreator(): void {
    this.editingRuleId = -1;
    this.editingExisting = false;
    this.ruleName = '';
    this.chapterRegex = '';
    this.exampleText = '';
    this.volumeRegex = '';
    this.clearRuleTest();
    this.showAddRule = true;
  }

  build() {
    Column() {
      Blank().height(32)
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
          .width(36).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        AppGlyph({ name: 'search', glyphSize: 19, tint: '#D8D9E0' }).padding({ left: 8, right: 8 })
          .onClick(() => {
            this.showSearch = !this.showSearch;
            if (!this.showSearch) { this.searchQuery = ''; }
          })
        AppGlyph({ name: 'more', glyphSize: 18, tint: '#D8D9E0' }).padding({ left: 6, right: 8 })
          .bindMenu(this.ImportMenu, { placement: Placement.BottomRight })
      }.width('100%').height(40).padding({ left: 18, right: 18 })
      Row() {
        Text(this.selectionMode ? `已选择 ${this.selectedRuleIds.length} 项` : 'TXT 目录规则')
          .fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
      }.width('100%').padding({ left: 18, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索 TXT 目录规则', text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_txt_toc_search')
            .onAppear(() => focusControl.requestFocus('my_txt_toc_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(24)
      }

      if (this.selectionMode) {
        Row() {
          Text(this.selectedRuleIds.length === 0 ? '取消' : `已选择 ${this.selectedRuleIds.length} 项`)
            .fontSize(14).fontColor('#D8D9E0').layoutWeight(1)
            .onClick(() => this.exitSelection())
          Text('全选').fontSize(14).fontColor('#AFC2FF').padding({ left: 10, right: 10 })
            .onClick(() => this.selectAllVisible())
          Text('反选').fontSize(14).fontColor('#AFC2FF').padding({ left: 0, right: 10 })
            .onClick(() => this.invertSelection())
        }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 4 })
        Row() {
          Text('启用').fontSize(14)
            .fontColor(this.selectedRuleIds.length > 0 ? '#AFC2FF' : '#5C5E68')
            .onClick(() => this.submitBatchEnabled(true))
          Text('停用').fontSize(14).margin({ left: 18 })
            .fontColor(this.selectedRuleIds.length > 0 ? '#AFC2FF' : '#5C5E68')
            .onClick(() => this.submitBatchEnabled(false))
          Text('导出').fontSize(14).margin({ left: 18 })
            .fontColor(this.selectedRuleIds.length > 0 ? '#AFC2FF' : '#5C5E68')
            .onClick(() => this.submitBatchExport())
          Blank().layoutWeight(1)
          Text('删除').fontSize(14)
            .fontColor(this.selectedRuleIds.length > 0 ? '#D99AA5' : '#5C5E68')
            .onClick(() => this.requestDelete(this.selectedNumericIds()))
        }.width('100%').padding({ left: 18, right: 18, top: 2, bottom: 10 })
      }
      RuleListBody({
        rules: this.rules, query: this.searchQuery, selectedIds: this.selectedRuleIds,
        selectionMode: this.selectionMode, sortMode: this.sortMode, emptyMessage: '暂无 TXT 目录规则',
        onOpen: (id: string) => this.openEditor(id),
        onToggle: (id: string) => this.toggleSelectedRule(id),
        onLongSelect: (id: string) => { this.selectionMode = true; this.selectedRuleIds = [id]; },
        onMove: (id: string, direction: number) => {
          const numericId = Number(id);
          if (Number.isInteger(numericId)) {
            this.onMoveRule(numericId, direction);
          }
        },
        onEnabledChange: (id: string, enabled: boolean) => {
          const numericId = Number(id);
          if (Number.isInteger(numericId)) {
            this.onToggleRule(numericId, enabled);
          }
        },
        onMoveToEdge: (id: string, toTop: boolean) => {
          const numericId = Number(id);
          if (Number.isInteger(numericId)) {
            this.onMoveRuleToEdge(numericId, toTop);
          }
        },
        onDelete: (id: string) => {
          const numericId = Number(id);
          if (Number.isInteger(numericId)) {
            this.requestDelete([numericId]);
          }
        }
      }).layoutWeight(1)
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'add', glyphSize: 24, tint: '#151720' })
        }.width(56).height(56).backgroundColor('#B9C8FF').borderRadius(28)
          .onClick(() => this.openCreator())
      }.width('100%').justifyContent(FlexAlign.End).padding({ right: 16, top: 8, bottom: 16 })
    }.width('100%').height('100%').backgroundColor('#111217')
      .bindSheet(this.showAddRule, this.ruleEditorSheet(), {
        height: 620,
        dragBar: true,
        showClose: false,
        backgroundColor: '#1C1D23',
        onDisappear: () => this.showAddRule = false
      })
      .bindSheet(this.confirmSheet === 'confirmDelete', this.DeleteConfirmSheet(), {
        // 删除确认只有几行文字，用内容自适应高度，避免半屏空白。
        height: SheetSize.FIT_CONTENT,
        dragBar: true,
        showClose: false,
        backgroundColor: '#17181E',
        onDisappear: () => this.confirmSheet = ''
      })
  }

  /**
   * 删除确认面板：批量删除与条目菜单的单条删除共用，确认前不动数据。
   * 与上游 RuleListScaffold.kt:75-86 的 AppAlertDialog 语义一致。
   */
  @Builder
  private DeleteConfirmSheet() {
    Column() {
      Text('删除规则').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
        .width('100%').padding({ left: 18, right: 18, top: 16, bottom: 10 })
      Text(this.pendingDeleteIds.length > 1
        ? `确定删除选中的 ${this.pendingDeleteIds.length} 条目录规则？删除后可通过导入恢复。`
        : '确定删除这条目录规则？删除后可通过导入恢复。')
        .fontSize(14).fontColor('#92949E')
        .width('100%').padding({ left: 18, right: 18, bottom: 20 })
      Row() {
        Text('取消').fontSize(15).fontColor('#92949E').layoutWeight(1).textAlign(TextAlign.Center)
          .padding({ top: 14, bottom: 14 })
          .onClick(() => this.cancelDelete())
        Text('删除').fontSize(15).fontColor('#D99AA5').layoutWeight(1).textAlign(TextAlign.Center)
          .padding({ top: 14, bottom: 14 })
          .onClick(() => this.confirmDelete())
      }.width('100%').padding({ left: 8, right: 8, bottom: 12 })
    }.width('100%').alignItems(HorizontalAlign.Start).backgroundColor('#17181E')
  }

  private isValidRegex(pattern: string): boolean {
    return TxtTocRuleRepository.isValidRegex(pattern, 'm');
  }
}

interface TxtRuleMatchRange {
  start: number;
  end: number;
}

interface TxtRuleTestLine {
  line: string;
  matched: boolean;
}

interface TxtRuleClipboardData {
  name?: string;
  chapterRule?: string;
  rule?: string;
  volumeRule?: string;
  example?: string | null;
}

@Component
export struct DictionaryRulesPage {
  onBack: () => void = () => {};
  onOpenEditor: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop rules: RuleListEntry[] = [];
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State selectionMode: boolean = false;
  @State selectedRuleIds: string[] = [];
  @State sortMode: boolean = false;
  @State showRuleEditor: boolean = false;
  @State ruleName: string = '';
  @State urlRule: string = '';
  @State showRule: string = '';
  @State showPasteAuthorization: boolean = false;

  @Builder
  private RuleEditorMenu() {
    Menu() {
      MenuItem({ content: '复制规则' }).onClick(() => this.copyDictionaryRule())
      MenuItem({ content: '粘贴规则' }).onClick(() => this.showPasteAuthorization = true)
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  private async copyDictionaryRule(): Promise<void> {
    try {
      const value = JSON.stringify({ name: this.ruleName, urlRule: this.urlRule,
        showRule: this.showRule, enabled: true, sortNumber: 0 });
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, value);
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制到剪贴板');
    } catch (_error) {
      this.onUnavailableAction('复制规则失败');
    }
  }

  private async pasteDictionaryRule(result: PasteButtonOnClickResult): Promise<void> {
    this.showPasteAuthorization = false;
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得读取剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onUnavailableAction('剪贴板为空');
        return;
      }
      const parsed: DictionaryRuleClipboardData = JSON.parse(data.getRecord(0).toPlainText());
      if (typeof parsed.name !== 'string' || typeof parsed.urlRule !== 'string' ||
        typeof parsed.showRule !== 'string') {
        this.onUnavailableAction('剪贴板规则格式无效');
        return;
      }
      this.ruleName = parsed.name;
      this.urlRule = parsed.urlRule;
      this.showRule = parsed.showRule;
      this.onUnavailableAction('规则已从剪贴板填入');
    } catch (_error) {
      this.onUnavailableAction('剪贴板规则格式无效');
    }
  }

  @Builder
  private DictionaryEditorField(label: string, value: string, field: string, multiline: boolean = false) {
    Column() {
      Text(label).fontSize(14).fontColor('#C3C5CD').margin({ left: 14, bottom: 3 })
      if (multiline) {
        TextArea({ placeholder: '', text: value }).fontSize(16).fontColor('#E3E4E8')
          .height(120).backgroundColor('#24252C').borderRadius(8)
          .padding({ left: 14, right: 14, top: 14 }).width('100%')
          .onChange((text: string) => this.updateDictionaryField(field, text))
      } else {
        TextInput({ placeholder: '', text: value }).fontSize(16).fontColor('#E3E4E8')
          .height(54).backgroundColor('#24252C').borderRadius(8)
          .padding({ left: 14, right: 14 }).width('100%')
          .onChange((text: string) => this.updateDictionaryField(field, text))
      }
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 10 })
  }

  private updateDictionaryField(field: string, value: string): void {
    if (field === 'name') { this.ruleName = value; }
    else if (field === 'urlRule') { this.urlRule = value; }
    else { this.showRule = value; }
  }

  private openRuleEditor(): void {
    this.ruleName = '';
    this.urlRule = '';
    this.showRule = '';
    this.showPasteAuthorization = false;
    this.showRuleEditor = true;
  }

  @Builder
  private DictionaryRuleSheet() {
    Column() {
      Row() {
        Text('字典规则').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#E3E4E8').layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileClose', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => this.showRuleEditor = false)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'more', glyphSize: 19, tint: '#D8D9E0' })
        }.width(40).height(40).bindMenu(this.RuleEditorMenu, { placement: Placement.BottomRight })
      }.width('100%').padding({ left: 18, right: 12, top: 12, bottom: 10 })
      Scroll() {
        Column() {
          this.DictionaryEditorField('名称', this.ruleName, 'name')
          this.DictionaryEditorField('Url规则 (urlRule)', this.urlRule, 'urlRule')
          this.DictionaryEditorField('显示规则 (showRule)', this.showRule, 'showRule', true)
        }.width('100%').alignItems(HorizontalAlign.Start)
          .padding({ left: 16, right: 16, top: 4, bottom: 120 })
      }.layoutWeight(1).scrollBar(BarState.Off)
      Row() {
        if (this.showPasteAuthorization) {
          PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
            .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) =>
              await this.pasteDictionaryRule(result))
        }
        Blank()
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileSave', glyphSize: 20, tint: '#B9C8FF' })
        }.width(50).height(50).backgroundColor('#454F70').borderRadius(14)
          .onClick(() => this.onUnavailableAction('字典规则存储尚未接入，规则未保存'))
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 14 })
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  @Builder
  private ImportMenu() {
    Menu() {
      MenuItem({ content: '排序' }).onClick(() => this.sortMode = !this.sortMode)
      MenuItem({ content: '选择模式' }).onClick(() => {
        this.selectionMode = !this.selectionMode;
        this.selectedRuleIds = [];
      })
      MenuItem({ content: '导入' })
        .onClick(() => this.onUnavailableAction('字典规则导入尚未接入，未导入任何数据'))
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  private toggleSelectedRule(id: string): void {
    this.selectedRuleIds = this.selectedRuleIds.includes(id) ?
      this.selectedRuleIds.filter((selectedId: string) => selectedId !== id) : [...this.selectedRuleIds, id];
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40)
          .onClick(() => {
            this.showSearch = !this.showSearch;
            if (!this.showSearch) { this.searchQuery = ''; }
          })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40)
          .bindMenu(this.ImportMenu, { placement: Placement.BottomRight })
      }.width('100%').height(40).padding({ left: 11, right: 12 })
        .margin({ top: -8 })

      Text(this.selectionMode ? `已选择 ${this.selectedRuleIds.length} 项` : '字典规则')
        .fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
        .width('100%').padding({ left: 12, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索字典规则', text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_dictionary_rule_search')
            .onAppear(() => focusControl.requestFocus('my_dictionary_rule_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(24)
      }

      if (this.selectionMode && this.selectedRuleIds.length > 0) {
        Row() {
          Text('全选').fontSize(14).fontColor('#AFC2FF').onClick(() =>
            this.selectedRuleIds = this.rules.map((rule: RuleListEntry) => rule.id))
          Text('删除').fontSize(14).fontColor('#F0A6A6').margin({ left: 18 })
            .onClick(() => this.onUnavailableAction('字典规则删除尚未迁移，未更改数据'))
        }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 8 })
      }
      RuleListBody({
        rules: this.rules, query: this.searchQuery, selectedIds: this.selectedRuleIds,
        selectionMode: this.selectionMode, sortMode: this.sortMode, emptyMessage: '暂无字典规则',
        onOpen: (_id: string) => this.onUnavailableAction('现有字典规则编辑尚未接入'),
        onToggle: (id: string) => this.toggleSelectedRule(id),
        onLongSelect: (id: string) => { this.selectionMode = true; this.selectedRuleIds = [id]; },
        onMove: (_id: string, _direction: number) => this.onUnavailableAction('字典规则排序尚未迁移')
      }).layoutWeight(1)
      Stack({ alignContent: Alignment.Center }) {
        AppGlyph({ name: 'add', glyphSize: 22, tint: '#B9C8FF' })
      }.width(50).height(50).backgroundColor('#454F70').borderRadius(14)
        .onClick(() => this.openRuleEditor())
        .margin({ right: 16, bottom: 16 }).alignSelf(ItemAlign.End)
    }.width('100%').height('100%').backgroundColor('#111217')
      .bindSheet(this.showRuleEditor, this.DictionaryRuleSheet(), {
        height: SheetSize.LARGE,
        dragBar: true,
        showClose: false,
        backgroundColor: '#17181E',
        onDisappear: () => { this.showRuleEditor = false; this.showPasteAuthorization = false; }
      })
  }
}

interface DictionaryRuleClipboardData {
  name?: string;
  urlRule?: string;
  showRule?: string;
  enabled?: boolean;
  sortNumber?: number;
}

@Component
export struct DictionaryRuleEditPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State name: string = '';
  @State urlRule: string = '';
  @State showRule: string = '';
  @State showPasteAuthorization: boolean = false;

  @Builder
  private RuleActionsMenu() {
    Menu() {
      MenuItem({ content: '复制规则' }).onClick(() => this.copyRule())
      MenuItem({ content: '粘贴规则' }).onClick(() => this.showPasteAuthorization = true)
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  private clipboardJson(): string {
    return JSON.stringify({
      name: this.name,
      urlRule: this.urlRule,
      showRule: this.showRule,
      enabled: true,
      sortNumber: 0
    });
  }

  private async copyRule(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.clipboardJson());
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制到剪贴板');
    } catch (_error) {
      this.onUnavailableAction('复制规则失败');
    }
  }

  private async pasteRule(result: PasteButtonOnClickResult): Promise<void> {
    this.showPasteAuthorization = false;
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得读取剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onUnavailableAction('剪贴板为空');
        return;
      }
      const parsed: DictionaryRuleClipboardData = JSON.parse(data.getRecord(0).toPlainText());
      if (typeof parsed.name !== 'string' || typeof parsed.urlRule !== 'string' ||
        typeof parsed.showRule !== 'string') {
        this.onUnavailableAction('剪贴板规则格式无效');
        return;
      }
      this.name = parsed.name;
      this.urlRule = parsed.urlRule;
      this.showRule = parsed.showRule;
      this.onUnavailableAction('规则已从剪贴板填入');
    } catch (_error) {
      this.onUnavailableAction('剪贴板规则格式无效');
    }
  }

  @Builder
  private RuleField(label: string, value: string, field: string, multiline: boolean = false) {
    Column() {
      Text(label).fontSize(14).fontColor('#C3C5CD').margin({ left: 14, bottom: 3 })
      if (multiline) {
        TextArea({ placeholder: '', text: value })
          .fontSize(16).fontColor('#E3E4E8').placeholderColor('#92949E')
          .height(120).backgroundColor('#24252C').borderRadius(8).padding({ left: 14, right: 14, top: 14 })
          .width('100%').onChange((text: string) => this.updateField(field, text))
      } else {
        TextInput({ placeholder: '', text: value })
          .fontSize(16).fontColor('#E3E4E8').placeholderColor('#92949E')
          .height(58).backgroundColor('#24252C').borderRadius(8).padding({ left: 14, right: 14 })
          .width('100%').onChange((text: string) => this.updateField(field, text))
      }
      Row().width('100%').height(1).backgroundColor('#898B94')
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 12 })
  }

  private updateField(field: string, value: string): void {
    if (field === 'name') { this.name = value; }
    else if (field === 'urlRule') { this.urlRule = value; }
    else { this.showRule = value; }
  }

  private saveRule(): void {
    if (this.name.trim().length === 0) {
      this.onUnavailableAction('名称不能为空');
      return;
    }
    this.onUnavailableAction('字典规则存储尚未接入，规则未保存');
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'profileClose', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).bindMenu(this.RuleActionsMenu, { placement: Placement.BottomRight })
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: -8 })
      Text('字典规则').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
        .width('100%').padding({ left: 14, right: 0, top: 12 })
      Scroll() {
        Column() {
          this.RuleField('名称', this.name, 'name')
          this.RuleField('Url规则 (urlRule)', this.urlRule, 'urlRule')
          this.RuleField('显示规则 (showRule)', this.showRule, 'showRule', true)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 0, bottom: 140 })
          .layoutWeight(1)
      }.layoutWeight(1).scrollBar(BarState.Off)
      Row() {
        if (this.showPasteAuthorization) {
          PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
            .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) => await this.pasteRule(result))
        }
        Blank()
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileSave', glyphSize: 20, tint: '#B9C8FF' })
        }.width(50).height(50).backgroundColor('#454F70').borderRadius(14).onClick(() => this.saveRule())
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 16 })
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
export struct HighlightTagRulesPage {
  onBack: () => void = () => {};
  onOpenEditor: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop rules: RuleListEntry[] = [];
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State selectionMode: boolean = false;
  @State selectedRuleIds: string[] = [];
  @State sortMode: boolean = false;
  @State showRuleEditor: boolean = false;
  @State draftTitle: string = '';
  @State draftPattern: string = '';
  @State draftEnabled: boolean = true;
  @State showPasteAuthorization: boolean = false;

  @Builder
  private ImportMenu() {
    Menu() {
      MenuItem({ content: '排序' }).onClick(() => this.sortMode = !this.sortMode)
      MenuItem({ content: '选择模式' }).onClick(() => {
        this.selectionMode = !this.selectionMode;
        this.selectedRuleIds = [];
      })
      MenuItem({ content: '导入' })
        .onClick(() => this.onUnavailableAction('标签规则导入尚未接入，未导入任何数据'))
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  private toggleSelectedRule(id: string): void {
    this.selectedRuleIds = this.selectedRuleIds.includes(id) ?
      this.selectedRuleIds.filter((selectedId: string) => selectedId !== id) : [...this.selectedRuleIds, id];
  }

  @Builder
  private TagEditorMenu() {
    Menu() {
      MenuItem({ content: '复制规则' }).onClick(() => this.copyTagRule())
      MenuItem({ content: '粘贴规则' }).onClick(() => this.showPasteAuthorization = true)
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  private async copyTagRule(): Promise<void> {
    try {
      const value = JSON.stringify({ id: Date.now(), title: this.draftTitle,
        pattern: this.draftPattern, enabled: this.draftEnabled, order: 0 });
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, value);
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制到剪贴板');
    } catch (_error) {
      this.onUnavailableAction('复制规则失败');
    }
  }

  private async pasteTagRule(result: PasteButtonOnClickResult): Promise<void> {
    this.showPasteAuthorization = false;
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得读取剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onUnavailableAction('剪贴板没有内容');
        return;
      }
      const parsed: HighlightTagRuleClipboardData = JSON.parse(data.getRecord(0).toPlainText());
      if (typeof parsed.title !== 'string' || typeof parsed.pattern !== 'string' ||
        (parsed.enabled !== undefined && typeof parsed.enabled !== 'boolean')) {
        this.onUnavailableAction('剪贴板规则格式无效');
        return;
      }
      this.draftTitle = parsed.title;
      this.draftPattern = parsed.pattern;
      this.draftEnabled = parsed.enabled !== false;
      this.onUnavailableAction('规则已从剪贴板填入');
    } catch (_error) {
      this.onUnavailableAction('剪贴板规则格式无效');
    }
  }

  private openTagRuleEditor(): void {
    this.draftTitle = '';
    this.draftPattern = '';
    this.draftEnabled = true;
    this.showPasteAuthorization = false;
    this.showRuleEditor = true;
  }

  @Builder
  private TagRuleEditorSheet() {
    Column() {
      Row() {
        Text('添加规则').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#E3E4E8').layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileClose', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => this.showRuleEditor = false)
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'more', glyphSize: 19, tint: '#D8D9E0' })
        }.width(40).height(40).bindMenu(this.TagEditorMenu, { placement: Placement.BottomRight })
      }.width('100%').padding({ left: 18, right: 12, top: 12, bottom: 10 })
      Scroll() {
        Column() {
          Text('标题（可选）').fontSize(14).fontColor('#C3C5CD').margin({ left: 14, bottom: 3 })
          TextInput({ placeholder: '', text: this.draftTitle }).fontSize(16).fontColor('#E3E4E8')
            .height(54).backgroundColor('#24252C').borderRadius(8)
            .padding({ left: 14, right: 14 }).width('100%')
            .onChange((value: string) => this.draftTitle = value)
          Text('匹配规则').fontSize(14).fontColor('#C3C5CD').margin({ left: 14, bottom: 3, top: 8 })
          TextArea({ placeholder: '', text: this.draftPattern }).fontSize(16).fontColor('#E3E4E8')
            .height(120).backgroundColor('#24252C').borderRadius(8)
            .padding({ left: 14, right: 14, top: 14 }).width('100%')
            .onChange((value: string) => this.draftPattern = value)
          Row() {
            Text('已启用').fontSize(16).fontColor('#E3E4E8').layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.draftEnabled })
              .onChange((value: boolean) => this.draftEnabled = value)
          }.width('100%').padding({ top: 12, bottom: 12 })
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 120 })
      }.layoutWeight(1).scrollBar(BarState.Off)
      Row() {
        if (this.showPasteAuthorization) {
          PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
            .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) =>
              await this.pasteTagRule(result))
        }
        Blank()
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileSave', glyphSize: 20, tint: '#B9C8FF' })
        }.width(50).height(50).backgroundColor('#454F70').borderRadius(14)
          .onClick(() => this.onUnavailableAction('标签规则存储尚未接入，规则未保存'))
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 14 })
    }.width('100%').height('100%').backgroundColor('#17181E')
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40)
          .onClick(() => {
            this.showSearch = !this.showSearch;
            if (!this.showSearch) { this.searchQuery = ''; }
          })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).bindMenu(this.ImportMenu, { placement: Placement.BottomRight })
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: -8 })

      Text(this.selectionMode ? `已选择 ${this.selectedRuleIds.length} 项` : '标签规则')
        .fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
        .width('100%').padding({ left: 12, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索标签规则', text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_highlight_tag_search')
            .onAppear(() => focusControl.requestFocus('my_highlight_tag_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(24)
      }

      if (this.selectionMode && this.selectedRuleIds.length > 0) {
        Row() {
          Text('全选').fontSize(14).fontColor('#AFC2FF').onClick(() =>
            this.selectedRuleIds = this.rules.map((rule: RuleListEntry) => rule.id))
          Text('删除').fontSize(14).fontColor('#F0A6A6').margin({ left: 18 })
            .onClick(() => this.onUnavailableAction('标签规则删除尚未迁移，未更改数据'))
        }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 8 })
      }
      RuleListBody({
        rules: this.rules, query: this.searchQuery, selectedIds: this.selectedRuleIds,
        selectionMode: this.selectionMode, sortMode: this.sortMode, emptyMessage: '暂无标签规则',
        onOpen: (_id: string) => this.onUnavailableAction('现有标签规则编辑尚未接入'),
        onToggle: (id: string) => this.toggleSelectedRule(id),
        onLongSelect: (id: string) => { this.selectionMode = true; this.selectedRuleIds = [id]; },
        onMove: (_id: string, _direction: number) => this.onUnavailableAction('标签规则排序尚未迁移')
      }).layoutWeight(1)
      Stack({ alignContent: Alignment.Center }) {
        AppGlyph({ name: 'add', glyphSize: 22, tint: '#B9C8FF' })
      }.width(50).height(50).backgroundColor('#454F70').borderRadius(14)
        .onClick(() => this.openTagRuleEditor())
        .margin({ right: 16, bottom: 16 }).alignSelf(ItemAlign.End)
    }.width('100%').height('100%').backgroundColor('#111217')
      .bindSheet(this.showRuleEditor, this.TagRuleEditorSheet(), {
        height: SheetSize.LARGE,
        dragBar: true,
        showClose: false,
        backgroundColor: '#17181E',
        onDisappear: () => { this.showRuleEditor = false; this.showPasteAuthorization = false; }
      })
  }
}

interface HighlightTagRuleClipboardData {
  id?: number;
  title?: string;
  pattern?: string;
  enabled?: boolean;
  order?: number;
}

@Component
export struct HighlightTagRuleEditPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State title: string = '';
  @State pattern: string = '';
  @State ruleEnabled: boolean = true;
  @State showPasteAuthorization: boolean = false;

  @Builder
  private RuleActionsMenu() {
    Menu() {
      MenuItem({ content: '复制规则' }).onClick(() => this.copyRule())
      MenuItem({ content: '粘贴规则' }).onClick(() => this.showPasteAuthorization = true)
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  private clipboardJson(): string {
    return JSON.stringify({ id: Date.now(), title: this.title, pattern: this.pattern, enabled: this.ruleEnabled, order: 0 });
  }

  private async copyRule(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.clipboardJson());
      await pasteboard.getSystemPasteboard().setData(data);
      this.onUnavailableAction('规则已复制到剪贴板');
    } catch (_error) {
      this.onUnavailableAction('复制规则失败');
    }
  }

  private async pasteRule(result: PasteButtonOnClickResult): Promise<void> {
    this.showPasteAuthorization = false;
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.onUnavailableAction('未获得读取剪贴板授权');
      return;
    }
    try {
      const data = await pasteboard.getSystemPasteboard().getData();
      if (data.getRecordCount() === 0) {
        this.onUnavailableAction('剪贴板没有内容');
        return;
      }
      const parsed: HighlightTagRuleClipboardData = JSON.parse(data.getRecord(0).toPlainText());
      if (typeof parsed.title !== 'string' || typeof parsed.pattern !== 'string' ||
        (parsed.enabled !== undefined && typeof parsed.enabled !== 'boolean')) {
        this.onUnavailableAction('剪贴板规则格式无效');
        return;
      }
      this.title = parsed.title;
      this.pattern = parsed.pattern;
      this.ruleEnabled = parsed.enabled !== false;
      this.onUnavailableAction('规则已从剪贴板填入');
    } catch (_error) {
      this.onUnavailableAction('剪贴板规则格式无效');
    }
  }

  private saveRule(): void {
    this.onUnavailableAction('标签规则存储尚未接入，规则未保存');
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'profileClose', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).bindMenu(this.RuleActionsMenu, { placement: Placement.BottomRight })
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: -8 })
      Text('添加规则').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
        .width('100%').padding({ left: 14, right: 0, top: 12 })
      Scroll() {
        Column() {
          Text('标题（可选）').fontSize(14).fontColor('#C3C5CD').margin({ left: 14, bottom: 3 })
          TextInput({ placeholder: '', text: this.title })
            .fontSize(16).fontColor('#E3E4E8').placeholderColor('#92949E')
            .height(58).backgroundColor('#24252C').borderRadius(8).padding({ left: 14, right: 14 }).width('100%')
            .onChange((value: string) => this.title = value)
          Row().width('100%').height(1).backgroundColor('#898B94').margin({ bottom: 12 })
          Text('匹配规则').fontSize(14).fontColor('#C3C5CD').margin({ left: 14, bottom: 3 })
          TextArea({ placeholder: '', text: this.pattern })
            .fontSize(16).fontColor('#E3E4E8').placeholderColor('#92949E')
            .height(120).backgroundColor('#24252C').borderRadius(8).padding({ left: 14, right: 14, top: 14 }).width('100%')
            .onChange((value: string) => this.pattern = value)
          Row().width('100%').height(1).backgroundColor('#898B94').margin({ bottom: 12 })
          Row() {
            Text('已启用').fontSize(16).fontColor('#E3E4E8').layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.ruleEnabled }).onChange((value: boolean) => this.ruleEnabled = value)
          }.width('100%').padding({ top: 8, bottom: 8 })
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 140 })
          .layoutWeight(1)
      }.layoutWeight(1).scrollBar(BarState.Off)
      Row() {
        if (this.showPasteAuthorization) {
          PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
            .onClick(async (_event: ClickEvent, result: PasteButtonOnClickResult) => await this.pasteRule(result))
        }
        Blank()
        Stack({ alignContent: Alignment.Center }) {
          AppGlyph({ name: 'profileSave', glyphSize: 20, tint: '#B9C8FF' })
        }.width(50).height(50).backgroundColor('#454F70').borderRadius(14).onClick(() => this.saveRule())
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 16 })
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

export interface BookmarkBookSummary {
  key: string;
  title: string;
  author: string;
  bookmarkCount: number;
  noteCount: number;
}

export interface BookmarkEntrySummary {
  id: string;
  bookKey: string;
  chapterName: string;
  excerpt: string;
  note: string;
  kind: 'bookmark' | 'note';
}

const BOOKMARK_EMPTY_FACES: string[] = [
  '(；′⌒`)', '(つ﹏⊂)', '(•̀ᴗ•́)و', '(๑•́ ₃ •̀๑)', '(눈‸눈)', '(ಥ﹏ಥ)', '(｡•́︿•̀｡)'
];

@Component
export struct AllBookmarksPage {
  onBack: () => void = () => {};
  onOpenBookmark: (bookmarkId: string) => void = (_bookmarkId: string) => {};
  /** 打开书签编辑面板；上游 AllBookmarkScreen 点击书签条目即进入编辑。 */
  onEditBookmark: (bookmarkId: string) => void = (_bookmarkId: string) => {};
  /** 打开一条笔记（kind === 'note' 的条目），跳到划线所在位置。 */
  onOpenMarking: (markingId: string) => void = (_markingId: string) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop books: BookmarkBookSummary[] = [];
  @Prop entries: BookmarkEntrySummary[] = [];
  /** 导出当前选中书的书签；isMarkdown 为 true 时导出 Markdown。 */
  onExportBookmarks: (bookKey: string, isMarkdown: boolean) => void =
    (_bookKey: string, _isMarkdown: boolean) => {};
  @State selectedBookKey: string = '';
  @State selectedBookTitle: string = '';
  @State selectedBookmarkCount: number = 0;
  @State selectedNoteCount: number = 0;
  @State selectedTab: number = 0;
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State emptyFaceIndex: number = Math.floor(Math.random() * BOOKMARK_EMPTY_FACES.length);

  private getVisibleBooks(): BookmarkBookSummary[] {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    return this.books.filter((book: BookmarkBookSummary) => {
      if (query.length === 0) { return true; }
      const basicMatch = book.title.toLocaleLowerCase().includes(query) || book.author.toLocaleLowerCase().includes(query);
      const noteMatch = this.entries.some((entry: BookmarkEntrySummary) =>
        entry.bookKey === book.key && (entry.excerpt.toLocaleLowerCase().includes(query) || entry.note.toLocaleLowerCase().includes(query)));
      return basicMatch || noteMatch;
    });
  }

  private getVisibleEntries(bookKey: string, tabIndex: number): BookmarkEntrySummary[] {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    return this.entries.filter((entry: BookmarkEntrySummary) => {
      if (entry.bookKey !== bookKey || (tabIndex === 0 && entry.kind !== 'bookmark') ||
        (tabIndex === 1 && entry.kind !== 'note')) { return false; }
      return query.length === 0 || entry.chapterName.toLocaleLowerCase().includes(query) ||
        entry.excerpt.toLocaleLowerCase().includes(query) || entry.note.toLocaleLowerCase().includes(query);
    });
  }

  private handleBack(): void {
    if (this.selectedBookKey.length > 0) {
      this.selectedBookKey = '';
      this.selectedBookTitle = '';
      this.selectedBookmarkCount = 0;
      this.selectedNoteCount = 0;
      this.searchQuery = '';
      this.selectedTab = 0;
    } else {
      this.onBack();
    }
  }

  private randomizeEmptyFace(): void {
    this.emptyFaceIndex = Math.floor(Math.random() * BOOKMARK_EMPTY_FACES.length);
  }

  /** 书签导出菜单，对应上游 AllBookmarkScreen 的两项导出。 */
  @Builder
  private BookmarkExportMenu() {
    Menu() {
      MenuItem({ content: '导出为 JSON' }).height(44)
        .onClick(() => this.onExportBookmarks(this.selectedBookKey, false))
      MenuItem({ content: '导出为 Markdown' }).height(44)
        .onClick(() => this.onExportBookmarks(this.selectedBookKey, true))
    }
  }

  @Builder
  private BookmarkEmptyMessage(message: string) {
    Column() {
      Text(BOOKMARK_EMPTY_FACES[this.emptyFaceIndex]).fontSize(32).fontColor('#E3E4E8')
        .textAlign(TextAlign.Center).onClick(() => this.randomizeEmptyFace())
      Text(message).fontSize(14).fontColor('#D8D9E0').textAlign(TextAlign.Center).maxLines(2)
        .margin({ top: 2 })
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .padding({ left: 16, right: 16 })
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.handleBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => {
          this.showSearch = !this.showSearch;
          if (!this.showSearch) { this.searchQuery = ''; }
        })
        if (this.selectedBookKey.length > 0) {
          Stack({ alignContent: Alignment.Center }) {
            Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
            AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
          }.width(40).height(40).bindMenu(this.BookmarkExportMenu, { placement: Placement.BottomRight })
        }
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: -8 })

      Text(this.selectedBookKey.length === 0 ? '所有书签' : this.selectedBookTitle)
        .fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%').padding({ left: 12, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: this.selectedBookKey.length === 0
            ? '搜索笔记内容'
            : `搜索当前${this.selectedTab === 0 ? '书签' : '笔记'}`, text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_bookmark_search')
            .onAppear(() => focusControl.requestFocus('my_bookmark_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(24)
      }

      if (this.selectedBookKey.length > 0) {
        Row() {
          ModuleTab({ label: `书签 ${this.selectedBookmarkCount}`, selected: this.selectedTab === 0, onSelect: () => { this.selectedTab = 0; this.searchQuery = ''; } })
          ModuleTab({ label: `笔记 ${this.selectedNoteCount}`, selected: this.selectedTab === 1, onSelect: () => { this.selectedTab = 1; this.searchQuery = ''; } })
        }.margin({ left: 16, right: 16, top: 8, bottom: 12 })
        Swiper() {
          ForEach([0, 1], (tabIndex: number) => {
            Column() {
              if (this.getVisibleEntries(this.selectedBookKey, tabIndex).length === 0) {
                this.BookmarkEmptyMessage(this.searchQuery.length > 0 ? '没有找到相关笔记' :
                  (tabIndex === 0 ? '暂无书签' : '暂无笔记'))
              } else {
                Scroll() {
                  Column() {
                    ForEach(this.getVisibleEntries(this.selectedBookKey, tabIndex), (entry: BookmarkEntrySummary) => {
                      BookmarkEntryCard({
                        entry: entry,
                        onSelect: () => {
                          // 上游：书签条目点击=编辑，长按=跳转正文；笔记条目点击=跳转划线
                          if (entry.kind === 'note') { this.onOpenMarking(entry.id); } else { this.onEditBookmark(entry.id); }
                        },
                        onJump: () => {
                          if (entry.kind === 'note') { this.onOpenMarking(entry.id); } else { this.onOpenBookmark(entry.id); }
                        }
                      })
                    }, (entry: BookmarkEntrySummary) => entry.id)
                  }.padding({ left: 16, right: 16, top: 4, bottom: 20 })
                }.layoutWeight(1).scrollBar(BarState.Off)
              }
            }.width('100%').height('100%')
          }, (tabIndex: number) => tabIndex.toString())
        }.layoutWeight(1).width('100%').index(this.selectedTab).loop(false).indicator(false)
          .onChange((index: number) => { this.selectedTab = index; this.searchQuery = ''; })
      } else if (this.getVisibleBooks().length === 0) {
        this.BookmarkEmptyMessage(this.searchQuery.length > 0 ? '没有找到相关笔记' : '暂无书签')
      } else {
        Scroll() {
          Column() {
            ForEach(this.getVisibleBooks(), (book: BookmarkBookSummary) => {
              BookmarkOverviewCard({
                book: book,
                onSelect: () => {
                  this.selectedBookKey = book.key;
                  this.selectedBookTitle = book.title;
                  this.selectedBookmarkCount = book.bookmarkCount;
                  this.selectedNoteCount = book.noteCount;
                  this.selectedTab = 0;
                  this.searchQuery = '';
                }
              })
            }, (book: BookmarkBookSummary) => book.key)
          }.padding({ left: 16, right: 16, top: 8, bottom: 20 })
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct BookmarkOverviewCard {
  @Prop book: BookmarkBookSummary = { key: '', title: '', author: '', bookmarkCount: 0, noteCount: 0 };
  onSelect: () => void = () => {};
  build() {
    Row() {
      AppGlyph({ name: 'bookmark', glyphSize: 22, tint: '#AFC2FF' }).width(38)
      Column() {
        Text(this.book.title).fontSize(17).fontColor('#D8D9E0').maxLines(2)
        if (this.book.author.length > 0) { Text(this.book.author).fontSize(14).fontColor('#92949E').margin({ top: 3 }) }
        Text(`${this.book.bookmarkCount} 条书签 · ${this.book.noteCount} 条笔记`).fontSize(12).fontColor('#92949E').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(18).height(18).fillColor('#92949E')
    }.width('100%').padding(14).backgroundColor('#1A1B21').borderRadius(14).margin({ bottom: 8 })
      .onClick(() => this.onSelect())
  }
}

@Component
struct BookmarkEntryCard {
  @Prop entry: BookmarkEntrySummary = { id: '', bookKey: '', chapterName: '', excerpt: '', note: '', kind: 'bookmark' };
  onSelect: () => void = () => {};
  /** 长按跳转到正文位置，保留原有的跳转能力。 */
  onJump: () => void = () => {};
  build() {
    Column() {
      Text(this.entry.chapterName).fontSize(14).fontColor('#AFC2FF').maxLines(1)
      if (this.entry.excerpt.length > 0) { Text(this.entry.excerpt).fontSize(14).fontColor('#D8D9E0').maxLines(3).margin({ top: 6 }) }
      if (this.entry.note.length > 0) { Text(this.entry.note).fontSize(14).fontColor('#92949E').maxLines(3).margin({ top: 4 }) }
    }.width('100%').padding(16).backgroundColor('#1A1B21').borderRadius(14).margin({ bottom: 8 })
      .onClick(() => this.onSelect())
      .gesture(LongPressGesture().onAction(() => this.onJump()))
  }
}

@Component
export struct ReadRecordsPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  /** 扫描/修复/清空改变了数据后通知 Index 重读会话，避免页面仍显示旧列表。 */
  onRecordsChanged: () => void = () => {};
  @Prop records: ReadTimeRecord[] = [];
  @Prop details: ReadRecordDetail[] = [];
  @Prop summaries: ReadRecordSummary[] = [];
  @State recordEnabled: boolean = true;
  @State displayMode: number = 0;
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State emptyFaceIndex: number = Math.floor(Math.random() * BOOKMARK_EMPTY_FACES.length);
  @State showActionsSheet: boolean = false;
  @State showCalendarSheet: boolean = false;
  @State showClearConfirm: boolean = false;
  @State selectedCalendarDay: number = 0;

  aboutToAppear(): void {
    this.recordEnabled = ReadRecordRepository.isEnabled();
  }

  private getModeLabel(): string {
    if (this.displayMode === 1) { return '时间线视图'; }
    if (this.displayMode === 2) { return '最后阅读视图'; }
    return '汇总视图';
  }

  private cycleDisplayMode(): void {
    this.displayMode = (this.displayMode + 1) % 3;
  }

  private getVisibleRecords(): ReadTimeRecord[] {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    if (query.length === 0) { return this.records; }
    return this.records.filter((record: ReadTimeRecord) =>
      record.bookName.toLocaleLowerCase().includes(query) || record.bookAuthor.toLocaleLowerCase().includes(query));
  }

  private getDateKey(timestamp: number): string {
    return this.formatRecordDate(timestamp).substring(0, 10);
  }

  /** 汇总视图按跨午夜拆分后的自然日明细分组；搜索仍匹配书名与作者。 */
  private getSummaryDateKeys(): string[] {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    const keys: string[] = [];
    for (const detail of this.details) {
      if (query.length > 0 && !detail.bookName.toLocaleLowerCase().includes(query) &&
        !detail.bookAuthor.toLocaleLowerCase().includes(query)) { continue; }
      if (!keys.includes(detail.date)) { keys.push(detail.date); }
    }
    return keys.sort((left: string, right: string) => right.localeCompare(left));
  }

  private getSummaryDetailsForDate(dateKey: string): ReadRecordDetail[] {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    return this.details.filter((detail: ReadRecordDetail) => detail.date === dateKey &&
      (query.length === 0 || detail.bookName.toLocaleLowerCase().includes(query) ||
        detail.bookAuthor.toLocaleLowerCase().includes(query)));
  }

  private getDistinctSummaryBooksForDate(dateKey: string): ReadRecordDetail[] {
    const result: ReadRecordDetail[] = [];
    for (const detail of this.getSummaryDetailsForDate(dateKey)) {
      if (!result.some((item: ReadRecordDetail) =>
        item.bookName === detail.bookName && item.bookAuthor === detail.bookAuthor)) {
        result.push(detail);
      }
    }
    return result;
  }

  private getSummaryDurationForDate(dateKey: string): number {
    return this.getSummaryDetailsForDate(dateKey)
      .reduce((total: number, detail: ReadRecordDetail) => total + detail.readTime, 0);
  }

  private getSummaryBookDurationForDate(dateKey: string, bookName: string, bookAuthor: string): number {
    return this.getSummaryDetailsForDate(dateKey)
      .filter((detail: ReadRecordDetail) => detail.bookName === bookName && detail.bookAuthor === bookAuthor)
      .reduce((total: number, detail: ReadRecordDetail) => total + detail.readTime, 0);
  }

  /** 时间线仍按会话开始时间分日，单条跨午夜会话保持完整时长。 */
  private getDateKeys(): string[] {
    const keys: string[] = [];
    for (const record of this.getVisibleRecords()) {
      const key = this.getDateKey(record.startTime);
      if (!keys.includes(key)) { keys.push(key); }
    }
    return keys.sort((left: string, right: string) => right.localeCompare(left));
  }

  private getRecordsForDate(dateKey: string): ReadTimeRecord[] {
    return this.getVisibleRecords().filter((record: ReadTimeRecord) => this.getDateKey(record.startTime) === dateKey);
  }

  private getDistinctBooks(records: ReadTimeRecord[]): ReadTimeRecord[] {
    const result: ReadTimeRecord[] = [];
    for (const record of records) {
      if (!result.some((item: ReadTimeRecord) => item.bookId === record.bookId)) { result.push(record); }
    }
    return result;
  }

  private getLatestRecords(): ReadTimeRecord[] {
    const ordered = [...this.getVisibleRecords()].sort((left: ReadTimeRecord, right: ReadTimeRecord) =>
      right.endTime - left.endTime);
    return this.getDistinctBooks(ordered);
  }

  private getTotalDuration(records: ReadTimeRecord[]): number {
    return records.reduce((total: number, record: ReadTimeRecord) => total + record.durationMs, 0);
  }

  private getBookDuration(bookId: string, records: ReadTimeRecord[]): number {
    return this.getTotalDuration(records.filter((record: ReadTimeRecord) => record.bookId === bookId));
  }

  private getCalendarCells(): number[] {
    const today = new Date();
    const firstWeekday = new Date(today.getFullYear(), today.getMonth(), 1).getDay();
    const dayCount = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
    const days: number[] = [];
    for (let index = 0; index < 42; index++) {
      const day = index - firstWeekday + 1;
      days.push(day > 0 && day <= dayCount ? day : 0);
    }
    return days;
  }

  private getCalendarDayDuration(day: number): number {
    if (day <= 0) { return 0; }
    const today = new Date();
    const year = today.getFullYear();
    const month = (today.getMonth() + 1).toString().padStart(2, '0');
    const date = day.toString().padStart(2, '0');
    const dateKey = `${year}-${month}-${date}`;
    const query = this.searchQuery.trim().toLocaleLowerCase();
    return this.details
      .filter((detail: ReadRecordDetail) => detail.date === dateKey &&
        (query.length === 0 || detail.bookName.toLocaleLowerCase().includes(query) ||
          detail.bookAuthor.toLocaleLowerCase().includes(query)))
      .reduce((total: number, detail: ReadRecordDetail) => total + detail.readTime, 0);
  }

  private getSummaryBookCount(): number {
    return this.summaries.length;
  }

  private getSummaryDuration(): number {
    return this.summaries.reduce((total: number, summary: ReadRecordSummary) => total + summary.readTime, 0);
  }

  private formatRecordDuration(durationMs: number): string {
    const minutes = Math.floor(durationMs / 60000);
    const hours = Math.floor(minutes / 60);
    if (hours > 0) { return `${hours} 小时 ${minutes % 60} 分钟`; }
    if (minutes > 0) { return `${minutes} 分钟`; }
    return `${Math.max(1, Math.floor(durationMs / 1000))} 秒`;
  }

  private formatRecordDate(timestamp: number): string {
    const date = new Date(timestamp);
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hour = date.getHours().toString().padStart(2, '0');
    const minute = date.getMinutes().toString().padStart(2, '0');
    return `${date.getFullYear()}-${month}-${day} ${hour}:${minute}`;
  }

  /** 取宿主 Ability 上下文，拿不到就提示并返回 undefined。 */
  private hostContext(): Context | undefined {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.onUnavailableAction('无法获取应用上下文，操作未执行');
    }
    return context;
  }

  /** 启用/停用阅读记录总开关，对应上游 localPreferences 的 readRecordEnabled。 */
  private async toggleRecordEnabled(): Promise<void> {
    const context = this.hostContext();
    if (context === undefined) { return; }
    const enabled = !ReadRecordRepository.isEnabled();
    await ReadRecordRepository.setEnabled(context, enabled);
    this.recordEnabled = enabled;
    this.onUnavailableAction(enabled ? '已启用阅读记录，之后会继续记账' : '已停用阅读记录，期间不再记账');
  }

  /** 扫描重复/异常记录，只读不改数据。 */
  private async runScanIssues(): Promise<void> {
    const context = this.hostContext();
    if (context === undefined) { return; }
    const report = await ReadRecordRepository.scanIssues(context);
    const parts: string[] = [];
    if (report.duplicateSessionCount > 0) { parts.push(`重复时段 ${report.duplicateSessionCount} 条`); }
    if (report.normalizedRecordCount > 0) { parts.push(`写法不规范 ${report.normalizedRecordCount} 条`); }
    if (report.mergedCount > 0) { parts.push(`明细/汇总不一致 ${report.mergedCount} 组`); }
    this.onUnavailableAction(parts.length > 0 ? `发现：${parts.join('，')}` : '未发现问题');
  }

  /** 修复重复记录与身份写法，并按会话重算明细与汇总。 */
  private async runRepair(): Promise<void> {
    const context = this.hostContext();
    if (context === undefined) { return; }
    const report = await ReadRecordRepository.repair(context);
    const total = report.duplicateSessionCount + report.normalizedRecordCount + report.mergedCount;
    this.onUnavailableAction(total > 0
      ? `修复完成：重复 ${report.duplicateSessionCount} 条、写法 ${report.normalizedRecordCount} 条、派生数据 ${report.mergedCount} 组`
      : '没有需要修复的问题');
    if (total > 0) { this.onRecordsChanged(); }
  }

  /** 清空全部本地阅读记录（含当前未落库的会话），有确认面板。 */
  private requestClearAll(): void {
    if (this.records.length === 0 && !ReadRecordRepository.isEnabled()) {
      this.onUnavailableAction('当前没有可清空的阅读记录');
      return;
    }
    if (this.records.length === 0) {
      this.onUnavailableAction('当前没有可清空的阅读记录');
      return;
    }
    this.showClearConfirm = true;
  }

  private async confirmClearAll(): Promise<void> {
    this.showClearConfirm = false;
    const context = this.hostContext();
    if (context === undefined) { return; }
    await ReadRecordRepository.clearAll(context);
    this.onRecordsChanged();
    this.onUnavailableAction('阅读记录已清空');
  }

  @Builder
  private ReadRecordEmptyMessage(message: string) {
    Column() {
      Text(BOOKMARK_EMPTY_FACES[this.emptyFaceIndex]).fontSize(32).fontColor('#E3E4E8')
        .textAlign(TextAlign.Center).onClick(() => {
          this.emptyFaceIndex = Math.floor(Math.random() * BOOKMARK_EMPTY_FACES.length);
        })
      Text(message).fontSize(14).fontColor('#D8D9E0').textAlign(TextAlign.Center).maxLines(2).margin({ top: 2 })
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .padding({ left: 16, right: 16 })
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.onBack())
        Column() {
          Text('阅读记录').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
          Text(this.getModeLabel()).fontSize(PROFILE_PAGE_SUBTITLE_SIZE).fontColor('#92949E').margin({ top: 3 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 2 })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: this.displayMode === 0 ? 'profileTimeline' : (this.displayMode === 1 ? 'clock' : 'list'), glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => this.cycleDisplayMode())
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => {
          this.showSearch = !this.showSearch;
          if (!this.showSearch) { this.searchQuery = ''; }
        })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'more', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => this.showActionsSheet = true)
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: -8 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '搜索', text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_read_record_search')
            .onAppear(() => focusControl.requestFocus('my_read_record_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(24)
          .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
      }

      if (this.getVisibleRecords().length === 0) {
        this.ReadRecordEmptyMessage(this.records.length === 0 ? '没有阅读记录' : '没有匹配的阅读记录')
      } else {
        Scroll() {
          Column() {
            Column() {
              Text('阅读总成就').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
              Row() {
                Text(`${this.getSummaryBookCount()} 本书`).fontSize(20).fontColor('#AFC2FF')
                Blank()
                Text(this.formatRecordDuration(this.getSummaryDuration()))
                  .fontSize(16).fontColor('#D8D9E0')
              }.width('100%').margin({ top: 12 })
            }.width('calc(100% - 32vp)').padding(16).backgroundColor('#1B1C22').borderRadius(16)
              .margin({ left: 16, right: 16, bottom: 10 }).onClick(() => this.showCalendarSheet = true)
            if (this.displayMode === 0) {
              ForEach(this.getSummaryDateKeys(), (dateKey: string) => {
                Column() {
                  Row() {
                    Text(dateKey).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#D8D9E0')
                    Blank()
                    Text(this.formatRecordDuration(this.getSummaryDurationForDate(dateKey)))
                      .fontSize(13).fontColor('#AFC2FF')
                  }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
                  ForEach(this.getDistinctSummaryBooksForDate(dateKey), (detail: ReadRecordDetail) => {
                    Row() {
                      Column() {
                        Text(detail.bookName).fontSize(16).fontColor('#E3E4E8')
                        Text(detail.bookAuthor).fontSize(12).fontColor('#92949E').margin({ top: 3 })
                      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                      Text(this.formatRecordDuration(this.getSummaryBookDurationForDate(dateKey, detail.bookName, detail.bookAuthor)))
                        .fontSize(13).fontColor('#AFC2FF')
                    }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
                      .border({ width: { top: 1 }, color: '#111217' })
                  }, (detail: ReadRecordDetail) => `${dateKey}-${detail.bookName}-${detail.bookAuthor}`)
                }.width('calc(100% - 32vp)').backgroundColor('#1B1C22').borderRadius(12)
                  .margin({ left: 16, right: 16, bottom: 8 })
              }, (dateKey: string) => dateKey)
            } else if (this.displayMode === 1) {
              ForEach(this.getDateKeys(), (dateKey: string) => {
                Column() {
                  Text(dateKey).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#D8D9E0')
                    .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
                  ForEach(this.getRecordsForDate(dateKey), (record: ReadTimeRecord) => {
                    Row() {
                      Text(this.formatRecordDate(record.startTime).substring(11)).fontSize(13).fontColor('#AFC2FF')
                        .width(56)
                      Column() {
                        Text(record.bookName).fontSize(16).fontColor('#E3E4E8')
                        Text(record.bookAuthor).fontSize(12).fontColor('#92949E').margin({ top: 3 })
                      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                      Text(this.formatRecordDuration(record.durationMs)).fontSize(13).fontColor('#D8D9E0')
                    }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
                      .border({ width: { top: 1 }, color: '#111217' })
                  }, (record: ReadTimeRecord) => record.id)
                }.width('calc(100% - 32vp)').backgroundColor('#1B1C22').borderRadius(12)
                  .margin({ left: 16, right: 16, bottom: 8 })
              }, (dateKey: string) => dateKey)
            } else {
              ForEach(this.getLatestRecords(), (record: ReadTimeRecord) => {
                Column() {
                  Row() {
                    Column() {
                      Text(record.bookName).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
                      Text(record.bookAuthor).fontSize(12).fontColor('#92949E').margin({ top: 4 })
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    Text(this.formatRecordDuration(this.getBookDuration(record.bookId, this.records)))
                      .fontSize(13).fontColor('#AFC2FF')
                  }.width('100%')
                  Text(`最后阅读 ${this.formatRecordDate(record.endTime)}`)
                    .fontSize(12).fontColor('#92949E').width('100%').margin({ top: 10 })
                }.width('calc(100% - 32vp)').padding(16).backgroundColor('#1B1C22').borderRadius(14)
                  .margin({ left: 16, right: 16, bottom: 8 })
              }, (record: ReadTimeRecord) => record.bookId)
            }
          }.width('100%').padding({ top: 8, bottom: 16 })
        }.layoutWeight(1).scrollBar(BarState.Off)
          .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseInOut }))
      }
    }.width('100%').height('100%').backgroundColor('#111217')
      // 三个半模态共用一个 bindSheet：同一节点链式挂多个 bindSheet 时，
      // 任一状态变化都会让刚打开的 sheet 立即 onDisappear（实测 0.6s 内被顶掉），
      // 所以用互斥条件 + 单一入口。
      .bindSheet(this.showActionsSheet || this.showCalendarSheet || this.showClearConfirm, this.ReadRecordSheetContent(), {
        height: this.showClearConfirm ? SheetSize.FIT_CONTENT : (this.showCalendarSheet ? 570 : 500),
        dragBar: !this.showClearConfirm,
        showClose: false,
        backgroundColor: '#1C1D23',
        onDisappear: () => { this.showActionsSheet = false; this.showCalendarSheet = false; this.showClearConfirm = false; }
      })
  }

  /** 清空确认面板，与替换净化的删除确认同款交互。 */
  @Builder
  private ReadRecordClearConfirmSheet() {
    Column() {
      Text('清空阅读记录').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
        .width('100%').textAlign(TextAlign.Center).padding({ top: 22 })
      Text(`确定删除全部 ${this.records.length} 条阅读会话？删除后不可恢复。`)
        .fontSize(14).fontColor('#D8D9E0').width('100%').textAlign(TextAlign.Center)
        .padding({ left: 28, right: 28, top: 12, bottom: 20 })
      Row() {
        Text('取消').fontSize(16).fontColor('#D8D9E0').textAlign(TextAlign.Center)
          .layoutWeight(1).height(48).backgroundColor('#23242C').borderRadius(24)
          .onClick(() => this.showClearConfirm = false)
        Text('清空').fontSize(16).fontColor('#FFFFFF').textAlign(TextAlign.Center)
          .layoutWeight(1).height(48).backgroundColor('#D95656').borderRadius(24).margin({ left: 12 })
          .onClick(() => { this.confirmClearAll(); })
      }.width('100%').padding({ left: 28, right: 28, bottom: 24 })
    }.backgroundColor('#1C1D23')
  }

  @Builder
  private ReadRecordSheetContent() {
    if (this.showClearConfirm) { this.ReadRecordClearConfirmSheet() }
    else if (this.showCalendarSheet) { this.ReadRecordCalendarSheet() }
    else { this.ReadRecordOptionsSheet() }
  }

  @Builder
  private ReadRecordCalendarSheet() {
    Column() {
      Row() {
        Text('阅读日历').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#E3E4E8').layoutWeight(1)
        Text('关闭').fontSize(14).fontColor('#AFC2FF').onClick(() => this.showCalendarSheet = false)
      }.width('100%').padding({ left: 18, right: 18, top: 12, bottom: 14 })
      Text(`${new Date().getFullYear()} 年 ${new Date().getMonth() + 1} 月`)
        .fontSize(16).fontColor('#D8D9E0').width('100%').textAlign(TextAlign.Center).margin({ bottom: 18 })
      Row() {
        ForEach(['日', '一', '二', '三', '四', '五', '六'], (weekday: string) => {
          Text(weekday).fontSize(12).fontColor('#92949E').layoutWeight(1).textAlign(TextAlign.Center)
        }, (weekday: string) => weekday)
      }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
      Grid() {
        ForEach(this.getCalendarCells(), (day: number, index: number) => {
          GridItem() {
            if (day > 0) {
              Text(day.toString()).fontSize(13).fontColor(this.selectedCalendarDay === day ? '#111217' : '#D8D9E0')
                .width(36).height(36).textAlign(TextAlign.Center)
                .backgroundColor(this.selectedCalendarDay === day ? '#AFC2FF' :
                  this.getCalendarDayDuration(day) > 0 ? '#48577D' : '#292B33')
                .borderRadius(8).onClick(() => this.selectedCalendarDay = day)
            }
          }.height(42)
        }, (_day: number, index: number) => index.toString())
      }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr').rowsGap(4).width('100%')
        .padding({ left: 16, right: 16 })
      Text(this.selectedCalendarDay > 0 ?
        `${this.selectedCalendarDay} 日 · ${this.formatRecordDuration(this.getCalendarDayDuration(this.selectedCalendarDay))}` :
        '选择日期查看当天阅读时长')
        .fontSize(13).fontColor('#AFC2FF').width('100%').textAlign(TextAlign.Center).margin({ top: 16 })
    }.width('100%').padding({ bottom: 20 })
  }

  @Builder
  private ReadRecordOptionsSheet() {
    Column() {
      Text('阅读记录选项').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
        .width('100%').padding({ left: 18, right: 16, top: 12, bottom: 14 })
      ReadRecordOptionRow({ icon: 'clock', title: '显示阅读日历', detail: '按日期查看阅读记录', onSelect: () => {
        this.showActionsSheet = false;
        this.showCalendarSheet = true;
      } })
      ReadRecordOptionRow({
        icon: 'clock',
        title: this.recordEnabled ? '停用阅读记录' : '启用阅读记录',
        detail: this.recordEnabled ? '当前已启用' : '当前已停用，开启后继续记账',
        onSelect: (): void => { this.toggleRecordEnabled(); }
      })
      ReadRecordOptionRow({ icon: 'search', title: '扫描阅读记录问题', detail: '检查重复或异常记录',
        onSelect: (): void => { this.runScanIssues(); } })
      ReadRecordOptionRow({ icon: 'swap', title: '修复阅读记录', detail: '修复重复记录和阅读时段',
        onSelect: (): void => { this.runRepair(); } })
      ReadRecordOptionRow({ icon: 'delete', title: '清空阅读记录', detail: '删除本地阅读历史',
        onSelect: (): void => { this.showActionsSheet = false; this.requestClearAll(); } })
    }.width('100%').padding({ bottom: 16 })
  }
}

@Component
export struct CacheManagementPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @Prop groups: string[] = [];
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State selectedCacheGroup: string = '全部';

  private cacheGroupOptions(): string[] {
    const options: string[] = ['全部', '无分组'];
    this.groups.forEach((group: string) => {
      if (group.length > 0 && group !== '全部' && group !== '无分组' && !options.includes(group)) {
        options.push(group);
      }
    });
    return options;
  }

  @Builder
  private CacheGroupMenu() {
    Menu() {
      ForEach(this.cacheGroupOptions(), (group: string) => {
        MenuItem({ content: group, labelInfo: this.selectedCacheGroup === group ? '✓' : '' })
          .onClick(() => this.selectedCacheGroup = group)
      }, (group: string) => group)
    }.backgroundColor('#1C1D23').fontColor('#E3E4E8').radius(20)
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.onBack())
        Blank().layoutWeight(1)
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => {
          this.showSearch = !this.showSearch;
          if (!this.showSearch) { this.searchQuery = ''; }
        })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'profileFilterAlt', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).bindMenu(this.CacheGroupMenu, { placement: Placement.BottomRight })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'profileRefresh', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => this.onUnavailableAction('缓存数据仓储尚未接入，未刷新缓存'))
      }.width('100%').height(40).padding({ left: 11, right: 12 }).margin({ top: -8 })

      Text('缓存管理').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Regular).fontColor('#E3E4E8')
        .width('100%').padding({ left: 12, right: 18, top: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '筛选书名/作者', text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_cache_manage_search')
            .onAppear(() => focusControl.requestFocus('my_cache_manage_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 8, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(24)
      }

      Column() {
        CacheEmptySection({
          title: '书架书籍',
          message: '没有书架内书籍缓存或下载任务'
        })
        if (this.selectedCacheGroup === '全部') {
          CacheEmptySection({
            title: '未在书架',
            message: '没有未在书架的书籍下载状态'
          })
        }
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 8, bottom: 18 })
        .layoutWeight(1)
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct ReadRecordOptionRow {
  @Prop icon: AppGlyphName = 'info';
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};

  build() {
    Row() {
      AppGlyph({ name: this.icon, glyphSize: 19, tint: '#AFC2FF' }).width(32)
      Column() {
        Text(this.title).fontSize(15).fontColor('#E3E4E8')
        Text(this.detail).fontSize(12).fontColor('#92949E').margin({ top: 3 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .onClick(() => this.onSelect())
  }
}

@Component
struct CacheEmptySection {
  @Prop title: string = '';
  @Prop message: string = '';
  build() {
    Column() {
      Text(this.title).fontSize(14).fontColor('#AFC2FF')
        .alignSelf(ItemAlign.Start).margin({ left: 10, bottom: 7 })
      Text(this.message).fontSize(14).fontColor('#D8D9E0').width('100%').textAlign(TextAlign.Start)
        .padding({ left: 12, right: 12, top: 12, bottom: 12 }).backgroundColor('#1A1B21').borderRadius(8)
    }.width('100%').margin({ bottom: 14 })
  }
}


@Component
export struct AboutAppPage {
  onBack: () => void = () => {};
  onOpenPrivacyNotice: () => void = () => {};
  onOpenLicense: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State versionName: string = '';
  @State collapsedHeader: boolean = false;
  private aboutScroller: Scroller = new Scroller();

  private updateHeader(): void {
    const offset = this.aboutScroller.currentOffset().yOffset;
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      animateTo({ duration: 220, curve: Curve.EaseInOut }, () => this.collapsedHeader = shouldCollapse);
    }
  }

  aboutToAppear(): void {
    this.loadVersionName();
  }

  private async loadVersionName(): Promise<void> {
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      this.versionName = bundleInfo.versionName;
    } catch (_) {
      this.versionName = '版本信息不可用';
    }
  }

  build() {
    Column() {
      CollapsingSettingsHeader({ title: '关于', collapsed: this.collapsedHeader, onBack: () => this.onBack() })
      Scroll(this.aboutScroller) {
        Column() {
          Column() {
            Image($r('app.media.about_cat')).width(72).height(72)
            Blank().height(18)
            Blank().height(5)
            Text('阅读·D').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
            if (this.versionName.length > 0) {
              Text(this.versionName).fontSize(12).fontColor('#D8D9E0').padding({ left: 9, right: 9, top: 4, bottom: 4 })
                .backgroundColor('#1C1D23').borderRadius(8).margin({ top: 3 })
            }
            Text('全新设计的阅读 3.0').fontSize(12).fontColor('#92949E').margin({ top: 4 })
          }.width('100%').padding({ top: 4, bottom: 8 }).alignItems(HorizontalAlign.Center)

          Row() {
            AboutQuickAction({ icon: 'about_web', description: '项目主页', onSelect: () => this.onUnavailableAction('项目主页尚未接入外部链接') })
            AboutQuickAction({ icon: 'about_github', description: 'GitHub', onSelect: () => this.onUnavailableAction('GitHub 尚未接入外部链接') })
            AboutQuickAction({ icon: 'about_update', description: '检查更新', onSelect: () => this.onUnavailableAction('更新检查尚未迁移') })
          }.width('100%').padding({ left: 12, right: 12, bottom: 8 })

          Column() {
            AboutActionRow({ title: '开发人员', onSelect: () => this.onUnavailableAction('开发人员页面尚未迁移') })
            AboutActionRow({ title: '用户隐私与协议', onSelect: () => this.onOpenPrivacyNotice() })
            AboutActionRow({ title: '开源许可', onSelect: () => this.onOpenLicense() })
            AboutActionRow({ title: '免责声明', onSelect: () => this.onUnavailableAction('免责声明页面尚未迁移') })
            AboutActionRow({ title: '崩溃日志', onSelect: () => this.onUnavailableAction('崩溃日志页面尚未迁移') })
            AboutActionRow({ title: '保存日志', onSelect: () => this.onUnavailableAction('日志导出尚未迁移') })
            AboutActionRow({ title: '创建堆转储', last: true, onSelect: () => this.onUnavailableAction('堆转储尚未迁移') })
          }.width('100%').padding({ top: 2, bottom: 2 }).backgroundColor('#1A1B21').borderRadius(14)
        }.padding({ left: 16, right: 16, top: 4, bottom: 18 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct AboutQuickAction {
  @Prop icon: string = 'about_web';
  @Prop description: string = '';
  onSelect: () => void = () => {};
  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Image(this.icon === 'about_github' ? $r('app.media.about_github') :
          (this.icon === 'about_update' ? $r('app.media.about_update') : $r('app.media.about_web')))
          .width(20).height(20).fillColor('#D8D9E0').accessibilityText(this.description)
      }.width(36).height(36).backgroundColor('#3A4054').borderRadius(18).onClick(() => this.onSelect())
    }.layoutWeight(1).alignItems(HorizontalAlign.Center)
  }
}

@Component
struct AboutActionRow {
  @Prop title: string = '';
  @Prop last: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Column() {
      Row() {
        Text(this.title).fontSize(PROFILE_ROW_TITLE_SIZE).fontColor('#D8D9E0').layoutWeight(1)
      }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 16 }).onClick(() => this.onSelect())
      if (!this.last) { Row().height(1).width('100%').backgroundColor('#111217').margin({ left: 16, right: 16 }) }
    }.width('100%')
  }
}

@Component
export struct AppSettingsHomePage {
  onBack: () => void = () => {};
  onOpenCategory: (destination: ProfileRoute) => void = (_destination: ProfileRoute) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State collapsedHeader: boolean = false;
  private settingsScroller: Scroller = new Scroller();

  private updateHeader(): void {
    const offset = this.settingsScroller.currentOffset().yOffset;
    const shouldCollapse = offset > 70 ? true : offset < 24 ? false : this.collapsedHeader;
    if (shouldCollapse !== this.collapsedHeader) {
      animateTo({ duration: 220, curve: Curve.EaseInOut }, () => this.collapsedHeader = shouldCollapse);
    }
  }
  build() {
    Column() {
      SettingsPageHeader({ title: '设置', collapsed: this.collapsedHeader, onBack: () => this.onBack() })
      Scroll(this.settingsScroller) {
        Column() {
          Column() {
          SettingsCategoryRow({ title: '外观', onSelect: () => this.onOpenCategory(ProfileRoute.APP_THEME_SETTINGS) })
          SettingsCategoryRow({ title: '高级', onSelect: () => this.onOpenCategory(ProfileRoute.APP_OTHER_SETTINGS) })
          SettingsCategoryRow({ title: '阅读界面', onSelect: () => this.onOpenCategory(ProfileRoute.APP_READ_SETTINGS) })
          SettingsCategoryRow({ title: '朗读设置', summary: '管理角色声音池、背景音乐池与角色配音分配', onSelect: () => this.onOpenCategory(ProfileRoute.APP_ALOUD_SETTINGS) })
          SettingsCategoryRow({ title: '封面设置', onSelect: () => this.onOpenCategory(ProfileRoute.APP_COVER_SETTINGS) })
          SettingsCategoryRow({ title: '下载与缓存', onSelect: () => this.onOpenCategory(ProfileRoute.APP_DOWNLOAD_CACHE_SETTINGS) })
          SettingsCategoryRow({ title: '备份与恢复', onSelect: () => this.onOpenCategory(ProfileRoute.APP_BACKUP_SETTINGS) })
          SettingsCategoryRow({ title: 'AI 设置', onSelect: () => this.onOpenCategory(ProfileRoute.APP_AI_SETTINGS) })
          SettingsCategoryRow({ title: '翻译设置', onSelect: () => this.onOpenCategory(ProfileRoute.APP_TRANSLATION_SETTINGS) })
          SettingsCategoryRow({ title: '隐私', onSelect: () => this.onOpenCategory(ProfileRoute.APP_PRIVACY_SETTINGS) })
          SettingsCategoryRow({ title: '实验室', last: true, onSelect: () => this.onOpenCategory(ProfileRoute.APP_LAB_SETTINGS) })
          }.width('100%').backgroundColor('#1A1B21').borderRadius(16)
        }.padding({ left: 16, right: 16, top: 8, bottom: 16 })
      }.layoutWeight(1).scrollBar(BarState.Off).onScroll(() => this.updateHeader())
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct SettingsPageHeader {
  @Prop title: string = '';
  @Prop collapsed: boolean = false;
  onBack: () => void = () => {};
  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.onBack())
        Text(this.title).fontSize(22).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
          .opacity(this.collapsed ? 1 : 0)
        Blank()
      }.width('100%').height(64).padding({ left: 12, right: 16 })
      Text(this.title).fontSize(28).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
        .width('100%').height(72).padding({ left: 16, bottom: 14 })
        .opacity(this.collapsed ? 0 : 1)
    }.width('100%').height(this.collapsed ? 64 : 136).clip(true)
  }
}

@Component
struct SettingsCategoryRow {
  @Prop title: string = '';
  @Prop summary: string = '';
  @Prop last: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Column() {
      Row() {
        Column() {
          Text(this.title).fontSize(PROFILE_ROW_TITLE_SIZE).fontColor('#D8D9E0')
          if (this.summary.length > 0) {
            Text(this.summary).fontSize(PROFILE_ROW_DETAIL_SIZE).fontColor('#92949E').margin({ top: 4 })
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Image($r('app.media.reader_next')).width(18).height(18).fillColor('#92949E')
      }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 16 })
        .onClick(() => this.onSelect())
      if (!this.last) { Row().width('100%').height(2).backgroundColor('#111217') }
    }.width('100%')
  }
}

@Component
export struct AiChatPage {
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State historyVisible: boolean = false;
  @State draft: string = '';
  @State reasoningIndex: number = 1;
  @State showReasoningSheet: boolean = false;

  private handleBack(): void {
    if (this.historyVisible) {
      this.historyVisible = false;
    } else {
      this.onBack();
    }
  }

  private sendDraft(): void {
    if (this.draft.trim().length === 0) { return; }
    this.onUnavailableAction('AI服务商未配置，消息未发送');
  }

  private reasoningLabel(): string {
    if (this.reasoningIndex <= 0) { return '关闭'; }
    if (this.reasoningIndex === 1) { return '自动'; }
    if (this.reasoningIndex === 2) { return '轻度'; }
    if (this.reasoningIndex === 3) { return '中'; }
    if (this.reasoningIndex === 4) { return '高'; }
    if (this.reasoningIndex === 5) { return '极高'; }
    return '最高';
  }

  @Builder
  private ReasoningSheet() {
    Column() {
      Text('思考模式').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#E3E4E8')
        .width('100%').padding({ left: 20, right: 20, top: 20, bottom: 10 })
      Text(this.reasoningLabel()).fontSize(24).fontColor('#E3E4E8')
        .width('100%').textAlign(TextAlign.Center).padding({ top: 20, bottom: 20 })
      Slider({ value: this.reasoningIndex, min: 0, max: 6, step: 1, style: SliderStyle.OutSet })
        .blockColor('#B9C8FF').trackColor('#41485D').selectedColor('#B9C8FF')
        .showSteps(true).showTips(false).margin({ left: 22, right: 22 })
        .onChange((value: number) => this.reasoningIndex = Math.round(value))
      Text('此选项仅为本页预览；AI 服务未连接时不会用于生成。')
        .fontSize(13).fontColor('#92949E').textAlign(TextAlign.Center)
        .width('100%').padding({ left: 20, right: 20, top: 18, bottom: 24 })
    }.width('100%').backgroundColor('#17181E')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Row() {
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
            .width(36).onClick(() => this.handleBack())
          Column() {
            Text('AI 对话').fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
            Text('新对话').fontSize(PROFILE_PAGE_SUBTITLE_SIZE).fontColor('#92949E').margin({ top: 3 })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          AppGlyph({ name: 'list', glyphSize: 19, tint: '#D8D9E0' }).padding({ left: 8, right: 8 })
            .onClick(() => this.historyVisible = true)
          AppGlyph({ name: 'add', glyphSize: 19, tint: '#D8D9E0' }).padding({ left: 8, right: 8 })
            .onClick(() => { this.draft = ''; this.onUnavailableAction('新会话已准备；配置 AI 服务后即可发送消息'); })
        }.width('100%').padding({ left: 12, right: 10, top: 11, bottom: 9 })

        Row() {
          AppGlyph({ name: 'sparkles', glyphSize: 16, tint: '#AFC2FF' }).margin({ right: 7 })
          Text('模型未配置').fontSize(14).fontColor('#D8D9E0')
          Blank()
          AppGlyph({ name: 'more', glyphSize: 16, tint: '#92949E' })
        }.padding({ left: 12, right: 12, top: 9, bottom: 9 }).margin({ left: 16, right: 16, top: 4 })
          .backgroundColor('#1A1B21').borderRadius(18)
          .onClick(() => this.onUnavailableAction('请先在“我的→设置→AI 设置”配置服务商和模型'))

        Column() {
          AppGlyph({ name: 'sparkles', glyphSize: 40, tint: '#AFC2FF' }).margin({ bottom: 14 })
          Text('和你的书对话').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#D8D9E0')
          Text('配置 AI 服务后，提问和回复会显示在这里。')
            .fontSize(14).fontColor('#858792').textAlign(TextAlign.Center).margin({ top: 8 })
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)

        Column() {
          Row() {
            TextInput({ placeholder: '输入问题…', text: this.draft })
              .fontSize(15).fontColor('#D8D9E0').placeholderColor('#92949E')
              .backgroundColor(Color.Transparent).layoutWeight(1).maxLines(4)
              .onChange((value: string) => this.draft = value)
            Image($r('app.media.app_send')).width(18).height(18).fillColor(this.draft.trim().length > 0 ? '#151720' : '#92949E')
              .width(40).height(40).backgroundColor(this.draft.trim().length > 0 ? '#B9C8FF' : '#303139')
              .borderRadius(20).onClick(() => this.sendDraft())
          }.padding({ left: 14, right: 8, top: 7, bottom: 7 }).backgroundColor('#1A1B21').borderRadius(24)
          Row() {
            Text(`思考模式：${this.reasoningLabel()}`).fontSize(12).fontColor('#92949E')
              .onClick(() => this.showReasoningSheet = true)
            Blank()
            Text('AI 服务未配置').fontSize(12).fontColor('#858792')
          }.padding({ left: 6, right: 6, top: 7, bottom: 5 })
        }.padding({ left: 16, right: 16, top: 8, bottom: 12 })
      }.width('100%').height('100%').backgroundColor('#111217')

      if (this.historyVisible) {
        Stack({ alignContent: Alignment.TopStart }) {
          Column().width('100%').height('100%').backgroundColor('#99000000')
            .onClick(() => this.historyVisible = false)
          Column() {
            Row() {
              Text('最近会话').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#E3E4E8').layoutWeight(1)
              AppGlyph({ name: 'add', glyphSize: 19, tint: '#D8D9E0' }).padding(8)
                .onClick(() => { this.historyVisible = false; this.draft = ''; })
            }.padding({ left: 18, right: 12, top: 18, bottom: 16 })
            Row() {
              AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
              TextInput({ placeholder: '搜索会话…' }).fontSize(14).fontColor('#D8D9E0')
                .placeholderColor('#92949E').backgroundColor(Color.Transparent).layoutWeight(1)
            }.padding({ left: 12, right: 12, top: 8, bottom: 8 }).margin({ left: 14, right: 14 })
              .backgroundColor('#22232A').borderRadius(20)
            Column() {
              AppGlyph({ name: 'sparkles', glyphSize: 28, tint: '#92949E' }).margin({ bottom: 10 })
              Text('暂无会话记录').fontSize(14).fontColor('#AEB0BA')
            }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
            Text('新建对话').fontSize(15).fontColor('#151720').textAlign(TextAlign.Center)
              .width('100%').padding(13).margin({ left: 14, right: 14, bottom: 20 })
              .backgroundColor('#B9C8FF').borderRadius(24)
              .onClick(() => { this.historyVisible = false; this.draft = ''; this.onUnavailableAction('配置 AI 服务后即可开始对话'); })
          }.width('82%').height('100%').backgroundColor('#17181E')
        }.width('100%').height('100%')
      }
    }.width('100%').height('100%').backgroundColor('#111217')
      .bindSheet(this.showReasoningSheet, this.ReasoningSheet(), {
        height: SheetSize.MEDIUM,
        dragBar: true,
        showClose: false,
        backgroundColor: '#17181E',
        onDisappear: () => this.showReasoningSheet = false
      })
  }
}

@Component
struct ModuleHeader {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  onBack: () => void = () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  build() {
    Column() {
      Row() {
        Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0').width(36).onClick(() => this.onBack())
        Column() {
          Text(this.title).fontSize(PROFILE_PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor('#E3E4E8')
          Text(this.subtitle).fontSize(PROFILE_PAGE_SUBTITLE_SIZE).fontColor('#92949E').margin({ top: 3 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        AppGlyph({ name: 'search', glyphSize: 18, tint: '#D8D9E0' }).padding({ left: 8, right: 8 })
          .onClick(() => this.onUnavailableAction('设置搜索尚未迁移'))
        AppGlyph({ name: 'more', glyphSize: 17, tint: '#D8D9E0' }).padding({ left: 6, right: 6 })
          .onClick(() => this.onUnavailableAction('设置更多操作尚未迁移'))
      }.width('100%').padding({ left: 12, right: 10, top: 11, bottom: 9 })
    }
  }
}

@Component
struct ModuleSearch {
  @Prop hint: string = '';
  @State query: string = '';
  build() {
    Row() {
      AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
      TextInput({ placeholder: this.hint, text: this.query })
        .fontSize(16)
        .fontColor('#D8D9E0')
        .placeholderColor('#92949E')
        .backgroundColor(Color.Transparent)
        .onChange((value: string) => this.query = value)
        .layoutWeight(1)
    }.width('100%').padding({ left: 12, right: 14, top: 7, bottom: 7 }).margin({ left: 16, right: 16 }).backgroundColor('#1B1C22').borderRadius(22)
  }
}

@Component
struct ModuleTab {
  @Prop label: string = '';
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  build() {
    Text(this.label).fontSize(16).fontColor(this.selected ? '#E1E5F3' : '#A4A6B0')
      .textAlign(TextAlign.Center).layoutWeight(1).padding({ top: 9, bottom: 9 })
      .backgroundColor(this.selected ? '#41485D' : '#1A1B21').borderRadius(20).margin({ right: 7 })
      .onClick(() => this.onSelect())
  }
}

@Component
struct ModuleEmpty {
  @Prop icon: AppGlyphName = 'book';
  @Prop title: string = '';
  @Prop detail: string = '';
  build() {
    Column() {
      AppGlyph({ name: this.icon, glyphSize: 34, tint: '#AFC2FF' }).margin({ bottom: 14 })
      Text(this.title).fontSize(18).fontColor('#D8D9E0')
      Text(this.detail).fontSize(15).fontColor('#858792').textAlign(TextAlign.Center).margin({ left: 34, right: 34, top: 8 })
    }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }
}

@Component
struct MetricCard {
  @Prop label: string = '';
  @Prop value: string = '';
  build() {
    Column() {
      Text(this.label).fontSize(14).fontColor('#92949E')
      Text(this.value).fontSize(17).fontColor('#D8D9E0').margin({ top: 5 })
    }.layoutWeight(1).alignItems(HorizontalAlign.Start).padding(15).backgroundColor('#1C1D23')
      .borderRadius(14).margin({ right: 6 })
  }
}

@Component
struct FileCategoryRow {
  @Prop icon: AppGlyphName = 'folder';
  @Prop title: string = '';
  @Prop detail: string = '';
  onSelect: () => void = () => {};
  build() {
    Row() {
      AppGlyph({ name: this.icon, glyphSize: 20, tint: '#AFC2FF' }).width(36)
      Column() {
        Text(this.title).fontSize(PROFILE_ROW_TITLE_SIZE).fontColor('#D8D9E0')
        Text(this.detail).fontSize(PROFILE_ROW_DETAIL_SIZE).fontColor('#92949E').margin({ top: 4 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.reader_next')).width(18).height(18).fillColor('#92949E')
    }.padding({ left: 15, right: 15, top: PROFILE_ROW_VERTICAL_PADDING, bottom: PROFILE_ROW_VERTICAL_PADDING }).margin({ left: 16, right: 16, bottom: 1 })
      .backgroundColor('#1A1B21').onClick(() => this.onSelect())
  }
}

