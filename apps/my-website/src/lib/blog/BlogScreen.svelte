<script lang="ts">
  import { useMachine } from '@xstate/svelte';
  import { onMount } from 'svelte';
  import MetadataComponent from '../components/atoms/MetadataComponent.svelte';
  import BlogCardComponent, { previewPost } from './BlogCardComponent.svelte';
  import type { BlogPost } from './content.js';
  import { searchMachine } from './SearchMachine.js';
  import { filterBlogPosts } from './search.js';
  let { posts = [previewPost] }: { posts?: BlogPost[] } = $props();
  const { snapshot, send } = useMachine(searchMachine);
  onMount(() => send({ type: 'component.mounted' }));
  const filteredPosts = $derived(filterBlogPosts(posts, $snapshot.context.query));
</script>

<MetadataComponent title="Saikat's Blog" description="This is my blog where I write about what I learn including things like SvelteJS, TailwindCSS, NodeJS, Linux, PostgreSQL among a few" />
<main class="max-w-screen-md mx-auto p-2">
  <input type="text" aria-label="Search blog posts" placeholder="Keep typing to see search results..." disabled={!$snapshot.matches('ready')} value={$snapshot.context.query} oninput={(event) => send({ type: 'query.changed', query: event.currentTarget.value })} class="block w-11/12 mx-auto my-6 border-b-2 border-gray-300 text-xl focus:outline-none focus:border-emerald-400 active:border-emerald-400" />
  <h1 class="text-3xl text-center mt-16 mb-8">Blog Posts</h1>
  <ul aria-label="Blog posts">{#each filteredPosts as post (post.slug)}<BlogCardComponent {post} />{/each}</ul>
</main>
