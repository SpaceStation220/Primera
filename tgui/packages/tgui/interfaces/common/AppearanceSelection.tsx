import type { ReactNode } from 'react';
import { useState } from 'react';
import { Box, ImageButton, Input, Section, Stack } from 'tgui-core/components';
import { capitalize, createSearch } from 'tgui-core/string';

type SelectionImage = { asset?: string[]; base64?: string };

type ChoicedSelectionProps = {
  name: string;
  catalog: { icons?: Record<string, string> };
  selected: string;
  supplementalInput?: ReactNode;
  onSelect: (value: string) => void;
  getImage?: (image: string) => SelectionImage;
};

export function ChoicedSelection(props: ChoicedSelectionProps) {
  const { catalog, getImage, supplementalInput } = props;
  const [searchText, setSearchText] = useState('');

  if (!catalog.icons) {
    return <Box color="red">В предоставленном каталоге не было иконок!</Box>;
  }

  const search = createSearch(searchText, ([name]: [string, string]) => name);
  const choices = Object.entries(catalog.icons).filter(search);

  return (
    <Stack fill vertical g={0} className="PreferencesMenu__ChoicedSelection">
      <Stack.Item>
        <Section
          fill
          title={capitalize(props.name)}
          buttons={supplementalInput}
        >
          <Input
            autoFocus
            fluid
            placeholder="Поиск..."
            value={searchText}
            onChange={setSearchText}
          />
        </Section>
      </Stack.Item>
      <Stack.Item grow>
        <Section fill scrollable noTopPadding>
          <Stack wrap>
            {choices.map(([name, image]) => (
              <ImageButton
                key={name}
                {...(getImage
                  ? getImage(image)
                  : { asset: ['preferences32x32', image] })}
                imageSize={32}
                selected={name === props.selected}
                tooltip={name}
                tooltipPosition="right"
                onClick={() => props.onSelect(name)}
              />
            ))}
          </Stack>
        </Section>
      </Stack.Item>
    </Stack>
  );
}

export function MainFeatureButton(
  props: SelectionImage & {
    buttons?: ReactNode;
    tooltip?: string;
    selected?: boolean;
    onClick?: () => void;
  },
) {
  return (
    <ImageButton
      className="PreferencesMenu__MainFeature"
      imageSize={48}
      {...props}
    />
  );
}
