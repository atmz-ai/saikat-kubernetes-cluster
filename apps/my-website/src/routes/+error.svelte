<script lang="ts">
  import { page } from '$app/state';
  import NotFoundScreen from '#lib/not-found/NotFoundScreen.svelte';
</script>

<svelte:head><title>Saikat's Website</title></svelte:head>
{#if page.status === 404}<NotFoundScreen />{:else}<main class="max-w-screen-md mx-auto p-2"><h1>{page.status}</h1><p>{page.error?.message}</p></main>{/if}
