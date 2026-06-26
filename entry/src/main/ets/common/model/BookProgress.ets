// 阅读进度模型
export interface BookProgress {
  id?: number;
  bookId: number;
  spineIndex: number;
  domPos: string;
  updateTime: number;     // timestamp
}
