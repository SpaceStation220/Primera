import { describe, expect, it } from 'bun:test';
import {
  appendCueText,
  parseCueDocument,
  rippleCueTime,
  shiftCues,
  validateCueInterval,
  validateCues,
} from './cues';

describe('OGG cue timing', () => {
  it('reports the particular cue limit and its actual value', () => {
    expect(() =>
      validateCues(Array(201).fill({ time: 0, text: 'a' }), 60),
    ).toThrow('Too many cues: 201; maximum 200.');
    expect(() =>
      validateCues(
        [
          { time: 0, text: 'a' },
          { time: 1, text: 'x'.repeat(301) },
        ],
        60,
      ),
    ).toThrow('Cue 2: 301 characters; maximum 300.');
    expect(() => validateCues([{ time: -1, text: 'a' }], 60)).toThrow(
      'Cue 1: time -1 s cannot be negative.',
    );
    expect(() => validateCues([{ time: NaN, text: 'a' }], 60)).toThrow(
      'Cue 1: time must be a finite number of seconds.',
    );
    expect(() => appendCueText([], 'a\nb\nc', 5, 8)).toThrow(
      'Cue 3: time 10 s exceeds OGG duration 8 s.',
    );
  });

  it('imports a track-bound JSON sheet preserving times, spacing and Unicode', () => {
    const sheet = {
      version: 1 as const,
      audio_hash: 'track',
      spacing_seconds: 2.5,
      cues: [
        { time: 9.125, text: '\u041f\u0435\u0441\u043d\u044f' },
        { time: 3, text: 'First' },
      ],
    };
    expect(parseCueDocument(JSON.stringify(sheet), 'track', 10)).toEqual({
      ...sheet,
      cues: [sheet.cues[1], sheet.cues[0]],
    });
    expect(
      parseCueDocument(
        JSON.stringify({ ...sheet, spacing_seconds: undefined }),
        'track',
        10,
      ).spacing_seconds,
    ).toBe(5);
  });

  it('distinguishes JSON syntax, format, track, interval and cue errors', () => {
    const sheet = {
      version: 1,
      audio_hash: 'track',
      cues: [{ time: 9, text: 'a' }],
    };
    expect(() => parseCueDocument('{', 'track', 10)).toThrow('Invalid JSON');
    expect(() => parseCueDocument('null', 'track', 10)).toThrow(
      'must be an object',
    );
    expect(() =>
      parseCueDocument(JSON.stringify({ ...sheet, version: 2 }), 'track', 10),
    ).toThrow('version 1');
    expect(() => parseCueDocument(JSON.stringify(sheet), null, 10)).toThrow(
      'Load an OGG',
    );
    expect(() => parseCueDocument(JSON.stringify(sheet), 'other', 10)).toThrow(
      'audio_hash',
    );
    expect(() =>
      parseCueDocument(JSON.stringify({ ...sheet, cues: null }), 'track', 10),
    ).toThrow('cues array');
    expect(() =>
      parseCueDocument(
        JSON.stringify({ ...sheet, spacing_seconds: 0 }),
        'track',
        10,
      ),
    ).toThrow('Interval');
    expect(() => parseCueDocument(JSON.stringify(sheet), 'track', 8)).toThrow(
      'Cue 1: time 9 s exceeds OGG duration 8 s.',
    );
    expect(() => parseCueDocument(' '.repeat(300001), 'track', 10)).toThrow(
      '300000 bytes',
    );
  });
  it('appends lyric lines at T-second intervals, ignoring blank lines', () => {
    expect(appendCueText([], 'First\r\n\r\nSecond\nThird', 5, 60)).toEqual([
      { time: 0, text: 'First' },
      { time: 5, text: 'Second' },
      { time: 10, text: 'Third' },
    ]);
    expect(
      appendCueText([{ time: 7, text: 'Existing' }], 'Next\nLast', 3, 60).map(
        (cue) => cue.time,
      ),
    ).toEqual([10, 13]);
  });
  it('moves every following cue by the edited time delta', () => {
    const original = [0, 5, 12, 20].map((time) => ({
      time,
      text: String(time),
    }));
    expect(rippleCueTime(original, 1, 8, 60).map((cue) => cue.time)).toEqual([
      0, 8, 15, 23,
    ]);
    expect(rippleCueTime(original, 1, 2, 60).map((cue) => cue.time)).toEqual([
      0, 2, 9, 17,
    ]);
    expect(original.map((cue) => cue.time)).toEqual([0, 5, 12, 20]);
  });
  it('shifts every cue equally when none are selected', () => {
    const original = [3, 8, 19].map((time) => ({
      time,
      text: '',
      selected: false,
    }));
    expect(shiftCues(original, 2, 60).map((cue) => cue.time)).toEqual([
      5, 10, 21,
    ]);
    expect(shiftCues(original, -2, 60).map((cue) => cue.time)).toEqual([
      1, 6, 17,
    ]);
  });
  it('retimes only selected cues, keeping selection attached after sorting', () => {
    const original = [
      { id: 1, time: 0, text: 'a', selected: true },
      { id: 2, time: 5, text: 'b', selected: false },
      { id: 3, time: 10, text: 'c', selected: true },
    ];
    const result = shiftCues(original, 6, 60);
    expect(result.map((cue) => [cue.id, cue.time, cue.selected])).toEqual([
      [2, 5, false],
      [1, 6, true],
      [3, 16, true],
    ]);
  });
  it('moves a single selected cue rather than anchoring it', () => {
    const original = [
      { time: 0, text: 'a', selected: false },
      { time: 8, text: 'b', selected: true },
    ];
    expect(shiftCues(original, 2, 60).map((cue) => cue.time)).toEqual([0, 10]);
    expect(() => shiftCues(original, -9, 60)).toThrow();
  });
  it('rejects track overflow and invalid intervals without mutating input', () => {
    const original = [
      { time: 5, text: 'a' },
      { time: 9, text: 'b' },
    ];
    expect(() => rippleCueTime(original, 0, 7, 10)).toThrow();
    expect(() => appendCueText(original, 'c', 2, 10)).toThrow();
    expect(() => validateCueInterval(0)).toThrow();
    expect(() =>
      shiftCues([{ time: 5, text: '', selected: true }], 6, 10),
    ).toThrow();
    expect(() => appendCueText([], 'x'.repeat(301), 1, 10)).toThrow();
    expect(() =>
      appendCueText([], Array(201).fill('line').join('\n'), 1, 1000),
    ).toThrow();
    expect(original.map((cue) => cue.time)).toEqual([5, 9]);
  });
});
