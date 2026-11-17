import { describe, expect, test } from 'vitest';
import { initialTransition, transition } from 'xstate';
import { navigationMachine } from './NavigationMachine.js';

describe('navigation lifecycle', () => {
  test('SSR stays initializing and cannot open before hydration', () => {
    const [initial] = initialTransition(navigationMachine);
    expect(initial.matches('initializing')).toBe(true);
    expect(initial.matches('ready')).toBe(false);
    for (const event of [{ type: 'menu.toggle' }, { type: 'menu.escape' }, { type: 'navigation.completed' }, { type: 'viewport.changed', wide: true }] as const) {
      const [unchanged] = transition(navigationMachine, initial, event);
      expect(unchanged.matches('initializing')).toBe(true);
      expect(unchanged.matches({ ready: { wide: 'open' } })).toBe(false);
    }
  });
  test.each([false, true])('mount enters the appropriate ready viewport without reset on a repeated mount: %s', (wide) => {
    const [initial] = initialTransition(navigationMachine);
    const [ready] = transition(navigationMachine, initial, { type: 'component.mounted', wide });
    expect(ready.matches(wide ? { ready: { wide: 'open' } } : { ready: { narrow: 'closed' } })).toBe(true);
    const [unchanged] = transition(navigationMachine, ready, { type: 'component.mounted', wide: !wide });
    expect(unchanged.value).toEqual(ready.value);
  });
  test('mobile starts closed and toggles in both directions', () => {
    const [initial] = initialTransition(navigationMachine);
    const [ready] = transition(navigationMachine, initial, { type: 'component.mounted', wide: false });
    expect(ready.matches({ ready: { narrow: 'closed' } })).toBe(true);
    const [opened] = transition(navigationMachine, ready, { type: 'menu.toggle' });
    expect(opened.matches({ ready: { narrow: 'open' } })).toBe(true);
    const [closed] = transition(navigationMachine, opened, { type: 'menu.toggle' });
    expect(closed.matches({ ready: { narrow: 'closed' } })).toBe(true);
  });
  test.each(['navigation.completed', 'menu.escape'] as const)('mobile closes on %s and closed ignores it', (type) => {
    const [initial] = initialTransition(navigationMachine);
    const [ready] = transition(navigationMachine, initial, { type: 'component.mounted', wide: false });
    const [unchanged] = transition(navigationMachine, ready, { type });
    expect(unchanged.matches({ ready: { narrow: 'closed' } })).toBe(true);
    const [opened] = transition(navigationMachine, ready, { type: 'menu.toggle' });
    const [closed] = transition(navigationMachine, opened, { type });
    expect(closed.matches({ ready: { narrow: 'open' } })).toBe(false);
    expect(closed.matches({ ready: { narrow: 'closed' } })).toBe(true);
  });
  test('wide viewport opens automatically, stays open on navigation, allows toggle and Escape', () => {
    const [initial] = initialTransition(navigationMachine);
    const [ready] = transition(navigationMachine, initial, { type: 'component.mounted', wide: false });
    const [wide] = transition(navigationMachine, ready, { type: 'viewport.changed', wide: true });
    expect(wide.matches({ ready: { wide: 'open' } })).toBe(true);
    const [navigated] = transition(navigationMachine, wide, { type: 'navigation.completed' });
    expect(navigated.matches({ ready: { wide: 'open' } })).toBe(true);
    const [closed] = transition(navigationMachine, navigated, { type: 'menu.toggle' });
    expect(closed.matches({ ready: { wide: 'closed' } })).toBe(true);
    const [reopened] = transition(navigationMachine, closed, { type: 'menu.toggle' });
    const [escaped] = transition(navigationMachine, reopened, { type: 'menu.escape' });
    expect(escaped.matches({ ready: { wide: 'closed' } })).toBe(true);
    const [unchanged] = transition(navigationMachine, escaped, { type: 'menu.escape' });
    expect(unchanged.matches({ ready: { wide: 'closed' } })).toBe(true);
  });
  test('returning to mobile closes the automatic desktop menu', () => {
    const [initial] = initialTransition(navigationMachine);
    const [wide] = transition(navigationMachine, initial, { type: 'component.mounted', wide: true });
    const [narrow] = transition(navigationMachine, wide, { type: 'viewport.changed', wide: false });
    expect(narrow.matches({ ready: { narrow: 'closed' } })).toBe(true);
  });
});
