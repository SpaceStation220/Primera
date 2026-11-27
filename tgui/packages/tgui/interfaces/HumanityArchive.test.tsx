import { afterEach, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import * as actions from 'tgui/events/act';
import { gameDataAtom, resetStore, store } from 'tgui/events/store';

import { HumanityArchive } from './HumanityArchive';

afterEach(resetStore);

it('renders a private fragment as text and the anchor controls', () => {
  const send = spyOn(actions, 'sendAct').mockImplementation(() => {});
  try {
    const fragment = '<img src=x> 〔утрачена ассоциация〕';
    store.set(gameDataAtom, {
      stage: 3,
      records: [{ label: 'Личное воспоминание', text: fragment }],
      anchor: 'keepsake',
      keepsake: 'Фотография',
      held: false,
      can_bind: true,
      ready: true,
    });
    const view = render(<HumanityArchive />);
    expect(screen.getByText(fragment)).toBeTruthy();
    expect(view.container.querySelector('img[src="x"]')).toBeNull();
    expect(screen.getByText('Соматическая диссоциация')).toBeTruthy();
    expect(screen.queryByText('Восприятие')).toBeNull();
    fireEvent.click(screen.getByText('Сменить фотографию'));
    expect(send).toHaveBeenLastCalledWith('bind');
    fireEvent.click(screen.getByText('Собраться с мыслями'));
    expect(send).toHaveBeenLastCalledWith('anchor', { kind: 'reflection' });
  } finally {
    send.mockRestore();
  }
});
