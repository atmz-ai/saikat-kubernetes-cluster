import { blogPosts } from '#lib/blog/content.server.js';
import type { PageServerLoad } from './$types';

export const prerender = true;
export const load: PageServerLoad = () => ({ posts: blogPosts.map(({ bodyHtml, ...post }) => ({ ...post, bodyHtml: '' })) });
