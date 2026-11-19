import { expect, it, mock, spyOn } from 'bun:test';
import { act, renderHook, waitFor } from '@testing-library/react';
import { type MusicUploadStatus, nativeMusicPages } from './upload';
import { useMusicUpload } from './useMusicUpload';

it('paces acknowledged parts and stops on a server rejection', async () => {
  const times: number[] = [];
  const send = mock((_action: string, _payload?: object) => {
    times.push(performance.now());
  });
  const view = renderHook(
    ({ status }: { status?: MusicUploadStatus }) =>
      useMusicUpload(send, status, 1200),
    { initialProps: {} },
  );
  act(() =>
    view.result.current.upload('cues', {
      version: 1,
      audio_hash: 'a'.repeat(32),
      cues: Array.from({ length: 20 }, (_, time) => ({
        time,
        text: 'La '.repeat(40),
      })),
    }),
  );
  await waitFor(() => expect(send).toHaveBeenCalledTimes(1));
  const part = send.mock.calls[0][1] as { id: string; count: number };
  expect(part.count).toBeGreaterThan(2);
  view.rerender({ status: { id: part.id, next: 1, state: 'receiving' } });
  expect(send).toHaveBeenCalledTimes(1);
  await waitFor(() => expect(send).toHaveBeenCalledTimes(2), { timeout: 4000 });
  expect(times[1] - times[0]).toBeGreaterThanOrEqual(1200);
  view.rerender({
    status: { id: part.id, next: 2, state: 'error', error: 'Denied' },
  });
  expect(view.result.current.busy).toBe(false);
  expect(view.result.current.error).toBe('Denied');
});

it('reuses a native bank with paced, indexed pages and no document in Topic actions', async () => {
  const document = {
    version: 1,
    title: 'Native pages',
    notes: Array.from({ length: 1800 }, (_, i) => ({
      time: i / 10,
      duration: 0.2,
      key: 60,
      velocity: 100,
      channel: 0,
      track: 0,
    })),
    tempos: [{ time: 0, bpm: 120 }],
    tracks: [{ id: 0, name: 'Track' }],
  };
  const pages = nativeMusicPages(document);
  expect(pages.length).toBeGreaterThan(1);
  const send = mock((_action: string, _payload?: object) => {});
  const write = spyOn(Byond, 'winset');
  const completed = mock(() => {});
  const controls = Array.from(
    { length: 32 },
    (_, i) => `mainwindow.music_${i}`,
  );
  const view = renderHook(
    ({ status }: { status?: MusicUploadStatus }) =>
      useMusicUpload(send, status),
    { initialProps: {} },
  );
  try {
    act(() =>
      view.result.current.upload('sequence', document, 'play_music', completed),
    );
    await waitFor(() => expect(send).toHaveBeenCalledTimes(1));
    const [name, header] = send.mock.calls[0];
    expect(name).toBe('begin_native_music_upload');
    const part = header as { id: string; count: number; size: number };
    expect(part.count).toBe(pages.length);
    expect(part.size).toBe(pages.join('').length);
    expect(write).not.toHaveBeenCalled();
    view.rerender({
      status: {
        id: part.id,
        next: 0,
        state: 'receiving',
        native_controls: controls,
      },
    });
    await waitFor(() => expect(send).toHaveBeenCalledTimes(2), {
      timeout: 4000,
    });
    expect(send.mock.calls[1]).toEqual([
      'read_native_music_upload',
      { id: part.id, index: 0 },
    ]);
    expect(
      write.mock.calls.map(([, , value]) => String(value).slice(2)).join(''),
    ).toBe(pages[0]);
    for (const [, property, value] of write.mock.calls) {
      expect(property).toBe('text');
      expect(String(value).length).toBeLessThanOrEqual(1026);
    }
    write.mockClear();
    view.rerender({
      status: {
        id: part.id,
        next: 1,
        state: 'receiving',
        native_controls: controls,
      },
    });
    expect(send).toHaveBeenCalledTimes(2);
    await waitFor(() => expect(send).toHaveBeenCalledTimes(3), {
      timeout: 4000,
    });
    expect(
      write.mock.calls.map(([, , value]) => String(value).slice(2)).join(''),
    ).toBe(pages[1]);
    expect(completed).not.toHaveBeenCalled();
    view.rerender({
      status: { id: part.id, next: part.count, state: 'complete' },
    });
    expect(completed).toHaveBeenCalledTimes(1);
    expect(view.result.current.busy).toBe(false);
  } finally {
    view.unmount();
    write.mockRestore();
  }
});

it('cancels its native reservation when the editor unmounts', async () => {
  const send = mock((_action: string, _payload?: object) => {});
  const view = renderHook(() => useMusicUpload(send));
  act(() => view.result.current.upload('sequence', { version: 1, notes: [] }));
  await waitFor(() => expect(send).toHaveBeenCalledTimes(1));
  const part = send.mock.calls[0][1] as { id: string };
  view.unmount();
  expect(send.mock.calls[1]).toEqual(['cancel_music_upload', { id: part.id }]);
});

it('imports 5924 Notes characters in one native page with only the required fields', async () => {
  const document = {
    version: 1,
    text: 'C4-D4/2,\n'.repeat(700).slice(0, 5924),
  };
  const pages = nativeMusicPages(document, 'notes');
  const send = mock((_action: string, _payload?: object) => {});
  const write = spyOn(Byond, 'winset');
  const completed = mock(() => {});
  const controls = Array.from(
    { length: Math.ceil(pages[0].length / 1024) },
    (_, i) => `mainwindow.notes_${i}`,
  );
  const view = renderHook(
    ({ status }: { status?: MusicUploadStatus }) =>
      useMusicUpload(send, status),
    { initialProps: {} },
  );
  try {
    act(() =>
      view.result.current.upload('notes', document, undefined, completed),
    );
    await waitFor(() => expect(send).toHaveBeenCalledTimes(1));
    const [action, payload] = send.mock.calls[0];
    expect(action).toBe('begin_native_music_upload');
    const header = payload as { id: string; kind: string; count: number };
    expect(header.kind).toBe('notes');
    expect(header.count).toBe(1);
    expect(controls.length).toBeLessThan(32);
    view.rerender({
      status: {
        id: header.id,
        next: 0,
        state: 'receiving',
        native_controls: controls,
      },
    });
    await waitFor(() => expect(send).toHaveBeenCalledTimes(2), {
      timeout: 4000,
    });
    expect(send.mock.calls[1]).toEqual([
      'read_native_music_upload',
      { id: header.id, index: 0 },
    ]);
    expect(write).toHaveBeenCalledTimes(controls.length);
    const encoded = write.mock.calls
      .map(([, , value]) => String(value).slice(2))
      .join('');
    expect(encoded).toBe(pages[0]);
    expect(
      JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8')),
    ).toEqual(document);
    expect(completed).not.toHaveBeenCalled();
    view.rerender({
      status: { id: header.id, next: 1, state: 'complete' },
    });
    expect(completed).toHaveBeenCalledTimes(1);
    expect(view.result.current.busy).toBe(false);
    expect(send).toHaveBeenCalledTimes(2);
  } finally {
    view.unmount();
    write.mockRestore();
  }
});

it('keeps small Notes in one page and larger Unicode Notes lossless across pages', () => {
  for (const length of [5924, 20000, 40000]) {
    const document = {
      version: 1,
      text: 'C4-D4/2,\n'.repeat(5000).slice(0, length),
    };
    const pages = nativeMusicPages(document, 'notes');
    expect(pages.length).toBe(length <= 20000 ? 1 : 2);
    expect(
      JSON.parse(Buffer.from(pages.join(''), 'base64url').toString('utf8')),
    ).toEqual(document);
  }
  const document = { version: 1, text: 'До♯4,\n'.repeat(6500) };
  const pages = nativeMusicPages(document, 'notes');
  expect(pages.length).toBeGreaterThan(1);
  expect(pages.every((page) => page.length <= 32768)).toBe(true);
  expect(
    JSON.parse(Buffer.from(pages.join(''), 'base64url').toString('utf8')),
  ).toEqual(document);
});
