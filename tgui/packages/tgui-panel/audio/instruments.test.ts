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
    size: 16000000,
    bytes: 12000000,
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

test('holds a cold initiator at zero until canplay and a fresh shared start', () => {
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
    expect(audio.play).not.toHaveBeenCalled();
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
    expect(audio.play).toHaveBeenCalledTimes(1);
    expect(audio.currentTime).toBe(0);
  } finally {
    now.mockRestore();
  }
});

test('cached restarts still acknowledge readiness without downloading again', () => {
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
  expect(
    messages.filter((m) => m.type === 'audio/instrumentRequest'),
  ).toHaveLength(1);
  expect(messages.at(-1)?.payload.token).toBe('cached-restart');
  expect(audio.play).not.toHaveBeenCalled();
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
    payload: { id: packet.id, token: 'retry', hash },
  });
});
