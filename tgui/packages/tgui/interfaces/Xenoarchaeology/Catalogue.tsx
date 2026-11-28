import { useState } from 'react';
import {
  Box,
  Button,
  Input,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
  TextArea,
} from 'tgui-core/components';

import { useBackend } from '../../backend';
import { MarkdownRenderer } from '../MarkdownViewer';

export type CatalogueEntry = {
  id: string;
  artifactName: string;
  title: string;
  report: string;
  analyzedAt: string;
  excavationId: string | null;
  age: number | null;
  notes: string;
  revision: number;
  editedBy: string | null;
  registeredBy: string | null;
  registeredAt: string | null;
  rewardClaimed: boolean;
};

export type CatalogueData = {
  entries: CatalogueEntry[];
  reward: number;
  titleLimit: number;
  notesLimit: number;
  printReady: boolean;
};

type Props = {
  catalogue: CatalogueData;
  operational: boolean;
  research: number;
  maxResearch: number;
};

export function XenoarchCatalogue(props: Props) {
  const [query, setQuery] = useState('');
  const [selectedId, setSelectedId] = useState<string | null>(
    () =>
      props.catalogue.entries[props.catalogue.entries.length - 1]?.id ?? null,
  );
  const entries = props.catalogue.entries
    .slice()
    .reverse()
    .filter((entry) =>
      `${entry.id} ${entry.title} ${entry.artifactName} ${entry.excavationId ?? ''}`
        .toLowerCase()
        .includes(query.toLowerCase()),
    );
  const selected = props.catalogue.entries.find(
    (entry) => entry.id === selectedId,
  );

  return (
    <>
      <NoticeBox>
        Общий журнал текущего раунда. Паспорт появляется после анализа;
        наблюдения сохраняются вручную. Награда полагается только за
        подтверждённую находку из археологического валуна.
      </NoticeBox>
      <Input
        fluid
        placeholder="Поиск по метке, названию или валуну"
        value={query}
        onChange={setQuery}
      />
      <Stack mt={1}>
        <Stack.Item width="190px">
          <Section title="Паспорта">
            <Box maxHeight="430px" overflowY="auto">
              {entries.map((entry) => (
                <Button
                  key={entry.id}
                  fluid
                  ellipsis
                  tooltip={entry.title}
                  selected={entry.id === selected?.id}
                  onClick={() => setSelectedId(entry.id)}
                >
                  {`${entry.id}: ${entry.title}`}
                </Button>
              ))}
              {!entries.length && 'Подходящих записей нет.'}
            </Box>
          </Section>
        </Stack.Item>
        <Stack.Item grow>
          {selected ? (
            <CatalogueRecord key={selected.id} {...props} entry={selected} />
          ) : (
            <NoticeBox>
              Выберите паспорт слева. Новые паспорта появляются после анализа
              артефактов на площадке.
            </NoticeBox>
          )}
        </Stack.Item>
      </Stack>
    </>
  );
}

function CatalogueRecord(props: Props & { entry: CatalogueEntry }) {
  const { act } = useBackend();
  const { entry, catalogue, operational, research, maxResearch } = props;
  const [draft, setDraft] = useState({
    title: entry.title,
    notes: entry.notes,
    revision: entry.revision,
  });
  const unchanged = draft.title === entry.title && draft.notes === entry.notes;
  const conflict = draft.revision !== entry.revision && !unchanged;
  const hasRoom = research + catalogue.reward <= maxResearch;
  const edit = (change: Partial<Pick<typeof draft, 'title' | 'notes'>>) =>
    setDraft({
      ...draft,
      ...change,
      revision: unchanged ? entry.revision : draft.revision,
    });

  return (
    <>
      <Section
        title={entry.id}
        buttons={
          <Button
            disabled={!operational || !catalogue.printReady}
            onClick={() => act('catalogue_print', { id: entry.id })}
          >
            Печать паспорта
          </Button>
        }
      >
        <LabeledList>
          <LabeledList.Item label="Объект">
            {entry.artifactName}
          </LabeledList.Item>
          <LabeledList.Item label="Первый анализ">
            {entry.analyzedAt}
          </LabeledList.Item>
          <LabeledList.Item label="Происхождение">
            {entry.excavationId
              ? `Валун ${entry.excavationId}; возраст ${entry.age} лет`
              : 'Раскопки не подтверждены — без награды'}
          </LabeledList.Item>
          <LabeledList.Item label="Регистрация">
            {entry.registeredBy
              ? `${entry.registeredBy}, ${entry.registeredAt}`
              : 'Ожидает подписи исследователя'}
          </LabeledList.Item>
        </LabeledList>
        <MarkdownRenderer content={entry.report} sanitize />
      </Section>
      <Section title="Наблюдения">
        <Input
          fluid
          aria-label="Название записи"
          value={draft.title}
          maxLength={catalogue.titleLimit}
          onChange={(title) => edit({ title })}
        />
        <TextArea
          fluid
          aria-label="Наблюдения исследователя"
          mt={1}
          height="100px"
          value={draft.notes}
          maxLength={catalogue.notesLimit}
          onChange={(notes) => edit({ notes })}
        />
        <Box my={1} color="label">
          Автор: {entry.editedBy ?? 'не указан'}.{' '}
          {unchanged ? 'Изменений нет.' : 'Есть несохранённые изменения.'}
        </Box>
        {conflict && (
          <NoticeBox danger>
            Запись изменена другим исследователем. Скопируйте свой черновик
            перед загрузкой актуальной версии.
            <Button
              mt={1}
              onClick={() =>
                setDraft({
                  title: entry.title,
                  notes: entry.notes,
                  revision: entry.revision,
                })
              }
            >
              Загрузить актуальную запись
            </Button>
          </NoticeBox>
        )}
        <Button
          disabled={
            !operational || unchanged || conflict || !draft.title.trim()
          }
          onClick={() => {
            const title = draft.title.replace(/[\r\n]/g, ' ').trim();
            setDraft({ ...draft, title });
            act('catalogue_save', { id: entry.id, ...draft, title });
          }}
        >
          Сохранить наблюдения
        </Button>
      </Section>
      <Section title="Регистрация результата">
        {!entry.registeredBy && (
          <Button
            disabled={!operational || !unchanged || conflict}
            onClick={() => act('catalogue_register', { id: entry.id })}
          >
            Подписать и зарегистрировать
          </Button>
        )}
        {entry.excavationId && (
          <Box mt={1}>
            {entry.rewardClaimed ? (
              'Награда уже получена.'
            ) : (
              <>
                <Button
                  disabled={!operational || !entry.registeredBy || !hasRoom}
                  onClick={() => act('catalogue_claim', { id: entry.id })}
                >
                  Получить {catalogue.reward} археологических очков
                </Button>
                {!hasRoom && (
                  <NoticeBox>
                    Освободите место для {catalogue.reward} очков или
                    используйте другой исследователь. Право на награду
                    сохранено.
                  </NoticeBox>
                )}
              </>
            )}
          </Box>
        )}
      </Section>
    </>
  );
}
