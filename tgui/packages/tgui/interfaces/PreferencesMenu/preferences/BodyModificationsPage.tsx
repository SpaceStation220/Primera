import {
  Button,
  Collapsible,
  Dropdown,
  Icon,
  Modal,
  Section,
  Stack,
  Tooltip,
} from 'tgui-core/components';

import { useBackend } from '../../../backend';
import { LoadingScreen } from '../../common/LoadingScreen';
import type { BodyModification, PreferencesMenuData } from '../types';
import { useServerPrefs } from '../useServerPrefs';
import { features } from './features';
import { FeatureValueInput } from './features/base';

const extremityByProsthesis = new Map([
  ['left_arm_prosthesis', 'cosmetic_left_hand'],
  ['right_arm_prosthesis', 'cosmetic_right_hand'],
  ['left_leg_prosthesis', 'cosmetic_left_foot'],
  ['right_leg_prosthesis', 'cosmetic_right_foot'],
]);

export const cosmeticExtremityPreferences = [...extremityByProsthesis.values()];

type BodyModificationsProps = {
  handleClose: () => void;
};

export const BodyModificationsPage = (props: BodyModificationsProps) => {
  const { act, data } = useBackend<PreferencesMenuData>();
  const serverData = useServerPrefs();
  const cosmeticPreferences = data.character_preferences.secondary_features ?? {};
  if (!serverData) {
    return <LoadingScreen />;
  }

  return (
    <Modal className="PreferencesMenu__Augmentations">
      <Section
        fill
        scrollable
        title={
          <Stack fill className="PreferencesMenu__AugmentationsTitle">
            <Stack.Item>
              <Icon name="robot" />
            </Stack.Item>
            <Stack.Item grow>Модификации тела</Stack.Item>
            {cosmeticExtremityPreferences.some(
              (id) => id in cosmeticPreferences,
            ) && (
              <Stack.Item>
                <Stack>
                  <Button
                    icon="undo"
                    tooltip="Повернуть манекен"
                    aria-label="Повернуть манекен"
                    onClick={() => act('rotate')}
                  />
                  <Button
                    icon="eye"
                    selected={data.show_cosmetic_extremities}
                    tooltip="Показать кисти и стопы без одежды в предпросмотре"
                    onClick={() =>
                      act('set_cosmetic_extremity_preview', {
                        enabled: data.show_cosmetic_extremities ? 0 : 1,
                      })
                    }
                  >
                    {data.show_cosmetic_extremities
                      ? 'Вернуть одежду'
                      : 'Без одежды'}
                  </Button>
                </Stack>
              </Stack.Item>
            )}
            <Stack.Item>
              <Button
                fontSize={1.1}
                icon="times"
                color="red"
                tooltip="Закрыть"
                tooltipPosition="top"
                onClick={props.handleClose}
              />
            </Stack.Item>
          </Stack>
        }
      >
        <BodyModificationsPageInner
          bodyModification={serverData.body_modifications}
          cosmeticPreferences={cosmeticPreferences}
        />
      </Section>
    </Modal>
  );
};

const BodyModificationsPageInner = (props: {
  bodyModification: BodyModification[];
  cosmeticPreferences: Record<string, unknown>;
}) => {
  const { data } = useBackend<PreferencesMenuData>();
  const {
    applied_body_modifications = [],
    incompatible_body_modifications = [],
  } = data;

  const appliedModifications = props.bodyModification.filter((mod) =>
    applied_body_modifications.includes(mod.key),
  );

  const modificationsByCategory: Record<string, BodyModification[]> = {};
  props.bodyModification.forEach((mod) => {
    const category = mod.category;
    if (category) {
      if (!modificationsByCategory[category]) {
        modificationsByCategory[category] = [];
      }
      modificationsByCategory[category].push(mod);
    }
  });

  return (
    <>
      {appliedModifications.length > 0 && (
        <Collapsible open title="Применённые модификации" color="blue">
          <Stack vertical>
            {appliedModifications.map((mod, index) => (
              <BodyModificationRow
                key={mod.key}
                added
                index={index}
                bodyModification={mod}
              />
            ))}
          </Stack>
        </Collapsible>
      )}
      {Object.entries(modificationsByCategory).map(([category, mods]) => {
        const featureId = mods
          .map((mod) => extremityByProsthesis.get(mod.key))
          .find(Boolean);
        const feature = featureId ? features[featureId] : undefined;

        return (
          <Collapsible key={category} title={category} open>
            <Stack vertical>
              {mods.map((mod, index) => (
                <BodyModificationRow
                  key={mod.key}
                  index={index}
                  bodyModification={mod}
                  usedKeys={[
                    ...applied_body_modifications,
                    ...incompatible_body_modifications,
                  ]}
                />
              ))}
              {featureId &&
                feature &&
                featureId in props.cosmeticPreferences && (
                  <Stack fill className="PreferencesMenu__AugmentationsRow">
                    <Stack.Item className="PreferencesMenu__AugmentationsRow--name">
                      <Tooltip content={feature.description}>
                        {feature.name}
                      </Tooltip>
                    </Stack.Item>
                    <Stack.Item width={9}>
                      <FeatureValueInput
                        value={props.cosmeticPreferences[featureId]}
                        feature={feature}
                        featureId={featureId}
                      />
                    </Stack.Item>
                  </Stack>
                )}
            </Stack>
          </Collapsible>
        );
      })}
    </>
  );
};

const BodyModificationRow = (props: {
  bodyModification: BodyModification;
  added?: boolean;
  usedKeys?: string[];
  index: number;
}) => {
  const { act, data } = useBackend<PreferencesMenuData>();
  const isUsed = props.usedKeys?.includes(props.bodyModification.key) || false;
  const manufacturers =
    data.manufacturers?.[props.bodyModification.key] || null;
  const selectedBrand =
    data.selected_manufacturer?.[props.bodyModification.key] ||
    (manufacturers ? manufacturers[0] : null);

  return (
    <Stack fill className="PreferencesMenu__AugmentationsRow">
      <Stack.Item className="PreferencesMenu__AugmentationsRow--name">
        {props.bodyModification.name}
      </Stack.Item>
      <Stack className="PreferencesMenu__AugmentationsRow--actions">
        {Array.isArray(manufacturers) && props.added && (
          <Dropdown
            width={7.5}
            menuWidth={17.5}
            selected={selectedBrand ?? ''}
            options={manufacturers.map((brand: string) => ({
              value: brand,
              displayText: brand === 'None' ? 'Без протеза' : brand,
            }))}
            onSelected={(brand) =>
              act('set_body_modification_manufacturer', {
                body_modification_key: props.bodyModification.key,
                manufacturer: brand,
              })
            }
          />
        )}
        {props.added ? (
          <Button
            fluid
            icon="times"
            color="red"
            onClick={() =>
              act('remove_body_modification', {
                body_modification_key: props.bodyModification.key,
              })
            }
          >
            Удалить
          </Button>
        ) : (
          <Button
            fluid
            icon="plus"
            color={isUsed ? 'grey' : 'green'}
            disabled={isUsed}
            onClick={() =>
              act('apply_body_modification', {
                body_modification_key: props.bodyModification.key,
              })
            }
          >
            Добавить
          </Button>
        )}
      </Stack>
    </Stack>
  );
};
