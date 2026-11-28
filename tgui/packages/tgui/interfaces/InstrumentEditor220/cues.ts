export type Cue = { time: number; text: string };
export type CueDocument = {
  version: 1;
  audio_hash: string | null;
  spacing_seconds?: number;
  cues: Cue[];
};

export function validateCues(cues: Cue[], length: number) {
  if (cues.length > 200)
    throw new Error(`Too many cues: ${cues.length}; maximum 200.`);
  if (!Number.isFinite(length) || length < 0)
    throw new Error('The loaded OGG duration is invalid.');
  for (const [index, cue] of cues.entries()) {
    const row = index + 1;
    if (!cue || typeof cue.text !== 'string')
      throw new Error(`Cue ${row}: text must be a string.`);
    const characters = Array.from(cue.text).length;
    if (characters > 300)
      throw new Error(`Cue ${row}: ${characters} characters; maximum 300.`);
    if (!Number.isFinite(cue.time))
      throw new Error(`Cue ${row}: time must be a finite number of seconds.`);
    if (cue.time < 0)
      throw new Error(`Cue ${row}: time ${cue.time} s cannot be negative.`);
    if (cue.time > length)
      throw new Error(
        `Cue ${row}: time ${cue.time} s exceeds OGG duration ${length} s.`,
      );
  }
}

/** Ignore bracketed performance annotations rather than singing them. */
function stripCueTags(text: string) {
  return text.replace(/\[[^\]\r\n]*\]/g, '').trim();
}

/** File and clipboard imports share the same cue-sheet format. */
export function parseCueDocument(
  raw: string,
  audioHash: string | null,
  length: number,
): CueDocument {
  if (new TextEncoder().encode(raw).length > 300000)
    throw new Error('Cue sheet exceeds 300000 bytes.');
  let data;
  try {
    data = JSON.parse(raw);
  } catch {
    throw new Error('Invalid JSON: check quotes, commas and brackets.');
  }
  if (!data || typeof data !== 'object' || Array.isArray(data))
    throw new Error('JSON cue sheet must be an object.');
  if (data.version !== 1)
    throw new Error('Unsupported cue sheet version; expected version 1.');
  if (!audioHash) throw new Error('Load an OGG before importing a cue sheet.');
  if (!Array.isArray(data.cues))
    throw new Error('JSON cue sheet must contain a cues array.');
  validateCues(data.cues, length);
  const spacing = data.spacing_seconds ?? 5;
  validateCueInterval(spacing);
  return {
    version: 1,
    audio_hash: audioHash,
    spacing_seconds: spacing,
    cues: data.cues
      .map(({ time, text }: Cue) => ({ time, text: stripCueTags(text) }))
      .filter((cue: Cue) => cue.text)
      .sort((a: Cue, b: Cue) => a.time - b.time),
  };
}

/** Move the edited cue and everything after it by the same delta. */
export function rippleCueTime<T extends Cue>(
  cues: T[],
  index: number,
  time: number,
  length: number,
): T[] {
  if (
    !cues[index] ||
    !Number.isFinite(time) ||
    time < (cues[index - 1]?.time ?? 0)
  )
    throw new Error('Cue time must not precede the previous line.');
  const delta = time - cues[index].time;
  const result = cues.map((cue, i) =>
    i >= index
      ? { ...cue, time: Math.round((cue.time + delta) * 1000) / 1000 }
      : cue,
  );
  validateCues(result, length);
  return result;
}

export function validateCueInterval(interval: number) {
  if (!Number.isFinite(interval) || interval < 0.1 || interval > 120)
    throw new Error('Interval must be between 0.1 and 120 seconds.');
}

/** Apply one delta to the selection, or to every cue when nothing is selected. */
export function shiftCues<T extends Cue & { selected: boolean }>(
  cues: T[],
  delta: number,
  length: number,
): T[] {
  if (!Number.isFinite(delta)) throw new Error('Invalid time shift.');
  const selected = cues.some((cue) => cue.selected);
  const result = cues
    .map((cue) =>
      selected && !cue.selected
        ? cue
        : { ...cue, time: Math.round((cue.time + delta) * 1000) / 1000 },
    )
    .sort((a, b) => a.time - b.time);
  validateCues(result, length);
  return result;
}

export function appendCueText(
  cues: Cue[],
  text: string,
  interval: number,
  length: number,
): Cue[] {
  validateCueInterval(interval);
  const lines = text
    .split(/\r\n|\n|\r/)
    .map(stripCueTags)
    .filter(Boolean);
  const start = cues.length ? cues[cues.length - 1].time + interval : 0;
  const added = lines.map((line, i) => ({
    time: Math.round((start + i * interval) * 1000) / 1000,
    text: line,
  }));
  validateCues([...cues, ...added], length);
  return added;
}
