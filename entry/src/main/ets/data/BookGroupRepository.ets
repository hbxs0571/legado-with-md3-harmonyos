import { preferences } from '@kit.ArkData';
import { fileIo, picker } from '@kit.CoreFileKit';
import { BookGroup, BookGroupDraft } from '../model/BookGroup';

interface AndroidBookGroupRecord {
  groupId?: number;
  groupName?: string;
  cover?: string;
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
    return BookGroupRepository.addWithDraft(context, {
      groupName: name, enableRefresh: true, bookSort: -1, isPrivate: false
    });
  }

  /** 按完整草稿新建分组，对应上游 GroupViewModel.addGroup。 */
  static async addWithDraft(context: Context, draft: BookGroupDraft): Promise<BookGroup> {
    const normalized = draft.groupName.trim();
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
      enableRefresh: draft.enableRefresh,
      bookSort: Number.isInteger(draft.bookSort) ? draft.bookSort : -1,
      isPrivate: draft.isPrivate,
      cover: draft.cover
    };
    await BookGroupRepository.persist(context, [...BookGroupRepository.groups, group]);
    return BookGroupRepository.copyGroup(group);
  }

  /** 保存编辑后的分组属性，对应上游 GroupViewModel.saveGroup。 */
  static async updateSettings(context: Context, groupId: number, draft: BookGroupDraft): Promise<void> {
    const normalized = draft.groupName.trim();
    if (normalized.length === 0) { throw new Error('分组名称不能为空'); }
    const current = BookGroupRepository.groups.find((group: BookGroup) => group.groupId === groupId);
    if (current === undefined || groupId <= 0) { throw new Error('只能编辑自定义分组'); }
    if (BookGroupRepository.groups.some((group: BookGroup) =>
      group.groupId > 0 && group.groupId !== groupId && group.groupName === normalized)) {
      throw new Error('分组名称已存在');
    }
    const updated: BookGroup = {
      groupId: current.groupId,
      groupName: normalized,
      order: current.order,
      show: current.show,
      enableRefresh: draft.enableRefresh,
      bookSort: Number.isInteger(draft.bookSort) ? draft.bookSort : -1,
      isPrivate: draft.isPrivate,
      cover: draft.cover
    };
    await BookGroupRepository.persist(context, BookGroupRepository.groups.map((group: BookGroup) =>
      group.groupId === groupId ? updated : BookGroupRepository.copyGroup(group)));
  }

  /** 记录分组封面路径；传 undefined 表示清空。 */
  static async setCover(context: Context, groupId: number, cover: string | undefined): Promise<void> {
    const current = BookGroupRepository.groups.find((group: BookGroup) => group.groupId === groupId);
    if (current === undefined || groupId <= 0) { throw new Error('只能设置自定义分组的封面'); }
    const updated: BookGroup = {
      groupId: current.groupId,
      groupName: current.groupName,
      order: current.order,
      show: current.show,
      enableRefresh: current.enableRefresh,
      bookSort: current.bookSort,
      isPrivate: current.isPrivate,
      cover: cover
    };
    await BookGroupRepository.persist(context, BookGroupRepository.groups.map((group: BookGroup) =>
      group.groupId === groupId ? updated : BookGroupRepository.copyGroup(group)));
  }

  /**
   * 弹出系统文件选择器挑一张图片，复制进应用私有目录后记录为分组封面。
   *
   * 复制副本而不是直接存 URI：系统选择器给的 URI 只是临时授权，
   * 应用重启后通常失效，与 BookRepository.chooseCustomCover 的做法保持一致。
   */
  static async chooseCover(context: Context, groupId: number): Promise<BookGroup | undefined> {
    const current = BookGroupRepository.groups.find((group: BookGroup) => group.groupId === groupId);
    if (current === undefined || groupId <= 0) { throw new Error('只能设置自定义分组的封面'); }
    const options = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['图片|.png', '图片|.jpg', '图片|.jpeg', '图片|.webp', '图片|.bmp'];
    options.maxSelectNumber = 1;
    const uris = await new picker.DocumentViewPicker(context).select(options);
    const uri = uris[0];
    if (uri === undefined) { return undefined; }
    const coversDirectory = `${context.filesDir}/group-covers`;
    BookGroupRepository.ensureDirectory(coversDirectory);
    const targetPath = `${coversDirectory}/group-${groupId}-${Date.now()}.img`;
    const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      fileIo.copyFileSync(source.fd, targetPath);
      if (fileIo.statSync(targetPath).size <= 0) { throw new Error('所选封面文件为空'); }
    } catch (error) {
      if (fileIo.accessSync(targetPath)) { fileIo.unlinkSync(targetPath); }
      if (error instanceof Error) { throw error; }
      throw new Error('保存分组封面失败');
    } finally {
      fileIo.closeSync(source);
    }
    await BookGroupRepository.setCover(context, groupId, `file://${targetPath}`);
    return BookGroupRepository.groups.find((group: BookGroup) => group.groupId === groupId);
  }

  /** 删除封面副本并清空记录，对应上游 GroupResetCoverAction。 */
  static async clearCover(context: Context, groupId: number): Promise<void> {
    const current = BookGroupRepository.groups.find((group: BookGroup) => group.groupId === groupId);
    if (current === undefined) { return; }
    const previous = current.cover;
    await BookGroupRepository.setCover(context, groupId, undefined);
    if (previous !== undefined && previous.length > 0) {
      const path = previous.startsWith('file://') ? previous.substring('file://'.length) : previous;
      try {
        if (fileIo.accessSync(path)) { fileIo.unlinkSync(path); }
      } catch (_) {
        // 副本可能已被系统清理，删不掉不影响已经清空的记录。
      }
    }
  }

  /**
   * 把分组移动到指定位置，对应上游 GroupManageSheet 拖拽后 upGroup(order = index)。
   *
   * 只重排自定义分组（groupId > 0），内置分组不参与顺序。
   */
  static async move(context: Context, fromId: number, toId: number): Promise<void> {
    const userGroups = BookGroupRepository.groups
      .filter((group: BookGroup) => group.groupId > 0)
      .sort((left: BookGroup, right: BookGroup) => left.order - right.order);
    const fromIndex = userGroups.findIndex((group: BookGroup) => group.groupId === fromId);
    const toIndex = userGroups.findIndex((group: BookGroup) => group.groupId === toId);
    if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) { return; }
    const reordered = userGroups.slice();
    const moved = reordered.splice(fromIndex, 1)[0];
    reordered.splice(toIndex, 0, moved);
    const others = BookGroupRepository.groups.filter((group: BookGroup) => group.groupId <= 0);
    await BookGroupRepository.persist(context, others.concat(reordered));
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

  /** 递归创建目录；已存在时 mkdirSync 会抛错，用 lstat 兜底确认。 */
  private static ensureDirectory(path: string): void {
    try {
      fileIo.mkdirSync(path, true);
    } catch (error) {
      try {
        if (fileIo.lstatSync(path).isDirectory()) { return; }
      } catch (_) {
        // 目录不存在且创建失败，把原始错误抛给调用方。
      }
      throw error instanceof Error ? error : new Error('创建分组封面目录失败');
    }
  }

  private static copyGroup(group: BookGroup): BookGroup {
    const copy: BookGroup = {
      groupId: group.groupId, groupName: group.groupName, order: group.order, show: group.show,
      enableRefresh: group.enableRefresh, bookSort: group.bookSort, isPrivate: group.isPrivate,
      cover: group.cover
    };
    return copy;
  }

  private static withName(group: BookGroup, name: string): BookGroup {
    const copy: BookGroup = {
      groupId: group.groupId, groupName: name, order: group.order, show: group.show,
      enableRefresh: group.enableRefresh, bookSort: group.bookSort, isPrivate: group.isPrivate,
      cover: group.cover
    };
    return copy;
  }

  private static withVisibility(group: BookGroup, visible: boolean): BookGroup {
    const copy: BookGroup = {
      groupId: group.groupId, groupName: group.groupName, order: group.order, show: visible,
      enableRefresh: group.enableRefresh, bookSort: group.bookSort, isPrivate: group.isPrivate,
      cover: group.cover
    };
    return copy;
  }

  private static withOrder(group: BookGroup, order: number): BookGroup {
    const copy: BookGroup = {
      groupId: group.groupId, groupName: group.groupName, order: order, show: group.show,
      enableRefresh: group.enableRefresh, bookSort: group.bookSort, isPrivate: group.isPrivate,
      cover: group.cover
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
      isPrivate: record.isPrivate === true,
      cover: typeof record.cover === 'string' && record.cover.length > 0 ? record.cover : undefined
    };
    return group;
  }

  private static toAndroidRecord(group: BookGroup): AndroidBookGroupRecord {
    const record: AndroidBookGroupRecord = {
      groupId: group.groupId, groupName: group.groupName, order: group.order, show: group.show,
      enableRefresh: group.enableRefresh, bookSort: group.bookSort, isPrivate: group.isPrivate,
      cover: group.cover
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
        isPrivate: group.isPrivate === true,
        // 封面必须在 normalize 里透传，否则 setCover 刚写入的路径
        // 会在 persist → normalize 重建对象时被抹掉。
        cover: group.cover
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
