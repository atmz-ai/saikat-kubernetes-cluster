<script lang="ts">
  import { useMachine } from '@xstate/svelte';
  import { onMount } from 'svelte';
  import MetadataComponent from '../components/atoms/MetadataComponent.svelte';
  import BlogCardComponent, { previewPost } from './BlogCardComponent.svelte';
  import type { BlogPost } from './content.js';
  import { searchMachine } from './SearchMachine.js';
  import { filterBlogPosts } from './search.js';
  let { posts = [previewPost] }: { posts?: BlogPost[] } = $props();
  const searchIdentifier = $props.id();
  const { snapshot, send } = useMachine(searchMachine);
  onMount(() => send({ type: 'component.mounted' }));
  const filteredPosts = $derived(filterBlogPosts(posts, $snapshot.context.query));
</script>

<MetadataComponent title="Saikat's Blog" description="This is my blog where I write about what I learn including things like SvelteJS, TailwindCSS, NodeJS, Linux, PostgreSQL among a few" />
<main class="page-shell">
  <header class="page-heading">
    <p class="eyebrow">Notes from the workbench</p>
    <h1>Blog Posts<span class="heading-dot">.</span></h1>
    <p class="page-description">Things I've learned, problems I've explored, and references worth keeping.</p>
  </header>
  <div class="search-panel">
    <label for={searchIdentifier}>Find something interesting</label>
    <div class="search-field">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><circle cx="10.5" cy="10.5" r="6.5" /><path d="m16 16 4.5 4.5" /></svg>
      <input id={searchIdentifier} type="text" aria-label="Search blog posts" placeholder="Search titles, topics, or tags..." disabled={!$snapshot.matches('ready')} value={$snapshot.context.query} oninput={(event) => send({ type: 'query.changed', query: event.currentTarget.value })} />
    </div>
    <p class="search-count" role="status">{filteredPosts.length} {filteredPosts.length === 1 ? 'article' : 'articles'}{$snapshot.context.query ? ' found' : ' to explore'}</p>
  </div>
  <ul class="article-list" aria-label="Blog posts">{#each filteredPosts as post (post.slug)}<BlogCardComponent {post} />{/each}</ul>
  {#if filteredPosts.length === 0}
    <section class="empty-state">
      <h2>{posts.length === 0 ? 'Notes are on their way.' : 'No matching articles.'}</h2>
      <p>{posts.length === 0 ? 'Check back for something new.' : 'Try another topic, or clear your search to see everything.'}</p>
      {#if $snapshot.context.query}<button class="button-link" type="button" onclick={() => send({ type: 'query.changed', query: '' })}>Clear search <span aria-hidden="true">↗</span></button>{/if}
    </section>
  {/if}
</main>
