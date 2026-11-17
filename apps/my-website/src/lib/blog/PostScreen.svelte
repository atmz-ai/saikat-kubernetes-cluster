<script lang="ts">
  import MetadataComponent from '../components/atoms/MetadataComponent.svelte';
  import { formatDate } from '../content/dates.js';
  import { previewPost } from './BlogCardComponent.svelte';
  import type { BlogPost } from './content.js';
  let { post = previewPost }: { post?: BlogPost } = $props();
</script>

<MetadataComponent title={post.title} description={post.description} />
<main class="page-shell reading-shell">
  <a class="back-link" href="/blog"><span aria-hidden="true">←</span> All articles</a>
  <article class="prose reading-content">
    <header class="article-heading">
      <p class="eyebrow">From the blog</p>
      <h1>{post.title}</h1>
      <p class="content-date">Published <time datetime={post.created}>{formatDate(post.created)}</time> <span aria-hidden="true">/</span> {post.author}</p>
    </header>
    <div>{@html post.bodyHtml}</div>
  </article>
  <a class="back-link article-end" href="/blog"><span aria-hidden="true">←</span> Back to the blog</a>
</main>
