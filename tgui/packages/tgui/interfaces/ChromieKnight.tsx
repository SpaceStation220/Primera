import '../styles/interfaces/ChromieKnight.scss';

import { useState } from 'react';
import {
  Box,
  Button,
  Dimmer,
  Icon,
  Input,
  Section,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  remote_enabled: boolean;
  active_devices: number;
  command_bots?: { id: string; name: string; selected: boolean }[];
  routing_result?: 'success' | 'failure';
  linked_bot_pilot?: string;
  pilot_instructions?: string;
  multitool_enabled?: boolean;
  relay_name?: string;
  relay_targets?: { id: string; name: string; authorized?: boolean }[];
  camera_targets?: { id: string; name: string; known: boolean }[];
  charge: number;
  temperature: number;
  memory: {
    id: string;
    name: string;
    available: boolean;
    category?: string;
    active?: boolean;
    reachable?: boolean;
    target?: string;
    pilot_kind?: string;
  }[];
  advanced?: boolean;
  pilot_kind?: string;
  pilot_distance?: number;
  pilot_integrity?: number;
  pilot_cost?: number;
  machine_link?: boolean;
  camera_network?: string[];
  buffer_name?: string;
  scanner_targets: { id: string; name: string }[];
  scan_cost: number;
  last_scan?: { name: string; integrity?: number; powered?: boolean };
  devices: {
    id: string;
    name: string;
    online: boolean;
    slot_access: boolean;
    known: boolean;
    pilot_kind?: 'civilian' | 'combat' | 'secbot' | 'bot';
    access_left: number;
    commands: { id: string; name: string }[];
  }[];
  board?: RoutingCell[] | null;
  attempt: number;
  phase: number;
  routing_left: number;
  routing_cooldown: number;
  command_cooldown: number;
  connected?: string;
  message?: string;
};

type RoutingCell = {
  index: number;
  mask: number;
  blocked: boolean;
  locked: boolean;
  output: number;
  required: boolean;
};

export const energizedCells = (
  board: RoutingCell[] = [],
  size = Number.isInteger(Math.sqrt(board.length)) && board.length > 1
    ? Math.sqrt(board.length)
    : 10,
) => {
  const cells = new Map(board.map((cell) => [cell.index, cell]));
  const reached = new Set<number>();
  const queue = cells.get(1)?.mask && cells.get(1)!.mask & 8 ? [1] : [];
  while (queue.length) {
    const index = queue.shift()!;
    if (reached.has(index)) continue;
    const cell = cells.get(index);
    if (!cell || cell.blocked) continue;
    reached.add(index);
    for (const [bit, opposite, offset] of [
      [1, 2, -size],
      [2, 1, size],
      [4, 8, 1],
      [8, 4, -1],
    ]) {
      if (!(cell.mask & bit) || (cell.output && cell.output !== bit)) continue;
      if (
        (bit === 4 && index % size === 0) ||
        (bit === 8 && index % size === 1)
      )
        continue;
      const next = cells.get(index + offset);
      if (
        next &&
        !next.blocked &&
        next.mask & opposite &&
        next.output !== opposite
      )
        queue.push(next.index);
    }
  }
  return reached;
};

export const RoutingGrid = () => {
  const { act, data } = useBackend<Data>();
  if (data.routing_result) {
    const success = data.routing_result === 'success';
    return (
      <Dimmer>
        <Section
          className="ChromieKnight__result"
          title={success ? 'Соединение установлено' : 'Соединение не удалось'}
        >
          <Box mb={2}>
            {success
              ? 'Маршрут принят. Доступ к устройству готов.'
              : data.routing_cooldown > 0
                ? `Маршрутизация сорвана. До новой попытки: ${data.routing_cooldown} с.`
                : 'Устройство не приняло соединение.'}
          </Box>
          <Button onClick={() => act('routing_dismiss')}>Понятно</Button>
        </Section>
      </Dimmer>
    );
  }
  const board = data.board;
  if (!board?.length) return null;

  const powered = energizedCells(board);
  const angles: Record<number, number> = { 1: 0, 4: 90, 2: 180, 8: 270 };
  const directions = [
    { bit: 1, x: 20, y: 0 },
    { bit: 2, x: 20, y: 40 },
    { bit: 4, x: 40, y: 20 },
    { bit: 8, x: 0, y: 20 },
  ];
  return (
    <Section
      className={data.advanced ? 'ck-advanced' : undefined}
      title={`Neural Routing · ${data.advanced ? 'Advanced Link' : 'Стандарт'} · фаза ${data.phase} · ${data.routing_left} с`}
    >
      <Box mb={1}>
        Вход слева в верхней клетке → выход справа в нижней. Нажмите, чтобы
        повернуть сегмент. × — повреждение; ● — обязательный узел; стрелка —
        односторонний выход. Закреплённые сегменты не вращаются.
      </Box>
      <div
        className="ChromieKnight__grid"
        style={{
          gridTemplateColumns: `repeat(${Math.sqrt(board.length)}, minmax(0, 1fr))`,
        }}
      >
        {board.map((cell) => (
          <button
            key={cell.index}
            type="button"
            className={`ChromieKnight__cell ${cell.blocked ? 'is-blocked' : ''} ${cell.locked ? 'is-locked' : ''} ${powered.has(cell.index) ? 'is-powered' : ''}`}
            disabled={!!cell.blocked || !!cell.locked}
            title={`Клетка ${cell.index}${cell.locked ? ', закреплена' : ''}${cell.required ? ', обязательный узел' : ''}`}
            onClick={() =>
              act('routing_rotate', {
                attempt: data.attempt,
                phase: data.phase,
                index: cell.index,
              })
            }
          >
            {cell.index === 1 && (
              <span
                className="ChromieKnight__port is-entry"
                title="Вход сигнала слева"
              />
            )}
            {cell.index === board.length && (
              <span
                className="ChromieKnight__port is-exit"
                title="Выход сигнала справа"
              />
            )}
            <svg viewBox="0 0 40 40" aria-hidden="true">
              {(cell.index === 1 || cell.index === board.length) && (
                <circle
                  cx="20"
                  cy="20"
                  r="9"
                  fill="none"
                  style={{
                    stroke: cell.index === 1 ? '#67e59b' : '#ff9a9a',
                    strokeWidth: 3,
                  }}
                />
              )}
              {!cell.blocked &&
                directions.map((dir) =>
                  cell.mask & dir.bit ? (
                    <line key={dir.bit} x1="20" y1="20" x2={dir.x} y2={dir.y} />
                  ) : null,
                )}
              {cell.blocked ? (
                <text x="20" y="28" textAnchor="middle">
                  ×
                </text>
              ) : cell.required ? (
                <circle className="is-required" cx="20" cy="20" r="6" />
              ) : null}
              {!!cell.output && (
                <polygon
                  points="20,5 15,15 25,15"
                  transform={`rotate(${angles[cell.output] ?? 0} 20 20)`}
                />
              )}
            </svg>
          </button>
        ))}
      </div>
      <Box mt={1}>
        <Button
          icon="check"
          onClick={() =>
            act('routing_submit', { attempt: data.attempt, phase: data.phase })
          }
        >
          Проверить маршрут
        </Button>
        <Button
          onClick={() =>
            act('routing_cancel', { attempt: data.attempt, phase: data.phase })
          }
        >
          Отменить
        </Button>
      </Box>
    </Section>
  );
};

const modules = [
  'Обзор',
  'Neural Routing',
  'Device Memory',
  'Remote Control',
  'Camera Network',
  'Боты',
  'Mech Link',
  'Neural Multitool',
  'Sensor Suite',
] as const;
const categories = {
  bot: 'Боты',
  mech: 'Мехи',
  camera: 'Камеры',
  machine: 'Прочая техника',
};

export const ChromieKnight = () => {
  const { act, data } = useBackend<Data>();
  const [cameraQuery, setCameraQuery] = useState('');
  const [page, setPage] = useState<(typeof modules)[number]>('Обзор');
  const is = (name: typeof page) => page === name;
  const pilotBots = data.devices.filter(
    (device) => device.pilot_kind === 'secbot' || device.pilot_kind === 'bot',
  );
  const possessBot = (target: string) => act('pilot_bot', { target });
  const memory = (kind: string) => {
    const rows = data.memory.filter((r) => (r.category ?? 'machine') === kind);
    return (
      <section key={kind} className="ck-group">
        <h3>
          {categories[kind as keyof typeof categories]}{' '}
          <small>{rows.length}</small>
        </h3>
        {rows.length === 0 && <Box color="label">Память пуста</Box>}
        {rows.map((r) => (
          <div className="ck-row" key={r.id}>
            <b>{r.name}</b>
            <span>
              {r.active
                ? 'На связи'
                : r.reachable
                  ? 'В зоне связи'
                  : r.available
                    ? 'Вне зоны'
                    : 'Утрачен'}
            </span>
            <span>
              {r.reachable && !r.active && r.pilot_kind !== 'secbot' && (
                <Button
                  onClick={() =>
                    act('route', {
                      target: r.target,
                      advanced: r.pilot_kind === 'combat',
                    })
                  }
                >
                  {kind === 'bot' ? 'Подключить для команд' : 'Подключить'}
                </Button>
              )}
              {!!r.target && pilotBots.some((bot) => bot.id === r.target) && (
                <Button onClick={() => possessBot(r.target!)}>Вселиться</Button>
              )}
            </span>
          </div>
        ))}
      </section>
    );
  };
  return (
    <Window width={820} height={700} title="ChromieКnight 4.4">
      <Window.Content scrollable className="ChromieKnight">
        <header className="ck-head">
          <div>
            <small>КИБЕРЛИНК / ПОКОЛЕНИЕ IV</small>
            <h1>
              ChromieКnight <em>4.4</em>
            </h1>
          </div>
          <span className={data.connected ? 'ck-online' : ''}>
            ● {data.connected || 'Канал свободен'}
          </span>
        </header>
        <div className="ck-meters">
          <div>
            Заряд корпуса<b>{data.charge}%</b>
          </div>
          <div>
            Температура<b>{data.temperature} °C</b>
          </div>
          <div>
            Основной канал<b>{data.connected ? 'Занят' : 'Свободен'}</b>
          </div>
          <div>
            Устройств на связи<b>{data.active_devices}</b>
          </div>
          <div>
            Удалённое управление<b>{data.remote_enabled ? 'ON' : 'OFF'}</b>
          </div>
        </div>
        <div className="ck-work">
          <nav aria-label="Модули">
            {modules.map((m) => (
              <button
                type="button"
                key={m}
                aria-current={is(m) ? 'page' : undefined}
                onClick={() => setPage(m)}
              >
                {m}
              </button>
            ))}
          </nav>
          <main>
            <h2>{page}</h2>
            {data.routing_cooldown > 0 && (
              <Box color="average">
                Восстановление маршрутизации: {data.routing_cooldown} с
              </Box>
            )}
            {data.message && <Box mb={1}>{data.message}</Box>}
            {data.connected && (
              <Section title={data.connected}>
                {!!data.machine_link && (
                  <Button onClick={() => act('connected_control')}>
                    Управление устройством
                  </Button>
                )}
                {!!data.linked_bot_pilot && (
                  <Button onClick={() => possessBot(data.linked_bot_pilot!)}>
                    Вселиться в бота
                  </Button>
                )}
                {data.pilot_instructions && (
                  <Box mb={1}>{data.pilot_instructions}</Box>
                )}
                {data.routing_left <= 0 && (
                  <Button onClick={() => act('disconnect')}>
                    {data.pilot_kind ? 'Вернуться в корпус' : 'Разорвать связь'}
                  </Button>
                )}
              </Section>
            )}
            {is('Обзор') && (
              <>
                <div className="ck-cards">
                  {(
                    [
                      'Neural Routing',
                      'Device Memory',
                      'Sensor Suite',
                      'Remote Control',
                    ] as const
                  ).map((m, i) => (
                    <button key={m} onClick={() => setPage(m)}>
                      <Icon
                        name={
                          (
                            [
                              'route',
                              'database',
                              'satellite-dish',
                              'sliders',
                            ] as const
                          )[i]
                        }
                      />
                      <b>{m}</b>
                      <span>
                        {
                          [
                            'Стандартный и продвинутый маршруты',
                            `${data.memory.length} устройств в памяти`,
                            data.scanner_targets.length +
                              ' целей в радиусе сканера',
                            '+25 °C за успешную команду',
                          ][i]
                        }
                      </span>
                    </button>
                  ))}
                </div>
                <Section title="Быстрые команды">
                  <Box>Shift + ЛКМ — открыть панель или шлюз.</Box>
                  <Box>Shift + ЛКМ по тайлу — отправить выбранного бота.</Box>
                  <Box>
                    Alt + ЛКМ / Alt + Shift + ЛКМ — стандартный / продвинутый
                    маршрут.
                  </Box>
                  <Box>● — обязательный узел маршрута.</Box>
                </Section>
              </>
            )}
            {is('Neural Routing') && (
              <Section title="Подключение к устройству">
                <Box>Shift + ЛКМ — открыть / закрыть шлюз.</Box>
                <Box>
                  Ctrl + ЛКМ по шлюзу — переключить болты (нужен расширенный
                  доступ).
                </Box>
                <Box>
                  Ctrl + Shift + ЛКМ — электризация (нужен расширенный доступ).
                </Box>
                <Box>
                  Shift + ЛКМ по APC, атмосферной тревоге или боту — меню
                  электронных команд.
                </Box>
                <Box>Shift + ЛКМ по машинерии или консоли — её панель.</Box>
                <Box>Ctrl + ЛКМ по APC / боту — питание.</Box>
                <Box>
                  Машины и консоли: до 4 видимых тайлов. Для боевых мехов и
                  секьюриботов нужна продвинутая маршрутизация.
                </Box>
                <Box>
                  Камеры: первое освоение — продвинутое, повторное —
                  стандартное. Подключение без ограничения дальности. Переход в
                  другую сеть — через видимую камеру и стандартный пазл.
                </Box>
                <Box>
                  Alt + ЛКМ — стандартная маршрутизация. Для обычных ботов и
                  машин нужна подходящая ID в слоте.
                </Box>
                <Box>Alt + Shift + ЛКМ — продвинутая маршрутизация.</Box>
                <Box mt={1}>
                  Мини-игра открывается отдельным окном. Вход слева сверху,
                  выход справа снизу; × — повреждение, ● — обязательный узел,
                  стрелка — направление диода. Закреплённые сегменты не
                  вращаются.
                </Box>
              </Section>
            )}
            {is('Device Memory') && Object.keys(categories).map(memory)}
            {is('Remote Control') && (
              <>
                <Section title="Электронные команды">
                  <Button.Checkbox
                    checked={data.remote_enabled}
                    onClick={() => act('remote_toggle')}
                  >
                    {data.remote_enabled ? 'Включено' : 'Выключено'}
                  </Button.Checkbox>
                  <Box mt={1}>
                    Shift + ЛКМ по цели. Прямая связь с машинами и консолями
                    действует в пределах 4 видимых тайлов. Успешная команда
                    нагревает корпус на 25 °C.
                  </Box>
                </Section>
                {data.devices.some((device) => device.access_left > 0) && (
                  <Section
                    className="ck-advanced"
                    title="Advanced Link · временный доступ"
                  >
                    {data.devices
                      .filter((device) => device.access_left > 0)
                      .map((device) => (
                        <div className="ck-row" key={device.id}>
                          {device.name}
                          <b>{device.access_left} с</b>
                        </div>
                      ))}
                  </Section>
                )}
                <Section
                  title={
                    data.relay_name
                      ? `Ретранслятор · ${data.relay_name}`
                      : 'Ретранслятор'
                  }
                >
                  {data.relay_name ? (
                    <Box mb={1}>
                      До 4 тайлов от узла. Команда через узел расходует 0,5%
                      батареи. Для устройств действуют их права доступа.
                    </Box>
                  ) : (
                    <Box>Завершите маршрутизацию на доступной машине.</Box>
                  )}
                  {data.relay_targets?.map((target) => (
                    <div className="ck-row" key={target.id}>
                      <b>{target.name}</b>
                      {target.authorized ? (
                        <Button
                          onClick={() =>
                            act('relay_control', { target: target.id })
                          }
                        >
                          Управление
                        </Button>
                      ) : (
                        <Button
                          onClick={() =>
                            act('route', {
                              target: target.id,
                              advanced: true,
                            })
                          }
                        >
                          Настроить доступ
                        </Button>
                      )}
                    </div>
                  ))}
                </Section>
              </>
            )}
            {is('Camera Network') && (
              <>
                <p>
                  Выберите камеру по имени. Для новой камеры нужна продвинутая
                  маршрутизация. Изученная камера подключается сразу.
                </p>
                {data.camera_network && (
                  <Box>Сеть: {data.camera_network.join(' / ')}</Box>
                )}
                {memory('camera')}
                {!!data.camera_targets?.length && (
                  <Section title="Точки входа">
                    <Input
                      value={cameraQuery}
                      onChange={setCameraQuery}
                      placeholder="Поиск камеры"
                      fluid
                    />
                    {data.camera_targets
                      .filter((camera) =>
                        camera.name
                          .toLowerCase()
                          .includes(cameraQuery.trim().toLowerCase()),
                      )
                      .slice(0, 18)
                      .map((camera) => (
                        <div className="ck-row" key={camera.id}>
                          <b>{camera.name}</b>
                          <Button
                            onClick={() =>
                              act('route', {
                                target: camera.id,
                                advanced: !camera.known,
                              })
                            }
                          >
                            {camera.known ? 'Подключиться' : 'Маршрутизация'}
                          </Button>
                        </div>
                      ))}
                  </Section>
                )}
              </>
            )}
            {is('Боты') && (
              <>
                <Section title="Прямое управление">
                  {!data.pilot_kind && !pilotBots.length && (
                    <Box color="label">
                      Нет доступных ботов на этом Z-уровне.
                    </Box>
                  )}
                  {pilotBots.map((bot) => (
                    <div className="ck-row" key={bot.id}>
                      <b>{bot.name}</b>
                      <span>
                        {bot.pilot_kind === 'bot' &&
                          bot.id !== data.linked_bot_pilot && (
                            <Button
                              onClick={() =>
                                act('route', {
                                  target: bot.id,
                                  advanced: !bot.known && !bot.slot_access,
                                })
                              }
                            >
                              Подключить для команд
                            </Button>
                          )}
                        <Button onClick={() => possessBot(bot.id)}>
                          Вселиться
                        </Button>
                      </span>
                    </div>
                  ))}
                </Section>
                <Section title="Команды ботам">
                  <Box mb={1}>
                    Выберите бота и нажмите Shift + ЛКМ по тайлу в игре. Из окна
                    камеры цель можно указать на её сетке.
                  </Box>
                  {data.command_bots?.map((bot) => (
                    <div className="ck-row" key={bot.id}>
                      <b>{bot.name}</b>
                      <span>
                        <Button
                          selected={bot.selected}
                          disabled={bot.selected}
                          onClick={() =>
                            act('bot_order_select', { target: bot.id })
                          }
                        >
                          {bot.selected ? 'Выбран' : 'Выбрать для маршрута'}
                        </Button>
                        <Button
                          onClick={() => act('bot_panel', { target: bot.id })}
                        >
                          Настройки
                        </Button>
                      </span>
                    </div>
                  ))}
                </Section>
              </>
            )}
            {is('Mech Link') && (
              <>
                {data.pilot_kind && data.pilot_integrity !== undefined ? (
                  <Section
                    title={
                      data.pilot_kind === 'combat'
                        ? 'Боевой канал'
                        : 'Гражданский канал'
                    }
                  >
                    <div className="ck-row">
                      Целостность <b>{data.pilot_integrity}%</b>
                    </div>
                    <div className="ck-row">
                      До корпуса <b>{data.pilot_distance} тайл.</b>
                    </div>
                    <div className="ck-row">
                      Нагрузка на батарею <b>{data.pilot_cost}% / 10 с</b>
                    </div>
                  </Section>
                ) : (
                  <p>Телеметрия появится при пилотировании меха.</p>
                )}
                <Section title="Доступные мехи на этом Z-уровне">
                  {data.devices
                    .filter(
                      (device) =>
                        device.pilot_kind === 'civilian' ||
                        device.pilot_kind === 'combat',
                    )
                    .map((device) => (
                      <Button
                        key={device.id}
                        onClick={() =>
                          act('route', {
                            target: device.id,
                            advanced: device.pilot_kind === 'combat',
                          })
                        }
                      >
                        {device.name}
                      </Button>
                    ))}
                </Section>
                {memory('mech')}
              </>
            )}
            {is('Neural Multitool') && (
              <Section title={`Буфер · ${data.buffer_name || 'пуст'}`}>
                <Button
                  selected={data.multitool_enabled}
                  onClick={() => act('multitool_toggle')}
                >
                  Нейронный мультитул
                </Button>
                <Button onClick={() => act('multitool_clear')}>
                  Очистить буфер мультитула
                </Button>
                <Box>
                  При включении: ЛКМ по поддерживаемому устройству — настройка и
                  буфер связывания. Нужна ID или временный доступ.
                  Поддерживаются телекоммы, атмосферные датчики и тревоги,
                  блюспейс-скрубберы и приёмники газа, квантовые площадки.
                  Физические панели открываются вручную.
                </Box>
              </Section>
            )}
            {is('Sensor Suite') && (
              <Section
                title={`Диагностика устройств · ${data.scan_cost}% батареи`}
              >
                <Box color="label" mb={1}>
                  Видимые устройства в пределах четырёх тайлов. Сканирование не
                  осваивает устройство и не даёт доступа к управлению.
                </Box>
                {data.scanner_targets.map((target) => (
                  <Button
                    key={target.id}
                    icon="magnifying-glass"
                    disabled={data.charge < data.scan_cost}
                    onClick={() => act('scan', { target: target.id })}
                  >
                    {target.name}
                  </Button>
                ))}
                {data.last_scan && (
                  <Box mt={1}>
                    {data.last_scan.name}: целостность{' '}
                    {data.last_scan.integrity ?? '—'}%
                    {data.last_scan.powered !== undefined &&
                      (data.last_scan.powered
                        ? ', питание есть'
                        : ', нет питания')}
                  </Box>
                )}
              </Section>
            )}
          </main>
        </div>
      </Window.Content>
    </Window>
  );
};
