/** 与 Android BookGroup 对应的可见分组元数据。 */
export interface BookGroup {
  groupId: number;
  groupName: string;
  order: number;
  show: boolean;
  enableRefresh: boolean;
  bookSort: number;
  isPrivate: boolean;
}
