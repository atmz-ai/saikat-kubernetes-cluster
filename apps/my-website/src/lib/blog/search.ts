import type { BlogPost } from './content.js';

export function filterBlogPosts(posts: readonly BlogPost[], searchText: string): BlogPost[] {
  const query = searchText.toLowerCase();
  return posts.filter((post) => query === '' || post.title.toLowerCase().includes(query)
    || post.description.toLowerCase().includes(query)
    || post.tags.some((tag) => tag.toLowerCase().includes(query)));
}
