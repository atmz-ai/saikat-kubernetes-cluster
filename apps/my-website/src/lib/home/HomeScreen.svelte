<script lang="ts">
  import MetadataComponent from '../components/atoms/MetadataComponent.svelte';
  import GithubComponent from './icons/GithubComponent.svelte';
  import GmailComponent from './icons/GmailComponent.svelte';
  import LinkedinComponent from './icons/LinkedinComponent.svelte';
  import NpmComponent from './icons/NpmComponent.svelte';
  import StackOverflowComponent from './icons/StackOverflowComponent.svelte';
  import SvelteComponent from './icons/SvelteComponent.svelte';
  import IndiaFlagComponent from './icons/IndiaFlagComponent.svelte';

  const socialLinks = [
    { href: 'https://saikat.dev', label: 'My Website', icon: SvelteComponent },
    { href: 'https://github.com/saikatdas0790', label: 'Github', icon: GithubComponent },
    { href: 'https://www.npmjs.com/~saikatdas0790', label: 'NPM', icon: NpmComponent },
    { href: 'mailto:saikatdas0790@gmail.com', label: 'Email', icon: GmailComponent },
    { href: 'https://www.linkedin.com/in/saikat-das-13674166/', label: 'LinkedIn', icon: LinkedinComponent },
    { href: 'https://stackoverflow.com/users/3462837/saikat-das', label: 'Stack Overflow', icon: StackOverflowComponent }
  ];

  const skillAreas = [
    { title: 'Services & systems', description: 'Rust services, asynchronous application integration, and authenticated APIs.', technologies: ['Rust', 'Python', 'Kotlin', 'HTTP APIs'] },
    { title: 'Cloud-native infrastructure', description: 'Kubernetes platforms, declarative deployments, and Linux fleet automation.', technologies: ['Kubernetes', 'Flux', 'Ansible', 'Linux', 'Helm'] },
    { title: 'Web interfaces', description: 'Server-rendered interfaces with typed state machines and browser-tested interactions.', technologies: ['TypeScript', 'SvelteKit', 'XState', 'Playwright'] },
    { title: 'Data & integration', description: 'Storage clients, database operators, identity flows, and typed service contracts.', technologies: ['PostgreSQL', 'S3-compatible storage', 'OAuth / PKCE', 'OpenAPI'] },
    { title: 'Developer workflows', description: 'Repeatable development environments and build, test, and deployment pipelines.', technologies: ['GitHub Actions', 'Devcontainers', 'mise', 'Automated testing'] },
    { title: 'AI-enabled applications', description: 'Application and API integration, including compatibility work for generated clients.', technologies: ['FastAPI', 'API contracts', 'Typed clients'] }
  ];
</script>

<MetadataComponent title="Saikat's Website" description="Saikat Das builds full-stack software and the infrastructure behind it: Rust services, Kubernetes GitOps, authenticated APIs, and TypeScript interfaces." />
<main class="page-shell home-screen">
  <section class="home-hero">
    <div class="hero-copy">
      <p class="eyebrow"><span class="status-dot" aria-hidden="true"></span> Welcome to my corner of the internet</p>
      <h1>Hi, I'm Saikat<span class="heading-dot">.</span><span class="hero-wave" role="img" aria-label="Hi">👋</span></h1>
      <p class="hero-description">A full-stack systems engineer based out of <span class="hero-location"><span role="img" aria-label="India"><IndiaFlagComponent className="inline h-5" /></span> India.</span><br />I build software and the systems behind it.</p>
      <p class="hero-interests">I like <span role="img" aria-label="computers">🖥️</span> computers and <span role="img" aria-label="gaming">🎮</span> gaming.</p>
      <div class="hero-actions">
        <a class="button-link" href="/projects">Explore my work <span aria-hidden="true">↗</span></a>
        <a class="quiet-link" href="/blog">Read the blog <span aria-hidden="true">→</span></a>
      </div>
    </div>
    <div class="hero-note" aria-hidden="true">
      <span class="note-label">A work in progress, just like me.</span>
      <span class="note-code">&lt;hello<br /><span>world</span> /&gt;</span>
      <span class="note-footer">Learn. Build. Share. Repeat.</span>
    </div>
  </section>
  <section class="social-section">
    <div class="section-heading"><h2>Find me at</h2><p>Around the web, or just an email away.</p></div>
    <ul class="social-grid">
      {#each socialLinks as socialLink (socialLink.href)}
        <li><a href={socialLink.href} target="_blank" rel="noopener noreferrer"><span class="social-icon"><socialLink.icon className="w-5 h-5" /></span><span>{socialLink.label}</span><span class="social-arrow" aria-hidden="true">↗</span></a></li>
      {/each}
    </ul>
  </section>
  <section class="skills-section" aria-labelledby="skills-heading">
    <div class="section-heading"><p class="eyebrow">Across application and infrastructure boundaries</p><h2 id="skills-heading">What I work with</h2></div>
    <ul class="skills-grid">
      {#each skillAreas as skillArea (skillArea.title)}
        <li><h3>{skillArea.title}</h3><p>{skillArea.description}</p><div class="tag-list">{#each skillArea.technologies as technology}<span>{technology}</span>{/each}</div></li>
      {/each}
    </ul>
  </section>
  <section class="profile-section">
  <div class="section-heading"><p class="eyebrow">The person behind the code</p><h2>A bit about me</h2></div>
  <article class="prose">
    <p>I build full-stack software and the infrastructure behind it, from Rust services and authenticated APIs to TypeScript and SvelteKit interfaces. My work spans Linux automation, Kubernetes GitOps, storage integrations, observability, and reproducible build and test pipelines.</p>
    <p>Recent work has focused on declarative infrastructure with Flux and Ansible, typed service contracts, and explicit state machines. I care about making systems understandable, testable, and repeatable, not just getting them to run once.</p>
    <p>I also contribute to AI-enabled applications and their API integrations. Earlier work includes Internet Computer applications, canister integration, and WebAssembly build and test workflows.</p>
  </article>
  </section>
  <section class="profile-section">
  <div class="section-heading"><p class="eyebrow">Beyond engineering</p><h2>Orthogonal Skills</h2></div>
  <article class="prose"><p>I've also worked in product management and managed engineering teams. Working with customer support and speaking directly with users has shaped how I approach engineering: understand the problem, communicate clearly, and connect technical decisions to the people using the product.</p></article>
  </section>
  <section class="profile-section">
  <div class="section-heading"><p class="eyebrow">Forever a student</p><h2>What I'm Learning</h2></div>
  <article class="prose"><ul>
    <li>Native Apple-app development with Swift and SwiftUI. This is an active learning focus, rather than an established production specialty.</li>
    <li>Applying typed states and events across interfaces and service workflows, building on my Rust and XState work.</li>
  </ul></article>
  </section>
  <section class="profile-section">
  <div class="section-heading"><p class="eyebrow">On the workbench</p><h2>What I'm Working On</h2></div>
  <article class="prose"><p>I'm maintaining a self-hosted Kubernetes platform and the development workflows around it. This website is part of that work: SvelteKit and TypeScript for the interface, XState for interactive lifecycles, and automated tests and GitOps for delivery.</p><p>You can explore <a href="https://github.com/atmz-ai/saikat-kubernetes-cluster" target="_blank" rel="noopener noreferrer">the platform and this site's source</a>, browse <a href="https://github.com/saikatdas0790" target="_blank" rel="noopener noreferrer">my recent work on GitHub</a>, or look through <a href="/projects">earlier projects</a>.</p></article>
  </section>
</main>
