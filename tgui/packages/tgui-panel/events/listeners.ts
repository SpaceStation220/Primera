import { loadStyleSheet } from 'common/assets';
import { EventBus } from 'tgui-core/eventbus';
import { playMusic, stopMusic } from '../audio/handlers';
import {
  abortInstrumentTransfer,
  beginInstrumentTransfer,
  playInstrumentMusic,
  receiveInstrumentChunk,
  stopInstrumentMusic,
} from '../audio/instruments';
import { chatMessage } from '../chat/handlers';
import * as emotes from '../emotes/handlers'; // BANDASTATION ADDITON: Emote panel
import { pingReply, pingSoft } from '../ping/handlers';
import {
  handleTelemetryData,
  telemetryRequest,
  testTelemetryCommand,
} from '../telemetry/handlers';
import {
  handleAddVerbs,
  handleClearCommandBar,
  handleFocusCommandBar,
  handleHotkeyMode,
  handleRemoveVerbs,
  handleTargets,
  handleVerbsInit,
} from '../verbs/handlers';
import { handleLoadAssets } from './handlers/assets';
import { playerSet } from './handlers/player';
import { roundrestart } from './handlers/roundrestart';

const listeners = {
  'verbs/add': handleAddVerbs,
  'verbs/clear': handleClearCommandBar,
  'verbs/focus': handleFocusCommandBar,
  'verbs/init': handleVerbsInit,
  'verbs/remove': handleRemoveVerbs,
  'verbs/targets': handleTargets,
  'verbs/hotkey_mode': handleHotkeyMode,
  'asset/stylesheet': loadStyleSheet,
  'asset/mappings': handleLoadAssets,
  'audio/playMusic': playMusic,
  'audio/stopMusic': stopMusic,
  'audio/instrumentPlay': playInstrumentMusic,
  'audio/instrumentStop': stopInstrumentMusic,
  'audio/instrumentBegin': beginInstrumentTransfer,
  'audio/instrumentChunk': receiveInstrumentChunk,
  'audio/instrumentAbort': abortInstrumentTransfer,
  'chat/message': chatMessage,
  'emotes/setList': emotes.setEmotesList, // BANDASTATION ADDITON: Emote panel
  'emotes/toggle': emotes.toggleEmotes, // BANDASTATION ADDITON: Emote panel
  'player/set': playerSet,
  'ping/reply': pingReply,
  'ping/soft': pingSoft,
  roundrestart,
  'telemetry/request': telemetryRequest,
  testTelemetryCommand,
  update: handleTelemetryData,
} as const;

export const bus = new EventBus(listeners);
