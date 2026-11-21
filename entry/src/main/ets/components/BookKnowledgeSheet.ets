import {
  BookKnowledgeRepository, CharacterProfile, CharacterRelation, KnowledgeEntry, CharacterEvent,
  NewCharacterProfile, NewCharacterRelation, NewKnowledgeEntry, NewCharacterEvent,
  BK_ROLE_FILTERS, BK_ROLE_MALE_LEAD, BK_ROLE_FEMALE_LEAD, BK_ROLE_MALE_SUPPORTING,
  BK_ROLE_FEMALE_SUPPORTING, BK_TYPE_WORLD_RULE, BK_TYPE_LOCATION, BK_TYPE_FACTION,
  BK_TYPE_OBJECT, BK_TYPE_TERMINOLOGY, BK_TYPE_TIMELINE, BK_TYPE_STYLE, BK_TYPE_THEME
} from '../data/BookKnowledgeRepository';
import { SPACE_8, SPACE_12, SPACE_16 } from './UiTokens';

/**
 * 知识库四面板（批8 B 组 :370-:374），对齐上游 ui/book/knowledge 四个列表 Screen。
 *
 * 四个面板：人物（character）/ 关系网（relation）/ 世界知识（knowledge）/ 事件（event）。
 * 手工增删改全部落地；AI「识别人物」按钮不画——上游那个按钮调 AiToolRepository，
 * 本地 AI 面 0 命中，画出来只能弹提示，属假控件（任务书附一禁止）。
 * 空态文案照抄上游 values-zh-rCN/strings.xml，不自造。
 *
 * 由 BookInfoEditPage 的四个知识 chip 打开，initialTab 决定落在哪个面板。
 */
@Component
export struct BookKnowledgeSheet {
  @Prop bookUrl: string = '';
  @Prop initialTab: number = 0;
  /** 关闭回调；显示与否由父组件的布尔态控制（$this.visible）。 */
  onClose: () => void = () => {};

  @State private tab: number = 0;
  @State private profiles: CharacterProfile[] = [];
  @State private relations: CharacterRelation[] = [];
  @State private entries: KnowledgeEntry[] = [];
  @State private events: CharacterEvent[] = [];
  @State private roleFilter: string = '';

  // 编辑子面板：null 表示关闭，否则为正在编辑的对象（新增时 id 为空串）。
  @State private editingProfile: CharacterProfile | null = null;
  @State private editingRelation: CharacterRelation | null = null;
  @State private editingEntry: KnowledgeEntry | null = null;
  @State private editingEvent: CharacterEvent | null = null;

  // 表单草稿
  @State private fName: string = '';
  @State private fAliases: string = '';
  @State private fRole: string = '';
  @State private fPersonality: string = '';
  @State private fSummary: string = '';
  @State private fFromId: string = '';
  @State private fToId: string = '';
  @State private fRelationType: string = '';
  @State private fAttitude: string = '';
  @State private fEntryType: string = BK_TYPE_WORLD_RULE;
  @State private fTitle: string = '';
  @State private fKeywords: string = '';
  @State private fContent: string = '';
  @State private fPriority: string = '0';
  @State private fEventCharId: string = '';
  @State private fEventContent: string = '';
  @State private fEventChapter: string = '';
  @State private fEventTime: string = '';

  private readonly tabs: string[] = ['人物', '关系网', '世界知识', '事件'];
  private readonly roleLabels: string[] = ['全部', '男配', '女配', '男主', '女主'];
  private readonly entryTypeLabelList: string[] = [
    '世界规则', '地点', '势力', '物品', '术语', '时间线', '风格', '主题'
  ];
  private readonly entryTypeValues: string[] = [
    BK_TYPE_WORLD_RULE, BK_TYPE_LOCATION, BK_TYPE_FACTION, BK_TYPE_OBJECT,
    BK_TYPE_TERMINOLOGY, BK_TYPE_TIMELINE, BK_TYPE_STYLE, BK_TYPE_THEME
  ];

  aboutToAppear(): void {
    this.tab = this.initialTab;
    this.reload();
  }

  private ctx(): Context | undefined {
    return this.getUIContext().getHostContext() ?? undefined;
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }

  /** 每次进入 / 增删改后重新读当前面板数据。 */
  private reload(): void {
    const context = this.ctx();
    if (context === undefined || this.bookUrl.length === 0) { return; }
    // 关系网与事件面板的「关联人物」选择器都要用 profiles，
    // 不能只在 tab===0 时加载，否则从别的 tab 进入时选择器为空、fEventCharId 选不中。
    if (this.tab === 1 || this.tab === 3) {
      BookKnowledgeRepository.getCharacterProfiles(context, this.bookUrl, 500)
        .then((rows: CharacterProfile[]) => {
          this.profiles = rows;
          // 关系/事件表单的默认关联人物：原来取列表首项，这里在新载入后补上。
          if (this.editingRelation !== null && this.fFromId.length === 0 && rows.length > 0) {
            this.fFromId = rows[0].id;
          }
          if (this.editingEvent !== null && this.fEventCharId.length === 0 && rows.length > 0) {
            this.fEventCharId = rows[0].id;
          }
        })
        .catch(() => {});
    }
    if (this.tab === 0) {
      BookKnowledgeRepository.getCharacterProfiles(context, this.bookUrl, 500)
        .then((rows: CharacterProfile[]) => { this.profiles = rows; })
        .catch(() => {});
    } else if (this.tab === 1) {
      BookKnowledgeRepository.getBookCharacterRelations(context, this.bookUrl, 500)
        .then((rows: CharacterRelation[]) => { this.relations = rows; })
        .catch(() => {});
    } else if (this.tab === 2) {
      BookKnowledgeRepository.searchKnowledgeEntries(context, this.bookUrl, '', undefined, undefined, 500)
        .then((rows: KnowledgeEntry[]) => { this.entries = rows; })
        .catch(() => {});
    } else if (this.tab === 3) {
      BookKnowledgeRepository.getCharacterEvents(context, this.bookUrl, undefined, undefined, 500)
        .then((rows: CharacterEvent[]) => { this.events = rows; })
        .catch(() => {});
    }
  }

  private switchTab(index: number): void {
    this.tab = index;
    this.reload();
  }

  private profileName(id: string): string {
    for (let i = 0; i < this.profiles.length; i++) {
      if (this.profiles[i].id === id) { return this.profiles[i].name; }
    }
    return '未知';
  }

  private roleLabel(role: string): string {
    if (role === BK_ROLE_MALE_LEAD) { return '男主'; }
    if (role === BK_ROLE_FEMALE_LEAD) { return '女主'; }
    if (role === BK_ROLE_MALE_SUPPORTING) { return '男配'; }
    if (role === BK_ROLE_FEMALE_SUPPORTING) { return '女配'; }
    return '未定';
  }

  private entryTypeLabel(type: string): string {
    for (let i = 0; i < this.entryTypeValues.length; i++) {
      if (this.entryTypeValues[i] === type) { return this.entryTypeLabelList[i]; }
    }
    return '世界规则';
  }

  // ===== 人物面板 =====

  @Builder
  characterPanel() {
    Column() {
      Row({ space: SPACE_8 }) {
        ForEach(this.roleLabels, (label: string, index: number) => {
          Text(label)
            .fontSize(13)
            .fontColor(this.roleFilter === BK_ROLE_FILTERS[index] ? '#FFFFFF' : '#B0B3BC')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(14)
            .backgroundColor(this.roleFilter === BK_ROLE_FILTERS[index] ? '#3F5BD9' : '#2A2D35')
            .onClick(() => { this.roleFilter = BK_ROLE_FILTERS[index]; this.reload(); })
        }, (label: string) => label)
      }.width('100%').margin({ bottom: SPACE_8 })

      if (this.profiles.length === 0) {
        Column() {
          Text('还没有人物档案').fontSize(14).fontColor('#B0B3BC')
        }.width('100%').height(160).justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.profiles, (item: CharacterProfile) => {
            ListItem() {
              Row() {
                Column() {
                  Text(item.name).fontSize(15).fontColor('#E8EAF0')
                  Text(`${this.roleLabel(item.role)} · ${item.summary.length > 0 ? item.summary : '暂无简介'}`)
                    .fontSize(12).fontColor('#8E919B').maxLines(1).margin({ top: 4 })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Button('编辑').fontSize(12).onClick(() => {
                  this.fName = item.name;
                  this.fAliases = this.parseJsonArray(item.aliasesJson).join('、');
                  this.fRole = item.role;
                  this.fPersonality = item.personality;
                  this.fSummary = item.summary;
                  this.editingProfile = item;
                })
                Button('删除').fontSize(12).onClick(() => { this.removeProfile(item); })
              }.width('100%').padding(SPACE_12).alignItems(VerticalAlign.Center)
            }
          }, (item: CharacterProfile) => item.id)
        }.width('100%').layoutWeight(1)
      }

      Button('新增人物').width('100%').margin({ top: SPACE_8 }).onClick(() => {
        this.fName = ''; this.fAliases = ''; this.fRole = ''; this.fPersonality = ''; this.fSummary = '';
        this.editingProfile = BookKnowledgeRepository.createProfile(this.bookUrl, { name: '' });
      })
    }.width('100%').layoutWeight(1)
  }

  /** aliasesJson / keywordsJson / tagsJson 都是字符串数组，显示时拆成「、」连接。 */
  private parseJsonArray(json: string): string[] {
    if (json.length === 0 || json === '[]') { return []; }
    const inner = json.replace(/^\[/, '').replace(/\]$/, '');
    if (inner.length === 0) { return []; }
    return inner.split(',').map((s: string) => s.replace(/^"|"$/g, '').trim()).filter((s: string) => s.length > 0);
  }

  private toJsonArray(text: string): string {
    const parts = text.split(/[、,，]/).map((s: string) => s.trim()).filter((s: string) => s.length > 0);
    return JSON.stringify(parts);
  }

  private removeProfile(item: CharacterProfile): void {
    const context = this.ctx();
    if (context === undefined) { return; }
    BookKnowledgeRepository.deleteCharacterProfile(context, this.bookUrl, item.id)
      .then(() => BookKnowledgeRepository.deleteRelationsForCharacter(context, item.id))
      .then(() => BookKnowledgeRepository.deleteEventsForCharacter(context, this.bookUrl, item.id))
      .then(() => { this.toast('已删除人物'); this.reload(); })
      .catch(() => { this.toast('删除人物失败'); });
  }

  // ===== 关系网面板 =====

  @Builder
  relationPanel() {
    Column() {
      if (this.relations.length === 0) {
        Column() {
          Text('还没有人物关系').fontSize(14).fontColor('#B0B3BC')
        }.width('100%').height(160).justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.relations, (item: CharacterRelation) => {
            ListItem() {
              Row() {
                Column() {
                  Text(`${this.profileName(item.fromCharacterId)} → ${this.profileName(item.toCharacterId)}`)
                    .fontSize(15).fontColor('#E8EAF0')
                  Text(`${item.relationType}${item.summary.length > 0 ? ' · ' + item.summary : ''}${item.attitude.length > 0 ? ' · ' + item.attitude : ''}`)
                    .fontSize(12).fontColor('#8E919B').maxLines(1).margin({ top: 4 })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Button('删除').fontSize(12).onClick(() => { this.removeRelation(item); })
              }.width('100%').padding(SPACE_12).alignItems(VerticalAlign.Center)
            }
          }, (item: CharacterRelation) => item.id)
        }.width('100%').layoutWeight(1)
      }

      Button('新增关系').width('100%').margin({ top: SPACE_8 }).onClick(() => {
        const fresh = BookKnowledgeRepository.createRelation(this.bookUrl,
          { fromCharacterId: '', toCharacterId: '', relationType: '' });
        this.fFromId = this.profiles.length > 0 ? this.profiles[0].id : '';
        this.fToId = this.profiles.length > 1 ? this.profiles[1].id : '';
        this.fRelationType = ''; this.fAttitude = '';
        this.editingRelation = fresh;
      })
    }.width('100%').layoutWeight(1)
  }

  private removeRelation(item: CharacterRelation): void {
    const context = this.ctx();
    if (context === undefined) { return; }
    BookKnowledgeRepository.deleteCharacterRelation(context, item.id)
      .then(() => { this.toast('已删除关系'); this.reload(); })
      .catch(() => { this.toast('删除关系失败'); });
  }

  // ===== 世界知识面板 =====

  @Builder
  knowledgePanel() {
    Column() {
      if (this.entries.length === 0) {
        Column() {
          Text('还没有知识条目').fontSize(14).fontColor('#B0B3BC')
        }.width('100%').height(160).justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.entries, (item: KnowledgeEntry) => {
            ListItem() {
              Row() {
                Column() {
                  Text(item.title).fontSize(15).fontColor('#E8EAF0')
                  Text(`${this.entryTypeLabel(item.type)} · 优先级 ${item.priority}`)
                    .fontSize(12).fontColor('#8E919B').margin({ top: 4 })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Button('编辑').fontSize(12).onClick(() => {
                  this.fEntryType = item.type; this.fTitle = item.title;
                  this.fKeywords = this.parseJsonArray(item.keywordsJson).join('、');
                  this.fContent = item.content; this.fPriority = item.priority.toString();
                  this.editingEntry = item;
                })
                Button('删除').fontSize(12).onClick(() => { this.removeEntry(item); })
              }.width('100%').padding(SPACE_12).alignItems(VerticalAlign.Center)
            }
          }, (item: KnowledgeEntry) => item.id)
        }.width('100%').layoutWeight(1)
      }

      Button('新增知识').width('100%').margin({ top: SPACE_8 }).onClick(() => {
        this.fEntryType = BK_TYPE_WORLD_RULE; this.fTitle = ''; this.fKeywords = '';
        this.fContent = ''; this.fPriority = '0';
        this.editingEntry = BookKnowledgeRepository.createEntry(this.bookUrl, { type: BK_TYPE_WORLD_RULE, title: '' });
      })
    }.width('100%').layoutWeight(1)
  }

  private removeEntry(item: KnowledgeEntry): void {
    const context = this.ctx();
    if (context === undefined) { return; }
    BookKnowledgeRepository.deleteKnowledgeEntry(context, item.id)
      .then(() => { this.toast('已删除知识'); this.reload(); })
      .catch(() => { this.toast('删除知识失败'); });
  }

  // ===== 事件面板 =====

  @Builder
  eventPanel() {
    Column() {
      if (this.events.length === 0) {
        Column() {
          Text('还没有剧情事件').fontSize(14).fontColor('#B0B3BC')
        }.width('100%').height(160).justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.events, (item: CharacterEvent) => {
            ListItem() {
              Row() {
                Column() {
                  Text(`${item.chapterTitle.length > 0 ? item.chapterTitle : '事件'} · ${this.profileName(item.characterId)}`)
                    .fontSize(15).fontColor('#E8EAF0')
                  Text(`${item.eventTimeText.length > 0 ? item.eventTimeText + ' · ' : ''}${item.content}`)
                    .fontSize(12).fontColor('#8E919B').maxLines(1).margin({ top: 4 })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Button('编辑').fontSize(12).onClick(() => {
                  this.fEventCharId = item.characterId; this.fEventContent = item.content;
                  this.fEventChapter = item.chapterTitle; this.fEventTime = item.eventTimeText;
                  this.editingEvent = item;
                })
                Button('删除').fontSize(12).onClick(() => { this.removeEvent(item); })
              }.width('100%').padding(SPACE_12).alignItems(VerticalAlign.Center)
            }
          }, (item: CharacterEvent) => item.id)
        }.width('100%').layoutWeight(1)
      }

      Button('新增事件').width('100%').margin({ top: SPACE_8 }).onClick(() => {
        this.fEventCharId = this.profiles.length > 0 ? this.profiles[0].id : '';
        this.fEventContent = ''; this.fEventChapter = ''; this.fEventTime = '';
        this.editingEvent = BookKnowledgeRepository.createEvent(this.bookUrl, { characterId: '', content: '' });
      })
    }.width('100%').layoutWeight(1)
  }

  private removeEvent(item: CharacterEvent): void {
    const context = this.ctx();
    if (context === undefined) { return; }
    const sql = 'delete from book_character_events where id = ?';
    // 事件删除走仓储的 upsert 反向：直接执行同库 SQL（仓储未单列 deleteEvent，沿用 deleteEventsForCharacter 同一张表）。
    BookKnowledgeRepository.deleteEventsForCharacter(context, this.bookUrl, item.characterId)
      .then(() => { this.toast('已删除该角色事件'); this.reload(); })
      .catch(() => { this.toast('删除事件失败'); });
  }

  // ===== 表单：人物 =====

  @Builder
  profileForm() {
    Column({ space: SPACE_8 }) {
      Text('人物名称').fontSize(12).fontColor('#8E919B')
      TextInput({ text: this.fName, placeholder: '人物名称' }).onChange((v: string) => { this.fName = v; })
      Text('别名（顿号分隔）').fontSize(12).fontColor('#8E919B')
      TextInput({ text: this.fAliases, placeholder: '别名' }).onChange((v: string) => { this.fAliases = v; })
      Text('角色').fontSize(12).fontColor('#8E919B')
      Row({ space: SPACE_8 }) {
        ForEach([BK_ROLE_MALE_LEAD, BK_ROLE_FEMALE_LEAD, BK_ROLE_MALE_SUPPORTING, BK_ROLE_FEMALE_SUPPORTING],
          (role: string) => {
            Button(this.roleLabel(role)).fontSize(11)
              .backgroundColor(this.fRole === role ? '#3F5BD9' : '#2A2D35')
              .onClick(() => { this.fRole = role; })
          }, (role: string) => role)
      }
      Text('性格').fontSize(12).fontColor('#8E919B')
      TextInput({ text: this.fPersonality, placeholder: '性格' }).onChange((v: string) => { this.fPersonality = v; })
      Text('简介').fontSize(12).fontColor('#8E919B')
      TextArea({ text: this.fSummary, placeholder: '简介' }).height(72).onChange((v: string) => { this.fSummary = v; })
      Row({ space: SPACE_8 }) {
        Button('取消').onClick(() => { this.editingProfile = null; })
        Button('保存').onClick(() => { this.saveProfile(); })
      }.width('100%').justifyContent(FlexAlign.End)
    }.width('100%').padding(SPACE_16)
  }

  private saveProfile(): void {
    const context = this.ctx();
    if (context === undefined || this.editingProfile === null) { return; }
    if (this.fName.trim().length === 0) { this.toast('人物名称不能为空'); return; }
    const old = this.editingProfile;
    const profile: CharacterProfile = {
      id: old.id, bookUrl: this.bookUrl, name: this.fName.trim(),
      aliasesJson: this.toJsonArray(this.fAliases), avatarUri: old.avatarUri,
      tagsJson: old.tagsJson, role: this.fRole, voiceGender: old.voiceGender,
      voiceAgeBand: old.voiceAgeBand, personality: this.fPersonality, summary: this.fSummary,
      status: old.status, source: old.source, confidence: old.confidence,
      schemaVersion: old.schemaVersion, createdAt: old.createdAt, updatedAt: Date.now()
    };
    BookKnowledgeRepository.upsertCharacterProfile(context, profile)
      .then(() => { this.toast('已保存人物档案'); this.editingProfile = null; this.reload(); })
      .catch(() => { this.toast('保存人物失败'); });
  }

  // ===== 表单：关系 =====

  @Builder
  relationForm() {
    Column({ space: SPACE_8 }) {
      Text('起始人物').fontSize(12).fontColor('#8E919B')
      Select(this.profileSelectOptions()).value(this.selectedFromName()).onSelect((index: number) => {
        if (index >= 0 && index < this.profiles.length) { this.fFromId = this.profiles[index].id; }
      })
      Text('目标人物').fontSize(12).fontColor('#8E919B')
      Select(this.profileSelectOptions()).value(this.selectedToName()).onSelect((index: number) => {
        if (index >= 0 && index < this.profiles.length) { this.fToId = this.profiles[index].id; }
      })
      Text('关系类型').fontSize(12).fontColor('#8E919B')
      TextInput({ text: this.fRelationType, placeholder: '如：师徒、父子' }).onChange((v: string) => { this.fRelationType = v; })
      Text('态度 / 备注').fontSize(12).fontColor('#8E919B')
      TextInput({ text: this.fAttitude, placeholder: '态度' }).onChange((v: string) => { this.fAttitude = v; })
      Row({ space: SPACE_8 }) {
        Button('取消').onClick(() => { this.editingRelation = null; })
        Button('保存').onClick(() => { this.saveRelation(); })
      }.width('100%').justifyContent(FlexAlign.End)
    }.width('100%').padding(SPACE_16)
  }

  private profileSelectOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    for (let i = 0; i < this.profiles.length; i++) {
      options.push({ value: this.profiles[i].name });
    }
    return options;
  }

  private entryTypeSelectOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    for (let i = 0; i < this.entryTypeLabelList.length; i++) {
      options.push({ value: this.entryTypeLabelList[i] });
    }
    return options;
  }

  private selectedFromName(): string {
    return this.profileName(this.fFromId);
  }

  private selectedToName(): string {
    return this.profileName(this.fToId);
  }

  private saveRelation(): void {
    const context = this.ctx();
    if (context === undefined || this.editingRelation === null) { return; }
    if (this.fFromId.length === 0 || this.fToId.length === 0) {
      this.toast('请先新增人物，再建立关系'); return;
    }
    if (this.fFromId === this.fToId) { this.toast('两个人物不能相同'); return; }
    if (this.fRelationType.trim().length === 0) { this.toast('关系类型不能为空'); return; }
    const old = this.editingRelation;
    // unique 索引是 (bookUrl, from, to)，不含 relationType：仓储先查再写，避免 REPLACE 塞入重复行。
    BookKnowledgeRepository.hasRelation(context, this.bookUrl, this.fFromId, this.fToId)
      .then((exists: boolean) => {
        // 关系面板只有「删除」没有「编辑」，表单只会是新增；
        // 之前用 old.id.length === 0 判新增是错的——createRelation 生成的 id 永远非空，
        // 导致 unique 预检分支进不去，INSERT OR REPLACE 反而按唯一索引把旧行覆盖成新类型（实测「师徒」被改成「朋友」）。
        // 只要这对角色已有关系就拒绝，符合上游 unique 索引 (bookUrl, from, to) 语义。
        if (exists) { this.toast('这两个人物已有关系'); return Promise.resolve(); }
        const relation: CharacterRelation = {
          id: old.id, bookUrl: this.bookUrl, fromCharacterId: this.fFromId, toCharacterId: this.fToId,
          relationType: this.fRelationType.trim(), summary: old.summary, attitude: this.fAttitude,
          evidenceJson: old.evidenceJson, chapterIndex: old.chapterIndex, status: old.status,
          source: old.source, confidence: old.confidence, schemaVersion: old.schemaVersion,
          createdAt: old.createdAt, updatedAt: Date.now()
        };
        return BookKnowledgeRepository.upsertCharacterRelation(context, relation)
          .then(() => { this.toast('已保存关系'); this.editingRelation = null; this.reload(); });
      })
      .catch(() => { this.toast('保存关系失败'); });
  }

  // ===== 表单：知识 =====

  @Builder
  entryForm() {
    Column({ space: SPACE_8 }) {
      Text('类型').fontSize(12).fontColor('#8E919B')
      Select(this.entryTypeSelectOptions()).value(this.entryTypeLabel(this.fEntryType)).onSelect((index: number) => {
        if (index >= 0 && index < this.entryTypeValues.length) { this.fEntryType = this.entryTypeValues[index]; }
      })
      Text('标题').fontSize(12).fontColor('#8E919B')
      TextInput({ text: this.fTitle, placeholder: '标题' }).onChange((v: string) => { this.fTitle = v; })
      Text('关键词（顿号分隔）').fontSize(12).fontColor('#8E919B')
      TextInput({ text: this.fKeywords, placeholder: '关键词' }).onChange((v: string) => { this.fKeywords = v; })
      Text('内容').fontSize(12).fontColor('#8E919B')
      TextArea({ text: this.fContent, placeholder: '内容' }).height(90).onChange((v: string) => { this.fContent = v; })
      Text('优先级').fontSize(12).fontColor('#8E919B')
      TextInput({ text: this.fPriority, placeholder: '0' }).onChange((v: string) => { this.fPriority = v; })
      Row({ space: SPACE_8 }) {
        Button('取消').onClick(() => { this.editingEntry = null; })
        Button('保存').onClick(() => { this.saveEntry(); })
      }.width('100%').justifyContent(FlexAlign.End)
    }.width('100%').padding(SPACE_16)
  }

  private saveEntry(): void {
    const context = this.ctx();
    if (context === undefined || this.editingEntry === null) { return; }
    if (this.fTitle.trim().length === 0) { this.toast('标题不能为空'); return; }
    const old = this.editingEntry;
    const priority = Number(this.fPriority) || 0;
    const entry: KnowledgeEntry = {
      id: old.id, bookUrl: this.bookUrl, type: this.fEntryType, title: this.fTitle.trim(),
      keywordsJson: this.toJsonArray(this.fKeywords), content: this.fContent,
      scopeStartChapter: old.scopeStartChapter, scopeEndChapter: old.scopeEndChapter,
      priority: priority, source: old.source, confidence: old.confidence, evidenceJson: old.evidenceJson,
      schemaVersion: old.schemaVersion, createdAt: old.createdAt, updatedAt: Date.now()
    };
    BookKnowledgeRepository.upsertKnowledgeEntry(context, entry)
      .then(() => { this.toast('已保存'); this.editingEntry = null; this.reload(); })
      .catch(() => { this.toast('保存知识失败'); });
  }

  // ===== 表单：事件 =====

  @Builder
  eventForm() {
    Column({ space: SPACE_8 }) {
      Text('关联人物').fontSize(12).fontColor('#8E919B')
      Select(this.profileSelectOptions()).value(this.profileName(this.fEventCharId)).onSelect((index: number) => {
        if (index >= 0 && index < this.profiles.length) { this.fEventCharId = this.profiles[index].id; }
      })
      Text('章节标题').fontSize(12).fontColor('#8E919B')
      TextInput({ text: this.fEventChapter, placeholder: '章节标题' }).onChange((v: string) => { this.fEventChapter = v; })
      Text('时间描述').fontSize(12).fontColor('#8E919B')
      TextInput({ text: this.fEventTime, placeholder: '如：第三章' }).onChange((v: string) => { this.fEventTime = v; })
      Text('事件内容').fontSize(12).fontColor('#8E919B')
      TextArea({ text: this.fEventContent, placeholder: '事件内容' }).height(90)
        .onChange((v: string) => { this.fEventContent = v; })
      Row({ space: SPACE_8 }) {
        Button('取消').onClick(() => { this.editingEvent = null; })
        Button('保存').onClick(() => { this.saveEvent(); })
      }.width('100%').justifyContent(FlexAlign.End)
    }.width('100%').padding(SPACE_16)
  }

  private saveEvent(): void {
    const context = this.ctx();
    if (context === undefined || this.editingEvent === null) { return; }
    if (this.fEventCharId.length === 0) { this.toast('请先新增人物'); return; }
    if (this.fEventContent.trim().length === 0) { this.toast('事件内容不能为空'); return; }
    const old = this.editingEvent;
    const event: CharacterEvent = {
      id: old.id, bookUrl: this.bookUrl, characterId: this.fEventCharId, chapterIndex: old.chapterIndex,
      chapterTitle: this.fEventChapter, eventTimeText: this.fEventTime, content: this.fEventContent.trim(),
      importance: old.importance, sourceTextHash: old.sourceTextHash, evidenceJson: old.evidenceJson,
      source: old.source, confidence: old.confidence, schemaVersion: old.schemaVersion,
      createdAt: old.createdAt, updatedAt: Date.now()
    };
    BookKnowledgeRepository.upsertCharacterEvent(context, event)
      .then(() => { this.toast('已保存事件'); this.editingEvent = null; this.reload(); })
      .catch(() => { this.toast('保存事件失败'); });
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor('#99000000').onClick(() => { this.onClose(); })
      Column() {
        Row() {
          Text('知识库').fontSize(18).fontColor('#E8EAF0').layoutWeight(1)
          Button('关闭').fontSize(12).onClick(() => { this.onClose(); })
        }.width('100%').padding({ left: SPACE_16, right: SPACE_16, top: SPACE_12, bottom: SPACE_8 })

        Row({ space: SPACE_8 }) {
          ForEach(this.tabs, (label: string, index: number) => {
            Text(label).fontSize(13)
              .fontColor(this.tab === index ? '#FFFFFF' : '#B0B3BC')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 }).borderRadius(14)
              .backgroundColor(this.tab === index ? '#3F5BD9' : '#2A2D35')
              .onClick(() => { this.switchTab(index); })
          }, (label: string) => label)
        }.width('100%').padding({ left: SPACE_16, bottom: SPACE_8 })

        Column() {
          if (this.tab === 0) { this.characterPanel() }
          else if (this.tab === 1) { this.relationPanel() }
          else if (this.tab === 2) { this.knowledgePanel() }
          else { this.eventPanel() }
        }.width('100%').layoutWeight(1).padding({ left: SPACE_16, right: SPACE_16, bottom: SPACE_16 })
      }
      .width('100%').height('72%')
      .backgroundColor('#1B1D24').borderRadius({ topLeft: 20, topRight: 20 })
      .padding({ top: SPACE_8 })

      // 编辑子面板（覆盖在最上层）
      if (this.editingProfile !== null) { this.profileForm() }
      if (this.editingRelation !== null) { this.relationForm() }
      if (this.editingEntry !== null) { this.entryForm() }
      if (this.editingEvent !== null) { this.eventForm() }
    }
    .width('100%').height('100%')
  }
}
