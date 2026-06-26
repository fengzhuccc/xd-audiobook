// 书签模型
export interface Bookmark {
  id?: number;
  bookId: number;
  spineIndex: number;
  domPos: string;
  chapterTitle: string;
  note?: string;
  createTime: number;
}
