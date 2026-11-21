import { afterEach, beforeEach, expect, spyOn, test } from 'bun:test';
import {
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

function begin(bytes: Uint8Array, trackHash = hash) {
  const encoded = Buffer.from(bytes).toString('base64');
  beginInstrumentTransfer({
    request: Number(
      messages.filter((m) => m.type === 'audio/instrumentRequest').at(-1)
        ?.payload.request,
    ),
    transfer: '1',
    hash: trackHash,
    size: encoded.length,
    bytes: bytes.length,
    chunkSize: 16384,
    window: 8,
  });
  return encoded;
}

function deliver(encoded: string) {
  for (let offset = 0; offset < encoded.length; offset += 16384) {
    receiveInstrumentChunk({
      transfer: '1',
      offset,
      data: encoded.slice(offset, offset + 16384),
    });
  }
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

test('rejects out of order chunks instead of playing damaged data', () => {
  playInstrumentMusic(packet);
  const encoded = begin(recording());
  receiveInstrumentChunk({
    transfer: '1',
    offset: 16384,
    data: encoded.slice(16384, 32768),
  });
  expect(blobs).toHaveLength(0);
  expect(messages.some((m) => m.type === 'audio/instrumentCancel')).toBe(true);
  expect(messages.some((m) => m.type === 'audio/instrumentError')).toBe(true);
  playInstrumentMusic(packet);
  expect(
    messages.filter((m) => m.type === 'audio/instrumentRequest'),
  ).toHaveLength(1);
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
    now.mockReturnValue(92_000);
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

test('other listeners cannot release the start and late listeners keep the shared position', () => {
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
  expect(audio.currentTime).toBeGreaterThanOrEqual(42);
  expect(audio.play).toHaveBeenCalledTimes(1);
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
  expect(messages.some((m) => m.type === 'audio/instrumentReady')).toBe(false);
});
