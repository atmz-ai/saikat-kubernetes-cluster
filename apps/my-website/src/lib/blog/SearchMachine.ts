import { assign, setup } from 'xstate';

export const searchMachine = setup({
  types: {
    context: {} as { query: string },
    events: {} as { type: 'query.changed'; query: string }
  }
}).createMachine({
  id: 'blogSearch',
  initial: 'empty',
  context: { query: '' },
  on: {
    'query.changed': [
      { guard: ({ event }) => event.query === '', target: '.empty', actions: assign({ query: ({ event }) => event.query }) },
      { target: '.searching', actions: assign({ query: ({ event }) => event.query }) }
    ]
  },
  states: { empty: {}, searching: {} }
});
