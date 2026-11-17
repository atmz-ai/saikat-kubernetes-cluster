<script lang="ts" module>
  import type { BlogPost } from './content.js';
  export const previewPost: BlogPost = {
    title: 'React Hooks: useState', description: 'A gentle introduction to the React Hook useState',
    author: 'Saikat Das', tags: ['react', 'reactjs', 'hooks'], created: '2019-08-29', icon: 'react.png',
    slug: '/blog/posts/react-hooks-usestate', bodyHtml: '<p>Offline article preview.</p>'
  };
</script>
<script lang="ts">
  import { formatDate } from '../content/dates.js';
  let { post = previewPost }: { post?: BlogPost } = $props();
</script>

<li class="article-card">
  <a href={post.slug}>
    <div class="topic-icon"><img src="/assets/icons/post-topics/{post.icon}" alt="" width="64" height="64" loading="lazy" /></div>
    <div class="article-card-body">
      <time class="content-date" datetime={post.created}>{formatDate(post.created)}</time>
      <h2>{post.title}</h2>
      <p>{post.description}</p>
      <div class="tag-list">{#each post.tags as tag}<span>#{tag}</span>{/each}</div>
    </div>
    <span class="card-arrow" aria-hidden="true">↗</span>
  </a>
</li>
