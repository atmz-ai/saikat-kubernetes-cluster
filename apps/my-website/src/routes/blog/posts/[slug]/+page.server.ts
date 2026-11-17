import { error } from '@sveltejs/kit';
import { blogPosts } from '#lib/blog/content.server.js';
import { findBlogPost } from '#lib/blog/content.js';
import type { EntryGenerator, PageServerLoad } from './$types';

export const prerender = 'auto';
export const entries: EntryGenerator = () => blogPosts.map((post) => ({ slug: post.slug.split('/').at(-1)! }));
export const load: PageServerLoad = ({ params }) => {
  const post = findBlogPost(blogPosts, params.slug);
  if (!post) error(404, 'Post not found');
  return { post };
};
