import Ability from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';

export default class MainAbility extends Ability {
  onCreate(want, launchParam) {
    console.log('MainAbility onCreate');
  }

  onDestroy() {
    console.log('MainAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    console.log('MainAbility onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        console.error('Failed to load the content. Cause: ' + JSON.stringify(err));
        return;
      }
      console.log('Succeeded in loading the content. Data: ' + JSON.stringify(data));
    });
  }

  onWindowStageDestroy() {
    console.log('MainAbility onWindowStageDestroy');
  }

  onForeground() {
    console.log('MainAbility onForeground');
  }

  onBackground() {
    console.log('MainAbility onBackground');
  }
}
