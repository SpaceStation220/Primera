import {
  Button,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  queued: number;
  capacity: number;
  progress: number;
  operational: boolean;
  research?: number;
  maxResearch?: number;
};

export const Xenoarchaeology = () => {
  const { act, data } = useBackend<Data>();
  return (
    <Window width={440} height={330}>
      <Window.Content>
        {!data.operational && (
          <NoticeBox>
            Обработка остановлена. Проверьте питание, крепление и сервисную
            панель.
          </NoticeBox>
        )}
        <Section
          title="Обработка образцов"
          buttons={<Button onClick={() => act('eject')}>Извлечь всё</Button>}
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
      </Window.Content>
    </Window>
  );
};
