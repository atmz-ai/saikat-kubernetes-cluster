<script lang="ts">
  import { onMount } from 'svelte';
  import { afterNavigate } from '$app/navigation';
  import { page } from '$app/state';
  import { useMachine } from '@xstate/svelte';
  import { navigationMachine } from './NavigationMachine.js';

  let { previewViewport }: { previewViewport?: 'narrow' | 'wide' } = $props();
  const { snapshot, send } = useMachine(navigationMachine);
  const open = $derived($snapshot.matches({ ready: { narrow: 'open' } }) || $snapshot.matches({ ready: 'wide' }));
  const navigationLinks = [
    { href: '/', label: 'About Me' },
    { href: '/blog', label: 'Blog' },
    { href: '/projects', label: "Things I've built" }
  ];

  afterNavigate(() => send({ type: 'navigation.completed' }));
  onMount(() => {
    if (previewViewport) {
      send({ type: 'component.mounted', wide: previewViewport === 'wide' });
      return;
    }
    const viewport = window.matchMedia('(min-width: 768px)');
    send({ type: 'component.mounted', wide: viewport.matches });
    const changed = (event: MediaQueryListEvent) => send({ type: 'viewport.changed', wide: event.matches });
    viewport.addEventListener('change', changed);
    return () => viewport.removeEventListener('change', changed);
  });
</script>

<svelte:window onkeydown={(event) => { if (event.key === 'Escape') send({ type: 'menu.escape' }); }} />
<header class="site-header">
  <div class="header-inner">
    <a class="site-brand" href="/" aria-label="Saikat Das, home">
      <span class="brand-mark" aria-hidden="true">sd.</span>
      <span>Saikat Das<span class="brand-caption">Code, curiosity & craft</span></span>
    </a>
    <button type="button" class="menu-toggle" aria-label="Toggle navigation menu" disabled={!$snapshot.matches('ready')} aria-expanded={open} aria-controls="site-navigation" onclick={() => send({ type: 'menu.toggle' })}>
      <span>{open ? 'Close' : 'Menu'}</span>
      <span class="menu-glyph" aria-hidden="true">{open ? '×' : '+'}</span>
    </button>
    <nav id="site-navigation" class="site-navigation" class:initializing={!$snapshot.matches('ready')} aria-label="Main navigation" hidden={!open && $snapshot.matches('ready')}>
      {#each navigationLinks as navigationLink (navigationLink.href)}
        <a href={navigationLink.href} aria-current={(page.url.pathname === navigationLink.href || (navigationLink.href !== '/' && page.url.pathname.startsWith(`${navigationLink.href}/`))) ? 'page' : undefined} onclick={() => send({ type: 'navigation.completed' })}>{navigationLink.label}</a>
      {/each}
    </nav>
    <noscript><div class="no-script-links"><a href="/">About Me</a><a href="/blog">Blog</a><a href="/projects">Things I've built</a></div></noscript>
  </div>
</header>
