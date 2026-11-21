import { LabeledList, Section } from 'tgui-core/components';

export const GeneticMakeupInfo = (props) => {
  const { makeup } = props;

  return (
    <Section title="Данные образца">
      <LabeledList>
        <LabeledList.Item label="Имя">
          {makeup.name || 'Нет данных'}
        </LabeledList.Item>
        <LabeledList.Item label="Группа крови">
          {makeup.blood_type || 'Нет данных'}
        </LabeledList.Item>
        <LabeledList.Item label="Отпечаток ДНК">
          {makeup.UE || 'Нет данных'}
        </LabeledList.Item>
        <LabeledList.Item label="Базовая ДНК">
          {makeup.UI || 'Нет данных'}
        </LabeledList.Item>
        <LabeledList.Item label="Видовая ДНК">
          {makeup.UF || 'Нет данных'}
        </LabeledList.Item>
      </LabeledList>
    </Section>
  );
};
