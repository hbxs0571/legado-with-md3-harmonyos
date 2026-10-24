import { preferences } from '@kit.ArkData';

export type HomeDashboardSection = 'recentBook' | 'totalBooks' | 'totalTime' | 'recentBooks' | 'dailyGoal' | 'backup';

export const HOME_DASHBOARD_SECTIONS: HomeDashboardSection[] = [
  'recentBook', 'totalBooks', 'totalTime', 'recentBooks', 'dailyGoal', 'backup'
];

export class HomeDashboardSettingsRepository {
  private static readonly preferenceName: string = 'legado_home_dashboard';

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
