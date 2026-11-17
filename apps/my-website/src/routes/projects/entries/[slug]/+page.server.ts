import { error } from '@sveltejs/kit';
import { projectEntries } from '#lib/projects/content.server.js';
import { findProjectEntry } from '#lib/projects/content.js';
import type { EntryGenerator, PageServerLoad } from './$types';

export const prerender = 'auto';
export const entries: EntryGenerator = () => projectEntries.map((entry) => ({ slug: entry.slug.split('/').at(-1)! }));
export const load: PageServerLoad = ({ params }) => {
  const entry = findProjectEntry(projectEntries, params.slug);
  if (!entry) error(404, 'Project not found');
  return { entry };
};
