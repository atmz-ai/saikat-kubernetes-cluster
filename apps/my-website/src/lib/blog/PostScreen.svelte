<script lang="ts">
  import MetadataComponent from '../components/atoms/MetadataComponent.svelte';
  import { formatDate } from '../content/dates.js';
  import { previewPost } from './BlogCardComponent.svelte';
  import type { BlogPost } from './content.js';
  let { post = previewPost }: { post?: BlogPost } = $props();
</script>

<MetadataComponent title={post.title} description={post.description} />
<article class="prose prose-emerald max-w-screen-md mx-auto my-8 px-4">
  <h1 class="!mb-2">{post.title}</h1>
  <span class="text-gray-400">published on <span class="text-emerald-600 font-medium">{formatDate(post.created)}</span></span>
  <div>{@html post.bodyHtml}</div>
</article>
