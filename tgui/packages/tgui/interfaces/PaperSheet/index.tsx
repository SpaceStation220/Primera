import { useBackend } from '../../backend';
import { Button } from 'tgui-core/components';
import { Window } from '../../layouts';
import { TEXTAREA_INPUT_HEIGHT } from './constants';
import { PrimaryView } from './PrimaryView';
import type { PaperContext } from './types';

export function PaperSheet(props) {
  const { data, act } = useBackend<PaperContext>();
  const {
    paper_color,
    paper_name,
    current_side,
    page_key,
    is_stack,
    stack_page_index = 1,
    stack_page_count = 1,
  } = data;

  return (
    <Window
      title={paper_name}
      theme="paper220"
      width={600}
      height={500 + TEXTAREA_INPUT_HEIGHT}
      buttons={
        is_stack ? (
          <>
            <Button
              icon="angle-left"
              tooltip="Previous page"
              disabled={stack_page_index <= 1}
              onClick={() => act('stack_prev')}
            />
            {stack_page_index} / {stack_page_count}
            <Button
              icon="angle-right"
              tooltip="Next page"
              disabled={stack_page_index >= stack_page_count}
              onClick={() => act('stack_next')}
            />
            <Button
              icon="file-export"
              tooltip="Remove sheet"
              onClick={() => act('remove_sheet')}
            />
          </>
        ) : (
          <Button icon="file" onClick={() => act('flip_side')}>
            {current_side === 2 ? 'Back' : 'Front'}
          </Button>
        )
      }
    >
      <Window.Content backgroundColor={paper_color}>
        <PrimaryView key={page_key} />
      </Window.Content>
    </Window>
  );
}
