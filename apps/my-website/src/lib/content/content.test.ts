import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { describe, expect, test } from 'vitest';
import { parseMarkdown } from './markdown.js';
import { formatDate } from './dates.js';
import { parseBlogPost, findBlogPost, sortBlogPosts } from '../blog/content.js';
import { parseProjectEntry, findProjectEntry, sortProjectEntries } from '../projects/content.js';

const blogFiles = readdirSync('content/blog').filter((filename) => filename.endsWith('.md'));
const projectFiles = readdirSync('content/projects').filter((filename) => filename.endsWith('.md'));
const posts = blogFiles.map((filename) => parseBlogPost(readFileSync(`content/blog/${filename}`, 'utf8'), filename));
const entries = projectFiles.map((filename) => parseProjectEntry(readFileSync(`content/projects/${filename}`, 'utf8'), filename));

describe('complete checked-in content corpus', () => {
  test('retains all 30 posts and 5 projects and sorts newest-first without mutation', () => {
    expect(posts).toHaveLength(30);
    expect(entries).toHaveLength(5);
    const sortedPosts = sortBlogPosts(posts);
    expect(sortedPosts[0].slug).toBe('/blog/posts/git-branching');
    expect(sortedPosts.at(-1)?.slug).toBe('/blog/posts/react-hooks-an-overview');
    const sortedEntries = sortProjectEntries(entries);
    expect(sortedEntries[0].slug).toBe('/projects/entries/my-website');
    expect(sortedEntries.at(-1)?.slug).toBe('/projects/entries/the-knotty-tales');
    expect(sortBlogPosts(posts)).not.toBe(posts);
    expect(sortProjectEntries(entries)).not.toBe(entries);
  });
  test.each(blogFiles)('parses every post and preserves its asset references: %s', (filename) => {
    const post = parseBlogPost(readFileSync(`content/blog/${filename}`, 'utf8'), filename);
    expect(post.author).toBe('Saikat Das');
    expect(post.tags.length).toBeGreaterThan(0);
    expect(post.bodyHtml.length).toBeGreaterThan(100);
    expect(existsSync(`public/assets/icons/post-topics/${post.icon}`)).toBe(true);
    for (const match of post.bodyHtml.matchAll(/src="(\/assets\/[^\"]+)"/g)) expect(existsSync(`public${match[1]}`)).toBe(true);
    expect(findBlogPost(posts, filename.replace(/\.md$/, ''))?.title).toBe(post.title);
  });
  test.each(projectFiles)('parses every project and preserves metadata and cover: %s', (filename) => {
    const entry = parseProjectEntry(readFileSync(`content/projects/${filename}`, 'utf8'), filename);
    expect(entry.author).toBe('Saikat Das');
    expect(entry.technologiesUsed.length).toBeGreaterThan(0);
    expect(existsSync(`public/assets/images/routes/projects/entries/${entry.coverPhoto}`)).toBe(true);
    expect(findProjectEntry(entries, filename.replace(/\.md$/, ''))?.title).toBe(entry.title);
  });
  test.each(['missing', 'GIT-BRANCHING', '../git-branching', 'git-branching.md', '/blog/posts/git-branching'])('does not return a different post for unknown slug %s', (slug) => {
    expect(findBlogPost(posts, slug)).toBeUndefined();
  });
  test.each(['missing', 'MY-WEBSITE', '../my-website', 'my-website.md'])('unknown project slug %s never returns content', (slug) => {
    expect(findProjectEntry(entries, slug)).toBeUndefined();
  });
  test('preserves exact dates and metadata', () => {
    const post = findBlogPost(posts, 'git-branching')!;
    expect(post.created).toBe('2021-07-27');
    expect(post.title).toBe('Using Git branches effectively: Creating, switching, deleting, tracking, renaming, publishing, merging, rebasing and comparing');
    const project = findProjectEntry(entries, 'go-bazzinga')!;
    expect([project.startDate, project.endDate]).toEqual(['2021-04-25', '2021-07-19']);
    expect(project.bodyHtml).toContain('/assets/images/projects/go-bazzinga/code-snapshot.jpg');
  });
});

describe('markdown rendering contract', () => {
  test('renders raw HTML tables strikethrough task lists footnotes autolinks and syntax classes', () => {
    const { bodyHtml } = parseMarkdown('\uFEFF---\ntitle: Test\n---\n<img src="/asset.png" alt="fixture">\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\n~~deleted~~\n\n- [x] done\n\nFootnote[^1]\n\n[^1]: note\n\nhttps://example.com\n\n```javascript\nconst count = 1;\n```');
    for (const fragment of ['<img src="/asset.png"', '<table>', '<s>deleted</s>', 'type="checkbox"', 'footnote', 'href="https://example.com"', 'language-javascript', 'token keyword']) expect(bodyHtml).toContain(fragment);
  });
  test('handles CRLF and YAML strings without losing body', () => {
    expect(parseMarkdown('---\r\ntitle: "2020-04-05"\r\n---\r\n# Heading').bodyHtml).toContain('<h1>Heading</h1>');
  });
  test.each(['no delimiters', '---\ntitle: Test', '---\n- invalid\n---\nbody', '---\ntitle: [\n---\nbody'])('malformed frontmatter fails explicitly: %s', (source) => {
    expect(() => parseMarkdown(source)).toThrow();
  });
  test('missing required metadata fails rather than silently discarding a page', () => {
    expect(() => parseBlogPost('---\ntitle: Test\n---\nbody', 'test.md')).toThrow('description');
    expect(() => parseProjectEntry('---\ntitle: Test\n---\nbody', 'test.md')).toThrow('description');
  });
});

describe('timezone-independent historical dates', () => {
  test('keeps zero-padded day and month ranges in every runtime timezone', () => {
    expect(formatDate('2020-04-05')).toBe('Sun Apr 05 2020');
    expect(formatDate('2021-07-27')).toBe('Tue Jul 27 2021');
    expect(formatDate('2021-04-25', true)).toBe('Apr 2021');
  });
  test.each(['not-a-date', '2021-02-30', '2021-13-01'])('invalid date remains unchanged: %s', (value) => {
    expect(formatDate(value)).toBe(value);
  });
});
