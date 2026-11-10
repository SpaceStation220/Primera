import { useState } from 'react';
import { Box, Button, Icon, NoticeBox, NumberInput, ProgressBar, Section, Stack, Tabs } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Program = {
  id: string;
  name: string;
  description: string;
  icon: string;
  size: number;
  illegal: boolean;
  installed: boolean;
  running: boolean;
  passive: boolean;
  ready: boolean;
};

type Data = {
  programs: Program[];
  used: number;
  capacity: number;
  charge: number;
  error?: string;
  frequency: number;
  code: number;
  minFrequency: number;
  maxFrequency: number;
};

export const IpcOS = () => {
  const { act, data } = useBackend<Data>();
  const [tab, setTab] = useState('desktop');
  const [selected, setSelected] = useState<string | null>(null);
  const installed = data.programs.filter((program) => program.installed);
  const program = installed.find((entry) => entry.id === selected);
  return (
    <Window width={720} height={580} theme="generic">
      <Window.Content scrollable style={{ backgroundImage: 'none' }}>
        <Section title="Positronic OS">
          <Stack align="center">
            <Stack.Item grow>
              <ProgressBar value={data.used / data.capacity}>
                {data.used} / {data.capacity} GB
              </ProgressBar>
            </Stack.Item>
            <Stack.Item>Заряд: {data.charge}%</Stack.Item>
          </Stack>
        </Section>
        <Tabs>
          <Tabs.Tab selected={tab === 'desktop'} icon="desktop" onClick={() => setTab('desktop')}>
            Рабочий стол
          </Tabs.Tab>
          <Tabs.Tab selected={tab === 'net'} icon="download" onClick={() => setTab('net')}>
            NET
          </Tabs.Tab>
        </Tabs>
        {!!data.error && <NoticeBox danger>{data.error}</NoticeBox>}
        {tab === 'desktop' ? (
          <>
            <Section title="Установленные программы">
              {!installed.length && <Box color="label">Установите программы из NET.</Box>}
              {installed.map((entry) => (
                <Button
                  key={entry.id}
                  width="128px"
                  height="82px"
                  textAlign="center"
                  verticalAlign="top"
                  mr={1}
                  mb={1}
                  selected={selected === entry.id}
                  onClick={() => setSelected(entry.id)}
                >
                  <Box mt={1} mb={0.5}><Icon name={entry.icon} size={2} /></Box>
                  <Box>{entry.name}</Box>
                </Button>
              ))}
            </Section>
            {program && (
              <Section
                title={program.name}
                buttons={<Button icon="trash" color="bad" onClick={() => act('uninstall', { id: program.id })}>Удалить</Button>}
              >
                <Box mb={1}>{program.description}</Box>
                <Box color="label">Занимает {program.size} GB.</Box>
                {program.ready ? (
                  <>
                    <Box my={1} color={program.running ? 'good' : 'label'}>
                      {program.running ? 'Работает' : 'Остановлена'}
                    </Box>
                    {!program.passive && (
                      <Button icon={program.running ? 'stop' : 'play'} onClick={() => act('toggle', { id: program.id })}>
                        {program.running ? 'Остановить' : 'Запустить'}
                      </Button>
                    )}
                    {program.passive && <Box color="label">Работает автоматически при включённой ОС.</Box>}
                    {program.running && program.id === 'pda' && (
                      <Button icon="tablet" onClick={() => act('pda_open')}>Открыть КПК</Button>
                    )}
                    {program.running && program.id === 'signal_boost' && (
                      <Section title="Передатчик">
                        <Stack align="center">
                          <Stack.Item>Частота</Stack.Item>
                          <Stack.Item>
                            <NumberInput value={data.frequency} minValue={data.minFrequency} maxValue={data.maxFrequency} step={2} onChange={(value) => act('signal_freq', { value })} />
                          </Stack.Item>
                          <Stack.Item>Код</Stack.Item>
                          <Stack.Item>
                            <NumberInput value={data.code} minValue={1} maxValue={100} step={1} onChange={(value) => act('signal_code', { value })} />
                          </Stack.Item>
                          <Stack.Item>
                            <Button icon="satellite-dish" onClick={() => act('signal_send')}>Передать</Button>
                          </Stack.Item>
                        </Stack>
                      </Section>
                    )}
                  </>
                ) : <NoticeBox>Программа пока недоступна.</NoticeBox>}
              </Section>
            )}
          </>
        ) : (
          <>
            {[false, true].map((illegal) => (
              <Section key={String(illegal)} title={illegal ? 'Black Wall' : 'White Wall'}>
                {data.programs.filter((entry) => entry.illegal === illegal).map((entry) => (
                  <Section
                    key={entry.id}
                    title={`${entry.name} · ${entry.size} GB`}
                    buttons={
                      <Button
                        icon={entry.installed ? 'check' : 'download'}
                        disabled={entry.installed || data.used + entry.size > data.capacity}
                        onClick={() => act('install', { id: entry.id })}
                      >
                        {entry.installed ? 'Установлено' : 'Установить'}
                      </Button>
                    }
                  >
                    {entry.description}
                  </Section>
                ))}
                {illegal && !data.programs.some((entry) => entry.illegal) && (
                  <Box color="label">Каталог недоступен. Требуется нелегальное обновление.</Box>
                )}
              </Section>
            ))}
          </>
        )}
      </Window.Content>
    </Window>
  );
};
