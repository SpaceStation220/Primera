import {
  Button,
  LabeledList,
  NumberInput,
  ProgressBar,
  Section,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  active: boolean;
  duration: number;
  remaining: number | null;
  hasBattery: boolean;
  charge: number;
  capacity: number;
  ready: boolean;
};

export const XenoartifactUtilizer = () => {
  const { act, data } = useBackend<Data>();
  const disabled =
    data.active || !data.ready || !data.hasBattery || data.charge <= 0;
  return (
    <Window width={410} height={260}>
      <Window.Content>
        <Section
          title={data.hasBattery ? 'Батарея установлена' : 'Вставьте батарею'}
          buttons={<Button onClick={() => act('eject')}>Извлечь</Button>}
        >
          <ProgressBar value={data.charge / data.capacity}>
            {Math.round(data.charge)} / {data.capacity}
          </ProgressBar>
          <LabeledList>
            <LabeledList.Item label="Состояние">
              {data.active
                ? 'Излучение'
                : data.ready
                  ? 'Ожидание'
                  : 'Перезарядка'}
            </LabeledList.Item>
            <LabeledList.Item label="Таймер, с">
              <NumberInput
                value={data.duration}
                minValue={1}
                maxValue={200}
                step={1}
                disabled={data.active}
                onChange={(value) => act('duration', { value: String(value) })}
              />
            </LabeledList.Item>
            {data.remaining !== null && (
              <LabeledList.Item label="Осталось">
                {Math.ceil(data.remaining)} с
              </LabeledList.Item>
            )}
          </LabeledList>
        </Section>
        <Button disabled={disabled} onClick={() => act('start')}>
          Непрерывно
        </Button>
        <Button disabled={disabled} onClick={() => act('timed')}>
          По таймеру
        </Button>
        <Button disabled={!data.active} onClick={() => act('stop')}>
          Выключить
        </Button>
      </Window.Content>
    </Window>
  );
};
