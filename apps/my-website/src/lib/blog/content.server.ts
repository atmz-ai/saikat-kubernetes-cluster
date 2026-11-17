import { parseBlogPost, sortBlogPosts } from './content.js';

const sources = import.meta.glob('../../../content/blog/*.md', { query: '?raw', import: 'default', eager: true });

export const blogPosts = sortBlogPosts(Object.entries(sources).map(([path, source]) => {
  const filename = path.split('/').at(-1)!;
  return parseBlogPost(String(source), filename);
}));
