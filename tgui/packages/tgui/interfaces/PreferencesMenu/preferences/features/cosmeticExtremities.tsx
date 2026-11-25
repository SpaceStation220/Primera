import type { FeatureChoiced } from './base';
import { FeatureDropdownInput } from './dropdowns';

const handAppearance = {
  description:
    'Только внешний вид. По умолчанию используется кисть тела или шасси. Протез всей руки имеет приоритет.',
  component: FeatureDropdownInput,
};

const footAppearance = {
  description:
    'Только внешний вид. По умолчанию используется стопа тела или шасси. Протез всей ноги имеет приоритет.',
  component: FeatureDropdownInput,
};

export const cosmetic_left_hand: FeatureChoiced = {
  ...handAppearance,
  name: 'Протез левой кисти',
};

export const cosmetic_right_hand: FeatureChoiced = {
  ...handAppearance,
  name: 'Протез правой кисти',
};

export const cosmetic_left_foot: FeatureChoiced = {
  ...footAppearance,
  name: 'Протез левой стопы',
};

export const cosmetic_right_foot: FeatureChoiced = {
  ...footAppearance,
  name: 'Протез правой стопы',
};
