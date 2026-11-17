import { error } from '@sveltejs/kit';

export function load(): never { error(404, 'Page not found'); }
