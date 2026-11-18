import { expect, it, mock } from 'bun:test';
import { act, renderHook, waitFor } from '@testing-library/react';
import type { MusicUploadStatus } from './upload';
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
    view.result.current.upload('notes', {
      version: 1,
      text: 'C4,'.repeat(800),
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
