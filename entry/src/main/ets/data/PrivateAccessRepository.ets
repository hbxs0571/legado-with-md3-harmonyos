import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import userAuth from '@ohos.userIAM.userAuth';
import { Book } from '../model/Book';
import { BookGroupRepository } from './BookGroupRepository';

/**
 * 私密体系（批6，对应本表 :257 :294 :325 :147 :150 :151）。
 *
 * 上游 domain/model/PrivateAccess.kt + data/repository/PrivateAccessRepository.kt + help/security/PrivatePasswordCipher.kt。
 *
 * 与上游的三处有意差异，都是安全侧收紧，写在最前面免得后人以为漏了：
 * 1. 上游把明文密码当唯一权威凭据存进偏好（PASSWORD），本地**不存明文**，只存 salt 与 PBKDF2 校验值。
 *    备份本来就把该键排除在外，所以互通性不受影响。
 * 2. 上游密码校验用 Android 的 PBKDF2WithHmacSHA256；本地用 @kit.CryptoArchitectureKit 的同名算法，
 *    迭代次数与 key 长度照抄（210000 / 32 字节），但派生出的是「校验值」而不是加密密钥。
 * 3. 上游生物识别用 AndroidKeyStore + AES/GCM 把密码封进信封；鸿蒙用
 *    @ohos.userIAM.userAuth 做「在场证明」——验证通过后仍走本地 verifyPassword/unlock,
 *    不拿生物结果当密码校验（见 verifyBiometric）。
 *
 * 解锁态只存进程内存（AppStorage），进程结束即回到锁定态，不做超时。
 * 这里不用 PersistentStorage：那会把「已解锁」持久化，等于永不解锁。
 */

/** 生物识别能力状态，对齐上游 PrivateBiometricStatus 五值中的鸿蒙可达四态。 */
export enum PrivateBiometricStatus {
  NOT_SET_PASSWORD = 0,
  AVAILABLE = 1,
  NOT_ENROLLED = 2,
  NO_HARDWARE = 3,
  UNAVAILABLE = 4
}

/** 解锁有效期：每次都验证。 */
export const PRIVATE_UNLOCK_EVERY_TIME: number = 0;
/** 解锁有效期：应用会话内有效。 */
export const PRIVATE_UNLOCK_APP_SESSION: number = 1;
/** 解锁有效期：离开应用前有效（切到后台即失效）。 */
export const PRIVATE_UNLOCK_UNTIL_BACKGROUND: number = 2;

/** AppStorage 键名，跨页面共享解锁态与设置快照。 */
export const PRIVATE_STORE_ENABLED: string = 'privateEnabled';
export const PRIVATE_STORE_HAS_PASSWORD: string = 'privateHasPassword';
export const PRIVATE_STORE_UNLOCKED: string = 'privateUnlocked';
export const PRIVATE_STORE_UNLOCK_SCOPE: string = 'privateUnlockScope';
export const PRIVATE_STORE_GRANTED_BOOK_KEYS: string = 'privateGrantedBookKeys';
export const PRIVATE_STORE_GRANTED_GROUP_IDS: string = 'privateGrantedGroupIds';
/** 启动验证门是否已过（verifyOnAppStart）。与 unlocked 分开：它只证明「进得来」。 */
export const PRIVATE_STORE_APP_START_VERIFIED: string = 'privateAppStartVerified';
/** 三个验证时机 + 宽限期，供设置页 @StorageProp 订阅。 */
export const PRIVATE_STORE_VERIFY_ON_ENTER_GROUP: string = 'privateVerifyOnEnterGroup';
export const PRIVATE_STORE_VERIFY_ON_OPEN_BOOK: string = 'privateVerifyOnOpenBook';
export const PRIVATE_STORE_VERIFY_ON_APP_START: string = 'privateVerifyOnAppStart';
export const PRIVATE_STORE_BACKGROUND_GRACE_SECONDS: string = 'privateBackgroundGraceSeconds';
/** 生物识别开关状态，供设置页 @StorageProp 订阅（可不可用另由能力探测给出）。 */
export const PRIVATE_STORE_BIOMETRIC_ENABLED: string = 'privateBiometricEnabled';

/** 私密设置快照。七字段对齐上游 domain/model/settings/PrivateAccessSettings.kt。 */
export interface PrivateAccessSettings {
  /** 总开关。关掉即整体休眠：不验证、不脱敏、不放守卫，密码与标记都留着。 */
  enabled: boolean;
  /** 是否已经设过本地密码（有 salt 与校验值）。 */
  hasPassword: boolean;
  /** 解锁有效期，取 PRIVATE_UNLOCK_*。 */
  unlockScope: number;
  /** 当前是否已解锁。只在进程内有效。 */
  unlocked: boolean;
  /** 切到私密分组时验证（默认 true）。 */
  verifyOnEnterGroup: boolean;
  /** 打开私密书籍时验证（默认 true）。 */
  verifyOnOpenBook: boolean;
  /** 应用启动时立即验证（默认 false）。 */
  verifyOnAppStart: boolean;
  /** 离开前台后多久重新验证，秒；仅 UntilBackground 档有意义（默认 0）。 */
  backgroundGraceSeconds: number;
}

export const DEFAULT_PRIVATE_ACCESS: PrivateAccessSettings = {
  enabled: false,
  hasPassword: false,
  unlockScope: PRIVATE_UNLOCK_APP_SESSION,
  unlocked: false,
  verifyOnEnterGroup: true,
  verifyOnOpenBook: true,
  verifyOnAppStart: false,
  backgroundGraceSeconds: 0
};

/** Uint8Array 转小写十六进制，用于把 salt 与校验值存成偏好字符串。 */
function bytesToHex(bytes: Uint8Array): string {
  let text = '';
  for (let index = 0; index < bytes.length; index += 1) {
    const value = bytes[index];
    const piece = value === undefined ? '00' : value.toString(16);
    text += piece.length === 1 ? '0' + piece : piece;
  }
  return text;
}

/** 十六进制转回字节；非法字符按 0 处理，调用方靠长度判断有效性。 */
function hexToBytes(text: string): Uint8Array {
  const clean = text.trim();
  const bytes = new Uint8Array(Math.floor(clean.length / 2));
  for (let index = 0; index < bytes.length; index += 1) {
    const piece = clean.substring(index * 2, index * 2 + 2);
    const value = parseInt(piece, 16);
    bytes[index] = Number.isFinite(value) ? value : 0;
  }
  return bytes;
}

/**
 * 定长比较，避免用 === 逐字节短路泄露时序。
 * 上游 help/security/PrivatePasswordCipher.kt 用 MessageDigest.isEqual 同一个意思。
 */
function constantTimeEquals(left: Uint8Array, right: Uint8Array): boolean {
  let diff = left.length === right.length ? 0 : 1;
  const limit = Math.min(left.length, right.length);
  for (let index = 0; index < limit; index += 1) {
    diff |= (left[index] ?? 0) ^ (right[index] ?? 0);
  }
  return diff === 0;
}

/**
 * 用 PBKDF2-HMAC-SHA256 派生校验值。
 * salt 与 iterations 必须与写入时一致，否则永远校验不过。
 */
function deriveVerifier(password: string, salt: Uint8Array): Uint8Array {
  const kdf = cryptoFramework.createKdf('PBKDF2|SHA256');
  const spec: cryptoFramework.PBKDF2Spec = {
    algName: 'PBKDF2',
    password: password,
    salt: salt,
    iterations: 210000,
    keySize: 32
  };
  const secret = kdf.generateSecretSync(spec);
  return secret.data;
}

/** 16 字节随机 salt。 */
function randomSalt(): Uint8Array {
  return cryptoFramework.createRandom().generateRandomSync(16).data;
}

export class PrivateAccessRepository {
  private static readonly preferenceName: string = 'legado_private_access';
  /** 只存 salt 与校验值，不存明文密码。 */
  private static readonly keySalt: string = 'PRIVATE_PASSWORD_SALT';
  private static readonly keyVerifier: string = 'PRIVATE_PASSWORD_VERIFIER';
  private static readonly keyEnabled: string = 'PRIVATE_ENABLED';
  private static readonly keyUnlockScope: string = 'PRIVATE_UNLOCK_SCOPE';
  // 下列五个键的值照抄上游 LocalPreferences.kt（private_verify_on_* 等），便于备份互通。
  private static readonly keyVerifyOnEnterGroup: string = 'private_verify_on_enter_group';
  private static readonly keyVerifyOnOpenBook: string = 'private_verify_on_open_book';
  private static readonly keyVerifyOnAppStart: string = 'private_verify_on_app_start';
  private static readonly keyBackgroundGraceSeconds: string = 'private_background_grace_seconds';
  private static readonly keyBiometricEnabled: string = 'private_biometric_enabled';
  /** 进入后台的时间戳（毫秒），仅进程内有效，宽限期判定用。 */
  private static backgroundTimestamp: number = 0;

  /** 把设置快照写进 AppStorage，页面用 @StorageProp 订阅。 */
  private static publish(settings: PrivateAccessSettings): void {
    AppStorage.setOrCreate(PRIVATE_STORE_ENABLED, settings.enabled);
    AppStorage.setOrCreate(PRIVATE_STORE_HAS_PASSWORD, settings.hasPassword);
    AppStorage.setOrCreate(PRIVATE_STORE_UNLOCK_SCOPE, settings.unlockScope);
    AppStorage.setOrCreate(PRIVATE_STORE_UNLOCKED, settings.unlocked);
    AppStorage.setOrCreate(PRIVATE_STORE_VERIFY_ON_ENTER_GROUP, settings.verifyOnEnterGroup);
    AppStorage.setOrCreate(PRIVATE_STORE_VERIFY_ON_OPEN_BOOK, settings.verifyOnOpenBook);
    AppStorage.setOrCreate(PRIVATE_STORE_VERIFY_ON_APP_START, settings.verifyOnAppStart);
    AppStorage.setOrCreate(PRIVATE_STORE_BACKGROUND_GRACE_SECONDS, settings.backgroundGraceSeconds);
    if (AppStorage.get<string[]>(PRIVATE_STORE_GRANTED_BOOK_KEYS) === undefined) {
      AppStorage.setOrCreate(PRIVATE_STORE_GRANTED_BOOK_KEYS, [] as string[]);
    }
    if (AppStorage.get<number[]>(PRIVATE_STORE_GRANTED_GROUP_IDS) === undefined) {
      AppStorage.setOrCreate(PRIVATE_STORE_GRANTED_GROUP_IDS, [] as number[]);
    }
  }

  /** 读当前设置快照（同步，来自 AppStorage）。 */
  static get(): PrivateAccessSettings {
    const enabled = AppStorage.get<boolean>(PRIVATE_STORE_ENABLED);
    const hasPassword = AppStorage.get<boolean>(PRIVATE_STORE_HAS_PASSWORD);
    const unlockScope = AppStorage.get<number>(PRIVATE_STORE_UNLOCK_SCOPE);
    const unlocked = AppStorage.get<boolean>(PRIVATE_STORE_UNLOCKED);
    const verifyOnEnterGroup = AppStorage.get<boolean>(PRIVATE_STORE_VERIFY_ON_ENTER_GROUP);
    const verifyOnOpenBook = AppStorage.get<boolean>(PRIVATE_STORE_VERIFY_ON_OPEN_BOOK);
    const verifyOnAppStart = AppStorage.get<boolean>(PRIVATE_STORE_VERIFY_ON_APP_START);
    const backgroundGraceSeconds = AppStorage.get<number>(PRIVATE_STORE_BACKGROUND_GRACE_SECONDS);
    return {
      enabled: enabled === true,
      hasPassword: hasPassword === true,
      unlockScope: unlockScope === undefined ? PRIVATE_UNLOCK_APP_SESSION : unlockScope,
      unlocked: unlocked === true,
      verifyOnEnterGroup: verifyOnEnterGroup === undefined ? true : verifyOnEnterGroup,
      verifyOnOpenBook: verifyOnOpenBook === undefined ? true : verifyOnOpenBook,
      verifyOnAppStart: verifyOnAppStart === true,
      backgroundGraceSeconds: backgroundGraceSeconds === undefined ? 0 : backgroundGraceSeconds
    };
  }

  /** 从偏好读全部设置并发布到 AppStorage。启动时调一次。 */
  static async load(context: Context): Promise<PrivateAccessSettings> {
    const settings = DEFAULT_PRIVATE_ACCESS;
    try {
      const store = await preferences.getPreferences(context, PrivateAccessRepository.preferenceName);
      const salt = await store.get(PrivateAccessRepository.keySalt, '') as string;
      const verifier = await store.get(PrivateAccessRepository.keyVerifier, '') as string;
      const enabled = await store.get(PrivateAccessRepository.keyEnabled, false) as boolean;
      const scope = await store.get(PrivateAccessRepository.keyUnlockScope,
        PRIVATE_UNLOCK_APP_SESSION) as number;
      const verifyOnEnterGroup = await store.get(PrivateAccessRepository.keyVerifyOnEnterGroup, true) as boolean;
      const verifyOnOpenBook = await store.get(PrivateAccessRepository.keyVerifyOnOpenBook, true) as boolean;
      const verifyOnAppStart = await store.get(PrivateAccessRepository.keyVerifyOnAppStart, false) as boolean;
      const grace = await store.get(PrivateAccessRepository.keyBackgroundGraceSeconds, 0) as number;
      const biometricEnabled = await store.get(PrivateAccessRepository.keyBiometricEnabled, false) as boolean;
      const next: PrivateAccessSettings = {
        enabled: enabled === true,
        hasPassword: salt.length > 0 && verifier.length > 0,
        unlockScope: scope,
        // 进程刚起，一律锁定态；启动验证门也未过。
        unlocked: false,
        verifyOnEnterGroup: verifyOnEnterGroup === true,
        verifyOnOpenBook: verifyOnOpenBook === true,
        verifyOnAppStart: verifyOnAppStart === true,
        backgroundGraceSeconds: Number.isFinite(grace) ? Math.max(0, Math.floor(grace)) : 0
      };
      PrivateAccessRepository.publish(next);
      AppStorage.setOrCreate(PRIVATE_STORE_BIOMETRIC_ENABLED, biometricEnabled === true);
      AppStorage.setOrCreate(PRIVATE_STORE_APP_START_VERIFIED, false);
      PrivateAccessRepository.backgroundTimestamp = 0;
      return next;
    } catch (error) {
      console.error(`[PrivateAccess] 私密设置读取失败：${error instanceof Error ? error.message : error}`);
      PrivateAccessRepository.publish(settings);
      return settings;
    }
  }

  /**
   * 设置或修改本地密码。salt 每次重新生成，旧密码立即失效。
   * 密码本身不落盘，只落 salt 与 PBKDF2 校验值。
   */
  static async setPassword(context: Context, password: string): Promise<void> {
    const trimmed = password.trim();
    if (trimmed.length === 0) {
      throw new Error('密码不能为空');
    }
    const salt = randomSalt();
    const verifier = deriveVerifier(trimmed, salt);
    const store = await preferences.getPreferences(context, PrivateAccessRepository.preferenceName);
    await store.put(PrivateAccessRepository.keySalt, bytesToHex(salt));
    await store.put(PrivateAccessRepository.keyVerifier, bytesToHex(verifier));
    await store.flush();
    const current = PrivateAccessRepository.get();
    PrivateAccessRepository.publish({
      enabled: current.enabled,
      hasPassword: true,
      unlockScope: current.unlockScope,
      unlocked: current.unlocked,
      verifyOnEnterGroup: current.verifyOnEnterGroup,
      verifyOnOpenBook: current.verifyOnOpenBook,
      verifyOnAppStart: current.verifyOnAppStart,
      backgroundGraceSeconds: current.backgroundGraceSeconds
    });
  }

  /** 校验密码。没设过密码一律返回 false，不区分「没设」与「不对」，避免泄露状态。 */
  static async verifyPassword(context: Context, password: string): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, PrivateAccessRepository.preferenceName);
      const saltText = await store.get(PrivateAccessRepository.keySalt, '') as string;
      const verifierText = await store.get(PrivateAccessRepository.keyVerifier, '') as string;
      if (saltText.length === 0 || verifierText.length === 0) {
        return false;
      }
      const expected = hexToBytes(verifierText);
      const actual = deriveVerifier(password, hexToBytes(saltText));
      return constantTimeEquals(expected, actual);
    } catch (error) {
      console.error(`[PrivateAccess] 密码校验失败：${error instanceof Error ? error.message : error}`);
      return false;
    }
  }

  /** 改总开关。关掉即整体休眠，但密码与标记都保留。 */
  static async setEnabled(context: Context, enabled: boolean): Promise<void> {
    const store = await preferences.getPreferences(context, PrivateAccessRepository.preferenceName);
    await store.put(PrivateAccessRepository.keyEnabled, enabled);
    await store.flush();
    const current = PrivateAccessRepository.get();
    PrivateAccessRepository.publish({
      enabled: enabled,
      hasPassword: current.hasPassword,
      unlockScope: current.unlockScope,
      unlocked: enabled ? current.unlocked : false,
      verifyOnEnterGroup: current.verifyOnEnterGroup,
      verifyOnOpenBook: current.verifyOnOpenBook,
      verifyOnAppStart: current.verifyOnAppStart,
      backgroundGraceSeconds: current.backgroundGraceSeconds
    });
  }

  /** 改解锁有效期。 */
  static async setUnlockScope(context: Context, scope: number): Promise<void> {
    const store = await preferences.getPreferences(context, PrivateAccessRepository.preferenceName);
    await store.put(PrivateAccessRepository.keyUnlockScope, scope);
    await store.flush();
    const current = PrivateAccessRepository.get();
    PrivateAccessRepository.publish({
      enabled: current.enabled,
      hasPassword: current.hasPassword,
      unlockScope: scope,
      unlocked: current.unlocked,
      verifyOnEnterGroup: current.verifyOnEnterGroup,
      verifyOnOpenBook: current.verifyOnOpenBook,
      verifyOnAppStart: current.verifyOnAppStart,
      backgroundGraceSeconds: current.backgroundGraceSeconds
    });
  }

  /**
   * 改四个验证时机字段中的一个并落盘。字段白名单避免拼错键名。
   */
  static async setVerifyOption(context: Context, key: 'verifyOnEnterGroup' | 'verifyOnOpenBook' |
    'verifyOnAppStart' | 'backgroundGraceSeconds', value: boolean | number): Promise<void> {
    const store = await preferences.getPreferences(context, PrivateAccessRepository.preferenceName);
    const prefKey = key === 'verifyOnEnterGroup' ? PrivateAccessRepository.keyVerifyOnEnterGroup
      : key === 'verifyOnOpenBook' ? PrivateAccessRepository.keyVerifyOnOpenBook
        : key === 'verifyOnAppStart' ? PrivateAccessRepository.keyVerifyOnAppStart
          : PrivateAccessRepository.keyBackgroundGraceSeconds;
    await store.put(prefKey, value);
    await store.flush();
    const current = PrivateAccessRepository.get();
    PrivateAccessRepository.publish({
      enabled: current.enabled,
      hasPassword: current.hasPassword,
      unlockScope: current.unlockScope,
      unlocked: current.unlocked,
      verifyOnEnterGroup: key === 'verifyOnEnterGroup' ? value === true : current.verifyOnEnterGroup,
      verifyOnOpenBook: key === 'verifyOnOpenBook' ? value === true : current.verifyOnOpenBook,
      verifyOnAppStart: key === 'verifyOnAppStart' ? value === true : current.verifyOnAppStart,
      backgroundGraceSeconds: key === 'backgroundGraceSeconds' ? (typeof value === 'number' ? value : 0) : current.backgroundGraceSeconds
    });
  }

  /** 生物识别开关落盘（只记开关状态；能力可用性由 detectBiometricStatus 现查）。 */
  static async setBiometricEnabled(context: Context, enabled: boolean): Promise<void> {
    const store = await preferences.getPreferences(context, PrivateAccessRepository.preferenceName);
    await store.put(PrivateAccessRepository.keyBiometricEnabled, enabled);
    await store.flush();
    AppStorage.setOrCreate(PRIVATE_STORE_BIOMETRIC_ENABLED, enabled);
  }

  /** 生物识别开关当前值（来自 AppStorage）。 */
  static isBiometricEnabled(): boolean {
    return AppStorage.get<boolean>(PRIVATE_STORE_BIOMETRIC_ENABLED) === true;
  }

  /** 启动验证门是否已过。 */
  static isAppStartVerified(): boolean {
    return AppStorage.get<boolean>(PRIVATE_STORE_APP_START_VERIFIED) === true;
  }

  /** 标记启动验证门通过。 */
  static markAppStartVerified(): void {
    AppStorage.setOrCreate(PRIVATE_STORE_APP_START_VERIFIED, true);
  }

  /**
   * 探测生物识别能力状态。getAvailableStatus 不抛=可用；抛码映射到上游五态的鸿蒙可达四态。
   * UnsupportedSystem 那档是 Android 11 以下专属，鸿蒙基线 6.0.0(20) 不可达（见 d.ts @since 10），
   * 故不产生该状态。
   */
  static detectBiometricStatus(): PrivateBiometricStatus {
    const settings = PrivateAccessRepository.get();
    if (!settings.hasPassword) {
      return PrivateBiometricStatus.NOT_SET_PASSWORD;
    }
    try {
      userAuth.getAvailableStatus(userAuth.UserAuthType.FACE, userAuth.AuthTrustLevel.ATL2);
      return PrivateBiometricStatus.AVAILABLE;
    } catch (error) {
      const code = (error as BusinessError).code;
      if (code === 12500010) {
        return PrivateBiometricStatus.NOT_ENROLLED;
      }
      if (code === 12500005) {
        return PrivateBiometricStatus.NO_HARDWARE;
      }
      return PrivateBiometricStatus.UNAVAILABLE;
    }
  }

  /**
   * 发起生物识别（在场证明）。验证通过后由调用方走本地密码解锁链；
   * 这里只把「生物验证成功」这一事实通过回调返回，绝不因为验了生物就跳过密码校验。
   * 每个 UserAuthInstance 只能用一次，所以每次都新建。
   */
  static authenticateBiometric(onSuccess: () => void, onFail: (message: string) => void): void {
    try {
      const challenge = cryptoFramework.createRandom().generateRandomSync(16).data;
      const authParam: userAuth.AuthParam = {
        challenge: challenge,
        authType: [userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT],
        authTrustLevel: userAuth.AuthTrustLevel.ATL2
      };
      const widgetParam: userAuth.WidgetParam = { title: '验证身份以查看私密内容' };
      const instance = userAuth.getUserAuthInstance(authParam, widgetParam);
      instance.on('result', {
        onResult: (result: userAuth.UserAuthResult) => {
          if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
            onSuccess();
          } else {
            onFail('生物识别未完成');
          }
        }
      });
      instance.start();
    } catch (error) {
      onFail(error instanceof Error ? error.message : '生物识别不可用');
    }
  }

  /** 解锁（本次会话或整个应用，取决于 unlockScope）。 */
  static unlock(): void {
    const current = PrivateAccessRepository.get();
    PrivateAccessRepository.publish({
      enabled: current.enabled,
      hasPassword: current.hasPassword,
      unlockScope: current.unlockScope,
      unlocked: true,
      verifyOnEnterGroup: current.verifyOnEnterGroup,
      verifyOnOpenBook: current.verifyOnOpenBook,
      verifyOnAppStart: current.verifyOnAppStart,
      backgroundGraceSeconds: current.backgroundGraceSeconds
    });
  }

  /**
   * 切后台时记时间戳。只在「离开应用前有效」这一档下有意义：
   * 立即锁（grace=0）就回锁定态；grace>0 则记下时刻，回前台时由 lockIfGraceExpired 比对。
   * 其它两档不动：每次都验证靠 grant 逐目标放行，应用会话内本来就该一直解锁。
   * （EntryAbility.onBackground 调。）
   */
  static onBackground(): void {
    const current = PrivateAccessRepository.get();
    PrivateAccessRepository.backgroundTimestamp = Date.now();
    if (current.unlockScope !== PRIVATE_UNLOCK_UNTIL_BACKGROUND) { return; }
    if (!current.unlocked) { return; }
    if (current.backgroundGraceSeconds <= 0) {
      PrivateAccessRepository.lock();
    }
  }

  /**
   * 回前台时检查宽限期：离开时长未超过宽限期就不重锁；超过则锁。
   * （EntryAbility.onForeground 调。）
   */
  static onForeground(): void {
    const current = PrivateAccessRepository.get();
    if (current.unlockScope !== PRIVATE_UNLOCK_UNTIL_BACKGROUND) { return; }
    if (!current.unlocked) { return; }
    if (PrivateAccessRepository.backgroundTimestamp <= 0) { return; }
    const elapsedSeconds = (Date.now() - PrivateAccessRepository.backgroundTimestamp) / 1000;
    PrivateAccessRepository.backgroundTimestamp = 0;
    if (elapsedSeconds >= current.backgroundGraceSeconds) {
      PrivateAccessRepository.lock();
    }
  }

  /** 回到锁定态。切后台、关总开关、会话结束时调。 */
  static lock(): void {
    const current = PrivateAccessRepository.get();
    PrivateAccessRepository.publish({
      enabled: current.enabled,
      hasPassword: current.hasPassword,
      unlockScope: current.unlockScope,
      unlocked: false,
      verifyOnEnterGroup: current.verifyOnEnterGroup,
      verifyOnOpenBook: current.verifyOnOpenBook,
      verifyOnAppStart: current.verifyOnAppStart,
      backgroundGraceSeconds: current.backgroundGraceSeconds
    });
    AppStorage.setOrCreate(PRIVATE_STORE_GRANTED_BOOK_KEYS, [] as string[]);
    AppStorage.setOrCreate(PRIVATE_STORE_GRANTED_GROUP_IDS, [] as number[]);
  }

  /**
   * 给单个目标（一本书或一个分组）授权，作用域为「每次都验证」时用。
   * 入参 bookKey 为空串表示只授权分组。
   */
  static grant(bookKey: string, groupId: number): void {
    const books = AppStorage.get<string[]>(PRIVATE_STORE_GRANTED_BOOK_KEYS) ?? [];
    const groups = AppStorage.get<number[]>(PRIVATE_STORE_GRANTED_GROUP_IDS) ?? [];
    if (bookKey.length > 0 && books.indexOf(bookKey) < 0) {
      AppStorage.setOrCreate(PRIVATE_STORE_GRANTED_BOOK_KEYS, books.concat([bookKey]));
    }
    if (groupId > 0 && groups.indexOf(groupId) < 0) {
      AppStorage.setOrCreate(PRIVATE_STORE_GRANTED_GROUP_IDS, groups.concat([groupId]));
    }
  }

  /** 该目标是否已单独授权。 */
  static isGranted(bookKey: string, groupId: number): boolean {
    const books = AppStorage.get<string[]>(PRIVATE_STORE_GRANTED_BOOK_KEYS) ?? [];
    const groups = AppStorage.get<number[]>(PRIVATE_STORE_GRANTED_GROUP_IDS) ?? [];
    if (bookKey.length > 0 && books.indexOf(bookKey) >= 0) { return true; }
    return groupId > 0 && groups.indexOf(groupId) >= 0;
  }
}

/**
 * 一本书是否属于私密内容。判定式照抄上游 domain/model/PrivateAccess.kt：
 * 单本标记 **并上** 所属私密分组，两者任一命中即是私密。
 *
 * mask 与分组 id 的比较用「除后取奇数位」而不是 & 位运算：
 * 本地 groupId 从 1 起逐位左移分配，几十个分组就会到 2^52 量级，
 * ArkTS 的 & 只保留低 32 位，会算错高位分组。这与 BookGroupRepository.namesFromMask 同一套算法。
 */
export function isPrivateBook(book: Book, privateGroupIds: number[]): boolean {
  if (book.isPrivate === true) { return true; }
  if (privateGroupIds.length === 0) { return false; }
  const mask = BookGroupRepository.maskFromNames(book.groupNames ?? []);
  if (mask <= 0) { return false; }
  return privateGroupIds.some((groupId: number) => {
    if (groupId <= 0) { return false; }
    return Math.floor(mask / groupId) % 2 === 1;
  });
}

/**
 * 私密体系的对外判定：这事要不要拦。
 *
 * 三条都满足才拦：总开关开着、设过密码；再看「本次是否已解锁」。
 * 解锁分三档（对齐上游 PrivateUnlockScope）：
 * * 每次都验证——只有单独授权过的目标放行；
 * * 应用会话内——解锁一次后本轮进程全放行；
 * * 离开应用前——同上，但 EntryAbility.onBackground 会把解锁态清掉。
 */
export function requiresPrivateUnlock(bookKey: string, groupId: number): boolean {
  const settings = PrivateAccessRepository.get();
  if (!settings.enabled) { return false; }
  // 总开关开着但还没设密码：上游这时不给解锁入口，只把内容锁住并引导去设密码
  // （PrivateGroupLockedPage 在 hasPassword 为 false 时给「设置本地密码」）。
  // 所以这里仍然返回 true，否则没密码的用户会看到私密分组直接敞开。
  if (!settings.hasPassword) { return true; }
  if (settings.unlockScope === PRIVATE_UNLOCK_EVERY_TIME) {
    return !PrivateAccessRepository.isGranted(bookKey, groupId);
  }
  return !settings.unlocked;
}
