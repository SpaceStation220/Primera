import { createLogger } from 'tgui/logging';

const logger = createLogger('InstrumentAudio');
const MAX_FILE_BYTES = 3 * 1024 * 1024;
const MAX_CACHE_BYTES = 40 * 1024 * 1024;
const MAX_VOICES = 32;
const TRANSFER_TIMEOUT_MS = 25_000;

type Packet = {
  id: string;
  token: string;
  hash: string;
  volume: number;
  position: number;
  waiting?: boolean | 0 | 1;
  prepare?: boolean | 0 | 1;
};

type Voice = {
  packet: Packet;
  receivedAt: number;
  audio?: HTMLAudioElement;
  pending: boolean;
  failed: boolean;
  disposed: boolean;
  readySent: boolean;
  autoplayBlocked: boolean;
  startTimer?: ReturnType<typeof setTimeout>;
};

type Transfer = {
  request: number;
  hash: string;
  transfer?: string;
  size: number;
  bytes: number;
  chunkSize: number;
  window: number;
  received: number;
  decoded: number;
  chunks: Uint8Array<ArrayBuffer>[];
  timer?: ReturnType<typeof setTimeout>;
};

const voices = new Map<string, Voice>();
const stopped = new Map<string, string>();
const cache = new Map<string, { url: string; bytes: number }>();
let cacheBytes = 0;
let active: Transfer | undefined;
let requestSerial = 0;

function dispose(voice: Voice) {
  voice.disposed = true;
  clearTimeout(voice.startTimer);
  const audio = voice.audio;
  if (!audio) return;
  audio.onloadedmetadata = null;
  audio.oncanplay = null;
  audio.onerror = null;
  audio.pause();
  audio.removeAttribute('src');
  audio.load();
}

function failHash(hash: string) {
  for (const voice of voices.values()) {
    if (voice.packet.hash !== hash) continue;
    dispose(voice);
    voice.failed = true;
    reportVoiceError(voice, 'transfer');
  }
  logger.warn('instrument transfer failed', hash);
}

function reportVoiceError(
  voice: Voice,
  reason: 'transfer' | 'decode' | 'blocked' | 'playback',
) {
  const { id, token, hash } = voice.packet;
  Byond.sendMessage('audio/instrumentError', { id, token, hash, reason });
}

function clearTransfer(cancel: boolean) {
  if (!active) return;
  clearTimeout(active.timer);
  if (cancel) {
    Byond.sendMessage('audio/instrumentCancel', {
      request: active.request,
      hash: active.hash,
    });
  }
  active = undefined;
}

function armTimeout(transfer: Transfer) {
  clearTimeout(transfer.timer);
  transfer.timer = setTimeout(() => {
    if (active !== transfer) return;
    clearTransfer(true);
    failHash(transfer.hash);
    requestNext();
  }, TRANSFER_TIMEOUT_MS);
}

function requestNext() {
  if (active) return;
  for (const voice of voices.values()) {
    const packet = voice.packet;
    if (voice.failed || voice.disposed || cache.has(packet.hash)) continue;
    active = {
      request: ++requestSerial,
      hash: packet.hash,
      size: 0,
      bytes: 0,
      chunkSize: 0,
      window: 0,
      received: 0,
      decoded: 0,
      chunks: [],
    };
    armTimeout(active);
    Byond.sendMessage('audio/instrumentRequest', {
      request: active.request,
      id: packet.id,
      token: packet.token,
      hash: packet.hash,
    });
    return;
  }
}

function makeRoom(bytes: number) {
  for (const [hash, entry] of cache) {
    if (cacheBytes + bytes <= MAX_CACHE_BYTES) break;
    if ([...voices.values()].some((voice) => voice.packet.hash === hash)) {
      continue;
    }
    URL.revokeObjectURL(entry.url);
    cacheBytes -= entry.bytes;
    cache.delete(hash);
  }
  return cacheBytes + bytes <= MAX_CACHE_BYTES;
}

function playVoice(voice: Voice, onPlayed?: () => void) {
  const audio = voice.audio;
  if (!audio || voice.pending) return;
  voice.pending = true;
  Promise.resolve(audio.play()).then(
    () => {
      voice.pending = false;
      if (voice.disposed || voice.failed) return;
      voice.autoplayBlocked = false;
      onPlayed?.();
    },
    (error) => {
      voice.pending = false;
      if (voice.disposed) return;
      if (error?.name === 'NotAllowedError') {
        if (!voice.autoplayBlocked) reportVoiceError(voice, 'blocked');
        voice.autoplayBlocked = true;
        return;
      }
      if (error?.name === 'AbortError') return;
      voice.failed = true;
      logger.warn('playback failed', error);
      reportVoiceError(
        voice,
        error?.name === 'NotSupportedError' ? 'decode' : 'playback',
      );
    },
  );
}

function synchronize(voice: Voice, force = false, userGesture = false) {
  const audio = voice.audio;
  if (!audio || voice.failed || voice.disposed) return;
  clearTimeout(voice.startTimer);
  if (voice.autoplayBlocked && !userGesture) return;
  if (voice.packet.waiting) {
    if (
      voice.packet.prepare &&
      audio.readyState >= 3 &&
      !voice.readySent &&
      !voice.pending
    ) {
      audio.muted = true;
      audio.volume = 0;
      playVoice(voice, () => {
        audio.pause();
        audio.currentTime = 0;
        voice.readySent = true;
        if (voice.packet.waiting) {
          const { id, token, hash } = voice.packet;
          Byond.sendMessage('audio/instrumentReady', { id, token, hash });
        } else {
          synchronize(voice, true);
        }
      });
    }
    return;
  }
  // A late warm-up must finish silently before joining an already started timeline.
  if (voice.pending && audio.muted && !voice.readySent) return;
  if (!audio.readyState || audio.ended) return;
  const position =
    voice.packet.position + (performance.now() - voice.receivedAt) / 1000;
  if (position < 0) {
    voice.startTimer = setTimeout(() => synchronize(voice), -position * 1000);
    return;
  }
  audio.muted = false;
  audio.volume = voice.packet.volume;
  if (Number.isFinite(audio.duration) && position >= audio.duration) return;
  // Packet transit delay must not rewind a recording that is already playing.
  if (
    !audio.seeking &&
    (force || (audio.paused && Math.abs(audio.currentTime - position) > 0.75))
  ) {
    try {
      audio.currentTime = Math.max(0, position);
    } catch (error) {
      logger.warn('seek failed', error);
    }
  }
  if (audio.paused && !voice.pending) playVoice(voice);
}

function retryBlockedVoices() {
  for (const voice of voices.values()) {
    if (voice.autoplayBlocked) synchronize(voice, true, true);
  }
}

window.addEventListener('mousedown', retryBlockedVoices);
window.addEventListener('keydown', retryBlockedVoices);

function attachAudio(voice: Voice) {
  const entry = cache.get(voice.packet.hash);
  if (!entry || voice.audio || voice.failed || voice.disposed) return;
  // Refresh LRU order; URLs stay alive while any voice references this recording.
  cache.delete(voice.packet.hash);
  cache.set(voice.packet.hash, entry);
  const audio = new Audio();
  voice.audio = audio;
  audio.onloadedmetadata = () => synchronize(voice, true);
  audio.oncanplay = () => synchronize(voice);
  audio.onerror = () => {
    if (voice.disposed) return;
    voice.failed = true;
    reportVoiceError(voice, 'decode');
  };
  audio.preload = 'auto';
  audio.volume = voice.packet.volume;
  audio.src = entry.url;
}

export function playInstrumentMusic(packet: Packet) {
  if (
    !packet ||
    !/^\d{1,4}$/.test(packet.id) ||
    Number(packet.id) < 1 ||
    Number(packet.id) > 1024 ||
    typeof packet.token !== 'string' ||
    !packet.token.length ||
    packet.token.length > 100 ||
    !/^[0-9a-f]{32}$/.test(packet.hash) ||
    !Number.isFinite(packet.volume) ||
    !Number.isFinite(packet.position)
  ) {
    return;
  }
  if (stopped.get(packet.id) === packet.token) return;
  stopped.delete(packet.id);
  let voice = voices.get(packet.id);
  if (
    voice &&
    (voice.packet.token !== packet.token || voice.packet.hash !== packet.hash)
  ) {
    dispose(voice);
    voices.delete(packet.id);
    voice = undefined;
  }
  packet = { ...packet, volume: Math.max(0, Math.min(1, packet.volume)) };
  if (!voice) {
    if (voices.size >= MAX_VOICES) return;
    voice = {
      packet,
      receivedAt: performance.now(),
      pending: false,
      failed: false,
      disposed: false,
      readySent: false,
      autoplayBlocked: false,
    };
    voices.set(packet.id, voice);
  }
  voice.packet = packet;
  voice.receivedAt = performance.now();
  attachAudio(voice);
  if (voice.audio) voice.audio.volume = packet.volume;
  synchronize(voice);
  pruneTransfer();
  requestNext();
}

export function beginInstrumentTransfer(packet: {
  request: number;
  transfer: string;
  hash: string;
  size: number;
  bytes: number;
  chunkSize: number;
  window: number;
}) {
  const transfer = active;
  if (
    !transfer ||
    !packet ||
    packet.hash !== transfer.hash ||
    packet.request !== transfer.request
  )
    return;
  if (
    transfer.transfer ||
    typeof packet.transfer !== 'string' ||
    !Number.isInteger(packet.bytes) ||
    packet.bytes < 4 ||
    packet.bytes > MAX_FILE_BYTES ||
    packet.size !== 4 * Math.ceil(packet.bytes / 3) ||
    !Number.isInteger(packet.chunkSize) ||
    packet.chunkSize < 4 ||
    packet.chunkSize > 16384 ||
    packet.chunkSize % 4 !== 0 ||
    !Number.isInteger(packet.window) ||
    packet.window < 1 ||
    packet.window > 8 ||
    !makeRoom(packet.bytes)
  ) {
    clearTransfer(true);
    failHash(packet.hash);
    requestNext();
    return;
  }
  Object.assign(transfer, packet);
  armTimeout(transfer);
}

export function receiveInstrumentChunk(packet: {
  transfer: string;
  offset: number;
  data: string;
}) {
  const transfer = active;
  if (!transfer?.transfer || packet?.transfer !== transfer.transfer) return;
  try {
    if (
      packet.offset !== transfer.received ||
      typeof packet.data !== 'string' ||
      packet.data.length !==
        Math.min(transfer.chunkSize, transfer.size - transfer.received)
    ) {
      throw new Error('Unexpected chunk offset or length');
    }
    const decoded = atob(packet.data);
    const bytes = new Uint8Array(decoded.length);
    for (let i = 0; i < decoded.length; i++) bytes[i] = decoded.charCodeAt(i);
    if (
      transfer.received === 0 &&
      (bytes[0] !== 79 ||
        bytes[1] !== 103 ||
        bytes[2] !== 103 ||
        bytes[3] !== 83)
    ) {
      throw new Error('Not an OGG recording');
    }
    transfer.chunks.push(bytes);
    transfer.received += packet.data.length;
    transfer.decoded += bytes.length;
    armTimeout(transfer);
    if (transfer.received === transfer.size) {
      if (transfer.decoded !== transfer.bytes) {
        throw new Error('Incomplete recording');
      }
      const blob = new Blob(transfer.chunks, { type: 'audio/ogg' });
      const url = URL.createObjectURL(blob);
      cache.set(transfer.hash, { url, bytes: transfer.bytes });
      cacheBytes += transfer.bytes;
      Byond.sendMessage('audio/instrumentAck', {
        transfer: transfer.transfer,
        received: transfer.received,
        bytes: transfer.decoded,
      });
      logger.log('recording received', transfer.hash, transfer.decoded);
      clearTransfer(false);
      for (const voice of voices.values()) attachAudio(voice);
      requestNext();
    } else if (transfer.chunks.length % transfer.window === 0) {
      Byond.sendMessage('audio/instrumentAck', {
        transfer: transfer.transfer,
        received: transfer.received,
      });
    }
  } catch (error) {
    logger.warn('invalid instrument transfer', error);
    clearTransfer(true);
    failHash(transfer.hash);
    requestNext();
  }
}

export function abortInstrumentTransfer(packet: {
  transfer: string;
  hash: string;
}) {
  if (!active || packet?.transfer !== active.transfer) return;
  clearTransfer(false);
  failHash(packet.hash);
  requestNext();
}

function pruneTransfer() {
  if (
    active &&
    ![...voices.values()].some(
      (voice) => voice.packet.hash === active?.hash && !voice.failed,
    )
  ) {
    clearTransfer(true);
  }
}

export function stopInstrumentMusic(packet: {
  id?: string;
  token?: string;
  reset?: boolean;
}) {
  if (packet?.id) {
    const voice = voices.get(packet.id);
    if (!voice || packet.token !== voice.packet.token) return;
    dispose(voice);
    voices.delete(packet.id);
  } else {
    for (const [id, voice] of voices) {
      if (!packet?.reset) stopped.set(id, voice.packet.token);
      dispose(voice);
    }
    voices.clear();
    if (packet?.reset) stopped.clear();
  }
  pruneTransfer();
  requestNext();
}

export function resetInstrumentMusic() {
  stopInstrumentMusic({});
  stopped.clear();
  for (const entry of cache.values()) URL.revokeObjectURL(entry.url);
  cache.clear();
  cacheBytes = 0;
}
