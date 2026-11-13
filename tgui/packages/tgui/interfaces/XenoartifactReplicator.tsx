import { Button, NoticeBox, ProgressBar, Section } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  recipes: string[];
  hasFeedstock: boolean;
  active: boolean;
  operational: boolean;
  progress: number;
};

export const XenoartifactReplicator = () => {
  const { act, data } = useBackend<Data>();
  return (
    <Window width={440} height={400}>
      <Window.Content scrollable>
        <Section
          title="Преобразование"
          buttons={
            <Button disabled={!data.hasFeedstock} onClick={() => act('eject')}>
              Извлечь сырьё
            </Button>
          }
        >
          <NoticeBox>
            {data.hasFeedstock
              ? 'Сырьё загружено. Выберите орган управления.'
              : 'Вставьте один предмет как сырьё.'}
          </NoticeBox>
          {!data.operational && (
            <NoticeBox color="bad">
              Нет питания или устройство повреждено.
            </NoticeBox>
          )}
          <ProgressBar value={data.progress} />
          {data.recipes.map((recipe, index) => (
            <Button
              fluid
              key={recipe}
              disabled={!data.hasFeedstock || data.active || !data.operational}
              onClick={() => act('recipe', { index: String(index + 1) })}
            >
              {recipe}
            </Button>
          ))}
        </Section>
      </Window.Content>
    </Window>
  );
};
