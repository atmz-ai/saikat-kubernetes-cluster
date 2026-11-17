import { describe, expect, test } from 'vitest';
import { initialTransition, transition } from 'xstate';
import { navigationMachine } from './NavigationMachine.js';

describe('navigation lifecycle', () => {
  test('mobile starts closed and toggles in both directions', () => {
    const [initial] = initialTransition(navigationMachine);
    expect(initial.matches({ narrow: 'closed' })).toBe(true);
    const [opened] = transition(navigationMachine, initial, { type: 'menu.toggle' });
    expect(opened.matches({ narrow: 'open' })).toBe(true);
    const [closed] = transition(navigationMachine, opened, { type: 'menu.toggle' });
    expect(closed.matches({ narrow: 'closed' })).toBe(true);
  });
  test.each(['navigation.completed', 'menu.escape'] as const)('mobile closes on %s and closed ignores it', (type) => {
    const [initial] = initialTransition(navigationMachine);
    const [unchanged] = transition(navigationMachine, initial, { type });
    expect(unchanged.matches({ narrow: 'closed' })).toBe(true);
    const [opened] = transition(navigationMachine, initial, { type: 'menu.toggle' });
    const [closed] = transition(navigationMachine, opened, { type });
    expect(closed.matches({ narrow: 'open' })).toBe(false);
    expect(closed.matches({ narrow: 'closed' })).toBe(true);
  });
  test('wide viewport opens automatically, stays open on navigation, allows toggle and Escape', () => {
    const [initial] = initialTransition(navigationMachine);
    const [wide] = transition(navigationMachine, initial, { type: 'viewport.changed', wide: true });
    expect(wide.matches({ wide: 'open' })).toBe(true);
    const [navigated] = transition(navigationMachine, wide, { type: 'navigation.completed' });
    expect(navigated.matches({ wide: 'open' })).toBe(true);
    const [closed] = transition(navigationMachine, navigated, { type: 'menu.toggle' });
    expect(closed.matches({ wide: 'closed' })).toBe(true);
    const [reopened] = transition(navigationMachine, closed, { type: 'menu.toggle' });
    const [escaped] = transition(navigationMachine, reopened, { type: 'menu.escape' });
    expect(escaped.matches({ wide: 'closed' })).toBe(true);
    const [unchanged] = transition(navigationMachine, escaped, { type: 'menu.escape' });
    expect(unchanged.matches({ wide: 'closed' })).toBe(true);
  });
  test('returning to mobile closes the automatic desktop menu', () => {
    const [initial] = initialTransition(navigationMachine);
    const [wide] = transition(navigationMachine, initial, { type: 'viewport.changed', wide: true });
    const [narrow] = transition(navigationMachine, wide, { type: 'viewport.changed', wide: false });
    expect(narrow.matches({ narrow: 'closed' })).toBe(true);
  });
});
