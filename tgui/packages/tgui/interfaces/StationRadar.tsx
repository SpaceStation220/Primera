import { useState } from 'react';
import { Icon } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import { Chart } from './SpaceNavigation/Chart';
import { ZoomKnob } from './SpaceNavigation/DisplayArt';
import {
  type ChartData,
  contactName,
  distanceLabel,
  speedLabel,
} from './SpaceNavigation/types';

type RadarData = ChartData & {
  scan_ready: BooleanLike;
  scan_cooldown: number;
};

export function StationRadar() {
  const { data } = useBackend<Partial<RadarData>>();

  return (
    <Window width={960} height={600}>
      <Window.Content>
        {data.sector ? (
          <RadarDisplay key={data.sector} />
        ) : (
          <main className="SpaceNavigation StationRadar--offline">
            <p className="SpaceNavigation__help" role="status">
              Нет связи с радаром станции
            </p>
          </main>
        )}
      </Window.Content>
    </Window>
  );
}

function RadarDisplay() {
  const { data, act } = useBackend<RadarData>();
  const [zoom, setZoom] = useState(1);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const activeContact = data.ship_contacts.find(
    (contact) => contact.id === selectedId,
  );
  const contacts = data.ship_contacts.map((contact) => ({
    contact,
    distance: Math.hypot(data.x - contact.x, data.y - contact.y),
  }));
  const selectContact = (id: number) => {
    setSelectedId((selected) => (selected === id ? null : id));
  };
  const range = distanceLabel(data.sensor_range, data.au_scale);
  const cooldown = Math.ceil(data.scan_cooldown);
  let scanLabel = 'Сканировать';
  if (!data.scan_ready) {
    scanLabel =
      cooldown > 0 ? `Перезарядка · ${cooldown} с` : 'Скан недоступен';
  }

  return (
    <main className="SpaceNavigation StationRadar">
      <header>
        <div className="SpaceNavigation__nameplate">
          <strong>{data.vessel_name}</strong>
          <span>СТАНЦИОННЫЙ РАДАР</span>
        </div>
        <ZoomKnob zoom={zoom} onChange={setZoom} />
      </header>
      <div className="StationRadar__body">
        <section className="SpaceNavigation__plot" aria-label="Карта сектора">
          <div className="SpaceNavigation__screen-label">
            {data.sector_name}
          </div>
          <Chart
            station
            data={data}
            zoom={zoom}
            hoveredTarget={null}
            focusedContact={activeContact?.id ?? null}
            onContact={selectContact}
          />
          <div className="SpaceNavigation__legend StationRadar__footer">
            <span>Дальность импульса · {range}</span>
            <button
              type="button"
              className="Button"
              disabled={!data.scan_ready}
              onClick={() => act('scan')}
            >
              <Icon name="satellite-dish" />
              {scanLabel}
            </button>
          </div>
        </section>
        <aside
          className="SpaceNavigation__contacts"
          aria-label="Контакты радара"
        >
          <div className="SpaceNavigation__screen-label">
            <span>КОНТАКТЫ</span>
            <span>{contacts.length}</span>
          </div>
          {contacts.length ? (
            <ul className="StationRadar__contacts">
              {contacts.map(({ contact, distance }) => (
                <li key={contact.id}>
                  <button
                    type="button"
                    className="Button"
                    aria-pressed={contact.id === activeContact?.id}
                    onClick={() => selectContact(contact.id)}
                  >
                    <span className="StationRadar__contact">
                      <span className="StationRadar__contact-id">
                        К{contact.id}
                      </span>
                      <strong>{contactName(contact)}</strong>
                      <span>{distanceLabel(distance, data.au_scale)}</span>
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          ) : (
            <p className="SpaceNavigation__help">Контакты не обнаружены</p>
          )}
          {activeContact && (
            <dl className="StationRadar__details" aria-label="Данные контакта">
              <dt>Регистрация</dt>
              <dd>{activeContact.identity?.faction || 'Нет ответа'}</dd>
              {activeContact.vx !== undefined &&
                activeContact.vy !== undefined && (
                  <>
                    <dt>Скорость</dt>
                    <dd>
                      {speedLabel(
                        Math.hypot(activeContact.vx, activeContact.vy),
                        data.au_scale,
                      )}
                    </dd>
                  </>
                )}
              <dt>Последний сигнал</dt>
              <dd>{Math.floor(activeContact.age)} с назад</dd>
            </dl>
          )}
        </aside>
      </div>
    </main>
  );
}
