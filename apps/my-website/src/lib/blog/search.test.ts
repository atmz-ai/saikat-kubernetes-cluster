import { describe, expect, test } from 'vitest';
import { initialTransition, transition, createActor } from 'xstate';
import { filterBlogPosts } from './search.js';
import { searchMachine } from './SearchMachine.js';
import type { BlogPost } from './content.js';

const posts: BlogPost[] = [
  { title: 'React Hooks: useState', description: 'A gentle introduction', tags: ['react', 'hooks'], slug: '/blog/posts/react-hooks-usestate', author: 'Saikat Das', icon: 'react.png', created: '2019-08-29', bodyHtml: '' },
  { title: 'Linux Processes', description: 'Monitoring with HTOP', tags: ['bash', 'command-line'], slug: '/blog/posts/linux-processes-monitoring-managing', author: 'Saikat Das', icon: 'bash.png', created: '2020-04-02', bodyHtml: '' }
];

describe('case-insensitive substring search', () => {
  test('empty query returns every post in original order without mutating input', () => {
    expect(filterBlogPosts(posts, '')).toEqual(posts);
    expect(filterBlogPosts(posts, '')).not.toBe(posts);
  });
  test.each(['React Hooks: useState', 'USESTATE', 'react hooks', 'gentle INTRODUCTION', 'HOOKS', 'eact'])('matches title description or tag: %s', (query) => {
    const result = filterBlogPosts(posts, query);
    expect(result).toEqual([posts[0]]);
    expect(result).not.toContain(posts[1]);
  });
  test.each(['HTOP', 'COMMAND-LINE'])('matches description and tags independently: %s', (query) => {
    expect(filterBlogPosts(posts, query)).toEqual([posts[1]]);
  });
  test.each(['no-such-word', '/blog/posts/', 'Saikat Das', ' USESTATE ', '.*'])('does not search authors URLs or interpret regex or trim query: %s', (query) => {
    expect(filterBlogPosts(posts, query)).toEqual([]);
  });
  test('a space is a literal substring, not an empty query', () => {
    const compactPost = { ...posts[0], title: 'Compact', description: 'Single', tags: ['word'] };
    expect(filterBlogPosts([compactPost], ' ')).toEqual([]);
  });
});

describe('search lifecycle', () => {
  test('query events enter searching, replace query and clear to empty', () => {
    const [initial] = initialTransition(searchMachine);
    expect(initial.matches('empty')).toBe(true);
    const [searching] = transition(searchMachine, initial, { type: 'query.changed', query: 'REACT' });
    expect(searching.matches('searching')).toBe(true);
    expect(filterBlogPosts(posts, searching.context.query)).toEqual([posts[0]]);
    const [changed] = transition(searchMachine, searching, { type: 'query.changed', query: 'HTOP' });
    expect(changed.context.query).toBe('HTOP');
    const [cleared] = transition(searchMachine, changed, { type: 'query.changed', query: '' });
    expect(cleared.matches('empty')).toBe(true);
    expect(cleared.context.query).toBe('');
    expect(initial.context.query).toBe('');
  });
  test('component actors do not share SSR search state', () => {
    const first = createActor(searchMachine).start();
    const second = createActor(searchMachine).start();
    first.send({ type: 'query.changed', query: 'REACT' });
    expect(second.getSnapshot().context.query).toBe('');
    first.stop();
    second.stop();
  });
});
