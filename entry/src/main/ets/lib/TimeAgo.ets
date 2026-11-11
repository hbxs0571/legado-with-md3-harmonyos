/**
 * 相对时间文案，对应上游 BookHelp / toTimeAgo() 的口径：
 * 刚刚 / N 分钟前 / N 小时前 / N 天前 / N 个月前。
 * 纯函数，不查章节表；本地书不显示最后更新时间时用不到它，见 :127。
 */
export function toTimeAgo(timestamp: number): string {
  if (timestamp <= 0) {
    return '';
  }
  const diff = Date.now() - timestamp;
  if (diff < 60 * 1000) {
    return '刚刚';
  }
  const minutes = Math.floor(diff / (60 * 1000));
  if (minutes < 60) {
    return `${minutes} 分钟前`;
  }
  const hours = Math.floor(diff / (60 * 60 * 1000));
  if (hours < 24) {
    return `${hours} 小时前`;
  }
  const days = Math.floor(diff / (24 * 60 * 60 * 1000));
  if (days < 30) {
    return `${days} 天前`;
  }
  return `${Math.floor(days / 30)} 个月前`;
}
