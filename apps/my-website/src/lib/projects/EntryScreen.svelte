<script lang="ts">
  import MetadataComponent from '../components/atoms/MetadataComponent.svelte';
  import { formatDate } from '../content/dates.js';
  import { previewEntry } from './ProjectCardComponent.svelte';
  import type { ProjectEntry } from './content.js';
  let { entry = previewEntry, preview = false }: { entry?: ProjectEntry; preview?: boolean } = $props();
</script>

<MetadataComponent title={entry.title} description={entry.description} />
<main class="page-shell reading-shell">
  <a class="back-link" href="/projects"><span aria-hidden="true">←</span> All projects</a>
  <article class="prose reading-content">
    <header class="article-heading">
      <p class="eyebrow">Project journal</p>
      <h1>{entry.title}</h1>
      <p class="content-date">{formatDate(entry.startDate, true)} <span aria-hidden="true">—</span> {formatDate(entry.endDate, true)}</p>
    </header>
    <div>{@html preview ? previewEntry.bodyHtml : entry.bodyHtml}</div>
    <h2>This Project Uses</h2>
    <ul>{#each entry.technologiesUsed as technology}<li>{technology}</li>{/each}</ul>
  </article>
  <a class="back-link article-end" href="/projects"><span aria-hidden="true">←</span> Explore more projects</a>
</main>
