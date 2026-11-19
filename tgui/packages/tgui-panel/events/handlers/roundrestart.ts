import { resetInstrumentMusic } from '../../audio/instruments';
import { saveChatToStorage } from '../../chat/helpers';
import { roundRestartedAtAtom } from '../../game/atoms';
import { store } from '../store';

export function roundrestart() {
  resetInstrumentMusic();
  store.set(roundRestartedAtAtom, Date.now());
  saveChatToStorage();
}
