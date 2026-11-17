<script lang="ts">
  import MetadataComponent from '../components/atoms/MetadataComponent.svelte';
  import ProjectCardComponent, { previewEntry } from './ProjectCardComponent.svelte';
  import type { ProjectEntry } from './content.js';
  let { entries = [previewEntry] }: { entries?: ProjectEntry[] } = $props();
</script>

<MetadataComponent title="Things I've Built" description="This is my portfolio of sorts where I document and showcase things I've built, going over their highlights or salient points." />
<main class="max-w-screen-md mx-auto p-2">
  <h1 class="text-3xl text-center my-8">Things I've Built</h1>
  <ul>{#each entries as entry (entry.slug)}<ProjectCardComponent {entry} />{/each}</ul>
</main>
