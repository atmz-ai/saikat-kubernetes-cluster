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

<li class="border-4 rounded-lg border-transparent block my-2 p-2 md:py-6">
  <a href={entry.slug}>
    <img src="/assets/images/routes/projects/entries/{entry.coverPhoto}" alt="Large screenshot of landing page" width="1280" height="720" loading="lazy" />
    <h2 class="text-2xl font-medium my-2">{entry.title}</h2>
    <p>worked on this between <span class="font-semibold">{formatDate(entry.startDate, true)}</span> and <span class="font-semibold">{formatDate(entry.endDate, true)}</span></p>
    <p class="my-4">{entry.description}</p>
    <p class="text-fuchsia-600 text-sm">{entry.technologiesUsed.map((technology) => `#${technology}`).join(' ')}</p>
  </a>
</li>
