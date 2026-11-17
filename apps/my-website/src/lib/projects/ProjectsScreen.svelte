<script lang="ts">
  import MetadataComponent from '../components/atoms/MetadataComponent.svelte';
  import ProjectCardComponent, { previewEntry } from './ProjectCardComponent.svelte';
  import type { ProjectEntry } from './content.js';
  let { entries = [previewEntry] }: { entries?: ProjectEntry[] } = $props();
</script>

<MetadataComponent title="Things I've Built" description="This is my portfolio of sorts where I document and showcase things I've built, going over their highlights or salient points." />
<main class="page-shell">
  <header class="page-heading">
    <p class="eyebrow">From idea to something real</p>
    <h1>Things I've Built<span class="heading-dot">.</span></h1>
    <p class="page-description">A collection of projects, experiments, and the details behind them.</p>
  </header>
  <ul class="project-grid" aria-label="Projects">{#each entries as entry (entry.slug)}<ProjectCardComponent {entry} />{/each}</ul>
  {#if entries.length === 0}<section class="empty-state"><h2>More to come.</h2><p>New projects will find a home here.</p></section>{/if}
</main>
