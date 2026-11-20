import { expect, it } from 'bun:test';
import { render, screen } from '@testing-library/react';
import { BookPageView } from './MarkdownViewer';

it('renders page text and an inline photograph', () => {
  const view = render(
    <BookPageView
      number={3}
      page={{
        content: 'Chapter',
        photo: 'iVBORw0KGgo=',
        stamps: [],
      }}
    />,
  );
  expect(screen.getByText('Chapter')).toBeTruthy();
  expect(screen.getByAltText('Photograph').getAttribute('src')).toBe(
    'data:image/png;base64,iVBORw0KGgo=',
  );
  expect(view.container.querySelectorAll('img').length).toBe(1);
});

it('renders a blank reverse side without inventing text or a photograph', () => {
  const view = render(
    <BookPageView number={4} page={{ content: '', photo: null, stamps: [] }} />,
  );
  expect(view.container.querySelector('.Book__PageNumber')?.textContent).toBe(
    '4',
  );
  expect(view.container.querySelector('img')).toBeNull();
  expect(view.container.querySelector('.Book__Content')?.textContent).toBe('');
});
