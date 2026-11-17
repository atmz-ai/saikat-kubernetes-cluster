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

<li>
  <a href={post.slug} class="border-4 rounded-lg border-transparent block my-2 p-2 md:py-6">
    <div class="grid grid-cols-1">
      <img src="/assets/icons/post-topics/{post.icon}" alt="{post.icon.replace('.svg', '')} icon" class="justify-self-center h-32 my-8 md:row-span-4 md:w-24 md:h-auto md:mr-8 md:ml-4 md:my-0 md:self-center" loading="lazy" />
      <h2 class="font-bold text-2xl">{post.title}</h2>
      <span class="text-gray-400">published on <span class="text-emerald-600 font-medium">{formatDate(post.created)}</span></span>
      <p class="my-2">{post.description}</p>
      <span class="text-fuchsia-600">{post.tags.map((tag) => `#${tag}`).join(' ')}</span>
    </div>
  </a>
</li>
