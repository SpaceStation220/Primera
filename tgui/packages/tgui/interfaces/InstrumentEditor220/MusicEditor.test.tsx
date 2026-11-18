import { expect, it, mock } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import { gameDataAtom, store } from '../../events/store';
import { MusicEditor } from '../InstrumentEditor220';

it('imports 40000 Notes characters intact and visibly rejects a larger input', () => {
  const previous = store.get(gameDataAtom);
  store.set(gameDataAtom, {
    bpm: 120,
    lines: [],
    max_lines: 1000,
    max_line_chars: 300,
  });
  const upload = mock((_text: string, _done: () => void) => {});
  try {
    render(<MusicEditor uploading={false} upload={upload} />);
    fireEvent.click(screen.getByText('Import a Song'));
    const text = `${'C4,'.repeat(66)}C\n`.repeat(200);
    expect(text.length).toBe(40000);
    const input = screen.getByRole('textbox', { name: 'Notes import' });
    fireEvent.change(input, { target: { value: text } });
    fireEvent.click(screen.getByText('Import notes'));
    expect(upload.mock.calls[0][0]).toBe(text);
    fireEvent.change(input, { target: { value: `${text}C` } });
    expect(screen.getByText('Maximum 40000 characters.')).toBeTruthy();
    fireEvent.click(screen.getByText('Import notes'));
    expect(upload).toHaveBeenCalledTimes(1);
  } finally {
    store.set(gameDataAtom, previous);
  }
});
