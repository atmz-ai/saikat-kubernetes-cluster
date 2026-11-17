<script lang="ts">
	import '../../style/tailwind.css';
	import NavigationComponent from '#lib/navigation/NavigationComponent.svelte';
	import type { LayoutProps } from './$types';

	let { children }: LayoutProps = $props();
</script>

<svelte:head>
	<link rel="icon" href="/favicon.png" />
	<link rel="manifest" href="/manifest.webmanifest" />
	<meta name="color-scheme" content="light dark" />
	<meta name="theme-color" content="#f6f7f3" media="(prefers-color-scheme: light)" />
	<meta name="theme-color" content="#101917" media="(prefers-color-scheme: dark)" />
</svelte:head>

<a class="skip-link" href="#main-content">Skip to content</a>
<NavigationComponent />
<div id="main-content" tabindex="-1">{@render children()}</div>
<footer class="site-footer">
	<p>Saikat Das <span aria-hidden="true">/</span> A little corner of the web.</p>
	<p class="appearance-note">Light or dark, at home on your device.</p>
</footer>
