import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import { MarkdownRenderer } from './MarkdownViewer';

type Data = {
  mode: 'analyzer' | 'spectrometer' | 'harvester' | 'draining';
  active: boolean;
  operational: boolean;
  progress: number;
  report: string;
  hasPad: boolean;
  hasSample: boolean;
  hasBattery: boolean;
  charge: number;
  capacity: number;
};

export const XenoartifactLab = () => {
  const { act, data } = useBackend<Data>();
  const harvester = data.mode === 'harvester' || data.mode === 'draining';
  return (
    <Window width={500} height={410}>
      <Window.Content scrollable>
        {!data.operational && (
          <NoticeBox>
            Проверьте питание, крепление и сервисную панель.
          </NoticeBox>
        )}
        <Section
          title="Состояние"
          buttons={
            <Button onClick={() => act('eject')}>Остановить и извлечь</Button>
          }
        >
          <LabeledList>
            <LabeledList.Item label="Работа">
              {data.active ? 'Выполняется' : 'Ожидание'}
            </LabeledList.Item>
            {data.mode !== 'spectrometer' && (
              <LabeledList.Item label="Площадка">
                {data.hasPad ? 'Подключена' : 'Не найдена рядом'}
              </LabeledList.Item>
            )}
            {data.mode === 'spectrometer' && (
              <LabeledList.Item label="Керн">
                {data.hasSample ? 'Загружен' : 'Не загружен'}
              </LabeledList.Item>
            )}
          </LabeledList>
          <ProgressBar
            value={harvester ? data.charge / data.capacity : data.progress}
          >
            {harvester
              ? `${Math.round(data.charge)} / ${data.capacity}`
              : 'Анализ'}
          </ProgressBar>
          <Button
            disabled={data.active || !data.operational}
            onClick={() => act(harvester ? 'harvest' : 'scan')}
          >
            {harvester ? 'Собирать частицы' : 'Начать анализ'}
          </Button>
          <Button disabled={!data.active} onClick={() => act('stop')}>
            Остановить
          </Button>
        </Section>
        {harvester ? (
          <Section title="Батарея">
            <Box mb={1}>
              {data.hasBattery ? 'Установлена' : 'Вставьте батарею частиц'}
            </Box>
            <Button.Confirm
              color="bad"
              disabled={data.active || !data.operational || data.charge <= 0}
              onClick={() => act('drain')}
            >
              Опасный разряд: высвободить эффект рядом
            </Button.Confirm>
          </Section>
        ) : (
          <Section title="Отчёт">
            {data.report ? (
              <MarkdownRenderer content={data.report} sanitize />
            ) : (
              'Результатов пока нет.'
            )}
          </Section>
        )}
      </Window.Content>
    </Window>
  );
};
