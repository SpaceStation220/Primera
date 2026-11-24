import { afterEach, beforeEach, expect, spyOn, test } from 'bun:test';
import {
  abortInstrumentTransfer,
  beginInstrumentTransfer,
  playInstrumentMusic,
  receiveInstrumentChunk,
  resetInstrumentMusic,
  stopInstrumentMusic,
} from './instruments';

const hash = 'a'.repeat(32);
const packet = { id: '17', token: 'first', hash, volume: 0.6, position: 0 };
let messages: { type: string; payload: Record<string, unknown> }[];
let blobs: Blob[];
let audios: HTMLAudioElement[];
let messageSpy: ReturnType<typeof spyOn>;
let audioDescriptor: PropertyDescriptor | undefined;
let urlSpy: ReturnType<typeof spyOn>;
let revokeSpy: ReturnType<typeof spyOn>;

beforeEach(() => {
  messages = [];
  blobs = [];
  audios = [];
  messageSpy = spyOn(Byond, 'sendMessage').mockImplementation(
    (
      message: string | { type: string; payload?: unknown },
      payload?: unknown,
    ) => {
      const type = typeof message === 'string' ? message : message.type;
      messages.push({
        type,
        payload: (typeof message === 'string'
          ? payload
          : message.payload) as Record<string, unknown>,
      });
    },
  );
  audioDescriptor = Object.getOwnPropertyDescriptor(globalThis, 'Audio');
  Object.defineProperty(globalThis, 'Audio', {
    configurable: true,
    writable: true,
    value: new Proxy(globalThis.Audio, {
      construct() {
        const audio = document.createElement('audio');
        spyOn(audio, 'pause').mockImplementation(() => {});
        spyOn(audio, 'load').mockImplementation(() => {});
        spyOn(audio, 'play').mockResolvedValue(undefined);
        audios.push(audio);
        return audio;
      },
    }),
  });
  urlSpy = spyOn(URL, 'createObjectURL').mockImplementation((blob) => {
    blobs.push(blob as Blob);
    return `blob:instrument-${blobs.length}`;
  });
  revokeSpy = spyOn(URL, 'revokeObjectURL').mockImplementation(() => {});
});

afterEach(() => {
  resetInstrumentMusic();
  messageSpy.mockRestore();
  if (audioDescriptor)
    Object.defineProperty(globalThis, 'Audio', audioDescriptor);
  urlSpy.mockRestore();
  revokeSpy.mockRestore();
});

function recording(length = 70013) {
  const bytes = Uint8Array.from({ length }, (_, i) => i % 256);
  bytes.set([79, 103, 103, 83]);
  return bytes;
}

function begin(bytes: Uint8Array, trackHash = hash, offset = 0, transfer = '1') {
  const encoded = Buffer.from(bytes).toString('base64');
  beginInstrumentTransfer({
    request: Number(
      messages.filter((m) => m.type === 'audio/instrumentRequest').at(-1)
        ?.payload.request,
    ),
    transfer,
    hash: trackHash,
    size: encoded.length,
    bytes: bytes.length,
    chunkSize: 16384,
    window: 8,
    offset,
  });
  return encoded;
}

function deliver(encoded: string, start = 0, transfer = '1') {
  for (let offset = start; offset < encoded.length; offset += 16384) {
    receiveInstrumentChunk({
      transfer,
      offset,
      data: encoded.slice(offset, offset + 16384),
    });
  }
}

function transferClock() {
  let serial = 0;
  const pending = new Map<number, { callback: () => void; delay: number }>();
  const timer = spyOn(globalThis, 'setTimeout').mockImplementation(((
    callback: () => void,
    delay: number,
  ) => {
    const id = ++serial;
    pending.set(id, { callback, delay });
    return id;
  }) as typeof setTimeout);
  const clear = spyOn(globalThis, 'clearTimeout').mockImplementation(((
    id: number,
  ) => pending.delete(id)) as typeof clearTimeout);
  return {
    run(delay: number) {
      expect(pending.size).toBe(1);
      const [id, next] = [...pending][0];
      expect(next.delay).toBe(delay);
      pending.delete(id);
      next.callback();
    },
    restore() {
      resetInstrumentMusic();
      timer.mockRestore();
      clear.mockRestore();
    },
  };
}

test('reassembles exact binary bytes, acknowledges bounded windows, then reuses one Blob', async () => {
  const original = recording(150013);
  playInstrumentMusic(packet);
  playInstrumentMusic({ ...packet, id: '18', token: 'other-source' });
  expect(
    messages.filter((m) => m.type === 'audio/instrumentRequest'),
  ).toHaveLength(1);
  const encoded = begin(original);
  for (let offset = 0; offset < encoded.length; offset += 16384) {
    expect(audios).toHaveLength(0);
    receiveInstrumentChunk({
      transfer: '1',
      offset,
      data: encoded.slice(offset, offset + 16384),
    });
  }
  expect(blobs).toHaveLength(1);
  expect(new Uint8Array(await blobs[0].arrayBuffer())).toEqual(original);
  expect(audios).toHaveLength(2);
  expect(audios[0].src).toBe(audios[1].src);
  expect(
    messages
      .filter((m) => m.type === 'audio/instrumentAck')
      .map((m) => m.payload.received),
  ).toEqual([8 * 16384, encoded.length]);
  expect(messages.at(-1)?.payload.bytes).toBe(original.length);
  stopInstrumentMusic({ id: packet.id, token: packet.token });
  playInstrumentMusic({ ...packet, token: 'restarted' });
  expect(
    messages.filter((m) => m.type === 'audio/instrumentRequest'),
  ).toHaveLength(1);
  resetInstrumentMusic();
  expect(revokeSpy).toHaveBeenCalledTimes(1);
});

test('queues different recordings and cancels a download with no remaining listener', () => {
  playInstrumentMusic(packet);
  playInstrumentMusic({
    ...packet,
    id: '18',
    token: 'second',
    hash: 'b'.repeat(32),
  });
  expect(messages).toHaveLength(1);
  begin(recording());
  stopInstrumentMusic({ id: packet.id, token: packet.token });
  expect(messages.at(-2)?.type).toBe('audio/instrumentCancel');
  expect(messages.at(-1)?.payload.hash).toBe('b'.repeat(32));
  receiveInstrumentChunk({ transfer: '1', offset: 0, data: 'T2dnUw==' });
  expect(blobs).toHaveLength(0);
});

test('stop all suppresses periodic updates and late chunks until a new playback token', () => {
  playInstrumentMusic(packet);
  const encoded = begin(recording());
  stopInstrumentMusic({});
  deliver(encoded);
  playInstrumentMusic(packet);
  expect(blobs).toHaveLength(0);
  expect(
    messages.filter((m) => m.type === 'audio/instrumentRequest'),
  ).toHaveLength(1);
  playInstrumentMusic({ ...packet, token: 'new-performance' });
  expect(
    messages.filter((m) => m.type === 'audio/instrumentRequest'),
  ).toHaveLength(2);
});

test('resumes a gap without discarding earlier bytes or appending duplicates', async () => {
  const clock = transferClock();
  try {
    const original = recording(150013);
    playInstrumentMusic(packet);
    const encoded = begin(original);
    const first = { transfer: '1', offset: 0, data: encoded.slice(0, 16384) };
    receiveInstrumentChunk(first);
    receiveInstrumentChunk(first);
    expect(messages.at(-1)?.payload.received).toBe(16384);
    receiveInstrumentChunk({
      transfer: '1',
      offset: 32768,
      data: encoded.slice(32768, 49152),
    });
    expect(blobs).toHaveLength(0);
    expect(messages.some((m) => m.type === 'audio/instrumentError')).toBe(false);
    clock.run(2000);
    expect(messages.at(-1)?.payload.offset).toBe(16384);
    begin(original, hash, 16384, '2');
    receiveInstrumentChunk(first);
    deliver(encoded, 16384, '2');
    expect(blobs).toHaveLength(1);
    expect(new Uint8Array(await blobs[0].arrayBuffer())).toEqual(original);
  } finally {
    clock.restore();
  }
});

test('retries a stalled request only three times with increasing pauses', () => {
  const clock = transferClock();
  try {
    playInstrumentMusic(packet);
    for (const delay of [2000, 4000, 6000]) {
      clock.run(25000);
      expect(messages.some((m) => m.type === 'audio/instrumentError')).toBe(false);
      clock.run(delay);
    }
    clock.run(25000);
    expect(
      messages.filter((m) => m.type === 'audio/instrumentRequest'),
    ).toHaveLength(4);
    expect(messages.at(-1)?.payload.detail).toBe('timeout');
    playInstrumentMusic(packet);
    expect(
      messages.filter((m) => m.type === 'audio/instrumentRequest'),
    ).toHaveLength(4);
  } finally {
    clock.restore();
  }
});

test('recovers a server acknowledgment timeout and ignores stale aborts', () => {
  const clock = transferClock();
  try {
    const original = recording();
    playInstrumentMusic(packet);
    const encoded = begin(original);
    const oldRequest = Number(messages[0].payload.request);
    receiveInstrumentChunk({
      transfer: '1',
      offset: 0,
      data: encoded.slice(0, 16384),
    });
    abortInstrumentTransfer({
      request: oldRequest,
      transfer: '1',
      hash,
      reason: 'ack_timeout',
    });
    clock.run(2000);
    const currentRequest = Number(messages.at(-1)?.payload.request);
    expect(currentRequest).toBeGreaterThan(oldRequest);
    abortInstrumentTransfer({ request: oldRequest, hash, reason: 'cancelled' });
    begin(original, hash, 16384, '2');
    begin(original, hash, 16384, '2');
    deliver(encoded, 16384, '2');
    expect(blobs).toHaveLength(1);
    expect(messages.some((m) => m.type === 'audio/instrumentError')).toBe(false);
  } finally {
    clock.restore();
  }
});

test('stop discards partial data and cancels a scheduled retry', () => {
  const clock = transferClock();
  try {
    playInstrumentMusic(packet);
    begin(recording());
    clock.run(25000);
    stopInstrumentMusic({ id: packet.id, token: packet.token });
    playInstrumentMusic({ ...packet, token: 'new-performance' });
    expect(messages.at(-1)?.payload.offset).toBe(0);
    expect(messages.at(-1)?.payload.token).toBe('new-performance');
    begin(recording(), hash, 0, '2');
    clock.run(25000);
    clock.run(2000);
    expect(messages.at(-1)?.payload.token).toBe('new-performance');
    expect(messages.some((m) => m.type === 'audio/instrumentError')).toBe(false);
  } finally {
    clock.restore();
  }
});

test('enforces the file bound before retaining chunks', () => {
  playInstrumentMusic(packet);
  beginInstrumentTransfer({
    request: Number(messages.at(-1)?.payload.request),
    transfer: '1',
    hash,
    size: 4 * Math.ceil((3 * 1024 * 1024 + 1) / 3),
    bytes: 3 * 1024 * 1024 + 1,
    chunkSize: 16384,
    window: 8,
  });
  expect(messages.at(-1)?.type).toBe('audio/instrumentError');
  expect(messages.at(-1)?.payload.detail).toBe('invalid_header');
  expect(blobs).toHaveLength(0);
});

test('reports a server abort once without blaming OGG decoding', () => {
  playInstrumentMusic(packet);
  begin(recording());
  abortInstrumentTransfer({ transfer: '1', hash });
  abortInstrumentTransfer({ transfer: '1', hash });
  playInstrumentMusic(packet);
  const errors = messages.filter((m) => m.type === 'audio/instrumentError');
  expect(errors).toHaveLength(1);
  expect(errors[0].payload).toMatchObject({
    id: packet.id,
    token: packet.token,
    reason: 'transfer',
    detail: 'server_abort',
  });
});

test('handles a rejected initial request without waiting for a transfer id', () => {
  playInstrumentMusic(packet);
  abortInstrumentTransfer({
    request: Number(messages[0].payload.request),
    reason: 'invalid_offset',
  });
  expect(messages.at(-1)?.payload.detail).toBe('invalid_offset');
  expect(blobs).toHaveLength(0);
  expect(
    messages.filter((m) => m.type === 'audio/instrumentRequest'),
  ).toHaveLength(1);
});

test('reports an invalid OGG signature separately from chunk ordering', () => {
  playInstrumentMusic(packet);
  const bytes = recording();
  bytes[0] = 0;
  const encoded = begin(bytes);
  deliver(encoded);
  expect(messages.at(-1)?.payload.detail).toBe('invalid_ogg');
  expect(blobs).toHaveLength(0);
});

test('body changes clear suppression and stale begin messages cannot claim a new request', () => {
  playInstrumentMusic(packet);
  const oldRequest = Number(messages.at(-1)?.payload.request);
  stopInstrumentMusic({ reset: true });
  playInstrumentMusic(packet);
  const bytes = recording();
  const encoded = Buffer.from(bytes).toString('base64');
  beginInstrumentTransfer({
    request: oldRequest,
    transfer: 'old',
    hash,
    size: encoded.length,
    bytes: bytes.length,
    chunkSize: 16384,
    window: 8,
  });
  receiveInstrumentChunk({
    transfer: 'old',
    offset: 0,
    data: encoded.slice(0, 16384),
  });
  expect(blobs).toHaveLength(0);
  deliver(begin(bytes));
  expect(blobs).toHaveLength(1);
});

test('warms a cold initiator silently, stops at zero, then accepts a fresh shared start', async () => {
  const now = spyOn(performance, 'now').mockReturnValue(1_000);
  try {
    playInstrumentMusic({ ...packet, waiting: true, prepare: true });
    now.mockReturnValue(91_000);
    deliver(begin(recording()));
    const audio = audios[0];
    Object.defineProperty(audio, 'readyState', {
      configurable: true,
      value: 1,
    });
    audio.dispatchEvent(new Event('loadedmetadata'));
    expect(audio.play).not.toHaveBeenCalled();
    expect(
      messages.filter((m) => m.type === 'audio/instrumentReady'),
    ).toHaveLength(0);
    Object.defineProperty(audio, 'readyState', {
      configurable: true,
      value: 4,
    });
    audio.dispatchEvent(new Event('canplay'));
    audio.dispatchEvent(new Event('canplay'));
    expect(audio.play).toHaveBeenCalledTimes(1);
    expect(audio.muted).toBe(true);
    expect(audio.volume).toBe(0);
    await Promise.resolve();
    expect(audio.pause).toHaveBeenCalledTimes(1);
    expect(audio.currentTime).toBe(0);
    const ready = messages.filter((m) => m.type === 'audio/instrumentReady');
    expect(ready).toHaveLength(1);
    expect(ready[0].payload).toEqual({
      id: packet.id,
      token: packet.token,
      hash,
    });
    // Spatial refreshes and a long wait must not repeat the transfer or silent warm-up.
    now.mockReturnValue(301_000);
    playInstrumentMusic({ ...packet, waiting: true, prepare: true });
    audio.dispatchEvent(new Event('canplay'));
    await Promise.resolve();
    expect(audio.play).toHaveBeenCalledTimes(1);
    expect(
      messages.filter((m) => m.type === 'audio/instrumentReady'),
    ).toHaveLength(1);
    expect(
      messages.filter((m) => m.type === 'audio/instrumentRequest'),
    ).toHaveLength(1);
    now.mockReturnValue(302_000);
    playInstrumentMusic({ ...packet, waiting: false });
    expect(audio.play).toHaveBeenCalledTimes(2);
    expect(audio.muted).toBe(false);
    expect(audio.volume).toBe(packet.volume);
    expect(audio.currentTime).toBe(0);
  } finally {
    now.mockRestore();
  }
});

test('cached restarts still acknowledge readiness without downloading again', async () => {
  playInstrumentMusic(packet);
  deliver(begin(recording()));
  stopInstrumentMusic({ id: packet.id, token: packet.token });
  playInstrumentMusic({
    ...packet,
    token: 'cached-restart',
    waiting: true,
    prepare: true,
  });
  const audio = audios[1];
  Object.defineProperty(audio, 'readyState', { value: 4 });
  audio.dispatchEvent(new Event('canplay'));
  await Promise.resolve();
  expect(
    messages.filter((m) => m.type === 'audio/instrumentRequest'),
  ).toHaveLength(1);
  expect(messages.at(-1)?.payload.token).toBe('cached-restart');
  expect(audio.play).toHaveBeenCalledTimes(1);
  expect(audio.muted).toBe(true);
});

test('a late listener acknowledges readiness at the shared position without a new transfer', async () => {
  playInstrumentMusic({ ...packet, waiting: true, prepare: false });
  deliver(begin(recording()));
  const audio = audios[0];
  Object.defineProperty(audio, 'readyState', { value: 4 });
  audio.dispatchEvent(new Event('canplay'));
  expect(
    messages.filter((m) => m.type === 'audio/instrumentReady'),
  ).toHaveLength(0);
  expect(audio.play).not.toHaveBeenCalled();
  playInstrumentMusic({ ...packet, waiting: false, position: 42 });
  await Promise.resolve();
  expect(audio.currentTime).toBeGreaterThanOrEqual(42);
  expect(audio.play).toHaveBeenCalledTimes(1);
  expect(
    messages.filter((m) => m.type === 'audio/instrumentReady'),
  ).toHaveLength(1);
  expect(
    messages.filter((m) => m.type === 'audio/instrumentRequest'),
  ).toHaveLength(1);
});

test('stop while preparing ignores later readiness and playback errors identify the performance', () => {
  playInstrumentMusic({ ...packet, waiting: true, prepare: true });
  deliver(begin(recording()));
  const audio = audios[0];
  Object.defineProperty(audio, 'readyState', { value: 4 });
  stopInstrumentMusic({ id: packet.id, token: packet.token });
  audio.dispatchEvent(new Event('canplay'));
  expect(
    messages.filter((m) => m.type === 'audio/instrumentReady'),
  ).toHaveLength(0);
  playInstrumentMusic({
    ...packet,
    token: 'retry',
    waiting: true,
    prepare: true,
  });
  audios[1].dispatchEvent(new Event('error'));
  expect(messages.at(-1)).toEqual({
    type: 'audio/instrumentError',
    payload: { id: packet.id, token: 'retry', hash, reason: 'decode' },
  });
});

test('blocked autoplay retries at the shared position on a user gesture without another download', async () => {
  playInstrumentMusic(packet);
  deliver(begin(recording()));
  const audio = audios[0];
  const play = spyOn(audio, 'play')
    .mockRejectedValueOnce(
      new DOMException('Gesture required', 'NotAllowedError'),
    )
    .mockResolvedValue(undefined);
  Object.defineProperty(audio, 'readyState', { value: 4 });
  audio.dispatchEvent(new Event('canplay'));
  await Promise.resolve();
  expect(messages.at(-1)?.payload.reason).toBe('blocked');
  playInstrumentMusic({ ...packet, position: 42 });
  expect(play).toHaveBeenCalledTimes(1);
  window.dispatchEvent(new MouseEvent('mousedown'));
  await Promise.resolve();
  expect(play).toHaveBeenCalledTimes(2);
  expect(audio.currentTime).toBeGreaterThanOrEqual(42);
  expect(
    messages.filter((m) => m.type === 'audio/instrumentRequest'),
  ).toHaveLength(1);
  expect(
    messages.filter((m) => m.type === 'audio/instrumentError'),
  ).toHaveLength(1);
  stopInstrumentMusic({ id: packet.id, token: packet.token });
  window.dispatchEvent(new KeyboardEvent('keydown'));
  expect(play).toHaveBeenCalledTimes(2);
});

test('an interrupted play is retried but a decode failure is not', async () => {
  playInstrumentMusic(packet);
  deliver(begin(recording()));
  const audio = audios[0];
  const play = spyOn(audio, 'play')
    .mockRejectedValueOnce(
      new DOMException('Seek interrupted playback', 'AbortError'),
    )
    .mockRejectedValueOnce(
      new DOMException('Invalid recording', 'NotSupportedError'),
    );
  Object.defineProperty(audio, 'readyState', { value: 4 });
  audio.dispatchEvent(new Event('canplay'));
  await Promise.resolve();
  expect(
    messages.filter((m) => m.type === 'audio/instrumentError'),
  ).toHaveLength(0);
  playInstrumentMusic({ ...packet, position: 1 });
  await Promise.resolve();
  expect(messages.at(-1)?.payload.reason).toBe('decode');
  playInstrumentMusic({ ...packet, position: 2 });
  window.dispatchEvent(new MouseEvent('mousedown'));
  expect(play).toHaveBeenCalledTimes(2);
});

test('delayed playback and gain packets do not seek an already playing recording', async () => {
  const now = spyOn(performance, 'now').mockReturnValue(0);
  try {
    playInstrumentMusic(packet);
    deliver(begin(recording()));
    const audio = audios[0];
    Object.defineProperty(audio, 'readyState', { value: 4 });
    audio.dispatchEvent(new Event('canplay'));
    await Promise.resolve();
    Object.defineProperty(audio, 'paused', { value: false });

    now.mockReturnValue(10_000);
    audio.currentTime = 10;
    playInstrumentMusic({ ...packet, position: 9 });
    expect(audio.currentTime).toBe(10);

    now.mockReturnValue(15_000);
    audio.currentTime = 15;
    playInstrumentMusic({ ...packet, position: 14, volume: 0.2 });
    expect(audio.currentTime).toBe(15);
    expect(audio.volume).toBe(0.2);
    expect(audio.play).toHaveBeenCalledTimes(1);
    expect(audios).toHaveLength(1);
    expect(
      messages.filter((m) => m.type === 'audio/instrumentRequest'),
    ).toHaveLength(1);
  } finally {
    now.mockRestore();
  }
});

test('a warmed listener waits for the shared future start without reloading', async () => {
  playInstrumentMusic({ ...packet, waiting: true, prepare: true });
  deliver(begin(recording()));
  const audio = audios[0];
  Object.defineProperty(audio, 'readyState', { value: 4 });
  audio.dispatchEvent(new Event('canplay'));
  await Promise.resolve();
  const now = spyOn(performance, 'now').mockReturnValue(0);
  const timers: { callback: () => void; delay: number }[] = [];
  const timer = spyOn(globalThis, 'setTimeout').mockImplementation(((
    callback: () => void,
    delay: number,
  ) => {
    timers.push({ callback, delay });
    return 1;
  }) as typeof setTimeout);
  try {
    playInstrumentMusic({ ...packet, position: -0.5, waiting: false });
    expect(audio.play).toHaveBeenCalledTimes(1);
    expect(timers.at(-1)?.delay).toBe(500);
    now.mockReturnValue(500);
    timers.at(-1)?.callback();
    expect(audio.play).toHaveBeenCalledTimes(2);
    expect(audio.currentTime).toBe(0);
    expect(
      messages.filter((m) => m.type === 'audio/instrumentRequest'),
    ).toHaveLength(1);
  } finally {
    timer.mockRestore();
    now.mockRestore();
    stopInstrumentMusic({ id: packet.id, token: packet.token });
  }
});

test('accepts a full 3 MiB recording in bounded chunks', () => {
  playInstrumentMusic({ ...packet, waiting: true, prepare: true });
  deliver(begin(recording(3 * 1024 * 1024)));
  expect(blobs).toHaveLength(1);
  expect(blobs[0].size).toBe(3 * 1024 * 1024);
  expect(messages.some((m) => m.type === 'audio/instrumentError')).toBe(false);
  expect(messages.at(-1)?.payload.bytes).toBe(3 * 1024 * 1024);
});

test('a late silent warm-up joins the current position instead of pausing the real performance', async () => {
  playInstrumentMusic({ ...packet, waiting: true, prepare: true });
  deliver(begin(recording()));
  const audio = audios[0];
  let finishWarmup!: () => void;
  const play = spyOn(audio, 'play')
    .mockImplementationOnce(
      () =>
        new Promise<void>((resolve) => {
          finishWarmup = resolve;
        }),
    )
    .mockResolvedValue(undefined);
  Object.defineProperty(audio, 'readyState', { value: 4 });
  audio.dispatchEvent(new Event('canplay'));
  playInstrumentMusic({ ...packet, waiting: false, position: 42 });
  expect(audio.muted).toBe(true);
  expect(play).toHaveBeenCalledTimes(1);
  finishWarmup();
  await Promise.resolve();
  expect(play).toHaveBeenCalledTimes(2);
  expect(audio.currentTime).toBeGreaterThanOrEqual(42);
  expect(audio.muted).toBe(false);
  expect(
    messages.filter((m) => m.type === 'audio/instrumentReady'),
  ).toHaveLength(1);
});
