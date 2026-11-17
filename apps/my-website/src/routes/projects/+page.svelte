<script lang="ts">
  import ProjectsScreen from '#lib/projects/ProjectsScreen.svelte';
  import type { PageProps } from './$types';
  let { data }: PageProps = $props();
</script>

<ProjectsScreen entries={data.entries} />
