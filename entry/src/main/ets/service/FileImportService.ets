import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BOOKS_DIR } from '../common/constants/AppConstants';
import { LogUtil } from '../common/utils/LogUtil';

export class FileImportService {
  /**
   * 打开系统文件选择器，选择并导入电子书文件到应用沙箱
   * @returns 沙箱内文件路径，失败返回 null
   */
  async selectAndImport(context: common.UIAbilityContext): Promise<string | null> {
    try {
      // 确保目标目录存在
      const destDir = `${context.filesDir}/${BOOKS_DIR}`;
      if (!fileIo.accessSync(destDir)) {
        fileIo.mkdirSync(destDir);
      }

      // 打开文件选择器（fileSuffixFilters 必须带 . 前缀）
      const documentPicker = new picker.DocumentViewPicker(context);
      const selectOptions = new picker.DocumentSelectOptions();
      selectOptions.maxSelectNumber = 1;
      selectOptions.fileSuffixFilters = ['.epub', '.txt', '.mobi', '.azw', '.azw3'];
      const selectResult = await documentPicker.select(selectOptions);

      if (!selectResult || selectResult.length === 0) {
        LogUtil.info('User cancelled file selection');
        return null;
      }

      const srcUri = selectResult[0];
      LogUtil.info(`Selected file URI: ${srcUri}`);

      // 从 URI 提取文件名
      const fileName = this.extractFileName(srcUri);
      const destPath = `${destDir}/${fileName}`;

      // 检查是否已存在（避免重复导入）
      if (fileIo.accessSync(destPath)) {
        LogUtil.info(`File already exists: ${destPath}`);
        return destPath;
      }

      // 复制文件到沙箱：picker 返回的是 URI，需先 openSync 获取 fd
      const srcFile = fileIo.openSync(srcUri, fileIo.OpenMode.READ_ONLY);
      try {
        fileIo.copyFileSync(srcFile.fd, destPath);
        LogUtil.info(`File imported to: ${destPath}`);
      } finally {
        fileIo.closeSync(srcFile);
      }
      return destPath;
    } catch (err) {
      LogUtil.error(`File import failed: ${JSON.stringify(err)}`);
      return null;
    }
  }

  /**
   * 从 URI 中提取文件名（含 URI 解码）
   */
  private extractFileName(uri: string): string {
    const parts = uri.split('/');
    const rawName = parts[parts.length - 1] || 'unknown.txt';
    try {
      return decodeURIComponent(rawName);
    } catch (e) {
      return rawName;
    }
  }

  /**
   * 获取文件大小
   */
  static getFileSize(filePath: string): number {
    try {
      const stat = fileIo.statSync(filePath);
      return stat.size;
    } catch (err) {
      LogUtil.error(`Failed to get file size: ${JSON.stringify(err)}`);
      return 0;
    }
  }

  /**
   * 从文件名提取格式后缀
   */
  static getFormatFromFileName(fileName: string): string {
    const dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex === fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  /**
   * 删除沙箱中的书籍文件
   */
  static deleteBookFile(filePath: string): void {
    try {
      if (fileIo.accessSync(filePath)) {
        fileIo.unlinkSync(filePath);
        LogUtil.info(`Book file deleted: ${filePath}`);
      }
    } catch (err) {
      LogUtil.error(`Failed to delete book file: ${JSON.stringify(err)}`);
    }
  }
}
