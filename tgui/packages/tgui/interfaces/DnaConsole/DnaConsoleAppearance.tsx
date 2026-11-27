import { useEffect, useRef, useState } from 'react';
import { type HsvaColor, hexToHsva, hsvaToHex } from 'tgui-core/color';
import {
  Box,
  Button,
  ColorBox,
  Dropdown,
  Floating,
  Icon,
  Image,
  Section,
  Stack,
} from 'tgui-core/components';
import { useBackend } from '../../backend';
import { Hue, SaturationValue } from '../ColorPickerModal/Color';
import { HexColorInput } from '../ColorPickerModal/TextSetter';
import {
  ChoicedSelection,
  MainFeatureButton,
} from '../common/AppearanceSelection';
import { features } from '../PreferencesMenu/preferences/features';

type AppearanceCatalog = {
  name?: string;
  icons?: Record<string, string>;
  choices?: string[];
  display_names?: Record<string, string>;
  kind?: 'color' | 'choice' | 'toggle';
  supplemental_feature?: string;
};

type Appearance = {
  subject_ref?: string;
  target_ref?: string;
  icon_source?: 'asset' | 'base64';
  portrait?: string;
  features: Record<string, string>;
  secondary_features: Record<string, string | boolean>;
  supplemental_features: Record<string, string>;
  catalog: Record<string, AppearanceCatalog>;
};

const appearanceNames: Record<string, string> = {
  hairstyle_name: 'Причёска',
  facial_style_name: 'Растительность на лице',
  eye_color: 'Цвет глаз',
  heterochromatic: 'Цвет правого глаза',
  hair_color: 'Цвет волос',
  facial_hair_color: 'Цвет растительности на лице',
  hair_gradient: 'Градиент волос',
  hair_gradient_color: 'Цвет градиента волос',
  facial_hair_gradient: 'Градиент растительности на лице',
  facial_hair_gradient_color: 'Цвет градиента растительности на лице',
  feature_mcolor: 'Основной цвет',
  feature_ethcolor: 'Цвет тела',
  feature_fish_tail_color: 'Цвет рыбьего хвоста',
  feature_lizard_frills: 'Шейный воротник',
};

function AppearanceColorInput(props: {
  value: string;
  onChange: (value: string) => void;
}) {
  const { value, onChange } = props;
  const [color, setColor] = useState(() => hexToHsva(value));
  const popup = useRef<{ close: () => void }>(null);
  useEffect(() => {
    if (hsvaToHex(color).toLowerCase() !== value.toLowerCase()) {
      setColor(hexToHsva(value));
    }
  }, [color, value]);
  const update = (change: Partial<HsvaColor>) => {
    const next = { ...color, ...change };
    setColor(next);
    onChange(hsvaToHex(next));
  };
  return (
    <Floating
      ref={popup}
      content={
        <Section title="Цвет" className="DnaAppearance__colorPicker">
          <div className="react-colorful">
            <SaturationValue hsva={color} onChange={update} />
            <Hue hue={color.h} onChange={update} />
          </div>
          <Box mt={1}>
            <HexColorInput
              color={value}
              onChange={(hex) => onChange(`#${hex}`)}
            />
          </Box>
          <Button fluid mt={1} onClick={() => popup.current?.close()}>
            Готово
          </Button>
        </Section>
      }
    >
      <Button fluid className="DnaAppearance__color">
        <ColorBox color={value} mr={1} />
        Изменить цвет
      </Button>
    </Floating>
  );
}

function AppearanceInput(props: {
  catalog: AppearanceCatalog;
  value: string | boolean;
  onChange: (value: string | boolean) => void;
}) {
  const { catalog, value, onChange } = props;
  if (catalog.kind === 'color') {
    return <AppearanceColorInput value={String(value)} onChange={onChange} />;
  }
  if (catalog.kind === 'toggle') {
    return (
      <Button.Checkbox checked={!!value} onClick={() => onChange(!value)} />
    );
  }
  return (
    <Dropdown
      fluid
      selected={String(value)}
      options={(catalog.choices ?? []).map((value) => ({
        value,
        displayText: catalog.display_names?.[value] ?? value,
      }))}
      onSelected={onChange}
    />
  );
}

function AppearanceEditor({ appearance }: { appearance: Appearance }) {
  const { act } = useBackend();
  const [values, setValues] = useState<Record<string, string | boolean>>({
    ...appearance.features,
    ...appearance.secondary_features,
    ...appearance.supplemental_features,
  });
  const [activeFeature, setActiveFeature] = useState('');
  useEffect(() => {
    setValues({
      ...appearance.features,
      ...appearance.secondary_features,
      ...appearance.supplemental_features,
    });
  }, [appearance]);
  const update = (id: string, value: string | boolean) => {
    setValues((previous) => ({ ...previous, [id]: value }));
    act('set_target_appearance', {
      subject_ref: appearance.subject_ref,
      target_ref: appearance.target_ref,
      preference: id,
      value,
    });
  };
  const catalog = appearance.catalog[activeFeature];
  const supplemental =
    catalog?.supplemental_feature &&
    appearance.catalog[catalog.supplemental_feature]
      ? catalog.supplemental_feature
      : undefined;
  const featureName = (id: string) =>
    appearanceNames[id] ||
    features[id]?.name ||
    appearance.catalog[id].name ||
    id;
  const getImage = (image?: string) =>
    !image
      ? {}
      : appearance.icon_source === 'asset'
        ? { asset: ['preferences32x32', image] }
        : { base64: image };

  return (
    <div className="DnaAppearance">
      <Stack fill vertical className="DnaAppearance__subject">
        <Stack.Item>
          <Section className="PreferencesMenu__Character">
            <Box className="DnaAppearance__portrait">
              {appearance.portrait ? (
                <Image
                  src={`data:image/png;base64,${appearance.portrait}`}
                  objectFit="contain"
                  width="160px"
                  height="160px"
                />
              ) : (
                <Box color="label" textAlign="center">
                  <Icon name="user" size={4} mb={1} />
                  <Box>Предпросмотр недоступен</Box>
                </Box>
              )}
            </Box>
          </Section>
        </Stack.Item>
        <Stack.Item grow>
          <Section fill scrollable title="Дополнительные признаки">
            <Stack vertical>
              {Object.entries(appearance.secondary_features).map(([id]) => (
                <Stack.Item key={id} className="PreferencesMenu__AltName">
                  <Box color="label" mb={0.5}>
                    {featureName(id)}
                  </Box>
                  <AppearanceInput
                    catalog={appearance.catalog[id]}
                    value={values[id]}
                    onChange={(value) => update(id, value)}
                  />
                </Stack.Item>
              ))}
              {Object.keys(appearance.secondary_features).length === 0 && (
                <Box color="label">Нет дополнительных особенностей.</Box>
              )}
            </Stack>
          </Section>
        </Stack.Item>
      </Stack>
      <Section fill scrollable className="DnaAppearance__features">
        <Stack vertical direction="column-reverse">
          {Object.keys(appearance.features).map((id) => (
            <Stack.Item key={id}>
              <MainFeatureButton
                {...getImage(
                  appearance.catalog[id].icons?.[String(values[id])],
                )}
                tooltip={`${featureName(id)}: ${values[id]}`}
                selected={activeFeature === id}
                onClick={() =>
                  setActiveFeature((previous) => (previous === id ? '' : id))
                }
              />
            </Stack.Item>
          ))}
        </Stack>
      </Section>
      {catalog && (
        <Box className="DnaAppearance__catalog">
          <ChoicedSelection
            key={activeFeature}
            name={featureName(activeFeature)}
            catalog={catalog}
            selected={String(values[activeFeature])}
            getImage={getImage}
            onSelect={(value) => update(activeFeature, value)}
            supplementalInput={
              <Button
                icon="times"
                tooltip="Закрыть каталог"
                onClick={() => setActiveFeature('')}
              />
            }
          />
          {supplemental && (
            <Section title={featureName(supplemental)}>
              <AppearanceInput
                key={supplemental}
                catalog={appearance.catalog[supplemental]}
                value={values[supplemental]}
                onChange={(value) => update(supplemental, value)}
              />
            </Section>
          )}
        </Box>
      )}
    </div>
  );
}

export function DnaConsoleAppearance() {
  const { data, act } = useBackend<{
    isViableSubject: boolean;
    subjectName: string | null;
    appearance?: Appearance;
  }>();
  return (
    <Section
      className="DnaAppearancePanel"
      title={
        <>
          <Button
            position="absolute"
            left="0.5rem"
            top="0.35rem"
            icon="rotate-right"
            tooltip="Повернуть предпросмотр"
            disabled={!data.appearance}
            onClick={() =>
              act('rotate_appearance_target', {
                subject_ref: data.appearance?.subject_ref,
                target_ref: data.appearance?.target_ref,
              })
            }
          />
          <Box pl="28px">Внешность цели</Box>
        </>
      }
    >
      {data.isViableSubject && data.appearance ? (
        <AppearanceEditor
          key={
            data.appearance.target_ref ??
            data.appearance.subject_ref ??
            data.subjectName
          }
          appearance={data.appearance}
        />
      ) : (
        <Box color="label" textAlign="center" py={3}>
          <Icon name={data.isViableSubject ? 'user' : 'user-slash'} size={3} />
          <Box mt={1}>
            {data.isViableSubject
              ? 'Данные внешности недоступны.'
              : 'Сканер пуст.'}
          </Box>
        </Box>
      )}
    </Section>
  );
}
