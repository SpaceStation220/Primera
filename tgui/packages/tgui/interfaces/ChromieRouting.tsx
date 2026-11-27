import { useBackend } from '../backend';
import { Window } from '../layouts';
import { RoutingGrid } from './ChromieKnight';
export const ChromieRouting = () => {
  const { data } = useBackend<{ routing_result?: 'success' | 'failure' }>();

  return (
    <Window
      width={540}
      height={740}
      title="Маршрутизация"
      canClose={!!data.routing_result}
    >
      <Window.Content className="ChromieKnight" scrollable>
        <RoutingGrid />
      </Window.Content>
    </Window>
  );
};
