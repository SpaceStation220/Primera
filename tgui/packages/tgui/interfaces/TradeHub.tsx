import {
  type KeyboardEvent,
  type ReactNode,
  useId,
  useLayoutEffect,
  useRef,
  useState,
} from 'react';
import { Box, Icon, ProgressBar, Section } from 'tgui-core/components';
import { formatMoney } from 'tgui-core/format';
import { type BooleanLike, classes } from 'tgui-core/react';
import { createSearch } from 'tgui-core/string';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import '../styles/themes/trade-hub.scss';

type Receipt = {
  action: string;
  id: string;
  success: BooleanLike;
  message: string;
  sequence: number;
};

type RewardQuote = {
  id: string;
  name: string;
  rate: number;
  count: number;
  gross: number;
};

type RewardMarketData = {
  cycle: number;
  seconds_left: number;
  quotes: RewardQuote[];
};

type Data = {
  reward_market?: RewardMarketData;
  name: string;
  specialization: string;
  reputation: number | null;
  connected: BooleanLike;
  operational: BooleanLike;
  balance: number;
  cargo_access: BooleanLike;
  cash_balance: number;
  cash_reason: string | null;
  status: string | null;
  receipt?: Receipt | null;
  terminal_reason: string | null;
  input_reason: string | null;
  output_reason: string | null;
  input_ready: BooleanLike;
  output_ready: BooleanLike;
  offers: {
    id: string;
    name: string;
    description: string;
    group: string;
    price: number;
    stock: number;
    capacity: number;
    cash_allowed: BooleanLike;
  }[];
  requests: {
    id: string;
    name: string;
    icon: string;
    group: string | null;
    category: string;
    base_unit_reward: number;
    regular_unit_reward: number;
    price_multiplier: number;
    highDemand: BooleanLike;
    high_demand_bonus: number;
    delivered: number;
    required: number | null;
    remaining: number | null;
    unit_reward: number;
    ready_quantity: number;
    restock_amount: number;
    restock_pending: BooleanLike;
    renewal_pending: BooleanLike;
    waiting_for_power: BooleanLike;
    waiting_for_core: BooleanLike;
    ready_in: number;
    renew_in: number;
  }[];
  contracts?: {
    id: string;
    name: string;
    customer: string;
    target: string;
    credits: number;
  }[];
};

const tabs = [
  { id: 'buy', label: 'Купить' },
  { id: 'sell', label: 'Сдать груз' },
] as const;
type Tab = (typeof tabs)[number]['id'];
type TradeRequest = Data['requests'][number];

export function TradeHub() {
  const { act, data } = useBackend<Data>();
  const { requests = [], contracts = [], reward_market } = data;
  const [selectedPayment, setPayment] = useState<'cash' | 'cargo'>(
    data.cargo_access ? 'cargo' : 'cash',
  );
  const payment = data.cargo_access ? selectedPayment : 'cash';
  const cash = payment === 'cash';
  const balance = cash ? data.cash_balance : data.balance;
  const offers = (data.offers || []).filter(
    (offer) => !cash || offer.cash_allowed,
  );
  const [dismissedSequence, setDismissedSequence] = useState<number>();
  const receipt =
    data.receipt?.sequence === dismissedSequence ? null : data.receipt;
  const [tab, setTab] = useState<Tab>('buy');
  const [searchText, setSearchText] = useState('');
  const [group, setGroup] = useState('');
  const [requestSearch, setRequestSearch] = useState('');
  const [sellView, setSellView] = useState('requests');
  const hasRewards = !!reward_market?.quotes.length;
  const hasContracts = !cash && contracts.length > 0;
  const activeView =
    (sellView === 'rewards' && hasRewards) ||
    (sellView === 'contracts' && hasContracts)
      ? sellView
      : 'requests';
  const nav = useRef<HTMLDivElement>(null);
  const lastAction = useRef<{
    action: TradeCommand;
    id: string;
    button: HTMLButtonElement;
    focused: boolean;
  } | null>(null);
  const lastSequence = useRef(receipt?.sequence);
  const submitTrade: SubmitTrade = (action, id, button, quote) => {
    lastAction.current = {
      action,
      id,
      button,
      focused: document.activeElement === button,
    };
    act(action, { id, payment, ...quote });
  };
  function selectTab(next: Tab) {
    if (next !== tab) lastAction.current = null;
    setTab(next);
  }
  const groups = [...new Set(offers.map((offer) => offer.group))].sort();
  const search = createSearch(searchText, (offer: Data['offers'][number]) =>
    [offer.name, offer.description, offer.group].join(' '),
  );
  const activeGroup = groups.includes(group) ? group : '';
  const filtered = offers.filter(
    (offer) => (!activeGroup || activeGroup === offer.group) && search(offer),
  );
  const findRequest = createSearch(requestSearch, (request: TradeRequest) =>
    [request.name, request.group, request.category].join(' '),
  );
  // A completed delivery stays with the ready rows while its receipt is visible.
  const isReadyOrJustSubmitted = (request: TradeRequest) =>
    request.ready_quantity > 0 ||
    (receipt?.action === 'accept' && receipt.id === request.id);
  const sortedRequests = requests
    .filter(findRequest)
    .sort(
      (a, b) =>
        Number(isReadyOrJustSubmitted(b)) - Number(isReadyOrJustSubmitted(a)),
    );
  const receiptInView =
    receipt &&
    (tab === 'buy'
      ? receipt.action === 'buy' &&
        filtered.some((offer) => offer.id === receipt.id)
      : (activeView === 'requests' &&
          receipt.action === 'accept' &&
          sortedRequests.some((request) => request.id === receipt.id)) ||
        (activeView === 'rewards' &&
          receipt.action === 'sell_reward' &&
          reward_market?.quotes.some((quote) => quote.id === receipt.id)) ||
        (activeView === 'contracts' &&
          receipt.action === 'deliver_contract' &&
          contracts.some((contract) => contract.id === receipt.id)));
  const terminalReason =
    (cash ? data.cash_reason : data.terminal_reason) ||
    (!data.connected ? 'Нет связи с узлом.' : null);
  const outputReason =
    data.output_reason ||
    (!data.output_ready ? 'Площадка выдачи недоступна.' : null);
  const inputReason =
    data.input_reason ||
    (!data.input_ready ? 'Площадка приёма недоступна.' : null);

  const sharedReason =
    terminalReason || (tab === 'buy' ? outputReason : inputReason);
  useLayoutEffect(() => {
    if (!receipt || lastSequence.current === receipt.sequence) return;
    lastSequence.current = receipt.sequence;
    const submitted = lastAction.current;
    if (
      !submitted ||
      submitted.action !== receipt.action ||
      submitted.id !== receipt.id
    )
      return;
    lastAction.current = null;
    const result = document.getElementById('trade-result');
    if (
      !result ||
      (document.activeElement !== submitted.button &&
        document.activeElement !== document.body)
    )
      return;
    if (submitted.focused && !submitted.button.isConnected)
      result.focus({ preventScroll: true });
    const scroller = result.closest('.Layout__content--scrollable');
    if (!scroller) return;
    const viewport = scroller.getBoundingClientRect();
    const row = result.getBoundingClientRect();
    if (row.bottom > viewport.bottom)
      scroller.scrollTop += row.bottom - viewport.bottom;
    else if (row.top < viewport.top)
      scroller.scrollTop += row.top - viewport.top;
  }, [receipt]);

  function navigateTabs(event: KeyboardEvent<HTMLButtonElement>) {
    let next: Tab;
    switch (event.key) {
      case 'ArrowLeft':
      case 'ArrowRight':
        next = tab === 'buy' ? 'sell' : 'buy';
        break;
      case 'Home':
        next = 'buy';
        break;
      case 'End':
        next = 'sell';
        break;
      default:
        return;
    }
    event.preventDefault();
    selectTab(next);
    nav.current
      ?.querySelector<HTMLButtonElement>(`#trade-tab-${next}`)
      ?.focus();
  }

  return (
    <Window title="Торговый узел" width={820} height={660} theme="trade-hub">
      <Window.Content fitted className="TradeHub">
        <div className="TradeHub__toolbar">
          <div role="tablist" aria-label="Торговля" ref={nav}>
            {tabs.map(({ id, label }) => (
              <button
                key={id}
                id={`trade-tab-${id}`}
                type="button"
                role="tab"
                aria-selected={tab === id}
                aria-controls={`trade-panel-${id}`}
                tabIndex={tab === id ? 0 : -1}
                onKeyDown={navigateTabs}
                onClick={() => selectTab(id)}
              >
                {label}
              </button>
            ))}
          </div>
          <label className="TradeHub__payment">
            {tab === 'buy' ? 'Оплата' : 'Получатель'}
            <select
              value={payment}
              onChange={(event) => {
                lastAction.current = null;
                setDismissedSequence(data.receipt?.sequence);
                setGroup('');
                setPayment(
                  event.currentTarget.value === 'cargo' ? 'cargo' : 'cash',
                );
              }}
            >
              <option value="cash">
                {tab === 'buy' ? 'Личные наличные' : 'Вы · голочип'}
              </option>
              <option value="cargo" disabled={!data.cargo_access}>
                Бюджет карго{data.cargo_access ? '' : ' · нужен доступ'}
              </option>
            </select>
          </label>
          {tab === 'buy' && (
            <span className="TradeHub__balance">
              {cash ? 'В руке' : 'Доступно'}{' '}
              <strong>{formatMoney(balance)} кр.</strong>
            </span>
          )}
        </div>
        {sharedReason && (
          <div id="trade-unavailable" className="TradeHub__unavailable">
            {sharedReason}
          </div>
        )}
        <div className="TradeHub__sr-only" role="status" aria-atomic="true">
          {receipt && <span key={receipt.sequence}>{receipt.message}</span>}
        </div>
        {receipt && !receiptInView && <ReceiptMessage receipt={receipt} />}
        {tabs.map(({ id }) => (
          <div
            className="TradeHub__screen"
            key={id}
            role="tabpanel"
            id={`trade-panel-${id}`}
            aria-labelledby={`trade-tab-${id}`}
            hidden={tab !== id}
          >
            {tab === id && (
              <Window.Content scrollable>
                <header className="TradeHub__identity">
                  <div>
                    <h1>{data.name}</h1>
                    <p>{data.specialization}</p>
                  </div>
                  {data.reputation != null && (
                    <div className="TradeHub__reputation">
                      Репутация{' '}
                      <strong>
                        {data.reputation}
                        <small> / 100</small>
                      </strong>
                    </div>
                  )}
                </header>
                {id === 'buy' ? (
                  <Section
                    title="Товары узла"
                    buttons={
                      <span className="TradeHub__count">
                        {filtered.length} из {offers.length}
                      </span>
                    }
                  >
                    <div className="TradeHub__guide">
                      {!sharedReason && <strong>Выдача свободна. </strong>}
                      Заказ появится на площадке выдачи.
                      {cash &&
                        ' Возьмите купюры или голочип в активную руку. Сдачу с купюр получите голочипом.'}
                    </div>
                    <div className="TradeHub__filters">
                      <label>
                        Поиск товара
                        <input
                          type="search"
                          value={searchText}
                          placeholder="Название, описание или группа"
                          onChange={(event) => {
                            lastAction.current = null;
                            setSearchText(event.currentTarget.value);
                          }}
                        />
                      </label>
                      <label>
                        Группа
                        <select
                          value={activeGroup}
                          onChange={(event) => {
                            lastAction.current = null;
                            setGroup(event.currentTarget.value);
                          }}
                        >
                          <option value="">Все группы</option>
                          {groups.map((name) => (
                            <option key={name}>{name}</option>
                          ))}
                        </select>
                      </label>
                      {(!!searchText || !!activeGroup) && (
                        <button
                          type="button"
                          onClick={() => {
                            lastAction.current = null;
                            setSearchText('');
                            setGroup('');
                          }}
                        >
                          Сбросить
                        </button>
                      )}
                    </div>
                    {!offers.length ? (
                      <p className="TradeHub__empty">
                        Узел не продаёт товары при выбранном способе оплаты.
                      </p>
                    ) : !filtered.length ? (
                      <p className="TradeHub__empty">
                        Товары не найдены. Измените запрос или сбросьте фильтры.
                      </p>
                    ) : (
                      <OffersTable
                        offers={filtered}
                        balance={balance}
                        reason={sharedReason}
                        submitTrade={submitTrade}
                        receipt={receipt}
                      />
                    )}
                  </Section>
                ) : (
                  <>
                    <div className="TradeHub__intake">
                      {(hasRewards || hasContracts) && (
                        <label>
                          Раздел приёмки
                          <select
                            value={activeView}
                            onChange={(event) => {
                              lastAction.current = null;
                              setSellView(event.currentTarget.value);
                            }}
                          >
                            <option value="requests">Товары по заявкам</option>
                            {hasRewards && (
                              <option value="rewards">Выкуп наград</option>
                            )}
                            {hasContracts && (
                              <option value="contracts">
                                Экспедиционные контракты
                              </option>
                            )}
                          </select>
                        </label>
                      )}
                      <div className="TradeHub__guide">
                        {!sharedReason && <strong>Приёмка готова. </strong>}
                        {cash
                          ? 'Вы получите голочип. Если руки заняты, чип упадёт у ваших ног.'
                          : 'Начисление поступит в бюджет карго.'}
                      </div>
                    </div>
                    {activeView === 'rewards' && reward_market ? (
                      <RewardMarket
                        market={reward_market}
                        reason={sharedReason}
                        submitTrade={submitTrade}
                        receipt={receipt}
                      />
                    ) : activeView === 'contracts' ? (
                      <ContractsTable
                        contracts={contracts}
                        reason={sharedReason}
                        submitTrade={submitTrade}
                        receipt={receipt}
                      />
                    ) : (
                      <Section
                        title="Заявки узла"
                        buttons={
                          <span className="TradeHub__count">
                            {sortedRequests.length} из {requests.length}
                          </span>
                        }
                      >
                        <p
                          className="TradeHub__guide"
                          id="trade-request-instructions"
                        >
                          Положите товар на площадку приёма или в открытый ящик
                          на ней. Излишки останутся на площадке.
                        </p>
                        <div className="TradeHub__filters">
                          <label>
                            Поиск заявки
                            <input
                              type="search"
                              value={requestSearch}
                              placeholder="Товар, группа или категория"
                              onChange={(event) => {
                                lastAction.current = null;
                                setRequestSearch(event.currentTarget.value);
                              }}
                            />
                          </label>
                          {!!requestSearch && (
                            <button
                              type="button"
                              onClick={() => {
                                lastAction.current = null;
                                setRequestSearch('');
                              }}
                            >
                              Сбросить
                            </button>
                          )}
                        </div>
                        {data.status && (
                          <p className="TradeHub__market-status">
                            {data.status}
                          </p>
                        )}
                        {!requests.length ? (
                          <p className="TradeHub__empty">
                            У узла пока нет заявок.
                          </p>
                        ) : !sortedRequests.length ? (
                          <p className="TradeHub__empty">
                            Заявки не найдены. Измените или сбросьте запрос.
                          </p>
                        ) : (
                          <TradeTable
                            name="Заявки узла"
                            className="TradeHub__requests-table"
                            headings={[
                              'Товар',
                              'К сдаче',
                              'Начисление',
                              'Действие',
                            ]}
                          >
                            {sortedRequests.map((request) => (
                              <RequestRow
                                key={request.id}
                                request={request}
                                reason={sharedReason}
                                submitTrade={submitTrade}
                                receipt={
                                  receipt?.action === 'accept' &&
                                  receipt.id === request.id
                                    ? receipt
                                    : null
                                }
                              />
                            ))}
                          </TradeTable>
                        )}
                      </Section>
                    )}
                  </>
                )}
              </Window.Content>
            )}
          </div>
        ))}
      </Window.Content>
    </Window>
  );
}

function TradeTable({
  name,
  headings,
  children,
  className,
}: {
  name: string;
  headings: string[];
  children: ReactNode;
  className?: string;
}) {
  return (
    <table
      className={classes(['TradeHub__table', className])}
      aria-label={name}
    >
      <thead>
        <tr>
          {headings.map((heading) => (
            <th key={heading} scope="col">
              {heading}
            </th>
          ))}
        </tr>
      </thead>
      {children}
    </table>
  );
}

function ReceiptMessage({ receipt }: { receipt: Receipt }) {
  return (
    <div
      id="trade-result"
      tabIndex={-1}
      className={`TradeHub__receipt ${receipt.success ? 'color-good' : 'color-bad'}`}
    >
      <Icon
        name={receipt.success ? 'check' : 'exclamation-triangle'}
        aria-hidden="true"
      />{' '}
      {receipt.message}
    </div>
  );
}

function TradeAction({
  action,
  id,
  name,
  label,
  reason,
  describedBy,
  sharedReason,
  submitTrade,
}: {
  action: TradeCommand;
  id: string;
  name: string;
  label: string;
  reason: string | null;
  describedBy?: string;
  sharedReason: string | null;
  submitTrade: SubmitTrade;
}) {
  const reasonId = useId();
  return (
    <>
      <button
        type="button"
        aria-label={`${label}: ${name}`}
        aria-disabled={!!sharedReason || !!reason}
        aria-describedby={
          [
            sharedReason && 'trade-unavailable',
            describedBy || (reason && reasonId),
          ]
            .filter(Boolean)
            .join(' ') || undefined
        }
        onClick={(event) => {
          if (!sharedReason && !reason)
            submitTrade(action, id, event.currentTarget);
        }}
      >
        {label}
      </button>
      {reason && !describedBy && (
        <div id={reasonId} className="TradeHub__reason">
          {reason}
        </div>
      )}
    </>
  );
}

function ReceiptRow({
  receipt,
  columns,
}: {
  receipt: Receipt;
  columns: number;
}) {
  return (
    <tr>
      <td colSpan={columns}>
        <ReceiptMessage receipt={receipt} />
      </td>
    </tr>
  );
}

type TradeCommand = 'buy' | 'accept' | 'deliver_contract' | 'sell_reward';
type SubmitTrade = (
  action: TradeCommand,
  id: string,
  button: HTMLButtonElement,
  quote?: { cycle: number; count: number; gross: number },
) => void;
type TradeListProps = {
  reason: string | null;
  receipt?: Receipt | null;
  submitTrade: SubmitTrade;
};

function RewardMarket({
  market,
  reason,
  receipt,
  submitTrade,
}: TradeListProps & { market: RewardMarketData }) {
  const padInstructionId = useId();
  const minutes = Math.floor(market.seconds_left / 60);
  const seconds = String(market.seconds_left % 60).padStart(2, '0');
  return (
    <Section
      title="Выкуп наград"
      buttons={
        <Box color="label">
          До смены курса {minutes}:{seconds}
        </Box>
      }
    >
      <Box id={padInstructionId} color="label" mb={1}>
        Положите награду прямо на площадку приёма. Расшифрованный кэш сдавайте
        невскрытым, вместе с содержимым.
      </Box>
      <TradeTable
        name="Выкуп наград"
        className="TradeHub__reward-table"
        headings={['Награда', 'От экспорта', 'Оценка груза', 'Действие']}
      >
        {market.quotes.map((quote) => (
          <tbody key={quote.id}>
            <tr>
              <th scope="row">{quote.name}</th>
              <td data-label="От экспорта" className="TradeHub__number">
                {quote.rate}%
              </td>
              <td data-label="Оценка груза">
                {quote.count > 0 ? (
                  <>
                    <strong className="TradeHub__number">
                      {formatMoney(quote.gross)} кр.
                    </strong>
                    <small>
                      {quote.count} шт.
                      {quote.id === 'bounty_cube' && ' · до вычета долей'}
                    </small>
                  </>
                ) : (
                  <Box id={`trade-empty-${quote.id}`} color="label">
                    Нет на площадке
                  </Box>
                )}
              </td>
              <td>
                <TradeAction
                  action="sell_reward"
                  id={quote.id}
                  name={quote.name}
                  label="Продать"
                  reason={quote.count ? null : 'Нет на площадке.'}
                  describedBy={
                    quote.count
                      ? padInstructionId
                      : `trade-empty-${quote.id} ${padInstructionId}`
                  }
                  sharedReason={reason}
                  submitTrade={(action, id, button) =>
                    submitTrade(action, id, button, {
                      cycle: market.cycle,
                      count: quote.count,
                      gross: quote.gross,
                    })
                  }
                />
              </td>
            </tr>
            {receipt?.action === 'sell_reward' && receipt.id === quote.id && (
              <ReceiptRow receipt={receipt} columns={4} />
            )}
          </tbody>
        ))}
      </TradeTable>
    </Section>
  );
}

function OffersTable({
  offers,
  balance,
  reason,
  receipt,
  submitTrade,
}: TradeListProps & {
  offers: Data['offers'];
  balance: number;
}) {
  return (
    <TradeTable
      name="Товары узла"
      className="TradeHub__offers-table"
      headings={['Товар', 'Запас', 'Цена за ящик', 'Действие']}
    >
      {offers.map((offer) => {
        const stockId = `trade-stock-${offer.id}`;
        return (
          <tbody key={offer.id}>
            <tr>
              <th scope="row">
                {offer.name}
                <small>{offer.group}</small>
                {!!offer.description && (
                  <details className="TradeHub__detail">
                    <summary>
                      Описание
                      <span className="TradeHub__sr-only">
                        {' '}
                        товара {offer.name}
                      </span>
                    </summary>
                    <small>{offer.description}</small>
                  </details>
                )}
              </th>
              <td data-label="Запас" id={stockId}>
                {offer.stock > 0 ? (
                  <span
                    className="TradeHub__number"
                    title="В наличии / вместимость склада"
                  >
                    {offer.stock} / {offer.capacity}
                  </span>
                ) : (
                  'Распродано'
                )}
              </td>
              <td data-label="Цена за ящик">
                <strong className="TradeHub__number">
                  {formatMoney(offer.price)} кр.
                </strong>
              </td>
              <td>
                <TradeAction
                  action="buy"
                  id={offer.id}
                  name={offer.name}
                  label="Купить"
                  sharedReason={reason}
                  submitTrade={submitTrade}
                  describedBy={offer.stock <= 0 ? stockId : undefined}
                  reason={
                    offer.stock <= 0
                      ? 'Распродано'
                      : balance < offer.price
                        ? `Не хватает ${formatMoney(offer.price - balance)} кр.`
                        : null
                  }
                />
              </td>
            </tr>
            {receipt?.action === 'buy' && receipt.id === offer.id && (
              <ReceiptRow receipt={receipt} columns={4} />
            )}
          </tbody>
        );
      })}
    </TradeTable>
  );
}

function ContractsTable({
  contracts,
  reason,
  receipt,
  submitTrade,
}: TradeListProps & { contracts: NonNullable<Data['contracts']> }) {
  const instructionId = useId();
  if (!contracts.length) return null;
  return (
    <Section title="Контракты экспедиционного корпуса">
      <Box id={instructionId} color="label" mb={1}>
        Поставьте на приём закрытый ящик с находкой. Для аномальной находки
        нужен ящик для образцов.
      </Box>
      <TradeTable
        name="Контракты экспедиционного корпуса"
        className="TradeHub__contracts-table"
        headings={['Контракт', 'Заказчик', 'Награда', 'Действие']}
      >
        {contracts.map((contract) => (
          <tbody key={contract.id}>
            <tr>
              <th scope="row">
                {contract.name}
                <small>
                  {contract.id} · {contract.target}
                </small>
              </th>
              <td data-label="Заказчик">{contract.customer}</td>
              <td data-label="Награда">
                <strong className="TradeHub__number">
                  {formatMoney(contract.credits)} кр.
                </strong>
              </td>
              <td>
                <TradeAction
                  action="deliver_contract"
                  id={contract.id}
                  name={contract.name}
                  label="Сдать"
                  sharedReason={reason}
                  describedBy={instructionId}
                  reason={null}
                  submitTrade={submitTrade}
                />
              </td>
            </tr>
            {receipt?.action === 'deliver_contract' &&
              receipt.id === contract.id && (
                <ReceiptRow receipt={receipt} columns={4} />
              )}
          </tbody>
        ))}
      </TradeTable>
    </Section>
  );
}

function requestPause(request: TradeRequest) {
  if (request.restock_pending || request.renewal_pending) {
    const operation = request.restock_pending ? 'Пополнение' : 'Смена заявки';
    if (request.waiting_for_power) return `${operation} ожидает питания ядра.`;
    if (request.waiting_for_core)
      return `${operation} ожидает восстановления ядра.`;
    const seconds = request.restock_pending
      ? request.ready_in
      : request.renew_in;
    return seconds > 0
      ? `${operation} через ${Math.ceil(seconds)} с.`
      : `${operation} выполняется.`;
  }
  return request.remaining !== null && request.remaining <= 0
    ? 'Квота исчерпана.'
    : null;
}

function RequestRow({
  request,
  reason,
  receipt,
  submitTrade,
}: TradeListProps & { request: TradeRequest }) {
  const pause = requestPause(request);
  const statusId = useId();
  const { required, remaining, ready_quantity: quantity } = request;
  const unavailable =
    pause || (quantity === 0 ? 'Нет подходящего груза.' : null);

  return (
    <tbody>
      <tr>
        <th scope="row">
          <div className="TradeHub__commodity">
            <img
              src={`data:image/png;base64,${request.icon}`}
              alt=""
              width="32"
              height="32"
            />
            <div>
              {request.name}
              <small>
                {required === null ? 'Постоянная закупка' : request.category}
              </small>
              {!!request.highDemand && (
                <small className="color-good">
                  Высокий спрос +{request.high_demand_bonus}%
                </small>
              )}
            </div>
          </div>
        </th>
        <td data-label="К сдаче">
          {unavailable ? (
            <div id={statusId} className="TradeHub__reason">
              {unavailable}
              {!pause && required === null && (
                <small>Нужен открытый пустой ящик.</small>
              )}
            </div>
          ) : (
            <strong className="TradeHub__number">{quantity} ед.</strong>
          )}
          {required === null ? (
            <small>Без лимита</small>
          ) : (
            <details className="TradeHub__detail">
              <summary>Условия партии</summary>
              <small>
                До полной партии —{' '}
                {Math.max(
                  0,
                  Math.min(required - request.delivered, remaining ?? required),
                )}{' '}
                ед.
              </small>
              <div
                role="progressbar"
                aria-label={`Партия: ${request.name}`}
                aria-valuemin={0}
                aria-valuemax={required}
                aria-valuenow={request.delivered}
              >
                <ProgressBar value={request.delivered} maxValue={required}>
                  {request.delivered} из {required} ед.
                </ProgressBar>
              </div>
              <small>Остаток квоты — {remaining} ед.</small>
              <small>
                Полная партия добавит до {request.restock_amount} ящ. каждого
                товара группы «{request.group}», пока на складе есть место.
              </small>
            </details>
          )}
        </td>
        <td data-label="Начисление">
          {!pause && quantity > 0 && (
            <strong className="TradeHub__number">
              {formatMoney(quantity * request.unit_reward)} кр.
            </strong>
          )}
          <small>
            {formatMoney(request.unit_reward)} кр. за{' '}
            {required === null ? 'ящик' : 'ед.'}
          </small>
          {(!!request.highDemand || request.price_multiplier !== 1) && (
            <details className="TradeHub__detail">
              <summary>Расчёт цены</summary>
              <small>
                Базовая ставка — {formatMoney(request.base_unit_reward)} кр.
              </small>
              <small>
                Коэффициент категории ×
                {request.price_multiplier.toLocaleString('ru-RU')}
              </small>
              <small>
                Ваша ставка при обычном спросе —{' '}
                {formatMoney(request.regular_unit_reward)} кр.
              </small>
            </details>
          )}
        </td>
        <td>
          <TradeAction
            action="accept"
            id={request.id}
            name={request.name}
            label="Сдать груз"
            sharedReason={reason}
            reason={unavailable}
            submitTrade={submitTrade}
            describedBy={unavailable ? statusId : 'trade-request-instructions'}
          />
        </td>
      </tr>
      {receipt && <ReceiptRow receipt={receipt} columns={4} />}
    </tbody>
  );
}
