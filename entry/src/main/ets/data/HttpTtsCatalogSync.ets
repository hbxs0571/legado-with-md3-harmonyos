import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { relationalStore } from '@kit.ArkData';
import { ReadAloudVoice, READ_ALOUD_VOICE_ENGINE_HTTP, READ_ALOUD_VOICE_MANAGED_BY_HTTP_SOURCE_CATALOG,
  copyReadAloudVoice } from '../model/ReadAloudVoice';
import { HttpTtsCatalogDraft, HttpTtsEmotionDraft } from './HttpTtsImporter';
import { ReadAloudVoiceRepository } from './ReadAloudVoiceRepository';

/**
 * httpTTS 源自带目录（speakersJson / emotionsJson）同步进 read_aloud_voices。
 *
 * 对应上游 `domain/usecase/SyncHttpTtsCatalogUseCase.kt` + `SyncReadAloudVoicesUseCase.kt`：
 *  - 目录的权威副本是表里那些行，不是源 JSON；导入之后改引擎、删引擎都只动表，源 JSON 不回写。
 *  - 音色 id 由 engineType + engineId + speakerId 推出（`SpeechIdentity.kt:8-9` 的 `voice:` + SHA-256 前 32 位），
 *    同一条源重复导入不会翻倍。
 *  - 回收范围限定在 engineId 这一个引擎上：上游默认按 managedBy 全局回收，直接用会把别的引擎的目录行
 *    当成「本次没出现」删掉（`SyncReadAloudVoicesUseCase.kt:18-22`）。
 */

/** 同步结果计数，对应上游 `SyncReadAloudVoicesResult`。 */
export interface SyncReadAloudVoicesResult {
  inserted: number;
  updated: number;
  unavailable: number;
}

/** 待写入目录的一行，对应上游 `VoiceCatalogEntry`。 */
interface VoiceCatalogEntry {
  engineType: string;
  engineId: string;
  speakerId: string;
  displayName: string;
  traitsJson: string;
  emotionCatalogJson: string;
  sourceRevision: number;
  managedBy: string;
}

/** 32 位小写十六进制 SHA-256，对应上游 `SpeechIdentity.sha256`。 */
function sha256Hex(text: string): string {
  const md = cryptoFramework.createMd('SHA256');
  md.updateSync({ data: new Uint8Array(new util.TextEncoder().encodeInto(text)) });
  const digest = md.digestSync();
  let hex: string = '';
  for (let index = 0; index < digest.data.length; index++) {
    hex += (digest.data[index] as number).toString(16).padStart(2, '0');
  }
  return hex;
}

/**
 * 音色主键：`voice:` + SHA-256(engineType \0 engineId \0 speakerId) 的前 32 个十六进制字符。
 * 上游用 \u0000 作分隔符，这里同样用 `\0` 拼，避免三段拼接出现歧义。
 */
export function voiceIdOf(engineType: string, engineId: string, speakerId: string): string {
  const raw: string = `${engineType}\u0000${engineId}\u0000${speakerId}`;
  return `voice:${sha256Hex(raw).substring(0, 32)}`;
}

/** 情绪目录整体序列化成 JSON，挂到该引擎每个音色上（上游同样按引擎级整份挂）。 */
function emotionsJsonOf(emotions: HttpTtsEmotionDraft[]): string {
  const items: Object[] = [];
  for (let index = 0; index < emotions.length; index++) {
    const emotion = emotions[index];
    const item: Record<string, string> = {};
    item['emotionName'] = emotion.emotionName;
    item['emotionTag'] = emotion.emotionTag;
    items.push(item);
  }
  return JSON.stringify(items);
}

/** tags 数组序列化，与上游 `GSON.toJson(speaker.tags)` 等价。 */
function tagsJsonOf(tags: string[]): string {
  return JSON.stringify(tags);
}

export class HttpTtsCatalogSync {
  /**
   * 源没带目录时什么都不做。
   *
   * 不能顺势清空：旧备份及不带目录的源更新没有 speakersJson 字段，恢复时会把每个源
   * 都当成「新版去掉了目录」，把用户已有的目录整批删掉（上游 `SyncHttpTtsCatalogUseCase.kt:22-28`）。
   */
  static async syncCatalog(store: relationalStore.RdbStore, engineId: string,
    draft: HttpTtsCatalogDraft, sourceRevision: number): Promise<SyncReadAloudVoicesResult> {
    if (draft.speakers.length === 0) {
      return { inserted: 0, updated: 0, unavailable: 0 };
    }
    const emotionCatalogJson: string = emotionsJsonOf(draft.emotions);
    const entries: VoiceCatalogEntry[] = [];
    for (let index = 0; index < draft.speakers.length; index++) {
      const speaker = draft.speakers[index];
      entries.push({
        engineType: READ_ALOUD_VOICE_ENGINE_HTTP,
        engineId: engineId,
        speakerId: speaker.toneID,
        displayName: speaker.speakerName,
        traitsJson: tagsJsonOf(speaker.tags),
        // 情绪在源里是引擎级的，整份挂到每个音色上：播放时按音色取，不用再回落引擎行
        emotionCatalogJson: emotionCatalogJson,
        sourceRevision: sourceRevision,
        managedBy: READ_ALOUD_VOICE_MANAGED_BY_HTTP_SOURCE_CATALOG
      });
    }
    return HttpTtsCatalogSync.sync(store, entries, [READ_ALOUD_VOICE_MANAGED_BY_HTTP_SOURCE_CATALOG],
      [READ_ALOUD_VOICE_ENGINE_HTTP], engineId);
  }

  /** 引擎被删除时清掉它上一次导入留下的行，否则这些目录行会变成孤儿（上游 `clear`）。 */
  static async clear(store: relationalStore.RdbStore, engineId: string): Promise<SyncReadAloudVoicesResult> {
    return HttpTtsCatalogSync.sync(store, [], [READ_ALOUD_VOICE_MANAGED_BY_HTTP_SOURCE_CATALOG],
      [READ_ALOUD_VOICE_ENGINE_HTTP], engineId);
  }

  /**
   * 目录同步主体，照 `SyncReadAloudVoicesUseCase.kt:29-99` 逐行移植：
   *  - 按 (engineType, engineId, speakerId) 去重后算 id；
   *  - metadataChanged 比八个字段，revision 三分支；
   *  - enabled / excluded / createdAt 保留旧值（用户排除过的音色不能因为源重新导入而复活）；
   *  - 回收段：本次没出现、且 managedBy 在 managedSources、且属于 managedScope 的行，
   *    engineType 在 removeMissingEngineTypes 里就删，否则置 available = false。
   */
  static async sync(store: relationalStore.RdbStore, entries: VoiceCatalogEntry[], managedSources: string[],
    removeMissingEngineTypes: string[], engineIdScope: string): Promise<SyncReadAloudVoicesResult> {
    const existing: ReadAloudVoice[] =
      await ReadAloudVoiceRepository.readRows(store, ReadAloudVoiceRepository.selectHttpAll);
    const existingById: Map<string, ReadAloudVoice> = new Map<string, ReadAloudVoice>();
    for (let index = 0; index < existing.length; index++) {
      existingById.set(existing[index].id, existing[index]);
    }
    // 上游 distinctBy { Triple(...) }：同一 (engineType, engineId, speakerId) 只保留第一条
    const seen: Set<string> = new Set<string>();
    const incomingIds: string[] = [];
    const incomingEntries: VoiceCatalogEntry[] = [];
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index];
      const dedupeKey: string = `${entry.engineType}\u0000${entry.engineId}\u0000${entry.speakerId}`;
      if (seen.has(dedupeKey)) {
        continue;
      }
      seen.add(dedupeKey);
      incomingEntries.push(entry);
      incomingIds.push(voiceIdOf(entry.engineType, entry.engineId, entry.speakerId));
    }

    const now: number = Date.now();
    let inserted: number = 0;
    let updated: number = 0;
    for (let index = 0; index < incomingEntries.length; index++) {
      const entry = incomingEntries[index];
      const id = incomingIds[index];
      const old: ReadAloudVoice | undefined = existingById.get(id);
      const metadataChanged: boolean = old === undefined ||
        old.engineType !== entry.engineType ||
        old.engineId !== entry.engineId ||
        old.speakerId !== entry.speakerId ||
        old.displayName !== entry.displayName ||
        old.traitsJson !== entry.traitsJson ||
        old.emotionCatalogJson !== entry.emotionCatalogJson ||
        old.managedBy !== entry.managedBy;
      let revision: number;
      if (old === undefined) {
        revision = entry.sourceRevision;
      } else if (metadataChanged) {
        revision = Math.max(entry.sourceRevision, old.revision + 1);
      } else {
        revision = Math.max(entry.sourceRevision, old.revision);
      }
      const voice: ReadAloudVoice = {
        id: id,
        engineType: entry.engineType,
        engineId: entry.engineId,
        speakerId: entry.speakerId,
        displayName: entry.displayName,
        traitsJson: entry.traitsJson,
        emotionCatalogJson: entry.emotionCatalogJson,
        managedBy: entry.managedBy,
        enabled: old === undefined ? true : old.enabled,
        available: true,
        // 用户排除过的音色不能因为源重新导入而复活
        excluded: old === undefined ? false : old.excluded,
        revision: revision,
        createdAt: old === undefined ? now : old.createdAt,
        updatedAt: (old === undefined || metadataChanged || !old.available || revision !== old.revision)
          ? now : old.updatedAt
      };
      if (old === undefined) {
        inserted += 1;
        await ReadAloudVoiceRepository.insertVoice(store, voice);
      } else if (!HttpTtsCatalogSync.sameVoice(voice, old)) {
        updated += 1;
        await ReadAloudVoiceRepository.insertVoice(store, voice);
      }
    }

    let unavailable: number = 0;
    for (let index = 0; index < existing.length; index++) {
      const voice = existing[index];
      if (managedSources.indexOf(voice.managedBy) < 0) {
        continue;
      }
      if (voice.engineId !== engineIdScope) {
        continue;
      }
      if (incomingIds.indexOf(voice.id) >= 0) {
        continue;
      }
      if (removeMissingEngineTypes.indexOf(voice.engineType) >= 0) {
        unavailable += 1;
        await ReadAloudVoiceRepository.deleteVoice(store, voice.id);
      } else if (voice.available) {
        unavailable += 1;
        const stale: ReadAloudVoice = copyReadAloudVoice(voice);
        stale.available = false;
        stale.updatedAt = now;
        await ReadAloudVoiceRepository.insertVoice(store, stale);
      }
    }
    return { inserted: inserted, updated: updated, unavailable: unavailable };
  }

  /** 逐字段比较，等价 Kotlin 的 data class `voice != old`。 */
  private static sameVoice(left: ReadAloudVoice, right: ReadAloudVoice): boolean {
    return left.id === right.id &&
      left.engineType === right.engineType &&
      left.engineId === right.engineId &&
      left.speakerId === right.speakerId &&
      left.displayName === right.displayName &&
      left.traitsJson === right.traitsJson &&
      left.emotionCatalogJson === right.emotionCatalogJson &&
      left.managedBy === right.managedBy &&
      left.enabled === right.enabled &&
      left.available === right.available &&
      left.excluded === right.excluded &&
      left.revision === right.revision &&
      left.createdAt === right.createdAt &&
      left.updatedAt === right.updatedAt;
  }
}
