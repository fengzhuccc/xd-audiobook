// 书籍信息模型
export interface BookInfo {
  id?: number;
  title: string;
  author: string;
  filePath: string;
  fileName: string;
  fileFormat: string;
  fileSize: number;       // bytes
  coverPath?: string;
  language?: string;
  totalSpines?: number;
  addTime: number;        // timestamp
  lastReadTime?: number;   // timestamp
}
