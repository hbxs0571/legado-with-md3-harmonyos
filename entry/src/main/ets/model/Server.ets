
/**
 * 与上游 Server 实体对齐的服务器配置。
 * 上游：app/src/main/java/io/legado/app/data/entities/Server.kt（56 行）
 * @Entity(tableName = "servers")，主键 id: Long = System.currentTimeMillis()。
 * 上游 type 是枚举 TYPE，当前只有 WEBDAV 一个值，本地存整数保持逐字节往返。
 */
export interface Server {
  id: number;
  name: string;
  type: number;
  config?: string;
  sortNumber: number;
  sourceJson: string;
}

/**
 * Server.config 那段 JSON 的形状（上游 Server.kt 内嵌的 WebDavConfig）。
 * 只在需要取 url/username/password 时解析；写回一律走 sourceJson，不反向拼。
 */
export interface WebDavConfig {
  url: string;
  username: string;
  password: string;
}
