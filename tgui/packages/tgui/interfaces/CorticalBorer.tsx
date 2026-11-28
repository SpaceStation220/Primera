import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Choice = {
  id: string;
  name: string;
  desc: string;
  cost: number;
};

type Data = {
  chemicals: number;
  capacity: number;
  host: string | null;
  generation: number;
  rank: string;
  points: number;
  reproductions: number;
  reproduction_cost: number;
  torment_cost: number;
  torment_ready: boolean;
  controlling: boolean;
  docile: boolean;
  busy: boolean;
  sneaking: boolean;
  can_act: boolean;
  can_control: boolean;
  cult_host: boolean;
  chemistry_ready: boolean;
  chemistry: Choice[];
  focuses: (Choice & { learned: boolean })[];
};

export const CorticalBorer = () => {
  const { act, data } = useBackend<Data>();
  const unavailable = !data.can_act;
  return (
    <Window width={650} height={760}>
      <Window.Content scrollable>
        <Section title="Мозговой червь">
          <LabeledList>
            <LabeledList.Item label="Носитель">
              {data.host || 'Снаружи — используйте кнопку заражения'}
            </LabeledList.Item>
            <LabeledList.Item label="Ресурс">
              {data.chemicals} / {data.capacity}
            </LabeledList.Item>
            <LabeledList.Item label="Развитие">
              {data.rank}; поколение {data.generation}; очки: {data.points}
            </LabeledList.Item>
            <LabeledList.Item label="Размножения к следующему рангу">
              {data.reproductions}
            </LabeledList.Item>
          </LabeledList>
        </Section>
        {!!data.docile && (
          <NoticeBox danger>
            Сахар подавляет ваши способности и прекращает контроль. Ждите его
            выведения из организма носителя.
          </NoticeBox>
        )}
        {!!data.busy && (
          <NoticeBox>Действие выполняется. Дождитесь его завершения.</NoticeBox>
        )}
        {!!data.cult_host && (
          <NoticeBox>
            Полный контроль культистов отключён в прототипе. Общение и помощь
            носителю остаются доступны.
          </NoticeBox>
        )}
        <Section title="Связь и носитель">
          <Stack wrap>
            <Stack.Item>
              <Button
                disabled={unavailable || !data.host}
                onClick={() => act('talk')}
              >
                Сообщение носителю
              </Button>
              <Button disabled={unavailable} onClick={() => act('hive')}>
                Связь бореров
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button
                disabled={unavailable || !data.host}
                onClick={() => act('scan')}
              >
                Анализ здоровья
              </Button>
              <Button
                disabled={unavailable || !data.host || data.controlling}
                onClick={() => act('speech')}
              >
                Речь носителя
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button
                disabled={unavailable || data.busy || !data.can_control}
                onClick={() => act('control')}
              >
                Взять контроль
              </Button>
              <Button
                disabled={unavailable || !data.controlling}
                onClick={() => act('release')}
              >
                Вернуть контроль
              </Button>
              <Button
                disabled={unavailable || data.busy || !data.host}
                onClick={() => act('leave')}
              >
                Покинуть носителя
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button
                disabled={
                  unavailable ||
                  !data.controlling ||
                  data.chemicals < data.reproduction_cost
                }
                onClick={() => act('reproduce')}
              >
                Родить личинку ({data.reproduction_cost})
              </Button>
              <Button
                disabled={
                  unavailable ||
                  !data.host ||
                  !data.torment_ready ||
                  data.chemicals < data.torment_cost
                }
                onClick={() => act('torment')}
              >
                Агония ({data.torment_cost})
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button
                selected={!!data.sneaking}
                disabled={unavailable || !data.controlling}
                tooltip="50 ресурса. Только для носителя без активного игрока; останавливает накопление ресурса."
                onClick={() => act('sneak')}
              >
                Скрыть медицинский HUD
              </Button>
            </Stack.Item>
          </Stack>
        </Section>
        <Section title="Химия и эффекты">
          <Box mb={1} color="label">
            Применяются при сосуществовании. Лекарства сохраняют местные
            побочные эффекты и передозировки; повторные дозы складываются.
          </Box>
          {data.chemistry.map((choice) => (
            <Section
              key={choice.id}
              title={choice.name}
              buttons={
                <Button
                  disabled={
                    unavailable ||
                    !data.host ||
                    data.controlling ||
                    !data.chemistry_ready ||
                    data.chemicals < choice.cost
                  }
                  onClick={() => act('secrete', { id: choice.id })}
                >
                  {choice.cost} ресурса
                </Button>
              }
            >
              {choice.desc}
            </Section>
          ))}
        </Section>
        <Section title="Фокусы развития">
          {data.focuses.map((choice) => (
            <Section
              key={choice.id}
              title={choice.name}
              buttons={
                <Button
                  selected={!!choice.learned}
                  disabled={
                    unavailable ||
                    !data.host ||
                    choice.learned ||
                    data.points < choice.cost
                  }
                  onClick={() => act('learn', { id: choice.id })}
                >
                  {choice.learned ? 'Изучено' : `${choice.cost} очков`}
                </Button>
              }
            >
              {choice.desc}
            </Section>
          ))}
        </Section>
      </Window.Content>
    </Window>
  );
};
