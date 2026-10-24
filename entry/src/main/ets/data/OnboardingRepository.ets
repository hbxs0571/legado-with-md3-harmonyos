import { preferences } from '@kit.ArkData';

export interface OnboardingSnapshot {
  completed: boolean;
  themeMode: number;
  paletteIndex: number;
}

export class OnboardingRepository {
  private static readonly preferenceName: string = 'legado_first_run';

  static async load(context: Context): Promise<OnboardingSnapshot> {
    const defaults: OnboardingSnapshot = { completed: false, themeMode: 0, paletteIndex: 0 };
    try {
      const store = await preferences.getPreferences(context, OnboardingRepository.preferenceName);
      const completed = await store.get('completed', false);
      const themeMode = await store.get('themeMode', defaults.themeMode);
      const paletteIndex = await store.get('paletteIndex', defaults.paletteIndex);
      return {
        completed: typeof completed === 'boolean' ? completed : false,
        themeMode: typeof themeMode === 'number' ? Math.max(0, Math.min(2, themeMode)) : defaults.themeMode,
        paletteIndex: typeof paletteIndex === 'number' ? Math.max(0, Math.min(4, paletteIndex)) : defaults.paletteIndex
      };
    } catch (_) {
      return defaults;
    }
  }

  static async complete(context: Context, themeMode: number, paletteIndex: number): Promise<void> {
    const store = await preferences.getPreferences(context, OnboardingRepository.preferenceName);
    await store.put('themeMode', Math.max(0, Math.min(2, themeMode)));
    await store.put('paletteIndex', Math.max(0, Math.min(4, paletteIndex)));
    await store.put('completed', true);
    await store.flush();
  }
}
