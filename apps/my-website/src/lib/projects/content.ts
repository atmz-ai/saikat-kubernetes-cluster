import { parseMarkdown, requiredString, requiredStrings } from '../content/markdown.js';

export interface ProjectEntry {
  title: string;
  description: string;
  author: string;
  technologiesUsed: string[];
  coverPhoto: string;
  startDate: string;
  endDate: string;
  slug: string;
  bodyHtml: string;
}

export function parseProjectEntry(source: string, filename: string): ProjectEntry {
  const { frontmatter, bodyHtml } = parseMarkdown(source);
  return {
    title: requiredString(frontmatter, 'title'),
    description: requiredString(frontmatter, 'description'),
    author: requiredString(frontmatter, 'author'),
    technologiesUsed: requiredStrings(frontmatter, 'technologiesUsed'),
    coverPhoto: requiredString(frontmatter, 'coverPhoto'),
    startDate: requiredString(frontmatter, 'startDate'),
    endDate: requiredString(frontmatter, 'endDate'),
    slug: `/projects/entries/${filename.replace(/\.md$/, '')}`,
    bodyHtml
  };
}

export function findProjectEntry(entries: readonly ProjectEntry[], slug: string): ProjectEntry | undefined {
  return entries.find((entry) => entry.slug === `/projects/entries/${slug}`);
}

export function sortProjectEntries(entries: readonly ProjectEntry[]): ProjectEntry[] {
  return [...entries].sort((first, second) => second.startDate.localeCompare(first.startDate));
}
