import { marked } from 'marked';
import { Box, Button, Stack } from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import { sanitizeText } from '../sanitize';
import { Stamp } from './PaperSheet/Stamp';

export type BookPage = {
  content: string;
  photo?: string | null;
  stamps: { class: string; x: number; y: number; rotation: number }[];
};

type MarkdownViewerData = {
  title: string;
  content: string;
  author: string;
  spread?: BookPage[];
  current_page?: number;
  total_pages?: number;
  can_tear?: boolean | 0 | 1;
};

export const MarkdownViewer = (_: any) => {
  const { data, act } = useBackend<MarkdownViewerData>();
  if (data.spread) {
    const current = data.current_page || 1;
    const total = data.total_pages || 0;
    return (
      <Window theme="paper" title={data.title} width={820} height={600}>
        <Window.Content>
          <Stack vertical fill>
            <Stack.Item grow>
              <div className="Book__Spread">
                {[0, 1].map((side) => (
                  <BookPageView
                    key={current + side}
                    page={data.spread?.[side]}
                    number={
                      current + side <= total ? current + side : undefined
                    }
                  />
                ))}
              </div>
            </Stack.Item>
            <Stack.Item>
              <Stack justify="space-between" align="center">
                <Stack.Item>
                  <Button
                    icon="arrow-left"
                    disabled={current <= 1}
                    onClick={() => act('prev_spread')}
                  >
                    Previous
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  {current} / {total}
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="scissors"
                    color="bad"
                    disabled={!data.can_tear || !total}
                    onClick={() => act('tear_sheet')}
                  >
                    Tear Sheet
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="arrow-right"
                    disabled={current + 2 > total}
                    onClick={() => act('next_spread')}
                  >
                    Next
                  </Button>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          </Stack>
        </Window.Content>
      </Window>
    );
  }
  return (
    <Window theme="paper" title={data.title} width={420} height={500}>
      <Window.Content scrollable backgroundColor={'#FFFFFF'}>
        <MarkdownRenderer content={data.content} />
      </Window.Content>
    </Window>
  );
};

export function BookPageView(props: { page?: BookPage; number?: number }) {
  const { page, number } = props;
  return (
    <div className="Book__Sheet">
      <div className="Book__Content">
        {page?.photo && (
          <img
            className="Book__Photo"
            alt="Photograph"
            src={`data:image/png;base64,${page.photo}`}
          />
        )}
        <MarkdownRenderer content={page?.content || ''} />
        <div className="Book__Stamps">
          {page?.stamps.map((stamp, index) => (
            <Stamp
              key={index}
              x={stamp.x}
              y={stamp.y}
              rotation={stamp.rotation}
              sprite={stamp.class}
            />
          ))}
        </div>
      </div>
      <div className="Book__PageNumber">{number}</div>
    </div>
  );
}

type MarkdownRendererProps = {
  content: string;
  sanitize?: boolean;
};

export const MarkdownRenderer = (props: MarkdownRendererProps) => {
  let { content, sanitize = true } = props;

  content = marked(content, { async: false });
  if (sanitize) {
    content = sanitizeText(content, /* advHtml = */ false);
  }

  return <Box dangerouslySetInnerHTML={{ __html: content }} />;
};
