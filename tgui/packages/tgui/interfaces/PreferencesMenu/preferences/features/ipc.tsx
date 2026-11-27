import { Box } from 'tgui-core/components';

import {
  type Feature,
  type FeatureChoiced,
  type FeatureChoicedServerData,
  FeatureColorInput,
  type FeatureValueProps,
} from './base';
import { FeatureDropdownInput } from './dropdowns';

const generationDetails: Record<
  string,
  { description: string; traits?: string[] }
> = {
  I: {
    description:
      'Заводские и недорогие модели позитронных машин, обладающие ограниченными вычислительными ресурсами и автономностью в угоду высокой работоспособности.',
    traits: [
      'Заводские программы и бонусы зависят от отдела стартовой профессии.',
      'Действия вне специализации занимают на 25% больше времени.',
      'Лёгкий ЭМИ парализует на 5 секунд, сильный — на 7 секунд.',
    ],
  },
  II: {
    description:
      'Массовые модели с полноценным автономным позитронным мозгом. Универсальные и надёжные представители современной синтетической рабочей силы.',
  },
  III: {
    description:
      'Бывшие органики, перенёсшие своё сознание в искусственное тело. Симулируют человеческие привычки, эмоции и воспоминания, сталкиваясь с ограничениями механического существования.',
  },
  IV: {
    description:
      'Редкие и дорогостоящие синтетические организмы с высоким вычислительным ресурсом. Изготавливаются преимущественно по индивидуальным заказам для дирижирования системами машин.',
    traits: [
      'ChromieКnight 4.4 позволяет удалённо управлять техникой, камерами, ботами и мехами.',
      'Дистанция Remote Control для машин и консолей — 4 тайла.',
      'На 15% меньше урона оружием ближнего боя и на 10% больше получаемого физического урона.',
    ],
  },
};

export const ipc_generation: FeatureChoiced = {
  name: 'КПБ-поколение',
  component: (props) => {
    const details = generationDetails[props.value];
    return (
      <Box>
        <FeatureDropdownInput {...props} />
        {details && (
          <Box mt={1} color="label">
            {details.description}
            {details.traits && (
              <Box mt={1}>
                <b>Характеристики поколения</b>
                <ul>
                  {details.traits.map((trait) => (
                    <li key={trait}>{trait}</li>
                  ))}
                </ul>
              </Box>
            )}
          </Box>
        )}
      </Box>
    );
  },
};

type IpcModelData = FeatureChoicedServerData & {
  choices_by_manufacturer: Record<string, string[]>;
};

const IpcModelInput = (
  props: FeatureValueProps<string, string, IpcModelData>,
) => {
  const { serverData, character_preferences } = props;
  const manufacturer =
    character_preferences.secondary_features.ipc_manufacturer;
  const choices =
    serverData && typeof manufacturer === 'string'
      ? serverData.choices_by_manufacturer[manufacturer] || []
      : serverData?.choices || [];
  return (
    <FeatureDropdownInput
      {...props}
      serverData={serverData ? { ...serverData, choices } : undefined}
    />
  );
};

type IpcManufacturerData = FeatureChoicedServerData & {
  descriptions: Record<string, string>;
};

export const ipc_manufacturer: Feature<string, string, IpcManufacturerData> = {
  name: 'КПБ — производитель',
  description:
    'Особенности производителя принадлежат торсу. CON свободно сочетает корпуса и не имеет брендовых бонусов.',
  component: (props) => (
    <Box>
      <FeatureDropdownInput {...props} />
      <Box mt={1} color="label">
        {props.serverData?.descriptions[props.value]}
      </Box>
    </Box>
  ),
};

export const ipc_chassis: Feature<string, string, IpcModelData> = {
  name: 'КПБ — корпус',
  component: IpcModelInput,
};

export const ipc_head: Feature<string, string, IpcModelData> = {
  name: 'КПБ — голова',
  component: IpcModelInput,
};

export const ipc_left_arm: Feature<string, string, IpcModelData> = {
  name: 'CON — левая рука',
  component: IpcModelInput,
};

export const ipc_right_arm: Feature<string, string, IpcModelData> = {
  name: 'CON — правая рука',
  component: IpcModelInput,
};

export const ipc_left_leg: Feature<string, string, IpcModelData> = {
  name: 'CON — левая нога',
  component: IpcModelInput,
};

export const ipc_right_leg: Feature<string, string, IpcModelData> = {
  name: 'CON — правая нога',
  component: IpcModelInput,
};

type IpcDisplayData = FeatureChoicedServerData & {
  choices_by_head: Record<string, string[]>;
};

export const ipc_screen: Feature<string, string, IpcDisplayData> = {
  name: 'КПБ — дисплей / оптика',
  component: (props) => {
    const { serverData, character_preferences } = props;
    const head = character_preferences.secondary_features.ipc_head;
    const choices =
      serverData && typeof head === 'string'
        ? serverData.choices_by_head[head] || []
        : [];
    return (
      <FeatureDropdownInput
        {...props}
        serverData={serverData ? { ...serverData, choices } : undefined}
      />
    );
  },
};

export const ipc_antenna: FeatureChoiced = {
  name: 'КПБ — головной аксессуар',
  component: FeatureDropdownInput,
};

export const ipc_chassis_color: Feature<string> = {
  name: 'КПБ — оттенок корпуса',
  component: FeatureColorInput,
};

export const ipc_screen_color: Feature<string> = {
  name: 'КПБ — основной цвет дисплея',
  component: FeatureColorInput,
};

export const ipc_screen_color_secondary: Feature<string> = {
  name: 'КПБ — цвет переднего плана дисплея',
  component: FeatureColorInput,
};

export const ipc_antenna_color: Feature<string> = {
  name: 'КПБ — цвет головного аксессуара',
  component: FeatureColorInput,
};
