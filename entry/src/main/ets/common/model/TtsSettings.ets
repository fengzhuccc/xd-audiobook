import { TtsEngineType } from '../service/ITtsEngine';

// 朗读设置模型
export interface TtsSettings {
  speed: number;
  autoNextChapter: boolean;
  highlightEnabled: boolean;
  voicePerson: number;
  engineType: TtsEngineType;
}
