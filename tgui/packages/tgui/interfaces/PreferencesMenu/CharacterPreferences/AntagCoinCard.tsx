import { Stack, Tooltip } from 'tgui-core/components';
import { resolveAsset } from '../../../assets';
import { useBackend } from '../../../backend';
import type { PreferencesMenuData } from '../types';

export function AntagCoinCard() {
  const { act, data } = useBackend<PreferencesMenuData>();
  const coin = data.antag_coin;
  const available =
    coin?.tier_five &&
    coin.lobby &&
    !coin.remaining &&
    !coin.pending &&
    !coin.approved;
  const status = !coin?.tier_five
    ? 'Требуется Tier 5'
    : coin.remaining > 0
      ? `${Math.ceil(coin.remaining / 3600)} ч.`
      : coin.pending || coin.approved
        ? 'Ожидание старта'
        : !coin.lobby
          ? 'Только в лобби'
          : 'Выбрать сценарий';
  const className = 'PreferencesMenu__AntagsSelection';
  return (
    <Tooltip content={`${status}. Одобрение администратора, раз в 168 часов.`}>
      <button
        type="button"
        aria-label="Антаг коин"
        aria-disabled={!available}
        onClick={() => act('antag_coin_open')}
        style={{
          appearance: 'none',
          background: 'none',
          border: 0,
          color: 'inherit',
          font: 'inherit',
          padding: 0,
          textAlign: 'inherit',
          width: '100%',
        }}
      >
        <Stack
          vertical
          className={`${className}__Antag ${available ? 'on' : 'off'} AntagCoinCard`}
        >
          <Stack.Item className={`${className}__AntagIcon--wrapper`}>
            <img
              src={resolveAsset('antag_coin.png')}
              alt="Tier 5"
              width={96}
              height={96}
              className={`${className}__AntagIcon`}
              style={{
                display: 'block',
                imageRendering: 'pixelated',
                filter: available
                  ? undefined
                  : 'grayscale(0.8) brightness(0.55)',
              }}
            />
          </Stack.Item>
          <Stack.Item className={`${className}__AntagName`}>
            Антаг коин
          </Stack.Item>
          <Stack.Item fontSize="0.85em" color="label">
            {status}
          </Stack.Item>
        </Stack>
      </button>
    </Tooltip>
  );
}
