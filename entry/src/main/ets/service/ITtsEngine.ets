import { common } from '@kit.AbilityKit';

export type TtsEngineState = 'idle' | 'playing' | 'paused' | 'stopped' | 'error';
export type TtsEngineType = 'system' | 'qwen';

export interface TtsEngineEventCallback {
  onStateChange?: (state: TtsEngineState) => void;
  onStart?: () => void;
  onComplete?: () => void;
  onError?: (message: string) => void;
}

export interface TtsEngineInitParams {
  context: common.UIAbilityContext;
  modelDir?: string;
  voice?: string;
  speed?: number;
}

/**
 * TTS 引擎抽象接口。系统 TTS 和 Qwen 本地 TTS 都实现此接口，
 * TtsService 根据设置选择具体引擎。
 */
export interface ITtsEngine {
  init(params: TtsEngineInitParams): Promise<void>;
  speak(text: string, requestId: string): void;
  stop(): void;
  pause(): void;
  resume(): void;
  setSpeed(speed: number): void;
  setVoice(voice: string): Promise<void>;
  release(): void;
  setEventCallback(callback: TtsEngineEventCallback | null): void;
}
