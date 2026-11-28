import type { MusicDocument } from './midi';

export type MusicUploadKind = 'sequence' | 'cues' | 'notes';
export type PlayAction = 'play_music';
export type MusicUploadStatus = {
  id: string;
  next: number;
  state: 'preparing' | 'receiving' | 'complete' | 'error';
  error?: string;
  native_controls?: string[] | null;
};

function serializeMusicDocument(document: object, kind?: MusicUploadKind) {
  if (kind === 'sequence') {
    const sequence = document as MusicDocument;
    document = {
      ...sequence,
      note_format: 'tuple-v1',
      notes: sequence.notes.map((note) => [
        note.time,
        note.duration,
        note.key,
        note.velocity,
        note.channel,
        note.track,
      ]),
    };
  }
  const text = JSON.stringify(document);
  if (text.length > 600000) throw new Error('Music project exceeds 600 KB.');
  return text;
}

// One small native bank is reused for each page; no data goes into act() payloads.
export function nativeMusicPages(
  document: object,
  kind: MusicUploadKind = 'sequence',
): string[] {
  const bytes = new TextEncoder().encode(
    serializeMusicDocument(document, kind),
  );
  if (bytes.length > 600000) throw new Error('Music project exceeds 600 KB.');
  let binary = '';
  for (let offset = 0; offset < bytes.length; offset += 8192) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 8192));
  }
  const encoded = btoa(binary).replaceAll('+', '-').replaceAll('/', '_');
  const pages: string[] = [];
  for (let offset = 0; offset < encoded.length; offset += 32768) {
    pages.push(encoded.slice(offset, offset + 32768));
  }
  return pages;
}

// Leave room for the envelope so sendAct never invokes TGUI's nested chunking.
export function splitMusicDocument(
  document: object,
  kind?: MusicUploadKind,
): string[] {
  const text = serializeMusicDocument(document, kind);
  const parts: string[] = [];
  let part = '';
  let size = 0;
  for (const character of text) {
    const encoded = encodeURIComponent(
      JSON.stringify(character).slice(1, -1),
    ).length;
    if (size + encoded > 900) {
      parts.push(part);
      part = '';
      size = 0;
    }
    part += character;
    size += encoded;
  }
  if (part) parts.push(part);
  return parts;
}
