import { createRequire } from 'node:module';
import { expect, test } from 'vitest';

const require = createRequire(import.meta.url);
const { commonTrailingPseudos } = require('@tailwindcss/typography/src/utils.js') as {
  commonTrailingPseudos: (selector: string) => [string | null, string];
};

test('patched selector parser preserves typography pseudo-element extraction', () => {
  expect(commonTrailingPseudos('h1::before, h2::before')).toEqual(['::before', 'h1, h2']);
  expect(commonTrailingPseudos('code::before::after')).toEqual(['::before::after', 'code']);
});

test('patched selector parser never strips distinct pseudo-elements or pseudo-classes', () => {
  for (const selector of ['h1::before, h2::after', 'a:hover', '.prose :where(code)']) {
    expect(commonTrailingPseudos(selector)).toEqual([null, selector]);
  }
});
