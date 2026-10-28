import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import abilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';
import { Hypium } from '@ohos/hypium';
import testsuite from '../test/List.test';

export default class TestAbility extends UIAbility {
  private abilityDelegator: abilityDelegatorRegistry.AbilityDelegator;

  constructor() {
    super();
    this.abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();
  }

  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    const argumentsForTests = abilityDelegatorRegistry.getArguments();
    Hypium.hypiumTest(this.abilityDelegator, argumentsForTests, testsuite);
  }

  onDestroy(): void {
    this.abilityDelegator.finishTest('TestAbility 意外退出', -2, () => {});
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      windowStage.loadContent('testability/pages/Index');
    } catch (_) {
    }
  }
}
