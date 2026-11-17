<script lang="ts">
  import MetadataComponent from '../components/atoms/MetadataComponent.svelte';
  import { formatDate } from '../content/dates.js';
  import { previewEntry } from './ProjectCardComponent.svelte';
  import type { ProjectEntry } from './content.js';
  let { entry = previewEntry, preview = false }: { entry?: ProjectEntry; preview?: boolean } = $props();
</script>

<MetadataComponent title={entry.title} description={entry.description} />
<article class="prose prose-emerald max-w-screen-md mx-auto my-8 px-4">
  <h1 class="!mb-2">{entry.title}</h1>
  <span class="text-gray-400">worked on between <span class="text-emerald-600 font-medium">{formatDate(entry.startDate, true)}</span> to <span class="text-emerald-600 font-medium">{formatDate(entry.endDate, true)}</span></span>
  <div>{@html preview ? previewEntry.bodyHtml : entry.bodyHtml}</div>
  <h2>This Project Uses</h2>
  <ul>{#each entry.technologiesUsed as technology}<li>{technology}</li>{/each}</ul>
</article>
