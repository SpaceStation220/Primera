import { useState } from 'react';
import { Box, Button, NoticeBox, ProgressBar, Section, Stack, Tabs } from 'tgui-core/components';

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
};

type Data = {
  programs: Program[];
  used: number;
  capacity: number;
  charge: number;
  error?: string;
  ready: boolean;
};

export const IpcOS = () => {
  const { act, data } = useBackend<Data>();
  const [tab, setTab] = useState('desktop');
  const [selected, setSelected] = useState<string | null>(null);
  const installed = data.programs.filter((program) => program.installed);
  const program = installed.find((entry) => entry.id === selected);
  return (
    <Window width={720} height={580}>
      <Window.Content scrollable>
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
                  icon={entry.icon}
                  selected={selected === entry.id}
                  onClick={() => setSelected(entry.id)}
                >
                  {entry.name}
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
                {!data.ready && <NoticeBox>Исполнение программ пока недоступно.</NoticeBox>}
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
