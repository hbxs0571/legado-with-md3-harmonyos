import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';

/**
 * 本地密码（应用访问密码）的明文存取，对应上游 `LocalPreferencesKeys.PASSWORD`
 * （`data/local/preferences/LocalPreferences.kt:26` `stringPreferencesKey("password")`）
 * 与 `data/repository/OtherConfigAuxiliaryRepositories.kt:62-93` 的 `LocalPasswordRepository.setPassword`。
 *
 * 上游把这个明文密码当唯一权威凭据：`help/storage/BackupAES.kt:9` 用它派生 AES 密钥
 * （`MD5Utils.md5Encode(LocalConfig.password ?: "")`），`ui/config/privateConfig` 用它做私密内容校验。
 * 本地此前只存 salt + PBKDF2 校验值（`data/PrivateAccessRepository.ets` 文件头 `:16-17` 记录的收紧），
 * 结果是备份加密恒用空密码 —— 与 Android 端设过密码的备份互相解不开。
 *
 * 这里按上游口径补上明文存储：设密码时与 salt/校验值同一次写入，备份加解密都读它。
 * 该键与上游同名（`password`），但存在本地独立的 preferences 里；它本来就在
 * `BackupRepository.alwaysIgnoredPreferenceKeys` 的排除名单里（上游 `BackupConfig.kt:22` 同样排除），
 * 所以不进 config.xml、不随备份走。
 */
export class LocalPasswordStore {
  private static readonly preferenceName: string = 'legado_local_password';
  /** 与上游 `LocalPreferencesKeys.PASSWORD` 同名，便于对照。 */
  private static readonly keyPassword: string = 'password';

  /** 读明文密码；没设过返回空串（上游 `LocalConfig.password ?: ""` 同一语义）。 */
  static async load(context: Context): Promise<string> {
    try {
      const store = await preferences.getPreferences(context, LocalPasswordStore.preferenceName);
      const value = await store.get(LocalPasswordStore.keyPassword, '') as string;
      return value ?? '';
    } catch (error) {
      console.error(`[LocalPassword] 读取失败：${error instanceof Error ? error.message : error}`);
      return '';
    }
  }

  /** 写明文密码。空串等同于清除（上游 `setPassword(null)` 把整条清空）。 */
  static async save(context: Context, password: string): Promise<void> {
    const store = await preferences.getPreferences(context, LocalPasswordStore.preferenceName);
    await store.put(LocalPasswordStore.keyPassword, password);
    await store.flush();
  }

  /** 清空明文密码，对齐上游 `setPassword(null)` 的 `normalized.isEmpty()` 分支。 */
  static async clear(context: Context): Promise<void> {
    const store = await preferences.getPreferences(context, LocalPasswordStore.preferenceName);
    await store.delete(LocalPasswordStore.keyPassword);
    await store.flush();
  }
}
