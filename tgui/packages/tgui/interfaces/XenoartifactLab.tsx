import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  NumberInput,
  ProgressBar,
  Section,
  Slider,
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
  control?: {
    temperature: number;
    maxTemperature: number;
    rpm: number;
    seal: number;
    coolant: number;
    coolantCapacity: number;
    coolantQuality: number;
    coolantRate: number;
    maxCoolantRate: number;
    wavelength: number;
    optimalWavelength: number;
    maxWavelength: number;
    efficiency: number;
    shieldClosed: boolean;
    radiationBurst: boolean;
    radiationTimer: number;
  };
};

export const XenoartifactLab = () => {
  const { act, data } = useBackend<Data>();
  const harvester = data.mode === 'harvester' || data.mode === 'draining';
  const control = data.control;
  return (
    <Window width={500} height={control ? 790 : 410}>
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
                {data.hasPad ? 'Подключена' : 'Нет свободной рядом'}
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
        {control && (
          <Section title="Управление спектрометром">
            <NoticeBox>
              Поддерживайте настройку рядом с требуемой волной. Залейте хладагент
              из открытой ёмкости ЛКМ, слейте в неё ПКМ. Объём задаётся дозой
              перелива ёмкости. Нанопаста восстанавливает уплотнение. Для перелива
              и ремонта остановите прибор. Вода подходит для базового охлаждения;
              криоксадон и криостилан эффективнее.
            </NoticeBox>
            {data.active && control.radiationBurst && (
              <NoticeBox danger>
                Всплеск излучения! Закройте защитный экран.
              </NoticeBox>
            )}
            <LabeledList>
              <LabeledList.Item label="Требуемая волна">
                {control.optimalWavelength} у.е.
              </LabeledList.Item>
              <LabeledList.Item label="Настройка волны">
                <Slider
                  value={control.wavelength}
                  minValue={1}
                  maxValue={control.maxWavelength}
                  step={100}
                  stepPixelSize={3}
                  tickWhileDragging
                  unit="у.е."
                  fillValue={control.optimalWavelength}
                  disabled={!data.operational}
                  onChange={(_, value) => act('set_wavelength', { value })}
                />
                <Box fontSize="0.85em" color="label">
                  1–{control.maxWavelength} у.е.; перетащите ползунок
                </Box>
              </LabeledList.Item>
              <LabeledList.Item label="Эффективность">
                <ProgressBar value={control.efficiency}>
                  {Math.round(control.efficiency * 100)}%
                </ProgressBar>
              </LabeledList.Item>
              <LabeledList.Item label="Хладагент">
                {control.coolant} / {control.coolantCapacity} ед.; качество{' '}
                {Math.round(control.coolantQuality * 100)}%
              </LabeledList.Item>
              <LabeledList.Item label="Расход">
                <NumberInput
                  value={control.coolantRate}
                  minValue={0}
                  maxValue={control.maxCoolantRate}
                  step={0.1}
                  unit="ед./с"
                  disabled={!data.operational}
                  onChange={(value) => act('set_coolant_rate', { value })}
                />
              </LabeledList.Item>
              <LabeledList.Item label="Температура">
                <ProgressBar
                  value={control.temperature / control.maxTemperature}
                  color={control.temperature >= 700 ? 'bad' : 'good'}
                >
                  {control.temperature} °C
                </ProgressBar>
              </LabeledList.Item>
              <LabeledList.Item label="Уплотнение">
                <ProgressBar
                  value={control.seal / 100}
                  color={control.seal <= 20 ? 'bad' : 'good'}
                >
                  {control.seal}%
                </ProgressBar>
              </LabeledList.Item>
              <LabeledList.Item label="Ротор">
                {control.rpm} об./мин
              </LabeledList.Item>
              <LabeledList.Item label="Защитный экран">
                <Button
                  selected={control.shieldClosed}
                  disabled={!data.operational}
                  onClick={() => act('toggle_shield')}
                >
                  {control.shieldClosed ? 'Закрыт — анализ на паузе' : 'Открыт'}
                </Button>
              </LabeledList.Item>
              <LabeledList.Item label="Излучение">
                {!data.active
                  ? 'Прибор остановлен'
                  : control.radiationBurst
                    ? control.shieldClosed
                      ? 'Всплеск, экран закрыт'
                      : 'Опасный всплеск'
                    : `Следующий всплеск через ${control.radiationTimer} с`}
              </LabeledList.Item>
            </LabeledList>
          </Section>
        )}
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
