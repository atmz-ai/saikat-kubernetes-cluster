<script lang="ts">
  import PostScreen from '#lib/blog/PostScreen.svelte';
  import type { PageProps } from './$types';
  let { data }: PageProps = $props();
</script>

<PostScreen post={data.post} />
