import { useRef, useState } from 'react';
import { Icon } from 'tgui-core/components';
import { formatMoney } from 'tgui-core/format';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import '../styles/themes/trade-hub.scss';

type TradeRequest = {
  id: string;
  name: string;
  status: 'open' | 'restocking' | 'renewing';
  quantity: number | null;
  unit_reward?: number;
  high_demand?: BooleanLike;
  rate_percent?: number;
  rate_seconds_left?: number;
};

type TradeOffer = {
  id: string;
  name: string;
  group: string;
  stock: number;
  price: number;
};

type TradeHub = {
  id: string;
  name: string;
  specialization?: string;
  reputation: number;
  input_problem: string | null;
  output_problem: string | null;
  offers: TradeOffer[];
  requests: TradeRequest[];
};

type TradeReport = {
  sector: string | null;
  hubs: TradeHub[] | null;
  age_seconds: number | null;
  refresh_seconds: number;
};

function clock(seconds: number) {
  const minutes = Math.floor(seconds / 60);
  return `${minutes}:${String(seconds % 60).padStart(2, '0')}`;
}

function acceptance(request: TradeRequest, hubUnavailable: boolean) {
  if (hubUnavailable) {
    return 'Приём закрыт';
  }
  if (request.status === 'renewing') {
    return 'Смена заявки';
  }
  if (request.status === 'restocking') {
    return 'Партия принята';
  }
  return request.quantity === null ? 'Без лимита' : `${request.quantity} ед.`;
}

export function SectorTradeMonitor() {
  const { act, data } = useBackend<TradeReport>();
  const { sector, hubs, age_seconds, refresh_seconds } = data;
  const [query, setQuery] = useState('');
  const [hubId, setHubId] = useState('');
  const [showOffers, setShowOffers] = useState(false);
  const searchInput = useRef<HTMLInputElement>(null);
  const reportBody = useRef<HTMLDivElement>(null);
  const selectedHub = hubs?.find((hub) => hub.id === hubId);
  const search = query.trim().toLocaleLowerCase('ru');
  const matches = (text: string) =>
    text.toLocaleLowerCase('ru').includes(search);
  const matchingHubs = (selectedHub ? [selectedHub] : (hubs ?? [])).flatMap(
    (hub) => {
      const allRows =
        !search || matches(hub.name) || matches(hub.specialization ?? '');
      const offers = showOffers
        ? hub.offers.filter(
            (row) => allRows || matches(row.name) || matches(row.group),
          )
        : [];
      const requests = showOffers
        ? []
        : hub.requests.filter((row) => allRows || matches(row.name));
      return offers.length || requests.length
        ? [{ hub, offers, requests }]
        : [];
    },
  );

  function rewindReport() {
    if (reportBody.current) reportBody.current.scrollTop = 0;
  }

  return (
    <Window
      title="Торговая сводка сектора"
      width={670}
      height={570}
      theme="trade-hub"
    >
      <Window.Content fitted className="SectorTradeMonitor">
        <header className="SectorTradeMonitor__toolbar">
          <div className="SectorTradeMonitor__masthead">
            <div>
              <h1>{sector ?? 'Сектор недоступен'}</h1>
              {sector && (
                <small>
                  {age_seconds == null
                    ? 'Сводка ещё не получена'
                    : `Сводка получена ${clock(age_seconds)} назад`}
                </small>
              )}
            </div>
            <button
              type="button"
              disabled={!sector || refresh_seconds > 0}
              onClick={() => act('refresh')}
            >
              <Icon aria-hidden="true" name="rotate" />{' '}
              {age_seconds == null
                ? 'Запросить сводку'
                : refresh_seconds > 0
                  ? `Обновить через ${clock(refresh_seconds)}`
                  : 'Обновить сводку'}
            </button>
          </div>
          {!!hubs?.length && (
            <>
              <div
                className="SectorTradeMonitor__directions"
                role="group"
                aria-label="Сторона сделки"
              >
                <button
                  type="button"
                  aria-pressed={!showOffers}
                  onClick={() => {
                    setShowOffers(false);
                    rewindReport();
                  }}
                >
                  Узлы покупают
                </button>
                <button
                  type="button"
                  aria-pressed={showOffers}
                  onClick={() => {
                    setShowOffers(true);
                    rewindReport();
                  }}
                >
                  Узлы продают
                </button>
              </div>
              <div className="SectorTradeMonitor__filters">
                <label className="SectorTradeMonitor__search">
                  <Icon aria-hidden="true" name="magnifying-glass" />
                  <input
                    ref={searchInput}
                    type="search"
                    aria-label="Поиск по товару, узлу или фракции"
                    placeholder="Товар, узел или фракция"
                    value={query}
                    onChange={(event) => {
                      setQuery(event.currentTarget.value);
                      rewindReport();
                    }}
                  />
                </label>
                <select
                  aria-label="Торговый узел"
                  value={selectedHub?.id ?? ''}
                  onChange={(event) => {
                    setHubId(event.currentTarget.value);
                    rewindReport();
                  }}
                >
                  <option value="">Все узлы</option>
                  {hubs.map((hub) => (
                    <option key={hub.id} value={hub.id}>
                      {hub.name}
                    </option>
                  ))}
                </select>
              </div>
            </>
          )}
        </header>
        <div className="SectorTradeMonitor__body" ref={reportBody}>
          {!sector ? (
            <p>Нет связи с сектором станции. Проверьте консоль позже.</p>
          ) : age_seconds == null ? (
            <p>Запросите сводку, чтобы увидеть спрос и ассортимент узлов.</p>
          ) : !hubs?.length ? (
            <p>В секторе нет торговых узлов, передавших сводку.</p>
          ) : !matchingHubs.length ? (
            <div className="SectorTradeMonitor__empty">
              <p>
                {search
                  ? 'По этому запросу ничего не найдено.'
                  : 'Доступных позиций нет.'}
              </p>
              {(search || selectedHub) && (
                <button
                  type="button"
                  onClick={() => {
                    setQuery('');
                    setHubId('');
                    searchInput.current?.focus();
                  }}
                >
                  Сбросить фильтры
                </button>
              )}
            </div>
          ) : (
            <table aria-label={showOffers ? 'Узлы продают' : 'Узлы покупают'}>
              <thead>
                <tr>
                  <th scope="col">Товар</th>
                  <th scope="col">{showOffers ? 'Поставок' : 'К приёму'}</th>
                  <th scope="col">
                    {showOffers ? 'Цена поставки' : 'Выплата'}
                  </th>
                </tr>
              </thead>
              {matchingHubs.map(({ hub, offers, requests }) => {
                const problem = showOffers
                  ? hub.output_problem
                  : hub.input_problem;
                return (
                  <tbody key={hub.id}>
                    <tr className="SectorTradeMonitor__hub">
                      <th colSpan={3} scope="rowgroup">
                        <div
                          className="SectorTradeMonitor__hubName"
                          title={hub.specialization}
                        >
                          <strong>{hub.name}</strong>
                          <span>
                            Ваша репутация <b>{hub.reputation}</b>/100
                          </span>
                        </div>
                        {problem && (
                          <small className="SectorTradeMonitor__warning">
                            <Icon
                              aria-hidden="true"
                              name="triangle-exclamation"
                            />{' '}
                            {problem}
                          </small>
                        )}
                      </th>
                    </tr>
                    {offers.map((offer) => (
                      <tr
                        key={offer.id}
                        className={
                          offer.stock === 0 || problem
                            ? 'SectorTradeMonitor__unavailable'
                            : undefined
                        }
                      >
                        <th scope="row">
                          {offer.name}
                          <small>{offer.group}</small>
                        </th>
                        <td>
                          {offer.stock === 0 ? 'Нет в наличии' : offer.stock}
                        </td>
                        <td>{formatMoney(offer.price)} кр.</td>
                      </tr>
                    ))}
                    {requests.map((request) => {
                      const expired =
                        request.rate_percent !== undefined &&
                        age_seconds >= (request.rate_seconds_left ?? 0);
                      return (
                        <tr
                          key={request.id}
                          className={
                            problem || expired || request.status !== 'open'
                              ? 'SectorTradeMonitor__unavailable'
                              : undefined
                          }
                        >
                          <th scope="row">
                            {request.name}
                            {!!request.high_demand && (
                              <small className="SectorTradeMonitor__premium">
                                Высокий спрос
                              </small>
                            )}
                          </th>
                          <td>{acceptance(request, !!problem)}</td>
                          <td>
                            {request.rate_percent === undefined ? (
                              `${formatMoney(request.unit_reward ?? 0)} кр./ед.`
                            ) : (
                              <>
                                {request.rate_percent}%
                                <small>от экспорта</small>
                                {expired && (
                                  <small className="SectorTradeMonitor__warning">
                                    Курс истёк
                                  </small>
                                )}
                              </>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                );
              })}
            </table>
          )}
        </div>
      </Window.Content>
    </Window>
  );
}
