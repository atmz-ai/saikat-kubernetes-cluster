<script lang="ts">
  import BlogScreen from '#lib/blog/BlogScreen.svelte';
  import type { PageProps } from './$types';
  let { data }: PageProps = $props();
</script>

<BlogScreen posts={data.posts} />
