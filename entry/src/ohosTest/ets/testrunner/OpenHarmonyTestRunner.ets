import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';
import { UIAbility, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * Hypium 测试运行器入口。
 * 工程原本缺少此文件，aa test 会报
 * "Cannot find module 'io.legado.harmony/entry_test/ets/testrunner/OpenHarmonyTestRunner'"。
 * 参照 DevEco 自带模板补齐，去掉 mock-config 检查以缩小失败面。
 */

const TAG: string = 'TestRunner';

async function onAbilityCreateCallback(data: UIAbility): Promise<void> {
  hilog.info(0x0000, TAG, 'onAbilityCreateCallback: %{public}s', JSON.stringify(data));
}

async function addAbilityMonitorCallback(err: BusinessError): Promise<void> {
  hilog.info(0x0000, TAG, 'addAbilityMonitorCallback: %{public}s', JSON.stringify(err) ?? '');
}

export default class OpenHarmonyTestRunner implements TestRunner {
  constructor() {
  }

  onPrepare(): void {
    hilog.info(0x0000, TAG, '%{public}s', 'onPrepare');
  }

  async onRun(): Promise<void> {
    hilog.info(0x0000, TAG, '%{public}s', 'onRun start');
    const args = abilityDelegatorRegistry.getArguments();
    const delegator = abilityDelegatorRegistry.getAbilityDelegator();
    const moduleName: string = args.parameters['-m'] as string;
    const bundleName: string = args.bundleName;
    const testAbilityName: string = 'TestAbility';

    const monitor: abilityDelegatorRegistry.AbilityMonitor = {
      abilityName: testAbilityName,
      moduleName: moduleName,
      onAbilityCreate: onAbilityCreateCallback
    };
    delegator.addAbilityMonitor(monitor, addAbilityMonitorCallback);

    const want: Want = {
      bundleName: bundleName,
      abilityName: testAbilityName,
      moduleName: moduleName
    };
    delegator.startAbility(want, (err: BusinessError, data: void) => {
      hilog.info(0x0000, TAG, 'startAbility err: %{public}s', JSON.stringify(err) ?? '');
      hilog.info(0x0000, TAG, 'startAbility data: %{public}s', JSON.stringify(data) ?? '');
    });
    hilog.info(0x0000, TAG, '%{public}s', 'onRun end');
  }
}
