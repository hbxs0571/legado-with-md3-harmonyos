import { preferences } from '@kit.ArkData';

export type HomeDashboardSection = 'recentBook' | 'totalBooks' | 'totalTime' | 'recentBooks' | 'dailyGoal' | 'backup';

export const HOME_DASHBOARD_SECTIONS: HomeDashboardSection[] = [
  'recentBook', 'totalBooks', 'totalTime', 'recentBooks', 'dailyGoal', 'backup'
];

// 与上游 domain/model/HomeDashboard.kt:47-48 同名同值，读取时 coerceIn(1, MAX)。
export const DEFAULT_DAILY_READING_GOAL_MINUTES: number = 30;
export const MAX_DAILY_READING_GOAL_MINUTES: number = 24 * 60;

export class HomeDashboardSettingsRepository {
  private static readonly preferenceName: string = 'legado_home_dashboard';
  // 与上游 daily_reading_goal_minutes 同名，便于备份互通；readingGoalKey 是本地偏好键。
  private static readonly readingGoalKey: string = 'dailyReadingGoalMinutes';

  static async loadReadingGoal(context: Context): Promise<number> {
    try {
      const store = await preferences.getPreferences(context, HomeDashboardSettingsRepository.preferenceName);
      const value = await store.get(HomeDashboardSettingsRepository.readingGoalKey, DEFAULT_DAILY_READING_GOAL_MINUTES);
      const minutes: number = typeof value === 'number' && isFinite(value) ? value : DEFAULT_DAILY_READING_GOAL_MINUTES;
      return Math.min(MAX_DAILY_READING_GOAL_MINUTES, Math.max(1, Math.floor(minutes)));
    } catch (_) {
      return DEFAULT_DAILY_READING_GOAL_MINUTES;
    }
  }

  static async saveReadingGoal(context: Context, minutes: number): Promise<void> {
    const store = await preferences.getPreferences(context, HomeDashboardSettingsRepository.preferenceName);
    const clamped: number = Math.min(MAX_DAILY_READING_GOAL_MINUTES, Math.max(1, Math.floor(minutes)));
    await store.put(HomeDashboardSettingsRepository.readingGoalKey, clamped);
    await store.flush();
  }

  static async load(context: Context): Promise<HomeDashboardSection[]> {
    try {
      const store = await preferences.getPreferences(context, HomeDashboardSettingsRepository.preferenceName);
      const value = await store.get('visibleSections', '');
      if (typeof value !== 'string' || !value.startsWith('v1:')) {
        return [...HOME_DASHBOARD_SECTIONS];
      }
      const savedValues = value.substring(3).split(',');
      return HOME_DASHBOARD_SECTIONS.filter((section: HomeDashboardSection) => savedValues.includes(section));
    } catch (_) {
      return [...HOME_DASHBOARD_SECTIONS];
    }
  }

  static async save(context: Context, visibleSections: HomeDashboardSection[]): Promise<void> {
    const store = await preferences.getPreferences(context, HomeDashboardSettingsRepository.preferenceName);
    const values = HOME_DASHBOARD_SECTIONS.filter((section: HomeDashboardSection) => visibleSections.includes(section));
    await store.put('visibleSections', `v1:${values.join(',')}`);
    await store.flush();
  }
}
