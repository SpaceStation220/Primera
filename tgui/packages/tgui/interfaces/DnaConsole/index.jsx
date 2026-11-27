import {
  Box,
  Button,
  Dimmer,
  Icon,
  LabeledList,
  Section,
  Stack,
} from 'tgui-core/components';

import { useBackend } from '../../backend';
import { Window } from '../../layouts';
import {
  CONSOLE_MODE_ENZYMES,
  CONSOLE_MODE_FEATURES,
  CONSOLE_MODE_SEQUENCER,
  CONSOLE_MODE_STORAGE,
  STORAGE_MODE_CONSOLE,
} from './constants';
import { DnaConsoleEnzymes } from './DnaConsoleEnzymes';
import { DnaConsoleSequencer } from './DnaConsoleSequencer';
import { DnaConsoleStorage } from './DnaConsoleStorage';
import { DnaScanner } from './DnaScanner';

export const DnaConsole = (props) => {
  const { data } = useBackend();
  const { isPulsing, timeToPulse, subjectUNI, subjectUF, targetUNI, targetUF } =
    data;
  const { consoleMode } = data.view;

  return (
    <Window title="Консоль ДНК" width={550} height={710}>
      {!!isPulsing && (
        <Dimmer fontSize="14px" textAlign="center">
          <Icon mr={1} name="spinner" spin />
          Идёт облучение…
          <Box mt={1} />
          {timeToPulse} с
        </Dimmer>
      )}
      <Window.Content scrollable>
        <Stack fill vertical>
          <Stack.Item>
            <DnaScanner />
          </Stack.Item>
          <Stack.Item>
            <DnaConsoleCommands />
          </Stack.Item>
          <Stack.Item grow>
            {consoleMode === CONSOLE_MODE_STORAGE && <DnaConsoleStorage />}
            {consoleMode === CONSOLE_MODE_SEQUENCER && <DnaConsoleSequencer />}
            {(consoleMode === CONSOLE_MODE_ENZYMES ||
              consoleMode === CONSOLE_MODE_FEATURES) && (
              <DnaConsoleEnzymes
                subjectBlock={
                  consoleMode === CONSOLE_MODE_FEATURES ? subjectUF : subjectUNI
                }
                targetBlock={
                  consoleMode === CONSOLE_MODE_FEATURES ? targetUF : targetUNI
                }
                type={consoleMode === CONSOLE_MODE_FEATURES ? 'uf' : 'ui'}
                name={
                  consoleMode === CONSOLE_MODE_FEATURES
                    ? 'Видовая ДНК'
                    : 'Базовая ДНК'
                }
              />
            )}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const DnaConsoleCommands = (props) => {
  const { data, act } = useBackend();
  const { hasDisk, isInjectorReady, injectorSeconds } = data;
  const { consoleMode } = data.view;

  return (
    <Section
      title="Консоль ДНК"
      buttons={
        !isInjectorReady && (
          <Box lineHeight="20px" color="label">
            Инъектор готов через {injectorSeconds} с
          </Box>
        )
      }
    >
      <LabeledList>
        <LabeledList.Item label="Раздел">
          <Button
            content="Хранилище"
            selected={consoleMode === CONSOLE_MODE_STORAGE}
            onClick={() =>
              act('set_view', {
                consoleMode: CONSOLE_MODE_STORAGE,
              })
            }
          />
          <Button
            content="Мутации"
            disabled={!data.isViableSubject}
            selected={consoleMode === CONSOLE_MODE_SEQUENCER}
            onClick={() =>
              act('set_view', {
                consoleMode: CONSOLE_MODE_SEQUENCER,
              })
            }
          />
          <Button
            content="Внешность"
            selected={
              consoleMode === CONSOLE_MODE_ENZYMES ||
              consoleMode === CONSOLE_MODE_FEATURES
            }
            onClick={() =>
              act('set_view', {
                consoleMode:
                  consoleMode === CONSOLE_MODE_FEATURES
                    ? CONSOLE_MODE_FEATURES
                    : CONSOLE_MODE_ENZYMES,
              })
            }
          />
        </LabeledList.Item>
        {!!hasDisk && (
          <LabeledList.Item label="Диск">
            <Button
              icon="eject"
              content="Извлечь"
              onClick={() => {
                act('eject_disk');
                act('set_view', {
                  storageMode: STORAGE_MODE_CONSOLE,
                });
              }}
            />
          </LabeledList.Item>
        )}
      </LabeledList>
    </Section>
  );
};
