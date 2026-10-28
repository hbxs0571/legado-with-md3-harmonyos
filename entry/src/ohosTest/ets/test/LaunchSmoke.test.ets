import { describe, expect, it } from '@ohos/hypium';
import abilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';
import { Driver, ON } from '@ohos.UiTest';

export default function launchSmokeTest(): void {
  describe('Legado 首页启动检查', () => {
    it('启动后显示首页或首次启动向导', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({
        bundleName: 'io.legado.harmony',
        abilityName: 'EntryAbility'
      });

      const driver = Driver.create();
      await driver.delayMs(2500);
      const homeLabels = await driver.findComponents(ON.text('首页'));
      const welcomeLabels = await driver.findComponents(ON.text('欢迎'));
      expect(homeLabels.length + welcomeLabels.length > 0).assertTrue();
    });
  });
}
