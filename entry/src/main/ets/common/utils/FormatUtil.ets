// 格式化工具
export class FormatUtil {
  /**
   * 格式化文件大小
   */
  static formatFileSize(bytes: number): string {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  }

  /**
   * 格式化时间戳为日期
   */
  static formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  /**
   * 格式化阅读进度百分比
   */
  static formatProgress(current: number, total: number): string {
    if (total === 0) return '0%';
    return Math.round((current / total) * 100) + '%';
  }
}
