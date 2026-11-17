<script lang="ts">
  import { onMount } from 'svelte';
  import { afterNavigate } from '$app/navigation';
  import { useMachine } from '@xstate/svelte';
  import { navigationMachine } from './NavigationMachine.js';
  let { previewViewport }: { previewViewport?: 'narrow' | 'wide' } = $props();
  const { snapshot, send } = useMachine(navigationMachine);
  const open = $derived($snapshot.matches({ narrow: 'open' }) || $snapshot.matches({ wide: 'open' }));
  afterNavigate(() => send({ type: 'navigation.completed' }));
  onMount(() => {
    if (previewViewport) {
      send({ type: 'viewport.changed', wide: previewViewport === 'wide' });
      return;
    }
    const viewport = window.matchMedia('(min-width: 1536px)');
    send({ type: 'viewport.changed', wide: viewport.matches });
    const changed = (event: MediaQueryListEvent) => send({ type: 'viewport.changed', wide: event.matches });
    viewport.addEventListener('change', changed);
    return () => viewport.removeEventListener('change', changed);
  });
</script>

<svelte:window onkeydown={(event) => { if (event.key === 'Escape') send({ type: 'menu.escape' }); }} />
<button type="button" aria-label="Toggle navigation menu" aria-expanded={open} aria-controls="site-navigation" onclick={() => send({ type: 'menu.toggle' })} class="w-12 h-12 fixed bottom-8 right-8 bg-gradient-to-tr from-emerald-500 via-blue-500 to-fuchsia-500 rounded-lg focus:outline-none focus:ring focus:ring-emerald-300 shadow-lg z-10">
  <span class:open class="hamburger"><span></span><span></span><span></span></span>
</button>
<aside id="site-navigation" hidden={!open} class="fixed bottom-8 right-8 w-64 h-96 shadow rounded-lg bg-gray-50 z-[9]">
  <nav aria-label="Main navigation"><ul>
    <li><a href="/" onclick={() => send({ type: 'navigation.completed' })} class="block py-2 px-6 text-lg text-emerald-800 hover:text-emerald-600 active:text-emerald-600 hover:bg-gradient-to-tr hover:from-emerald-100 hover:via-blue-100 hover:to-fuchsia-100 active:bg-gradient-to-tr active:from-emerald-100 active:via-blue-100 active:to-fuchsia-100"><span class="h-10 flex flex-row items-center">
      <svg xmlns="http://www.w3.org/2000/svg" aria-hidden="true" focusable="false" class="h-5 mr-3" preserveAspectRatio="xMidYMid meet" viewBox="0 0 48 48">
        <path fill="#E8EAF6" d="M42 39H6V23L24 6l18 17z" /><g fill="#C5CAE9"><path d="M39 21l-5-5V9h5z" /><path d="M6 39h36v5H6z" /></g><path fill="#B71C1C" d="M24 4.3L4 22.9l2 2.2L24 8.4l18 16.7l2-2.2z" /><path fill="#D84315" d="M18 28h12v16H18z" /><path fill="#01579B" d="M21 17h6v6h-6z" /><path fill="#FF8A65" d="M27.5 35.5c-.3 0-.5.2-.5.5v2c0 .3.2.5.5.5s.5-.2.5-.5v-2c0-.3-.2-.5-.5-.5z" />
      </svg><span>About Me</span></span></a></li>
    <li><a href="/blog" onclick={() => send({ type: 'navigation.completed' })} class="block py-2 px-6 text-lg text-emerald-800 hover:text-emerald-600 active:text-emerald-600 hover:bg-gradient-to-tr hover:from-emerald-100 hover:via-blue-100 hover:to-fuchsia-100 active:bg-gradient-to-tr active:from-emerald-100 active:via-blue-100 active:to-fuchsia-100"><span class="h-10 flex flex-row items-center">
      <svg xmlns="http://www.w3.org/2000/svg" aria-hidden="true" focusable="false" class="h-5 mr-3" preserveAspectRatio="xMidYMid meet" viewBox="0 0 48 48">
        <path fill="#FF5722" d="M32 15v28H10c-2.2 0-4-1.8-4-4V15h26z" /><path fill="#FFCCBC" d="M14 5v34c0 2.2-1.8 4-4 4h29c2.2 0 4-1.8 4-4V5H14z" /><g fill="#FF5722"><path d="M20 10h18v4H20z" /><path d="M20 17h8v2h-8z" /><path d="M30 17h8v2h-8z" /><path d="M20 21h8v2h-8z" /><path d="M30 21h8v2h-8z" /><path d="M20 25h8v2h-8z" /><path d="M30 25h8v2h-8z" /><path d="M20 29h8v2h-8z" /><path d="M30 29h8v2h-8z" /><path d="M20 33h8v2h-8z" /><path d="M30 33h8v2h-8z" /><path d="M20 37h8v2h-8z" /><path d="M30 37h8v2h-8z" /></g>
      </svg><span>Blog</span></span></a></li>
    <li><a href="/projects" onclick={() => send({ type: 'navigation.completed' })} class="block py-2 px-6 text-lg text-emerald-800 hover:text-emerald-600 active:text-emerald-600 hover:bg-gradient-to-tr hover:from-emerald-100 hover:via-blue-100 hover:to-fuchsia-100 active:bg-gradient-to-tr active:from-emerald-100 active:via-blue-100 active:to-fuchsia-100"><span class="h-10 flex flex-row items-center">
      <svg xmlns="http://www.w3.org/2000/svg" aria-hidden="true" focusable="false" class="h-5 mr-3" preserveAspectRatio="xMidYMid meet" viewBox="0 0 48 48">
        <path fill="#B0BEC5" d="M37 42H5V32h32c2.8 0 5 2.2 5 5s-2.2 5-5 5z" /><path fill="#37474F" d="M10 34c-1.7 0-3 1.3-3 3s1.3 3 3 3s3-1.3 3-3s-1.3-3-3-3zm0 4c-.6 0-1-.4-1-1s.4-1 1-1s1 .4 1 1s-.4 1-1 1z" /><path fill="#37474F" d="M19 34c-1.7 0-3 1.3-3 3s1.3 3 3 3s3-1.3 3-3s-1.3-3-3-3zm0 4c-.6 0-1-.4-1-1s.4-1 1-1s1 .4 1 1s-.4 1-1 1z" /><path fill="#37474F" d="M37 34c-1.7 0-3 1.3-3 3s1.3 3 3 3s3-1.3 3-3s-1.3-3-3-3zm0 4c-.6 0-1-.4-1-1s.4-1 1-1s1 .4 1 1s-.4 1-1 1z" /><path fill="#37474F" d="M28 34c-1.7 0-3 1.3-3 3s1.3 3 3 3s3-1.3 3-3s-1.3-3-3-3zm0 4c-.6 0-1-.4-1-1s.4-1 1-1s1 .4 1 1s-.4 1-1 1z" /><path fill="#FF9800" d="M35 31H11c-1.1 0-2-.9-2-2V7c0-1.1.9-2 2-2h24c1.1 0 2 .9 2 2v22c0 1.1-.9 2-2 2z" /><path fill="#8A5100" d="M26.5 13h-7c-.8 0-1.5-.7-1.5-1.5s.7-1.5 1.5-1.5h7c.8 0 1.5.7 1.5 1.5s-.7 1.5-1.5 1.5z" /><path fill="#607D8B" d="M37 31H5v2h32c2.2 0 4 1.8 4 4s-1.8 4-4 4H5v2h32c3.3 0 6-2.7 6-6s-2.7-6-6-6z" />
      </svg><span>Things I've built</span></span></a></li>
  </ul></nav>
</aside>

<style>
  .hamburger { display: block; width: 1.5rem; margin: auto; }
  .hamburger > span { display: block; height: 0.125rem; width: 1.5rem; background: white; margin: 0.375rem 0; border-radius: 9999px; transition: transform 150ms, opacity 150ms; }
  .open > span:nth-child(1) { transform: translateY(0.5rem) rotate(45deg); }
  .open > span:nth-child(2) { opacity: 0; }
  .open > span:nth-child(3) { transform: translateY(-0.5rem) rotate(-45deg); }
</style>
