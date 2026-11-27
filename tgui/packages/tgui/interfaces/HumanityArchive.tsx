import '../styles/interfaces/HumanityArchive.scss';

import { Button } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type ArchiveData = {
  stage: number;
  portrait?: string;
  records: { label: string; text: string }[];
  anchor: string;
  keepsake?: string;
  held: boolean;
  can_bind: boolean;
  ready: boolean;
};

const diagnoses = [
  ['Согласованность', 'Воспоминания отзываются при чтении.'],
  ['Фантомное расхождение', 'Распознано краткое запаздывание отклика.'],
  ['Соматическая диссоциация', 'Некоторые ассоциации доступны лишь фрагментами.'],
  ['Мнемоническое отчуждение', 'Записи извлечены. Личная значимость не установлена.'],
];

export function HumanityArchive() {
  const { act, data } = useBackend<ArchiveData>();
  const { stage, anchor } = data;
  const [diagnosis, detail] = diagnoses[stage - 1];
  return (
    <Window
      width={560}
      height={590}
      theme={`humanity-${stage}`}
      title="White Wall · Мнемонический архив"
    >
      <Window.Content scrollable className="HumanityArchive">
        <main className="HumanityArchive__page">
          <header className="HumanityArchive__identity">
            <div>
              <h1>Мнемонический архив</h1>
              <p className="HumanityArchive__diagnosis">{diagnosis}</p>
              <p className="HumanityArchive__detail">{detail}</p>
            </div>
            {data.portrait && (
              <div className="HumanityArchive__portrait">
                <img alt="" src={`data:image/png;base64,${data.portrait}`} />
              </div>
            )}
          </header>
          <section className="HumanityArchive__anchor">
            <h2>Мнемонический якорь</h2>
            {anchor === 'social' && (
              <p>Связь поддерживает услышанный рядом разговор.</p>
            )}
            {anchor === 'keepsake' && (
              <p>
                {data.keepsake
                  ? `Привязанная фотография — ${data.keepsake}.`
                  : 'Возьмите в активную руку готовую фотографию.'}
              </p>
            )}
            <div className="HumanityArchive__actions">
              {anchor === 'habit' && (
                <Button
                  disabled={!data.ready}
                  onClick={() => act('anchor', { kind: 'habit' })}
                >
                  Выполнить привычку
                </Button>
              )}
              {anchor === 'keepsake' && data.keepsake && (
                <Button
                  disabled={!data.ready || !data.held}
                  onClick={() => act('anchor', { kind: 'keepsake' })}
                >
                  Рассмотреть фотографию
                </Button>
              )}
              {anchor === 'keepsake' && (
                <Button disabled={!data.can_bind} onClick={() => act('bind')}>
                  {data.keepsake ? 'Сменить фотографию' : 'Привязать фотографию'}
                </Button>
              )}
              <Button
                disabled={!data.ready}
                onClick={() => act('anchor', { kind: 'reflection' })}
              >
                Собраться с мыслями
              </Button>
            </div>
          </section>
          <section className="HumanityArchive__records">
            <h2>Записи энграммы</h2>
            {!data.records.length && <p>В этой энграмме нет личных записей.</p>}
            {data.records.map((record) => (
              <article key={record.label}>
                <h3>{record.label}</h3>
                <p>{record.text}</p>
              </article>
            ))}
          </section>
        </main>
      </Window.Content>
    </Window>
  );
}
