import { setup } from 'xstate';

export const navigationMachine = setup({
  types: {
    events: {} as { type: 'menu.toggle' } | { type: 'menu.escape' } | { type: 'navigation.completed' }
      | { type: 'component.mounted'; wide: boolean }
      | { type: 'viewport.changed'; wide: boolean }
  }
}).createMachine({
  id: 'navigation',
  initial: 'initializing',
  states: {
    initializing: {
      on: {
        'component.mounted': [
          { guard: ({ event }) => event.wide, target: 'ready.wide.open' },
          { target: 'ready.narrow.closed' }
        ]
      }
    },
    ready: {
      initial: 'narrow',
      on: {
        'viewport.changed': [
          { guard: ({ event }) => event.wide, target: '.wide.open' },
          { target: '.narrow.closed' }
        ]
      },
      states: {
        narrow: {
          initial: 'closed',
          states: {
            closed: { on: { 'menu.toggle': 'open' } },
            open: { on: { 'menu.toggle': 'closed', 'menu.escape': 'closed', 'navigation.completed': 'closed' } }
          }
        },
        wide: {
          initial: 'open',
          states: {
            closed: { on: { 'menu.toggle': 'open' } },
            open: { on: { 'menu.toggle': 'closed', 'menu.escape': 'closed' } }
          }
        }
      }
    }
  }
});
