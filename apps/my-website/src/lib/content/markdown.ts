import MarkdownIt from 'markdown-it';
import footnote from 'markdown-it-footnote';
import taskLists from 'markdown-it-task-lists';
import Prism from 'prismjs';
import 'prismjs/components/prism-bash.js';
import 'prismjs/components/prism-css.js';
import 'prismjs/components/prism-json.js';
import 'prismjs/components/prism-sql.js';
import { parse } from 'yaml';

export function parseMarkdown(source: string): { frontmatter: Record<string, unknown>; bodyHtml: string } {
  const match = source.replace(/^\uFEFF/, '').match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)([\s\S]*)$/);
  if (!match) throw new Error('Missing or malformed frontmatter delimiters');
  const frontmatter: unknown = parse(match[1]);
  if (!frontmatter || typeof frontmatter !== 'object' || Array.isArray(frontmatter)) {
    throw new Error('Frontmatter must be a YAML mapping');
  }
  const renderer = new MarkdownIt({
    html: true,
    linkify: true,
    typographer: true,
    highlight(code, language) {
      const grammar = Prism.languages[language];
      return grammar ? Prism.highlight(code, grammar, language) : '';
    }
  }).use(footnote).use(taskLists);
  return { frontmatter: frontmatter as Record<string, unknown>, bodyHtml: renderer.render(match[2].trim()) };
}

export function requiredString(frontmatter: Record<string, unknown>, key: string): string {
  const value = frontmatter[key];
  if (typeof value !== 'string' || !value) throw new Error(`Missing string frontmatter: ${key}`);
  return value;
}

export function requiredStrings(frontmatter: Record<string, unknown>, key: string): string[] {
  const value = frontmatter[key];
  if (!Array.isArray(value) || !value.every((item) => typeof item === 'string')) {
    throw new Error(`Missing string array frontmatter: ${key}`);
  }
  return value;
}
