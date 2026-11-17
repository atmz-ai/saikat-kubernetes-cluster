<script lang="ts">
  import EntryScreen from '#lib/projects/EntryScreen.svelte';
  import type { PageProps } from './$types';
  let { data }: PageProps = $props();
</script>

<EntryScreen entry={data.entry} />
