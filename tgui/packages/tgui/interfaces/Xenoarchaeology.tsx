import { useState } from 'react';
import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Tabs,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import {
  type CatalogueData,
  XenoarchCatalogue,
} from './Xenoarchaeology/Catalogue';

type Data = {
  queued: number;
  capacity: number;
  progress: number;
  operational: boolean;
  research?: number;
  maxResearch?: number;
  catalogue?: CatalogueData;
};

export const Xenoarchaeology = () => {
  const { act, data } = useBackend<Data>();
  const [tab, setTab] = useState('processing');
  return (
    <Window
      width={data.catalogue ? 780 : 440}
      height={data.catalogue ? 680 : 330}
    >
      <Window.Content scrollable>
        {!data.operational && (
          <NoticeBox>
            Обработка остановлена. Проверьте питание, крепление и сервисную
            панель.
          </NoticeBox>
        )}
        {data.catalogue && (
          <Tabs>
            <Tabs.Tab
              selected={tab === 'processing'}
              onClick={() => setTab('processing')}
            >
              Образцы и награды
            </Tabs.Tab>
            <Tabs.Tab
              selected={tab === 'catalogue'}
              onClick={() => setTab('catalogue')}
            >
              Журнал исследований ({data.catalogue.entries.length})
            </Tabs.Tab>
          </Tabs>
        )}
        {data.catalogue && tab === 'catalogue' ? (
          <XenoarchCatalogue
            catalogue={data.catalogue}
            operational={data.operational}
            research={data.research ?? 0}
            maxResearch={data.maxResearch ?? 0}
          />
        ) : (
          <Box>
            <Section
              title="Обработка образцов"
              buttons={
                <Button onClick={() => act('eject')}>Извлечь всё</Button>
              }
            >
              <LabeledList>
                <LabeledList.Item label="В очереди">
                  {data.queued} / {data.capacity}
                </LabeledList.Item>
                <LabeledList.Item label="Прогресс">
                  <ProgressBar value={data.progress} />
                </LabeledList.Item>
              </LabeledList>
            </Section>
            {data.research !== undefined && (
              <Section
                title={`Исследование: ${data.research} / ${data.maxResearch}`}
              >
                <Button
                  fluid
                  disabled={data.research < 100 || !data.operational}
                  onClick={() => act('redeem', { reward: 'crate' })}
                >
                  Сундук некрополя — 100
                </Button>
                <Button
                  fluid
                  disabled={data.research < 100 || !data.operational}
                  onClick={() => act('redeem', { reward: 'crystal' })}
                >
                  Аномальный кристалл — 100
                </Button>
                <Button
                  fluid
                  disabled={data.research < 60 || !data.operational}
                  onClick={() => act('redeem', { reward: 'technology' })}
                >
                  Технология B.E.P.I.S. — 60
                </Button>
              </Section>
            )}
          </Box>
        )}
      </Window.Content>
    </Window>
  );
};
