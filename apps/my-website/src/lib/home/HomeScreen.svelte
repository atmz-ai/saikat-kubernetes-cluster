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
</script>

<MetadataComponent title="Saikat's Website" description="This is a website where I blog about full stack JavaScript including things like SvelteJS, TailwindCSS, NodeJS, Linux, PostgreSQL among a few and showcase projects I've worked on" />
<main class="page-shell home-screen">
  <section class="home-hero">
    <div class="hero-copy">
      <p class="eyebrow"><span class="status-dot" aria-hidden="true"></span> Welcome to my corner of the internet</p>
      <h1>Hi, I'm Saikat<span class="heading-dot">.</span><span class="hero-wave" role="img" aria-label="Hi">👋</span></h1>
      <p class="hero-description">A programmer based out of <span class="hero-location"><span role="img" aria-label="India"><IndiaFlagComponent className="inline h-5" /></span> India.</span><br />Curious about code. Always building something.</p>
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
  <section class="profile-section">
  <div class="section-heading"><p class="eyebrow">The person behind the code</p><h2>A bit about me</h2></div>
  <article class="prose">
    <p>I'm elated to have discovered SvelteJS last year and since then have dived headfirst into the SvelteJS, TypeScript and TailwindCSS ecosystems. Was tinkering with static site generation, ReactJS and GatsbyJS prior to that.</p>
    <p>Have a decent amount of experience with NodeJS / ExpressJS. Have also gone through the docs on Apollo Server/GraphQL Nexus but haven't built any GraphQL servers yet. Understand the fundamentals though, so, shouldn't be difficult at all.</p>
    <p>Used Firebase (BaaS) for various projects to rapidly accelerate initial time to market. Am also quite competent with Google Cloud as a whole and used their products extensively. Huge proponent of the entire serverless movement. Google Cloud Run is a goto choice for all kinds of deployments.</p>
    <p>For databases, primarily used PostgreSQL and Firestore. Also used MongoDB and found it quite intuitive but haven't built any products on it as MongoDB Atlas costs are quite prohibitive at scale. Not a huge SQL fan but have working knowledge. Mostly use Prisma 2 to interact with PostgreSQL. Have also tinkered with Dgraph and FaunaDB but found them lacking.</p>
    <section>Also quite conversant with CI/CD workflows which include pushing to a Git repository and that triggering a list of steps such as:
      <ul><li>running DB migrations</li><li>running test suite</li><li>deploying to corresponding environment</li></ul>
      Used Google Cloud Build for this primarily. Aware of Github Actions.
    </section>
    <p>Decent experience with Figma to be able to quickly do some wireframes to put thought into form that can be collaborated/ideated on with a team.</p>
  </article>
  </section>
  <section class="profile-section">
  <div class="section-heading"><p class="eyebrow">Beyond engineering</p><h2>Orthogonal Skills</h2></div>
  <article class="prose"><p>Have worked as a product manager before, so I understand what it takes to build, manage, scale a product and the team behind it. Worked closely with customer support and on occasion, taken customer chats/calls to speak directly to end users and get feedback on products. Managed engineering teams with direct reportees, able to manage expectations and build rapport.</p></article>
  </section>
  <section class="profile-section">
  <div class="section-heading"><p class="eyebrow">Forever a student</p><h2>What I'm Learning</h2></div>
  <article class="prose"><ul>
    <li>Test driven development (TDD) especially in the context of testing frontend and backend apps. Exploring unit tests, integration tests and end-to-end (e2e) tests. As a library I'm favouring Jest for unit and integration and Playwright for end-to-end testing.</li>
    <li>Blockchains and building decentralized tokenized apps and smart contracts. I'm favouring Dfinity's Internet Computer (ICP) for this.</li>
    <li>WebAssembly and how to use them in web apps. Still exploring this space.</li>
  </ul></article>
  </section>
  <section class="profile-section">
  <div class="section-heading"><p class="eyebrow">On the workbench</p><h2>What I'm Working On</h2></div>
  <article class="prose"><p>I'm currently building the Go Bazzinga app as a progressive web app (PWA). You can check out what it's about <a href="/projects/entries/go-bazzinga" target="_blank" rel="noopener noreferrer">here</a> and the app <a href="https://gobazzinga.io" target="_blank" rel="noopener noreferrer">here</a></p></article>
  </section>
</main>
