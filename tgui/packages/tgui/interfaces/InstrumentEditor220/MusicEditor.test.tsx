import { expect, it, mock } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import { gameDataAtom, store } from '../../events/store';
import { MusicEditor, TopBar } from '../InstrumentEditor220';

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

it.each([
  ['midi', false, false, false],
  ['sequence', false, false, true],
  ['file', false, false, true],
  ['midi', false, true, true],
  ['sequence', true, false, false],
  ['file', true, false, false],
] as const)(
  'checks Start access for mode=%s, musician=%s, uploading=%s',
  (mode, musician, uploading, disabled) => {
    const previous = store.get(gameDataAtom);
    const onPlay = mock(() => {});
    store.set(gameDataAtom, {
      advanced_music_access: musician,
      instrument_ready: true,
      repeat: 0,
      max_repeats: 10,
      auto_repeat: false,
      lines: [{ line_count: 1, line_text: 'C4,D4' }],
      sequence_document: { notes: [{}] },
      file_track_name: 'test.ogg',
      playback_mode: mode,
      playing: false,
      midi_start_pending: false,
    });
    try {
      render(
        <TopBar
          onPlay={onPlay}
          uploading={uploading}
          mode={mode}
          showHelp={false}
          setShowHelp={() => {}}
        />,
      );
      const start = screen.getByText('Start').closest('.Button')!;
      expect(start.classList.contains('Button--disabled')).toBe(disabled);
      fireEvent.click(start);
      expect(onPlay).toHaveBeenCalledTimes(disabled ? 0 : 1);
    } finally {
      store.set(gameDataAtom, previous);
    }
  },
);
