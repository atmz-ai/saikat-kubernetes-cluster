<script lang="ts">
	import '../../style/tailwind.css';
	import NavigationComponent from '#lib/navigation/NavigationComponent.svelte';
	import type { LayoutProps } from './$types';

	let { children }: LayoutProps = $props();
</script>

<svelte:head>
	<link rel="icon" href="/favicon.png" />
	<link rel="manifest" href="/manifest.webmanifest" />
	<meta name="theme-color" content="#10B981" />
</svelte:head>

{@render children()}
<NavigationComponent />
