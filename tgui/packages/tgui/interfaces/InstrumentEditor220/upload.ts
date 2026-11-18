import type { MusicDocument } from './midi';

export type MusicUploadKind = 'sequence' | 'cues' | 'notes';
export type PlayAction = 'play_music';
export type MusicUploadStatus = {
  id: string;
  next: number;
  state: 'receiving' | 'complete' | 'error';
  error?: string;
};

// Leave room for the envelope so sendAct never invokes TGUI's nested chunking.
export function splitMusicDocument(
  document: object,
  kind?: MusicUploadKind,
): string[] {
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
