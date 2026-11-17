import { parseProjectEntry, sortProjectEntries } from './content.js';

const sources = import.meta.glob('../../../content/projects/*.md', { query: '?raw', import: 'default', eager: true });

export const projectEntries = sortProjectEntries(Object.entries(sources).map(([path, source]) => {
  const filename = path.split('/').at(-1)!;
  return parseProjectEntry(String(source), filename);
}));
