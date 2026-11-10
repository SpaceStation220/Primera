import { afterEach, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import * as actions from 'tgui/events/act';
import { gameDataAtom, resetStore, store } from 'tgui/events/store';
import { AntagCoinCard } from './AntagCoinCard';

afterEach(() => resetStore());

it('keeps the locked card clickable so the server can explain the tier requirement', () => {
  const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
  try {
    store.set(gameDataAtom, {
      antag_coin: {
        tier_five: false,
        lobby: true,
        remaining: 0,
        pending: false,
        approved: false,
      },
    });
    render(<AntagCoinCard />);
    const card = screen.getByRole('button', { name: 'Антаг коин' });
    expect(card.getAttribute('aria-disabled')).toBe('true');
    expect(screen.getByText('Требуется Tier 5')).toBeTruthy();
    fireEvent.click(card);
    expect(sendAct).toHaveBeenLastCalledWith('antag_coin_open');
  } finally {
    sendAct.mockRestore();
  }
});

it('opens the available coin without toggling antagonist preferences', () => {
  const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
  try {
    store.set(gameDataAtom, {
      antag_coin: {
        tier_five: true,
        lobby: true,
        remaining: 0,
        pending: false,
        approved: false,
      },
    });
    render(<AntagCoinCard />);
    const card = screen.getByRole('button', { name: 'Антаг коин' });
    expect(card.getAttribute('aria-disabled')).toBe('false');
    fireEvent.click(card);
    expect(sendAct).toHaveBeenLastCalledWith('antag_coin_open');
    expect(sendAct.mock.calls.some(([action]) => action === 'set_antags')).toBe(
      false,
    );
  } finally {
    sendAct.mockRestore();
  }
});

it('shows cooldown hours and allows a click to request the exact time in chat', () => {
  const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
  try {
    store.set(gameDataAtom, {
      antag_coin: {
        tier_five: true,
        lobby: true,
        remaining: 168 * 3600,
        pending: false,
        approved: false,
      },
    });
    render(<AntagCoinCard />);
    expect(screen.getByText('168 ч.')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Антаг коин' }));
    expect(sendAct).toHaveBeenLastCalledWith('antag_coin_open');
  } finally {
    sendAct.mockRestore();
  }
});
