import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

/**
 * 上游 BackupAES 的 ArkTS 复刻，用于 servers.json 与 config.xml 里的密码类键。
 * 这里刻意使用 AES-128-ECB：它是上游既定格式（SymmetricCryptoAndroid 在算法名
 * 不含斜杠时补 '/ECB/PKCS5Padding'），改成 CBC/GCM 会让本地写出的包在 Android
 * 端解不开。codelinter 的 no-unsafe-aes 规则会针对 ECB 报警，本仓未启用该规则集，
 * 且此处不能改算法，故不按该规则整改。
 *
 * key 口径（与上游 BackupAES.kt 逐字节对齐）：
 *   MD5Utils.md5Encode(password) 返回 32 位小写十六进制「字符串」，
 *   .encodeToByteArray(0, 16) 取的是这个字符串的前 16 个 ASCII 字符的字节，
 *   不是 16 字节原始摘要、也不是 hex 解码后的 8 字节。
 *   空密码 → md5("") = d41d8cd98f00b204e9800998ecf8427e → 前 16 字符 d41d8cd98f00b204。
 */

/** 32 位小写十六进制 MD5。与 BookRepository.md5Encode16 的取段位置不同，不可互换：那个取中段 8–24，这里取完整 32 位。 */
export function md5Hex32(text: string): string {
  const md = cryptoFramework.createMd('MD5');
  md.updateSync({ data: new Uint8Array(new util.TextEncoder().encodeInto(text)) });
  const digest = md.digestSync();
  let hex: string = '';
  for (let index = 0; index < digest.data.length; index++) {
    hex += (digest.data[index] as number).toString(16).padStart(2, '0');
  }
  return hex;
}

/**
 * 由备份密码推导 AES key：md5 hex 字符串的前 16 个字符的 ASCII 字节（16 字节）。
 * 上游对空密码不做特殊处理，所以空串也走这条路径。
 */
export function aesEcKeyFromPassword(password: string): Uint8Array {
  const front16 = md5Hex32(password).substring(0, 16);
  // front16 恒为 ASCII 十六进制字符，UTF-8 编码逐字符 1 字节，正好 16 字节。
  return new util.TextEncoder().encodeInto(front16);
}

/**
 * 用 AES-128-ECB + PKCS7 加密明文并返回 base64 文本。
 * PKCS7 在 16 字节分组下与上游 Java 的 PKCS5Padding 等价。
 */
export function aesEcbEncryptToBase64(plain: string, key: Uint8Array): string {
  const cipher = cryptoFramework.createCipher('AES128|ECB|PKCS7');
  const generator = cryptoFramework.createSymKeyGenerator('AES128');
  const symKey = generator.convertKeySync({ data: key });
  // ECB 不需要 IV：d.ts 明确要求这类模式传 null，传 {} 会被判参数错误。
  cipher.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, null);
  const plainBytes = new Uint8Array(new util.TextEncoder().encodeInto(plain));
  const out = cipher.doFinalSync({ data: plainBytes });
  return new util.Base64Helper().encodeToStringSync(out.data);
}

/**
 * 解密 base64 密文为明文字符串。密文损坏、非分组整数倍或 PKCS7 校验失败时 doFinalSync 会抛，
 * 由调用方 catch 后走「设过备份密码」的归档兜底。
 */
export function aesEcbDecryptFromBase64(cipherBase64: string, key: Uint8Array): string {
  const cipher = cryptoFramework.createCipher('AES128|ECB|PKCS7');
  const generator = cryptoFramework.createSymKeyGenerator('AES128');
  const symKey = generator.convertKeySync({ data: key });
  cipher.initSync(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, null);
  const cipherBytes = new util.Base64Helper().decodeSync(cipherBase64);
  const out = cipher.doFinalSync({ data: cipherBytes });
  return new util.TextDecoder('utf-8').decodeToString(out.data);
}
