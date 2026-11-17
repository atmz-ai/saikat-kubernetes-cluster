<script lang="ts">
  import HomeScreen from '#lib/home/HomeScreen.svelte';
  import BlogScreen from '#lib/blog/BlogScreen.svelte';
  import PostScreen from '#lib/blog/PostScreen.svelte';
  import ProjectsScreen from '#lib/projects/ProjectsScreen.svelte';
  import EntryScreen from '#lib/projects/EntryScreen.svelte';
  import NotFoundScreen from '#lib/not-found/NotFoundScreen.svelte';
  import { previewPost } from '#lib/blog/BlogCardComponent.svelte';
  import { previewEntry } from '#lib/projects/ProjectCardComponent.svelte';
</script>

<h1>Offline fixture previews</h1>
<HomeScreen />
<BlogScreen />
<BlogScreen posts={[]} />
<BlogScreen posts={[{ ...previewPost, title: 'Long content '.repeat(16), description: 'Long description '.repeat(24) }]} />
<PostScreen />
<ProjectsScreen />
<ProjectsScreen entries={[]} />
<ProjectsScreen entries={[{ ...previewEntry, title: 'Long project title '.repeat(16) }]} />
<EntryScreen />
<NotFoundScreen />
