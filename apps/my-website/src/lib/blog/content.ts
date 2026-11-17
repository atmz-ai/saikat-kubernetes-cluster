import { parseMarkdown, requiredString, requiredStrings } from '../content/markdown.js';

export interface BlogPost {
  title: string;
  description: string;
  author: string;
  tags: string[];
  icon: string;
  created: string;
  slug: string;
  bodyHtml: string;
}

export function parseBlogPost(source: string, filename: string): BlogPost {
  const { frontmatter, bodyHtml } = parseMarkdown(source);
  return {
    title: requiredString(frontmatter, 'title'),
    description: requiredString(frontmatter, 'description'),
    author: requiredString(frontmatter, 'author'),
    tags: requiredStrings(frontmatter, 'tags'),
    icon: requiredString(frontmatter, 'icon'),
    created: requiredString(frontmatter, 'date'),
    slug: `/blog/posts/${filename.replace(/\.md$/, '')}`,
    bodyHtml
  };
}

export function findBlogPost(posts: readonly BlogPost[], slug: string): BlogPost | undefined {
  return posts.find((post) => post.slug === `/blog/posts/${slug}`);
}

export function sortBlogPosts(posts: readonly BlogPost[]): BlogPost[] {
  return [...posts].sort((first, second) => second.created.localeCompare(first.created));
}
