import {
  Box,
  Button,
  Icon,
  LabeledList,
  ProgressBar,
  Section,
} from 'tgui-core/components';

import { useBackend } from '../../backend';
import {
  SUBJECT_CONCIOUS,
  SUBJECT_DEAD,
  SUBJECT_HARD_CRIT,
  SUBJECT_SOFT_CRIT,
  SUBJECT_TRANSFORMING,
  SUBJECT_UNCONSCIOUS,
} from './constants';

const DnaScannerButtons = (props) => {
  const { data, act } = useBackend();
  const {
    hasDelayedAction,
    isPulsing,
    isScannerConnected,
    isScrambleReady,
    isViableSubject,
    scannerLocked,
    scannerOpen,
    scrambleSeconds,
  } = data;
  if (!isScannerConnected) {
    return (
      <Button
        content="Подключить сканер"
        onClick={() => act('connect_scanner')}
      />
    );
  }
  return (
    <>
      {!!hasDelayedAction && (
        <Button
          content="Отменить перенос"
          onClick={() => act('cancel_delay')}
        />
      )}
      {!!isViableSubject && (
        <Button
          disabled={!isScrambleReady || isPulsing}
          tooltip="Удаляет мутации, создаёт новый набор генов и повреждает ДНК"
          onClick={() => act('scramble_dna')}
        >
          Перемешать гены
          {!isScrambleReady && ` (${scrambleSeconds} с)`}
        </Button>
      )}
      <Box inline mr={1} />
      <Button
        icon={scannerLocked ? 'lock' : 'lock-open'}
        tooltip={
          scannerLocked
            ? 'Разблокировать дверь сканера'
            : 'Заблокировать дверь сканера'
        }
        color={scannerLocked && 'bad'}
        disabled={scannerOpen}
        content={scannerLocked ? 'Отпереть' : 'Запереть'}
        onClick={() => act('toggle_lock')}
      />
      <Button
        disabled={scannerLocked}
        content={scannerOpen ? 'Закрыть' : 'Открыть'}
        onClick={() => act('toggle_door')}
      />
    </>
  );
};

/**
 * Displays subject status based on the value of the status prop.
 */
const SubjectStatus = (props) => {
  const { status } = props;
  if (status === SUBJECT_CONCIOUS) {
    return (
      <Box inline color="good">
        В сознании
      </Box>
    );
  }
  if (status === SUBJECT_UNCONSCIOUS || status === SUBJECT_HARD_CRIT) {
    return (
      <Box inline color="average">
        Без сознания
      </Box>
    );
  }
  if (status === SUBJECT_SOFT_CRIT) {
    return (
      <Box inline color="average">
        Критическое состояние
      </Box>
    );
  }
  if (status === SUBJECT_DEAD) {
    return (
      <Box inline color="bad">
        Мёртв
      </Box>
    );
  }
  if (status === SUBJECT_TRANSFORMING) {
    return (
      <Box inline color="bad">
        Трансформация
      </Box>
    );
  }
  return <Box inline>Неизвестно</Box>;
};

const DnaScannerContent = (props) => {
  const { data, act } = useBackend();
  const {
    subjectName,
    isScannerConnected,
    isViableSubject,
    subjectHealth,
    subjectDamage,
    subjectStatus,
  } = data;
  if (!isScannerConnected) {
    return <Box color="bad">Сканер ДНК не подключён.</Box>;
  }
  if (!isViableSubject) {
    return <Box color="average">В сканере нет подходящего подопытного.</Box>;
  }
  return (
    <LabeledList>
      <LabeledList.Item label="Состояние">
        {subjectName}
        <Icon mx={1} color="label" name="long-arrow-alt-right" />
        <SubjectStatus status={subjectStatus} />
      </LabeledList.Item>
      <LabeledList.Item label="Здоровье">
        <ProgressBar
          value={subjectHealth}
          minValue={0}
          maxValue={100}
          ranges={{
            olive: [101, Infinity],
            good: [70, 101],
            average: [30, 70],
            bad: [-Infinity, 30],
          }}
        >
          {subjectHealth}%
        </ProgressBar>
      </LabeledList.Item>
      <LabeledList.Item label="Повреждение ДНК">
        <ProgressBar
          value={subjectDamage}
          minValue={0}
          maxValue={100}
          ranges={{
            bad: [71, Infinity],
            average: [30, 71],
            good: [0, 30],
            olive: [-Infinity, 0],
          }}
        >
          {subjectDamage}%
        </ProgressBar>
      </LabeledList.Item>
    </LabeledList>
  );
};

export const DnaScanner = (props) => {
  return (
    <Section title="Сканер ДНК" buttons={<DnaScannerButtons />}>
      <DnaScannerContent />
    </Section>
  );
};
