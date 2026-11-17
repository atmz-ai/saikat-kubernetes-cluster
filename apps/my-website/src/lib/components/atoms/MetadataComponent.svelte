<script lang="ts">
  let { title = "Saikat's Website", description = 'Offline metadata preview' }: { title?: string; description?: string } = $props();
</script>

<svelte:head>
  <title>{title}</title>
  <meta name="description" content={description} />
  <meta name="twitter:card" content="summary" />
  <meta name="twitter:site" content="@saikatdas0790" />
  <meta name="twitter:title" content={title} />
  <meta name="twitter:description" content={description} />
  <meta name="twitter:image" content="https://saikat.dev/assets/logos/logo-square-192.png" />
  <meta property="og:type" content="website" />
  <meta property="og:title" content={title} />
  <meta property="og:description" content={description} />
  <meta property="og:image" content="https://saikat.dev/assets/logos/logo-square-192.png" />
</svelte:head>
