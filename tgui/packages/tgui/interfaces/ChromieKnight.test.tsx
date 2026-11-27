import { afterEach, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import * as actions from 'tgui/events/act';
import { gameDataAtom, resetStore, store } from 'tgui/events/store';
import { ChromieKnight, energizedCells } from './ChromieKnight';
import { ChromieRouting } from './ChromieRouting';

afterEach(resetStore);
const data = {
  remote_enabled: true,
  charge: 90,
  temperature: 30,
  memory: [],
  scanner_targets: [],
  scan_cost: 1,
  devices: [],
  attempt: 1,
  phase: 1,
  routing_left: 40,
  routing_cooldown: 0,
  command_cooldown: 0,
  board: [
    {
      index: 1,
      mask: 10,
      blocked: false,
      locked: false,
      output: 0,
      required: false,
    },
  ],
};
it('shows hotkey help and legend while the puzzle stays in its own window', () => {
  store.set(gameDataAtom, data);
  render(<ChromieKnight />);
  expect(screen.getByText(/Alt \+ Shift \+ ЛКМ/)).toBeTruthy();
  expect(screen.getByText(/Shift \+ ЛКМ — открыть/)).toBeTruthy();
  expect(screen.getByText(/обязательный узел/)).toBeTruthy();
  expect(screen.queryByText('Проверить маршрут')).toBeNull();
});
it('lets the player cancel the current board while keeping the title close locked', () => {
  const send = spyOn(actions, 'sendAct').mockImplementation(() => {});
  try {
    store.set(gameDataAtom, data);
    const { container } = render(<ChromieRouting />);
    expect(screen.getByText('Проверить маршрут')).toBeTruthy();
    expect(screen.getByTitle('Клетка 1')).toBeTruthy();
    expect(
      container.querySelector('.Window')?.getAttribute('data-can-close'),
    ).toBe('false');
    fireEvent.click(screen.getByText('Отменить'));
    expect(send).toHaveBeenLastCalledWith('routing_cancel', {
      attempt: data.attempt,
      phase: data.phase,
    });
  } finally {
    send.mockRestore();
  }
});

it('shows the active relay and opens a reachable machine for commands', () => {
  const send = spyOn(actions, 'sendAct').mockImplementation(() => {});
  try {
    store.set(gameDataAtom, {
      ...data,
      relay_name: 'Узел в коридоре',
      relay_targets: [
        { id: 'console', name: 'Консоль за стеной', authorized: true },
      ],
    });
    render(<ChromieKnight />);
    fireEvent.click(
      screen.getByRole('navigation').querySelectorAll('button')[3],
    );
    expect(screen.getByText('Ретранслятор · Узел в коридоре')).toBeTruthy();
    expect(screen.getByText(/До 4 тайлов от узла/)).toBeTruthy();
    expect(screen.getByText('Консоль за стеной')).toBeTruthy();
    fireEvent.click(screen.getByText('Управление'));
    expect(send).toHaveBeenLastCalledWith('relay_control', {
      target: 'console',
    });
  } finally {
    send.mockRestore();
  }
});

it('keeps the failed-routing cooldown visible outside the puzzle', () => {
  store.set(gameDataAtom, { ...data, board: null, routing_cooldown: 120 });
  render(<ChromieKnight />);
  expect(screen.getByText(/Восстановление маршрутизации: 120 с/)).toBeTruthy();
});

it('shows colored external ports on the board', () => {
  store.set(gameDataAtom, {
    ...data,
    board: Array.from({ length: 49 }, (_, offset) => ({
      ...data.board[0],
      index: offset + 1,
    })),
  });
  render(<ChromieRouting />);
  expect(screen.getByTitle('Вход сигнала слева')).toBeTruthy();
  expect(screen.getByTitle('Выход сигнала справа')).toBeTruthy();
});
it.each([
  ['success', 'Соединение установлено'],
  ['failure', 'Соединение не удалось'],
])('shows the %s result when the server discards the board', (result, title) => {
  store.set(gameDataAtom, {
    ...data,
    routing_result: result,
    board: null,
    routing_cooldown: result === 'failure' ? 80 : 0,
  });
  const { container } = render(<ChromieRouting />);
  expect(screen.getByText(title)).toBeTruthy();
  expect(
    container.querySelector('.Window')?.getAttribute('data-can-close'),
  ).toBe('true');
  expect(screen.getByText('Понятно')).toBeTruthy();
  expect(screen.queryByText('Проверить маршрут')).toBeNull();
});
it('lights only connected pipes with a valid external input and respects diode direction', () => {
  const cell = (index: number, mask: number, output = 0) => ({
    ...data.board[0],
    index,
    mask,
    output,
  });
  expect([...energizedCells([cell(1, 3), cell(11, 3)])]).toEqual([]);
  expect([
    ...energizedCells([cell(1, 12), cell(2, 12, 8), cell(3, 12)]),
  ]).toEqual([1]);
  expect([
    ...energizedCells([cell(1, 12), cell(2, 12, 4), cell(3, 12)]),
  ]).toEqual([1, 2, 3]);
});

it('navigates between device memory and live mech telemetry', () => {
  store.set(gameDataAtom, {
    ...data,
    memory: [{ id: 'r', name: 'Ripley 3', category: 'mech', available: true }],
    pilot_kind: 'civilian',
    pilot_distance: 14,
    pilot_integrity: 78,
    pilot_cost: 1,
  });
  render(<ChromieKnight />);
  fireEvent.click(screen.getByRole('navigation').querySelectorAll('button')[2]);
  expect(screen.getByText('Ripley 3')).toBeTruthy();
  fireEvent.click(screen.getByRole('button', { name: 'Mech Link' }));
  expect(screen.getByText('78%')).toBeTruthy();
  expect(screen.getByText('14 тайл.')).toBeTruthy();
});

it('offers direct bot piloting without an ID and reconnects to learned cameras', () => {
  const send = spyOn(actions, 'sendAct').mockImplementation(() => {});
  try {
    store.set(gameDataAtom, {
      ...data,
      devices: [
        {
          id: 'medbot',
          name: 'Медбот',
          pilot_kind: 'bot',
          slot_access: false,
        },
      ],
      camera_targets: [{ id: 'cam', name: 'Камера ангара', known: true }],
    });
    render(<ChromieKnight />);
    fireEvent.click(screen.getByRole('button', { name: 'Боты' }));
    expect(screen.getByText('Медбот')).toBeTruthy();
    expect(screen.getByText(/Shift \+ ЛКМ по тайлу в игре/)).toBeTruthy();
    fireEvent.click(screen.getByText('Подключить для команд'));
    expect(send).toHaveBeenLastCalledWith('route', {
      target: 'medbot',
      advanced: true,
    });
    fireEvent.click(screen.getByText('Вселиться'));
    expect(send).toHaveBeenLastCalledWith('pilot_bot', { target: 'medbot' });
    fireEvent.click(screen.getByRole('button', { name: 'Camera Network' }));
    fireEvent.click(screen.getByText('Подключиться'));
    expect(send).toHaveBeenLastCalledWith('route', {
      target: 'cam',
      advanced: false,
    });
  } finally {
    send.mockRestore();
  }
});
