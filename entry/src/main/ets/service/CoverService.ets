import { common } from '@kit.AbilityKit';
import { image } from '@kit.MultimediaImage';
import { fileIo } from '@kit.CoreFileKit';
import { COVERS_DIR } from '../common/constants/AppConstants';
import { LogUtil } from '../common/utils/LogUtil';

export class CoverService {
  /**
   * 生成文字占位封面图并缓存
   * 用于无封面的书籍
   */
  static async generatePlaceholderCover(
    context: common.UIAbilityContext,
    bookTitle: string,
    bookId: number
  ): Promise<string> {
    const coversDir = `${context.filesDir}/${COVERS_DIR}`;
    if (!fileIo.accessSync(coversDir)) {
      fileIo.mkdirSync(coversDir);
    }

    const coverPath = `${coversDir}/cover_${bookId}.png`;
    // 如果已存在则直接返回
    if (fileIo.accessSync(coverPath)) {
      return coverPath;
    }

    try {
      const width = 200;
      const height = 280;
      const imageData = image.createPixelMapSync(new ArrayBuffer(width * height * 4), {
        pixelFormat: image.PixelFormat.RGBA_8888,
        size: { width, height },
      });

      // 简单纯色占位，实际项目用 Canvas API 绘制渐变 + 文字
      const buffer = imageData.getImageDataSync();
      const hash = bookTitle.split('').reduce((acc, c) => acc + c.charCodeAt(0), 0);
      const hue = hash % 360;
      const r = Math.round(128 + 64 * Math.sin(hue * Math.PI / 180));
      const g = Math.round(128 + 64 * Math.sin((hue + 120) * Math.PI / 180));
      const b = Math.round(128 + 64 * Math.sin((hue + 240) * Math.PI / 180));

      for (let i = 0; i < buffer.data.length; i += 4) {
        buffer.data[i] = r;     // R
        buffer.data[i + 1] = g; // G
        buffer.data[i + 2] = b; // B
        buffer.data[i + 3] = 255; // A
      }
      imageData.writeImageDataSync(buffer);

      const imagePackerApi = image.createImagePacker();
      const packOpts: image.PackingOption = { format: 'image/png', quality: 90 };
      const packedData = await imagePackerApi.packing(imageData, packOpts);

      // Note: In actual HarmonyOS 6.0, use fileIo.write for ArrayBuffer
      const file = fileIo.openSync(coverPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      fileIo.writeSync(file.fd, packedData);
      fileIo.closeSync(file);

      LogUtil.info(`Placeholder cover generated: ${coverPath}`);
      return coverPath;
    } catch (err) {
      LogUtil.error(`Failed to generate placeholder cover: ${JSON.stringify(err)}`);
      return '';
    }
  }
}
