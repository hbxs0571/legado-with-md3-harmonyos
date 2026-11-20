// 引擎运行时持久化实现（P1）。
//
// 引擎通过 BookSourceRuntimeStore 拿到宿主的书源与回写登录态，它自己不开数据库。
// 这里把三个方法接到本地 BookSourceRepository：
//   getBookSource            → 仓储缓存找条 → LegadoSourceMapper 投影成引擎 BookSource
//   updateBookSourceLoginRuntime → 改 sourceJson 里的 variable/loginHeader/loginInfo 三键 → save 整表
//
// 注意：三个键在 Legado BookSource 实体里不存在（上游在 BaseSource 方法里），本地 sourceJson
// 多半没有；写之前先 JSON.parse，没有就新增。整条 sourceJson 仍保持 Legado 原格式，备份可往返。
import {
  BookSource as EngineBookSource,
  BookSourceRuntimePersistence
} from '@legado/sourceengine';
import { BookSourceRepository } from '../data/BookSourceRepository';
import { BookSource } from '../model/BookSource';
import { LegadoSourceMapper } from './LegadoSourceMapper';

export class BookSourceRuntimePersistenceImpl implements BookSourceRuntimePersistence {
  private readonly context: Context;

  constructor(context: Context) {
    this.context = context;
  }

  async getBookSource(bookSourceUrl: string): Promise<EngineBookSource | null> {
    const all = BookSourceRepository.getAll();
    for (const local of all) {
      if (local.bookSourceUrl === bookSourceUrl) {
        return LegadoSourceMapper.fromLocal(local);
      }
    }
    return null;
  }

  async updateBookSourceLoginRuntime(bookSourceUrl: string, variable: string, loginHeader: string,
    loginInfo: string): Promise<void> {
    const all = BookSourceRepository.getAll();
    const index = all.findIndex((r: BookSource): boolean => r.bookSourceUrl === bookSourceUrl);
    if (index < 0) {
      return;
    }
    const target = all[index];
    let raw: Record<string, Object> = {};
    try {
      const parsed: Object = JSON.parse(target.sourceJson);
      if (parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed)) {
        raw = parsed as Record<string, Object>;
      }
    } catch (_) {
      // 坏 JSON 不覆盖：保留原样，避免把一条脏源的 sourceJson 洗掉。
      return;
    }
    raw['variable'] = variable;
    raw['loginHeader'] = loginHeader;
    raw['loginInfo'] = loginInfo;
    target.sourceJson = JSON.stringify(raw);
    await BookSourceRepository.save(this.context, all);
  }
}
