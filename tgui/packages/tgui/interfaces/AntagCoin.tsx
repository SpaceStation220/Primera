import { Button, NoticeBox, Section, Stack } from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  options: { id: string; name: string; reason: string | null }[];
  blocked: boolean | string;
};

export function AntagCoin() {
  const { act, data } = useBackend<Data>();
  return (
    <Window width={500} height={650} theme="ss220">
      <Window.Content scrollable>
        <NoticeBox>
          Выберите стартовый сценарий. После одобрения администратора коин
          расходуется на 168 часов. На решение даётся 30 секунд.
        </NoticeBox>
        {!!data.blocked && (
          <NoticeBox color="orange">
            Условия использования изменились. Проверьте готовность, подписку и
            наличие администратора.
          </NoticeBox>
        )}
        <Section title="Roundstart antagonists">
          <Stack vertical>
            {data.options.map((option) => (
              <Stack.Item key={option.id}>
                <Button
                  fluid
                  icon="coins"
                  disabled={!!data.blocked || !!option.reason}
                  tooltip={option.reason || 'Отправить заявку администратору'}
                  onClick={() => act('request', { choice: option.id })}
                >
                  {option.name}
                </Button>
                {!!option.reason && (
                  <Stack.Item color="label" fontSize="0.9em">
                    {option.reason}
                  </Stack.Item>
                )}
              </Stack.Item>
            ))}
          </Stack>
        </Section>
      </Window.Content>
    </Window>
  );
}
