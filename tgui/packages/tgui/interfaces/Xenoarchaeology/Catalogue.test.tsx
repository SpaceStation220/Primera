import { afterEach, describe, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import * as actions from '../../events/act';
import { resetStore } from '../../events/store';

import {
  type CatalogueData,
  type CatalogueEntry,
  XenoarchCatalogue,
} from './Catalogue';

function catalogue(patch: Partial<CatalogueEntry> = {}): CatalogueData {
  return {
    reward: 20,
    titleLimit: 64,
    notesLimit: 1024,
    printReady: true,
    entries: [
      {
        id: 'КСА-1',
        artifactName: 'Инопланетный артефакт',
        title: 'Находка',
        report: 'Состав: неизвестный сплав.',
        analyzedAt: '00:10:00',
        excavationId: 'Каппа-1234',
        age: 1000,
        notes: '',
        revision: 0,
        editedBy: null,
        registeredBy: null,
        registeredAt: null,
        rewardClaimed: false,
        ...patch,
      },
    ],
  };
}

const machine = { operational: true, research: 0, maxResearch: 300 };
afterEach(resetStore);

describe('Xenoarchaeology catalogue editor', () => {
  it('accepts its own normalized title and allows registration', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const { rerender } = render(
        <XenoarchCatalogue {...machine} catalogue={catalogue()} />,
      );
      fireEvent.change(screen.getByLabelText('Название записи'), {
        target: { value: '  Название находки  ' },
      });
      fireEvent.click(screen.getByText('Сохранить наблюдения'));
      rerender(
        <XenoarchCatalogue
          {...machine}
          catalogue={catalogue({ title: 'Название находки', revision: 1 })}
        />,
      );
      expect(
        !!screen.queryByText(/Запись изменена другим исследователем/),
      ).toBe(false);
      fireEvent.click(screen.getByText('Подписать и зарегистрировать'));
      expect(sendAct).toHaveBeenLastCalledWith('catalogue_register', {
        id: 'КСА-1',
      });
    } finally {
      sendAct.mockRestore();
    }
  });

  it('keeps the selected draft when a new analysis adds another passport', () => {
    const { rerender } = render(
      <XenoarchCatalogue {...machine} catalogue={catalogue()} />,
    );
    fireEvent.change(screen.getByLabelText('Наблюдения исследователя'), {
      target: { value: 'Не терять черновик' },
    });
    const updated = catalogue();
    updated.entries.push({
      ...updated.entries[0],
      id: 'КСА-2',
      title: 'Новое',
    });
    rerender(<XenoarchCatalogue {...machine} catalogue={updated} />);
    expect(screen.getByDisplayValue('Не терять черновик')).toBeDefined();
  });

  it('keeps a local draft and blocks overwriting a newer observation', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const { rerender } = render(
        <XenoarchCatalogue {...machine} catalogue={catalogue()} />,
      );
      fireEvent.change(screen.getByLabelText('Наблюдения исследователя'), {
        target: { value: 'Мой черновик' },
      });
      rerender(
        <XenoarchCatalogue
          {...machine}
          catalogue={catalogue({ notes: 'Запись коллеги', revision: 1 })}
        />,
      );
      expect(screen.getByDisplayValue('Мой черновик')).toBeDefined();
      fireEvent.click(screen.getByText('Сохранить наблюдения'));
      expect(sendAct).not.toHaveBeenCalled();
      fireEvent.click(screen.getByText('Загрузить актуальную запись'));
      expect(screen.getByDisplayValue('Запись коллеги')).toBeDefined();
      fireEvent.change(screen.getByLabelText('Наблюдения исследователя'), {
        target: { value: 'Дополнение' },
      });
      fireEvent.click(screen.getByText('Сохранить наблюдения'));
      expect(sendAct).toHaveBeenCalledWith('catalogue_save', {
        id: 'КСА-1',
        title: 'Находка',
        notes: 'Дополнение',
        revision: 1,
      });
    } finally {
      sendAct.mockRestore();
    }
  });

  it('uses the acknowledged server revision for the next edit', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const { rerender } = render(
        <XenoarchCatalogue {...machine} catalogue={catalogue()} />,
      );
      fireEvent.change(screen.getByLabelText('Наблюдения исследователя'), {
        target: { value: 'Первое наблюдение' },
      });
      fireEvent.click(screen.getByText('Сохранить наблюдения'));
      rerender(
        <XenoarchCatalogue
          {...machine}
          catalogue={catalogue({ notes: 'Первое наблюдение', revision: 1 })}
        />,
      );
      fireEvent.change(screen.getByLabelText('Наблюдения исследователя'), {
        target: { value: 'Второе наблюдение' },
      });
      fireEvent.click(screen.getByText('Сохранить наблюдения'));
      expect(sendAct).toHaveBeenLastCalledWith('catalogue_save', {
        id: 'КСА-1',
        title: 'Находка',
        notes: 'Второе наблюдение',
        revision: 1,
      });
    } finally {
      sendAct.mockRestore();
    }
  });
});
