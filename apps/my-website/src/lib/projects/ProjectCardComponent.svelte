<script lang="ts" module>
  import type { ProjectEntry } from './content.js';
  export const previewEntry: ProjectEntry = {
    title: 'My Personal Website', description: 'My personal website.', author: 'Saikat Das',
    technologiesUsed: ['SvelteJS', 'SvelteKit', 'TypeScript', 'TailwindCSS'],
    coverPhoto: 'my-website/my-website-cover.jpg', startDate: '2021-06-13', endDate: '2021-07-21',
    slug: '/projects/entries/my-website', bodyHtml: '<p>Offline project preview.</p>'
  };
</script>
<script lang="ts">
  import { formatDate } from '../content/dates.js';
  let { entry = previewEntry }: { entry?: ProjectEntry } = $props();
</script>

<li class="project-card">
  <a href={entry.slug}>
    <div class="project-cover"><img src="/assets/images/routes/projects/entries/{entry.coverPhoto}" alt="Screenshot of {entry.title}" width="1280" height="720" loading="lazy" /></div>
    <div class="project-card-body">
      <p class="content-date">{formatDate(entry.startDate, true)} <span aria-hidden="true">—</span> {formatDate(entry.endDate, true)}</p>
      <h2>{entry.title}<span class="card-arrow" aria-hidden="true">↗</span></h2>
      <p>{entry.description}</p>
      <div class="tag-list">{#each entry.technologiesUsed as technology}<span>{technology}</span>{/each}</div>
    </div>
  </a>
</li>
