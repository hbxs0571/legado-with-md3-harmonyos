import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { BookGroup } from '../model/BookGroup';

interface AndroidBookGroupRecord {
  groupId?: number;
  groupName?: string;
  order?: number;
  show?: boolean;
  enableRefresh?: boolean;
  bookSort?: number;
  isPrivate?: boolean;
}

/** 持久化 Android 兼容书架分组，并在 HOS 页面间提供稳定映射。 */
export class BookGroupRepository {
  private static readonly preferenceName: string = 'book_group_store';
  private static readonly groupsKey: string = 'android_groups_v1';
  private static groups: BookGroup[] = [];
  private static loaded: boolean = false;
  private static saveQueue: Promise<void> = Promise.resolve();

  static getAll(): BookGroup[] {
    return BookGroupRepository.groups.map((group: BookGroup) => BookGroupRepository.copyGroup(group));
  }

  static getVisibleUserGroups(): BookGroup[] {
    return BookGroupRepository.groups
      .filter((group: BookGroup) => group.groupId > 0 && group.show)
      .sort((left: BookGroup, right: BookGroup) => left.order - right.order)
      .map((group: BookGroup) => BookGroupRepository.copyGroup(group));
  }

  static async load(context: Context): Promise<BookGroup[]> {
    if (BookGroupRepository.loaded) { return BookGroupRepository.getAll(); }
    let loadedGroups: BookGroup[] = [];
    try {
      const store = await preferences.getPreferences(context, BookGroupRepository.preferenceName);
      const saved = await store.get(BookGroupRepository.groupsKey, '');
      if (typeof saved === 'string' && saved.length > 0) {
        loadedGroups = BookGroupRepository.parseStoredGroups(saved);
      } else {
        loadedGroups = BookGroupRepository.readPreservedAndroidGroups(context);
        await BookGroupRepository.persist(context, loadedGroups);
      }
    } catch (_) {
      loadedGroups = BookGroupRepository.readPreservedAndroidGroups(context);
    }
    BookGroupRepository.groups = BookGroupRepository.normalize(loadedGroups);
    BookGroupRepository.loaded = true;
    return BookGroupRepository.getAll();
  }

  /** 导入 Android 分组定义；同 ID 的定义以本次恢复内容为准。 */
  static async importAndroidFile(context: Context, path: string): Promise<BookGroup[]> {
    if (!fileIo.accessSync(path)) { return BookGroupRepository.getAll(); }
    let imported: BookGroup[] = [];
    try {
      const parsed: AndroidBookGroupRecord[] = JSON.parse(fileIo.readTextSync(path));
      imported = parsed.filter((group: AndroidBookGroupRecord) =>
        typeof group.groupId === 'number' && Number.isSafeInteger(group.groupId) && typeof group.groupName === 'string')
        .map((group: AndroidBookGroupRecord, index: number) => BookGroupRepository.fromAndroidRecord(group, index));
    } catch (_) {
      throw new Error('Android 分组文件格式不正确');
    }
    const merged = BookGroupRepository.groups.filter((current: BookGroup) =>
      !imported.some((incoming: BookGroup) => incoming.groupId === current.groupId)).concat(imported);
    await BookGroupRepository.persist(context, merged);
    return BookGroupRepository.getAll();
  }

  static async add(context: Context, name: string): Promise<BookGroup> {
    const normalized = name.trim();
    if (normalized.length === 0) { throw new Error('分组名称不能为空'); }
    if (BookGroupRepository.groups.some((group: BookGroup) => group.groupId > 0 && group.groupName === normalized)) {
      throw new Error('分组名称已存在');
    }
    let groupId: number = 1;
    while (BookGroupRepository.groups.some((group: BookGroup) => group.groupId === groupId)) {
      groupId *= 2;
      if (groupId > Number.MAX_SAFE_INTEGER / 2) { throw new Error('Android 分组 ID 已用尽'); }
    }
    const group: BookGroup = {
      groupId: groupId,
      groupName: normalized,
      order: BookGroupRepository.groups.filter((item: BookGroup) => item.groupId > 0).length,
      show: true,
      enableRefresh: true,
      bookSort: -1,
      isPrivate: false
    };
    await BookGroupRepository.persist(context, [...BookGroupRepository.groups, group]);
    return BookGroupRepository.copyGroup(group);
  }

  static async rename(context: Context, groupId: number, name: string): Promise<void> {
    const normalized = name.trim();
    if (normalized.length === 0) { throw new Error('分组名称不能为空'); }
    const current = BookGroupRepository.groups.find((group: BookGroup) => group.groupId === groupId);
    if (current === undefined || groupId <= 0) { throw new Error('只能重命名自定义分组'); }
    if (BookGroupRepository.groups.some((group: BookGroup) =>
      group.groupId > 0 && group.groupId !== groupId && group.groupName === normalized)) {
      throw new Error('分组名称已存在');
    }
    await BookGroupRepository.persist(context, BookGroupRepository.groups.map((group: BookGroup) =>
      group.groupId === groupId ? BookGroupRepository.withName(group, normalized) : BookGroupRepository.copyGroup(group)));
  }

  static async setVisible(context: Context, groupId: number, visible: boolean): Promise<void> {
    await BookGroupRepository.persist(context, BookGroupRepository.groups.map((group: BookGroup) =>
      group.groupId === groupId && group.groupId > 0 ? BookGroupRepository.withVisibility(group, visible) :
        BookGroupRepository.copyGroup(group)));
  }

  static async remove(context: Context, groupId: number): Promise<void> {
    if (groupId <= 0 || !BookGroupRepository.groups.some((group: BookGroup) => group.groupId === groupId)) {
      throw new Error('只能删除自定义分组');
    }
    const remaining = BookGroupRepository.groups
      .filter((group: BookGroup) => group.groupId !== groupId)
      .map((group: BookGroup, index: number) => group.groupId > 0
        ? BookGroupRepository.withOrder(group, index) : BookGroupRepository.copyGroup(group));
    await BookGroupRepository.persist(context, remaining);
  }

  static namesFromMask(mask: number): string[] {
    if (!Number.isSafeInteger(mask) || mask <= 0) { return []; }
    return BookGroupRepository.groups
      .filter((group: BookGroup) => group.groupId > 0 && Math.floor(mask / group.groupId) % 2 === 1)
      .sort((left: BookGroup, right: BookGroup) => left.order - right.order)
      .map((group: BookGroup) => group.groupName);
  }

  static maskFromNames(names: string[]): number {
    let mask: number = 0;
    names.forEach((name: string) => {
      const group = BookGroupRepository.groups.find((item: BookGroup) => item.groupId > 0 && item.groupName === name);
      if (group !== undefined) { mask += group.groupId; }
    });
    return mask;
  }

  static exportAndroidGroups(): string {
    const ordered = BookGroupRepository.groups.slice()
      .sort((left: BookGroup, right: BookGroup) => left.order - right.order);
    return JSON.stringify(ordered.map((group: BookGroup) => BookGroupRepository.toAndroidRecord(group)), null, 2);
  }

  private static copyGroup(group: BookGroup): BookGroup {
    const copy: BookGroup = {
      groupId: group.groupId, groupName: group.groupName, order: group.order, show: group.show,
      enableRefresh: group.enableRefresh, bookSort: group.bookSort, isPrivate: group.isPrivate
    };
    return copy;
  }

  private static withName(group: BookGroup, name: string): BookGroup {
    const copy: BookGroup = {
      groupId: group.groupId, groupName: name, order: group.order, show: group.show,
      enableRefresh: group.enableRefresh, bookSort: group.bookSort, isPrivate: group.isPrivate
    };
    return copy;
  }

  private static withVisibility(group: BookGroup, visible: boolean): BookGroup {
    const copy: BookGroup = {
      groupId: group.groupId, groupName: group.groupName, order: group.order, show: visible,
      enableRefresh: group.enableRefresh, bookSort: group.bookSort, isPrivate: group.isPrivate
    };
    return copy;
  }

  private static withOrder(group: BookGroup, order: number): BookGroup {
    const copy: BookGroup = {
      groupId: group.groupId, groupName: group.groupName, order: order, show: group.show,
      enableRefresh: group.enableRefresh, bookSort: group.bookSort, isPrivate: group.isPrivate
    };
    return copy;
  }

  private static fromAndroidRecord(record: AndroidBookGroupRecord, fallbackOrder: number): BookGroup {
    const group: BookGroup = {
      groupId: record.groupId ?? 0,
      groupName: (record.groupName ?? '').trim(),
      order: typeof record.order === 'number' ? record.order : fallbackOrder,
      show: record.show !== false,
      enableRefresh: record.enableRefresh !== false,
      bookSort: typeof record.bookSort === 'number' ? record.bookSort : -1,
      isPrivate: record.isPrivate === true
    };
    return group;
  }

  private static toAndroidRecord(group: BookGroup): AndroidBookGroupRecord {
    const record: AndroidBookGroupRecord = {
      groupId: group.groupId, groupName: group.groupName, order: group.order, show: group.show,
      enableRefresh: group.enableRefresh, bookSort: group.bookSort, isPrivate: group.isPrivate
    };
    return record;
  }

  private static readPreservedAndroidGroups(context: Context): BookGroup[] {
    const path = `${context.filesDir}/android-backup-entries/bookGroup.json`;
    if (!fileIo.accessSync(path)) { return []; }
    try {
      const parsed: AndroidBookGroupRecord[] = JSON.parse(fileIo.readTextSync(path));
      return parsed.filter((group: AndroidBookGroupRecord) =>
        typeof group.groupId === 'number' && Number.isSafeInteger(group.groupId) && typeof group.groupName === 'string')
        .map((group: AndroidBookGroupRecord, index: number) => BookGroupRepository.fromAndroidRecord(group, index));
    } catch (_) {
      return [];
    }
  }

  private static parseStoredGroups(text: string): BookGroup[] {
    try {
      const parsed: BookGroup[] = JSON.parse(text);
      return BookGroupRepository.normalize(parsed);
    } catch (_) {
      return [];
    }
  }

  private static normalize(groups: BookGroup[]): BookGroup[] {
    const normalized: BookGroup[] = [];
    groups.forEach((group: BookGroup) => {
      if (!Number.isSafeInteger(group.groupId) || typeof group.groupName !== 'string' ||
        group.groupName.trim().length === 0 || normalized.some((item: BookGroup) => item.groupId === group.groupId)) {
        return;
      }
      normalized.push({
        groupId: group.groupId,
        groupName: group.groupName.trim(),
        order: Number.isInteger(group.order) ? group.order : normalized.length,
        show: group.show !== false,
        enableRefresh: group.enableRefresh !== false,
        bookSort: Number.isInteger(group.bookSort) ? group.bookSort : -1,
        isPrivate: group.isPrivate === true
      });
    });
    return normalized.sort((left: BookGroup, right: BookGroup) => left.order - right.order);
  }

  private static async persist(context: Context, groups: BookGroup[]): Promise<void> {
    const normalized = BookGroupRepository.normalize(groups);
    const ordered = normalized.map((group: BookGroup, index: number) =>
      group.groupId > 0 ? BookGroupRepository.withOrder(group, index) : BookGroupRepository.copyGroup(group));
    const operation = BookGroupRepository.saveQueue.then(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, BookGroupRepository.preferenceName);
      await store.put(BookGroupRepository.groupsKey, JSON.stringify(ordered));
      await store.flush();
    });
    BookGroupRepository.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    await operation;
    BookGroupRepository.groups = ordered;
    BookGroupRepository.loaded = true;
  }
}
