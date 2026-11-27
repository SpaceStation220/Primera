import { afterEach, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import * as actions from 'tgui/events/act';
import { gameDataAtom, resetStore, store } from 'tgui/events/store';
import { CameraConsole220 } from './CameraConsole220';

afterEach(resetStore);
const cameraData = {
  activeCamera: null,
  cameras: [],
  network: ['ss13'],
  mapRef: 'test-map',
  can_spy: false,
  mapData: {
    name: 'MetaStation',
    minFloor: 1,
    mainFloor: 1,
    maxFloor: 1,
    lavalandLevel: 3,
    stairs: [],
  },
};
it('offers only the gateways supplied by the neural server and requests a standard hop', () => {
  const send = spyOn(actions, 'sendAct').mockImplementation(() => {});
  try {
    store.set(gameDataAtom, {
      ...cameraData,
      neural_routes: [{ name: 'B', ref: 'camera-b' }],
      neural_hops: 1,
      neural_cost: 1.5,
    });
    render(<CameraConsole220 />);
    fireEvent.click(screen.getByText('Стандартная маршрутизация: B'));
    expect(send).toHaveBeenLastCalledWith('neural_route', {
      camera: 'camera-b',
    });
    expect(screen.getByText(/переходов 1/)).toBeTruthy();
  } finally {
    send.mockRestore();
  }
});
it('keeps ordinary security consoles free of neural routing controls', () => {
  store.set(gameDataAtom, cameraData);
  render(<CameraConsole220 />);
  expect(screen.queryByText(/Нейронная сеть/)).toBeNull();
});
