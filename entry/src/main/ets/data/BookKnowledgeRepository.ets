import { relationalStore } from '@kit.ArkData';
import { RdbStore } from './RdbStore';
import { RdbSchema } from './RdbSchema';
import { RdbCodec } from './RdbCodec';

/**
 * 知识库五表的仓储，逐一对应上游 `BookKnowledgeDao.kt` 的方法名与 SQL。
 *
 * 批8 B 组（:370-:374）：上游 `source` 默认值是 SOURCE_USER，手工录入是一等路径；
 * AI 抽取那一半依赖 AiToolRepository（本地 0 命中），不在本仓储范围。
 * 查询 SQL 逐字照抄上游 DAO 的八条 @Query（含 coalesce / order by / limit），
 * 可空参数用 `? is null` 让绑定 null 时条件恒真，与 Room 的 `:x is null` 等价。
 */

// ===== 常量，照抄上游 BookKnowledge.kt 的 companion object =====
export const BK_STATUS_DRAFT: number = 0;
export const BK_STATUS_ACTIVE: number = 1;
export const BK_STATUS_DISABLED: number = 2;
export const BK_STATUS_DELETED: number = 3;

export const BK_SOURCE_USER: string = 'user';
export const BK_SOURCE_AI: string = 'ai';
export const BK_SOURCE_IMPORT: string = 'import';

export const BK_ROLE_MALE_LEAD: string = 'male_lead';
export const BK_ROLE_FEMALE_LEAD: string = 'female_lead';
export const BK_ROLE_MALE_SUPPORTING: string = 'male_supporting';
export const BK_ROLE_FEMALE_SUPPORTING: string = 'female_supporting';

export const BK_TYPE_WORLD_RULE: string = 'world_rule';
export const BK_TYPE_LOCATION: string = 'location';
export const BK_TYPE_FACTION: string = 'faction';
export const BK_TYPE_OBJECT: string = 'object';
export const BK_TYPE_TERMINOLOGY: string = 'terminology';
export const BK_TYPE_TIMELINE: string = 'timeline';
export const BK_TYPE_STYLE: string = 'style';
export const BK_TYPE_THEME: string = 'theme';

/** 上游角色筛选顺序：全部 / 男配 / 女配 / 男主 / 女主。 */
export const BK_ROLE_FILTERS: string[] = [
  '', BK_ROLE_MALE_SUPPORTING, BK_ROLE_FEMALE_SUPPORTING, BK_ROLE_MALE_LEAD, BK_ROLE_FEMALE_LEAD
];

/** 生成主键：上游是 UUID，本地用时间戳 + 随机串，进程内与跨重启都保证唯一。 */
function newBkId(): string {
  return `${Date.now().toString(36)}-${Math.floor(Math.random() * 1e9).toString(36)}`;
}

// ===== 五个实体接口，逐字段对齐上游 Room 实体 =====
export interface CharacterProfile {
  id: string;
  bookUrl: string;
  name: string;
  aliasesJson: string;
  avatarUri?: string;
  tagsJson: string;
  role: string;
  voiceGender: string;
  voiceAgeBand: string;
  personality: string;
  summary: string;
  status: number;
  source: string;
  confidence: number;
  schemaVersion: number;
  createdAt: number;
  updatedAt: number;
}

export interface CharacterEvent {
  id: string;
  bookUrl: string;
  characterId: string;
  chapterIndex?: number;
  chapterTitle: string;
  eventTimeText: string;
  content: string;
  importance: number;
  sourceTextHash?: string;
  evidenceJson: string;
  source: string;
  confidence: number;
  schemaVersion: number;
  createdAt: number;
  updatedAt: number;
}

export interface CharacterRelation {
  id: string;
  bookUrl: string;
  fromCharacterId: string;
  toCharacterId: string;
  relationType: string;
  summary: string;
  attitude: string;
  evidenceJson: string;
  chapterIndex?: number;
  status: number;
  source: string;
  confidence: number;
  schemaVersion: number;
  createdAt: number;
  updatedAt: number;
}

export interface KnowledgeEntry {
  id: string;
  bookUrl: string;
  type: string;
  title: string;
  keywordsJson: string;
  content: string;
  scopeStartChapter?: number;
  scopeEndChapter?: number;
  priority: number;
  source: string;
  confidence: number;
  evidenceJson: string;
  schemaVersion: number;
  createdAt: number;
  updatedAt: number;
}

export interface OutlineNode {
  id: string;
  bookUrl: string;
  parentId?: string;
  nodeType: string;
  title: string;
  summary: string;
  startChapterIndex?: number;
  endChapterIndex?: number;
  order: number;
  source: string;
  confidence: number;
  schemaVersion: number;
  createdAt: number;
  updatedAt: number;
}

/** 新建实体用的最小入参，其余字段在 create* 里填上游默认值。 */
export interface NewCharacterProfile {
  name: string;
  aliasesJson?: string;
  avatarUri?: string;
  tagsJson?: string;
  role?: string;
  personality?: string;
  summary?: string;
  status?: number;
}
export interface NewCharacterRelation {
  fromCharacterId: string;
  toCharacterId: string;
  relationType: string;
  summary?: string;
  attitude?: string;
  chapterIndex?: number;
}
export interface NewKnowledgeEntry {
  type: string;
  title: string;
  keywordsJson?: string;
  content?: string;
  scopeStartChapter?: number;
  scopeEndChapter?: number;
  priority?: number;
}
export interface NewCharacterEvent {
  characterId: string;
  chapterIndex?: number;
  chapterTitle?: string;
  eventTimeText?: string;
  content: string;
  importance?: number;
}

export class BookKnowledgeRepository {
  // ===== 查询方法，SQL 逐字照抄 BookKnowledgeDao.kt =====

  static async searchCharacterProfiles(context: Context, bookUrl: string, query: string,
    limit: number): Promise<CharacterProfile[]> {
    const sql = 'select * from book_character_profiles where bookUrl = ? and status != ' +
      BK_STATUS_DELETED.toString() +
      " and (? = '' or name like '%' || ? || '%' or aliasesJson like '%' || ? || '%' or summary like '%' || ? || '%')" +
      ' order by updatedAt desc limit ?';
    const args: relationalStore.ValueType[] = [bookUrl, query, query, query, query, limit];
    return await BookKnowledgeRepository.queryProfiles(context, sql, args);
  }

  static async getCharacterProfiles(context: Context, bookUrl: string,
    limit: number): Promise<CharacterProfile[]> {
    const sql = 'select * from book_character_profiles where bookUrl = ? and status != ' +
      BK_STATUS_DELETED.toString() + ' order by updatedAt desc limit ?';
    return await BookKnowledgeRepository.queryProfiles(context, sql, [bookUrl, limit]);
  }

  static async getCharacterProfile(context: Context, bookUrl: string,
    idOrName: string): Promise<CharacterProfile | undefined> {
    const sql = 'select * from book_character_profiles where bookUrl = ? and status != ' +
      BK_STATUS_DELETED.toString() +
      " and (id = ? or name = ? or aliasesJson like '%' || ? || '%')" +
      ' order by updatedAt desc limit 1';
    const rows = await BookKnowledgeRepository.queryProfiles(context, sql,
      [bookUrl, idOrName, idOrName, idOrName]);
    return rows.length > 0 ? rows[0] : undefined;
  }

  static async getCharacterEvents(context: Context, bookUrl: string, characterId: string | undefined,
    maxChapterIndex: number | undefined, limit: number): Promise<CharacterEvent[]> {
    const sql = 'select * from book_character_events where bookUrl = ? ' +
      'and (? is null or characterId = ?) ' +
      'and (? is null or chapterIndex is null or chapterIndex <= ?) ' +
      'order by coalesce(chapterIndex, 2147483647), importance desc, updatedAt desc limit ?';
    const args: relationalStore.ValueType[] = [
      bookUrl, characterId ?? null, characterId ?? null,
      maxChapterIndex ?? null, maxChapterIndex ?? null, limit
    ];
    return await BookKnowledgeRepository.queryEvents(context, sql, args);
  }

  static async getCharacterRelations(context: Context, bookUrl: string, characterId: string,
    limit: number): Promise<CharacterRelation[]> {
    const sql = 'select * from book_character_relations where bookUrl = ? and status != ' +
      BK_STATUS_DELETED.toString() +
      ' and (fromCharacterId = ? or toCharacterId = ?) order by updatedAt desc limit ?';
    return await BookKnowledgeRepository.queryRelations(context, sql, [bookUrl, characterId, characterId, limit]);
  }

  static async getBookCharacterRelations(context: Context, bookUrl: string,
    limit: number): Promise<CharacterRelation[]> {
    const sql = 'select * from book_character_relations where bookUrl = ? and status != ' +
      BK_STATUS_DELETED.toString() + ' order by updatedAt desc limit ?';
    return await BookKnowledgeRepository.queryRelations(context, sql, [bookUrl, limit]);
  }

  static async searchKnowledgeEntries(context: Context, bookUrl: string, query: string,
    type: string | undefined, chapterIndex: number | undefined, limit: number): Promise<KnowledgeEntry[]> {
    const sql = 'select * from book_knowledge_entries where bookUrl = ? ' +
      'and (? is null or type = ?) ' +
      'and (? is null or (scopeStartChapter is null or scopeStartChapter <= ?) ' +
      'and (scopeEndChapter is null or scopeEndChapter >= ?)) ' +
      "and (? = '' or title like '%' || ? || '%' or keywordsJson like '%' || ? || '%' or content like '%' || ? || '%') " +
      'order by priority desc, updatedAt desc limit ?';
    const args: relationalStore.ValueType[] = [
      bookUrl, type ?? null, type ?? null,
      chapterIndex ?? null, chapterIndex ?? null, chapterIndex ?? null,
      query, query, query, query, limit
    ];
    return await BookKnowledgeRepository.queryEntries(context, sql, args);
  }

  static async getOutlineNodes(context: Context, bookUrl: string, chapterIndex: number | undefined,
    nodeType: string | undefined, limit: number): Promise<OutlineNode[]> {
    const sql = 'select * from book_outline_nodes where bookUrl = ? ' +
      'and (? is null or nodeType = ?) ' +
      'and (? is null or (startChapterIndex is null or startChapterIndex <= ?) ' +
      'and (endChapterIndex is null or endChapterIndex >= ?)) ' +
      'order by coalesce(startChapterIndex, -1), `order`, updatedAt desc limit ?';
    const args: relationalStore.ValueType[] = [
      bookUrl, nodeType ?? null, nodeType ?? null,
      chapterIndex ?? null, chapterIndex ?? null, chapterIndex ?? null, limit
    ];
    return await BookKnowledgeRepository.queryNodes(context, sql, args);
  }

  /** 关系唯一性预检：上游 unique 索引是 (bookUrl, fromCharacterId, toCharacterId)，不含 relationType。 */
  static async hasRelation(context: Context, bookUrl: string, fromId: string,
    toId: string): Promise<boolean> {
    const sql = 'select count(*) from book_character_relations where bookUrl = ? ' +
      'and fromCharacterId = ? and toCharacterId = ?';
    const store = await BookKnowledgeRepository.store(context);
    const resultSet = await store.querySql(sql, [bookUrl, fromId, toId]);
    try {
      if (!resultSet.goToNextRow()) { return false; }
      return RdbCodec.integer(resultSet, 0, 0) > 0;
    } finally {
      resultSet.close();
    }
  }

  // ===== 工厂：填上游默认值 =====

  static createProfile(bookUrl: string, input: NewCharacterProfile): CharacterProfile {
    const now = Date.now();
    return {
      id: newBkId(), bookUrl, name: input.name,
      aliasesJson: input.aliasesJson ?? '[]', avatarUri: input.avatarUri,
      tagsJson: input.tagsJson ?? '[]', role: input.role ?? '',
      voiceGender: 'unknown', voiceAgeBand: 'unknown',
      personality: input.personality ?? '', summary: input.summary ?? '',
      status: input.status ?? BK_STATUS_ACTIVE, source: BK_SOURCE_USER,
      confidence: 1, schemaVersion: 1, createdAt: now, updatedAt: now
    };
  }

  static createRelation(bookUrl: string, input: NewCharacterRelation): CharacterRelation {
    const now = Date.now();
    return {
      id: newBkId(), bookUrl, fromCharacterId: input.fromCharacterId, toCharacterId: input.toCharacterId,
      relationType: input.relationType, summary: input.summary ?? '', attitude: input.attitude ?? '',
      evidenceJson: '[]', chapterIndex: input.chapterIndex, status: BK_STATUS_ACTIVE,
      source: BK_SOURCE_USER, confidence: 1, schemaVersion: 1, createdAt: now, updatedAt: now
    };
  }

  static createEntry(bookUrl: string, input: NewKnowledgeEntry): KnowledgeEntry {
    const now = Date.now();
    return {
      id: newBkId(), bookUrl, type: input.type, title: input.title,
      keywordsJson: input.keywordsJson ?? '[]', content: input.content ?? '',
      scopeStartChapter: input.scopeStartChapter, scopeEndChapter: input.scopeEndChapter,
      priority: input.priority ?? 0, source: BK_SOURCE_USER, confidence: 1,
      evidenceJson: '[]', schemaVersion: 1, createdAt: now, updatedAt: now
    };
  }

  static createEvent(bookUrl: string, input: NewCharacterEvent): CharacterEvent {
    const now = Date.now();
    return {
      id: newBkId(), bookUrl, characterId: input.characterId, chapterIndex: input.chapterIndex,
      chapterTitle: input.chapterTitle ?? '', eventTimeText: input.eventTimeText ?? '',
      content: input.content, importance: input.importance ?? 0, sourceTextHash: undefined,
      evidenceJson: '[]', source: BK_SOURCE_USER, confidence: 1, schemaVersion: 1,
      createdAt: now, updatedAt: now
    };
  }

  // ===== 写入（INSERT OR REPLACE，对齐 Room 的 OnConflictStrategy.REPLACE） =====

  static async upsertCharacterProfile(context: Context, profile: CharacterProfile): Promise<void> {
    const sql = 'INSERT OR REPLACE INTO book_character_profiles ' +
      '(id, bookUrl, name, aliasesJson, avatarUri, tagsJson, role, voiceGender, voiceAgeBand, ' +
      'personality, summary, status, source, confidence, schemaVersion, createdAt, updatedAt) ' +
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
    const args: relationalStore.ValueType[] = [
      profile.id, profile.bookUrl, profile.name, profile.aliasesJson, profile.avatarUri ?? null,
      profile.tagsJson, profile.role, profile.voiceGender, profile.voiceAgeBand,
      profile.personality, profile.summary, profile.status, profile.source, profile.confidence,
      profile.schemaVersion, profile.createdAt, profile.updatedAt
    ];
    await (await BookKnowledgeRepository.store(context)).executeSql(sql, args);
  }

  static async upsertCharacterEvent(context: Context, event: CharacterEvent): Promise<void> {
    const sql = 'INSERT OR REPLACE INTO book_character_events ' +
      '(id, bookUrl, characterId, chapterIndex, chapterTitle, eventTimeText, content, importance, ' +
      'sourceTextHash, evidenceJson, source, confidence, schemaVersion, createdAt, updatedAt) ' +
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
    const args: relationalStore.ValueType[] = [
      event.id, event.bookUrl, event.characterId, event.chapterIndex ?? null,
      event.chapterTitle, event.eventTimeText, event.content, event.importance,
      event.sourceTextHash ?? null, event.evidenceJson, event.source, event.confidence,
      event.schemaVersion, event.createdAt, event.updatedAt
    ];
    await (await BookKnowledgeRepository.store(context)).executeSql(sql, args);
  }

  static async upsertCharacterRelation(context: Context, relation: CharacterRelation): Promise<void> {
    const sql = 'INSERT OR REPLACE INTO book_character_relations ' +
      '(id, bookUrl, fromCharacterId, toCharacterId, relationType, summary, attitude, evidenceJson, ' +
      'chapterIndex, status, source, confidence, schemaVersion, createdAt, updatedAt) ' +
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
    const args: relationalStore.ValueType[] = [
      relation.id, relation.bookUrl, relation.fromCharacterId, relation.toCharacterId,
      relation.relationType, relation.summary, relation.attitude, relation.evidenceJson,
      relation.chapterIndex ?? null, relation.status, relation.source, relation.confidence,
      relation.schemaVersion, relation.createdAt, relation.updatedAt
    ];
    await (await BookKnowledgeRepository.store(context)).executeSql(sql, args);
  }

  static async upsertKnowledgeEntry(context: Context, entry: KnowledgeEntry): Promise<void> {
    const sql = 'INSERT OR REPLACE INTO book_knowledge_entries ' +
      '(id, bookUrl, type, title, keywordsJson, content, scopeStartChapter, scopeEndChapter, ' +
      'priority, source, confidence, evidenceJson, schemaVersion, createdAt, updatedAt) ' +
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
    const args: relationalStore.ValueType[] = [
      entry.id, entry.bookUrl, entry.type, entry.title, entry.keywordsJson, entry.content,
      entry.scopeStartChapter ?? null, entry.scopeEndChapter ?? null, entry.priority,
      entry.source, entry.confidence, entry.evidenceJson, entry.schemaVersion,
      entry.createdAt, entry.updatedAt
    ];
    await (await BookKnowledgeRepository.store(context)).executeSql(sql, args);
  }

  static async upsertOutlineNode(context: Context, node: OutlineNode): Promise<void> {
    const sql = 'INSERT OR REPLACE INTO book_outline_nodes ' +
      '(id, bookUrl, parentId, nodeType, title, summary, startChapterIndex, endChapterIndex, ' +
      '`order`, source, confidence, schemaVersion, createdAt, updatedAt) ' +
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
    const args: relationalStore.ValueType[] = [
      node.id, node.bookUrl, node.parentId ?? null, node.nodeType, node.title, node.summary,
      node.startChapterIndex ?? null, node.endChapterIndex ?? null, node.order,
      node.source, node.confidence, node.schemaVersion, node.createdAt, node.updatedAt
    ];
    await (await BookKnowledgeRepository.store(context)).executeSql(sql, args);
  }

  // ===== 删除：逐条对齐上游 BookKnowledgeDao.kt:160-173 =====
  // 角色/关系明细/事件/知识是硬删；只有「删角色时连带处理关系」用 status=3 软删
  // （上游 :163 deleteRelationsForCharacter 是 update status=3）。
  // 改判说明：任务书 B.7 写「删角色 status=3」，但上游 BookKnowledgeDao.kt:160
  // 的 deleteCharacterProfile 是 `delete from` 硬删，按用户长期偏好「任务书与上游不符按上游」，
  // 角色硬删；status=3 用在上游真正使用它的关系表，与上游源码一致。

  static async deleteCharacterProfile(context: Context, bookUrl: string, characterId: string): Promise<void> {
    await (await BookKnowledgeRepository.store(context)).executeSql(
      'delete from book_character_profiles where bookUrl = ? and id = ?', [bookUrl, characterId]);
  }

  /** 删单条事件（面板删除按钮用）；上游 DAO 只按角色批量删，本地面板要能删单条。 */
  static async deleteCharacterEvent(context: Context, eventId: string): Promise<void> {
    await (await BookKnowledgeRepository.store(context)).executeSql(
      'delete from book_character_events where id = ?', [eventId]);
  }

  static async deleteRelationsForCharacter(context: Context, characterId: string): Promise<void> {
    await (await BookKnowledgeRepository.store(context)).executeSql(
      `update book_character_relations set status = ${BK_STATUS_DELETED.toString()} ` +
      'where fromCharacterId = ? or toCharacterId = ?', [characterId, characterId]);
  }

  static async deleteEventsForCharacter(context: Context, bookUrl: string, characterId: string): Promise<void> {
    await (await BookKnowledgeRepository.store(context)).executeSql(
      'delete from book_character_events where bookUrl = ? and characterId = ?', [bookUrl, characterId]);
  }

  static async deleteCharacterRelation(context: Context, relationId: string): Promise<void> {
    await (await BookKnowledgeRepository.store(context)).executeSql(
      'delete from book_character_relations where id = ?', [relationId]);
  }

  static async deleteKnowledgeEntry(context: Context, entryId: string): Promise<void> {
    await (await BookKnowledgeRepository.store(context)).executeSql(
      'delete from book_knowledge_entries where id = ?', [entryId]);
  }

  /**
   * 删书连带清五表。上游 DeleteBooksUseCase 会级联删这些内容，
   * 本地 relationalStore 外键 CASCADE 实测不生效，必须显式删，
   * 否则私密书的角色名还留在库里（数据泄漏）。
   */
  static async deleteBookKnowledge(context: Context, bookUrl: string): Promise<void> {
    const store = await BookKnowledgeRepository.store(context);
    const tables: string[] = [
      'book_character_profiles', 'book_character_events', 'book_character_relations',
      'book_knowledge_entries', 'book_outline_nodes'
    ];
    for (let i = 0; i < tables.length; i++) {
      await store.executeSql(`delete from ${tables[i]} where bookUrl = ?`, [bookUrl]);
    }
  }

  // ===== 私有：取库 + ResultSet 映射 =====

  private static async store(context: Context): Promise<relationalStore.RdbStore> {
    const store = await RdbStore.getStore(context);
    await RdbSchema.ensure(store);
    return store;
  }

  private static async queryProfiles(context: Context, sql: string,
    args: relationalStore.ValueType[]): Promise<CharacterProfile[]> {
    const resultSet = await (await BookKnowledgeRepository.store(context)).querySql(sql, args);
    const rows: CharacterProfile[] = [];
    try {
      while (resultSet.goToNextRow()) {
        rows.push({
          id: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'id')),
          bookUrl: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'bookUrl')),
          name: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'name')),
          aliasesJson: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'aliasesJson'), '[]'),
          avatarUri: RdbCodec.optionalText(resultSet, RdbCodec.column(resultSet, 'avatarUri')),
          tagsJson: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'tagsJson'), '[]'),
          role: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'role')),
          voiceGender: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'voiceGender'), 'unknown'),
          voiceAgeBand: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'voiceAgeBand'), 'unknown'),
          personality: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'personality')),
          summary: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'summary')),
          status: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'status'), BK_STATUS_ACTIVE),
          source: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'source'), BK_SOURCE_USER),
          confidence: RdbCodec.real(resultSet, RdbCodec.column(resultSet, 'confidence'), 1),
          schemaVersion: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'schemaVersion'), 1),
          createdAt: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'createdAt'), 0),
          updatedAt: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'updatedAt'), 0)
        });
      }
    } finally {
      resultSet.close();
    }
    return rows;
  }

  private static async queryEvents(context: Context, sql: string,
    args: relationalStore.ValueType[]): Promise<CharacterEvent[]> {
    const resultSet = await (await BookKnowledgeRepository.store(context)).querySql(sql, args);
    const rows: CharacterEvent[] = [];
    try {
      while (resultSet.goToNextRow()) {
        rows.push({
          id: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'id')),
          bookUrl: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'bookUrl')),
          characterId: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'characterId')),
          chapterIndex: RdbCodec.optionalInteger(resultSet, RdbCodec.column(resultSet, 'chapterIndex')),
          chapterTitle: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'chapterTitle')),
          eventTimeText: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'eventTimeText')),
          content: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'content')),
          importance: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'importance'), 0),
          sourceTextHash: RdbCodec.optionalText(resultSet, RdbCodec.column(resultSet, 'sourceTextHash')),
          evidenceJson: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'evidenceJson'), '[]'),
          source: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'source'), BK_SOURCE_USER),
          confidence: RdbCodec.real(resultSet, RdbCodec.column(resultSet, 'confidence'), 1),
          schemaVersion: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'schemaVersion'), 1),
          createdAt: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'createdAt'), 0),
          updatedAt: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'updatedAt'), 0)
        });
      }
    } finally {
      resultSet.close();
    }
    return rows;
  }

  private static async queryRelations(context: Context, sql: string,
    args: relationalStore.ValueType[]): Promise<CharacterRelation[]> {
    const resultSet = await (await BookKnowledgeRepository.store(context)).querySql(sql, args);
    const rows: CharacterRelation[] = [];
    try {
      while (resultSet.goToNextRow()) {
        rows.push({
          id: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'id')),
          bookUrl: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'bookUrl')),
          fromCharacterId: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'fromCharacterId')),
          toCharacterId: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'toCharacterId')),
          relationType: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'relationType')),
          summary: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'summary')),
          attitude: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'attitude')),
          evidenceJson: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'evidenceJson'), '[]'),
          chapterIndex: RdbCodec.optionalInteger(resultSet, RdbCodec.column(resultSet, 'chapterIndex')),
          status: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'status'), BK_STATUS_ACTIVE),
          source: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'source'), BK_SOURCE_USER),
          confidence: RdbCodec.real(resultSet, RdbCodec.column(resultSet, 'confidence'), 1),
          schemaVersion: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'schemaVersion'), 1),
          createdAt: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'createdAt'), 0),
          updatedAt: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'updatedAt'), 0)
        });
      }
    } finally {
      resultSet.close();
    }
    return rows;
  }

  private static async queryEntries(context: Context, sql: string,
    args: relationalStore.ValueType[]): Promise<KnowledgeEntry[]> {
    const resultSet = await (await BookKnowledgeRepository.store(context)).querySql(sql, args);
    const rows: KnowledgeEntry[] = [];
    try {
      while (resultSet.goToNextRow()) {
        rows.push({
          id: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'id')),
          bookUrl: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'bookUrl')),
          type: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'type')),
          title: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'title')),
          keywordsJson: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'keywordsJson'), '[]'),
          content: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'content')),
          scopeStartChapter: RdbCodec.optionalInteger(resultSet, RdbCodec.column(resultSet, 'scopeStartChapter')),
          scopeEndChapter: RdbCodec.optionalInteger(resultSet, RdbCodec.column(resultSet, 'scopeEndChapter')),
          priority: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'priority'), 0),
          source: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'source'), BK_SOURCE_USER),
          confidence: RdbCodec.real(resultSet, RdbCodec.column(resultSet, 'confidence'), 1),
          evidenceJson: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'evidenceJson'), '[]'),
          schemaVersion: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'schemaVersion'), 1),
          createdAt: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'createdAt'), 0),
          updatedAt: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'updatedAt'), 0)
        });
      }
    } finally {
      resultSet.close();
    }
    return rows;
  }

  private static async queryNodes(context: Context, sql: string,
    args: relationalStore.ValueType[]): Promise<OutlineNode[]> {
    const resultSet = await (await BookKnowledgeRepository.store(context)).querySql(sql, args);
    const rows: OutlineNode[] = [];
    try {
      while (resultSet.goToNextRow()) {
        rows.push({
          id: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'id')),
          bookUrl: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'bookUrl')),
          parentId: RdbCodec.optionalText(resultSet, RdbCodec.column(resultSet, 'parentId')),
          nodeType: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'nodeType')),
          title: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'title')),
          summary: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'summary')),
          startChapterIndex: RdbCodec.optionalInteger(resultSet, RdbCodec.column(resultSet, 'startChapterIndex')),
          endChapterIndex: RdbCodec.optionalInteger(resultSet, RdbCodec.column(resultSet, 'endChapterIndex')),
          order: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'order'), 0),
          source: RdbCodec.text(resultSet, RdbCodec.column(resultSet, 'source'), BK_SOURCE_USER),
          confidence: RdbCodec.real(resultSet, RdbCodec.column(resultSet, 'confidence'), 1),
          schemaVersion: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'schemaVersion'), 1),
          createdAt: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'createdAt'), 0),
          updatedAt: RdbCodec.integer(resultSet, RdbCodec.column(resultSet, 'updatedAt'), 0)
        });
      }
    } finally {
      resultSet.close();
    }
    return rows;
  }
}
