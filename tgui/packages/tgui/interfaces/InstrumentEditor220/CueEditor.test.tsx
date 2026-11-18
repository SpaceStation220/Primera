import { expect, it, mock } from 'bun:test';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { type CueDocument, CueEditor } from './CueEditor';

it('pastes JSON as a replacement sheet, preserves it on errors and still appends plain lyrics', () => {
  const source: CueDocument = {
    version: 1,
    audio_hash: 'track',
    cues: [{ time: 0, text: 'Old' }],
  };
  const upload = mock((_document: CueDocument) => {});
  render(
    <CueEditor
      document={source}
      commitRef={{ current: null }}
      length={12}
      disabled={false}
      autoSing={false}
      tts={false}
      act={() => {}}
      upload={upload}
    />,
  );
  const input = screen.getByRole('textbox', { name: 'Mass cue' });
  const sheet: CueDocument = {
    version: 1,
    audio_hash: 'track',
    spacing_seconds: 2,
    cues: [{ time: 7, text: 'Imported' }],
  };
  fireEvent.change(input, { target: { value: JSON.stringify(sheet) } });
  fireEvent.click(screen.getByLabelText('Parse mass cue'));
  expect(screen.queryByDisplayValue('Old')).toBeNull();
  fireEvent.click(screen.getByLabelText('Apply cues'));
  expect(upload.mock.calls[0][0]).toEqual(sheet);
  fireEvent.change(input, {
    target: { value: JSON.stringify({ ...sheet, audio_hash: 'other' }) },
  });
  fireEvent.click(screen.getByLabelText('Parse mass cue'));
  expect(screen.getByText(/audio_hash does not match/)).toBeTruthy();
  expect(screen.getByDisplayValue('Imported')).toBeTruthy();
  fireEvent.change(input, { target: { value: '{' } });
  fireEvent.click(screen.getByLabelText('Parse mass cue'));
  expect(screen.getByText(/Invalid JSON/)).toBeTruthy();
  fireEvent.change(input, { target: { value: 'Next\nLast' } });
  fireEvent.click(screen.getByLabelText('Parse mass cue'));
  fireEvent.click(screen.getByLabelText('Apply cues'));
  expect(upload.mock.calls[1][0].cues).toEqual([
    { time: 7, text: 'Imported' },
    { time: 9, text: 'Next' },
    { time: 11, text: 'Last' },
  ]);
  fireEvent.change(input, { target: { value: 'Too late' } });
  fireEvent.click(screen.getByLabelText('Parse mass cue'));
  expect(
    screen.getByText(/Cue 4: time 13 s exceeds OGG duration 12 s/),
  ).toBeTruthy();
  expect(screen.queryByDisplayValue('Too late')).toBe(input);
});

it('checks the current OGG again when a file read finishes', async () => {
  const source: CueDocument = { version: 1, audio_hash: 'first', cues: [] };
  const props = {
    document: source,
    commitRef: { current: null },
    length: 12,
    disabled: false,
    autoSing: false,
    tts: false,
    act: () => {},
    upload: () => {},
  };
  const view = render(<CueEditor {...props} />);
  let finishRead!: (value: string) => void;
  const pending = new Promise<string>((resolve) => {
    finishRead = resolve;
  });
  const raw = JSON.stringify({ ...source, cues: [{ time: 3, text: 'Stale' }] });
  const file = new File([raw], 'lyrics.json', { type: 'application/json' });
  Object.defineProperty(file, 'text', { value: () => pending });
  fireEvent.change(view.container.querySelector('input[type="file"]')!, {
    target: { files: [file] },
  });
  view.rerender(
    <CueEditor
      {...props}
      document={{
        ...source,
        audio_hash: 'second',
        cues: [{ time: 0, text: 'Current' }],
      }}
    />,
  );
  finishRead(raw);
  await waitFor(() =>
    expect(screen.getByText(/audio_hash does not match/)).toBeTruthy(),
  );
  expect(screen.getByDisplayValue('Current')).toBeTruthy();
  expect(screen.queryByDisplayValue('Stale')).toBeNull();
});
