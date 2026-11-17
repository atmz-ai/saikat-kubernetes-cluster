import { projectEntries } from '#lib/projects/content.server.js';
import type { PageServerLoad } from './$types';

export const prerender = true;
export const load: PageServerLoad = () => ({ entries: projectEntries.map(({ bodyHtml, ...entry }) => ({ ...entry, bodyHtml: '' })) });
