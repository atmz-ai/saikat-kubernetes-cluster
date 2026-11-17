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
    { href: 'https://saikat.dev', label: 'My Website', border: 'border-yellow-600', icon: SvelteComponent },
    { href: 'https://github.com/saikatdas0790', label: 'Github', border: 'border-black', icon: GithubComponent },
    { href: 'https://www.npmjs.com/~saikatdas0790', label: 'NPM', border: 'border-red-600', icon: NpmComponent },
    { href: 'mailto:saikatdas0790@gmail.com', label: 'Email', border: 'border-red-500', icon: GmailComponent },
    { href: 'https://www.linkedin.com/in/saikat-das-13674166/', label: 'LinkedIn', border: 'border-blue-700', icon: LinkedinComponent },
    { href: 'https://stackoverflow.com/users/3462837/saikat-das', label: 'Stack Overflow', border: 'border-yellow-500', icon: StackOverflowComponent }
  ];
</script>

<MetadataComponent title="Saikat's Website" description="This is a website where I blog about full stack JavaScript including things like SvelteJS, TailwindCSS, NodeJS, Linux, PostgreSQL among a few and showcase projects I've worked on" />
<main class="max-w-screen-md mx-auto p-2 mb-8">
  <section class="text-xl mt-8 border-l-4 pl-8 border-fuchsia-500">
    <p><span role="img" aria-label="Hi">👋</span>, I'm Saikat!<br />
      I'm a programmer based out of <span role="img" aria-label="India" class="align-text-bottom"><IndiaFlagComponent className="inline h-5" /></span><br />
      I like <span role="img" aria-label="computers">🖥️</span> and <span role="img" aria-label="gaming">🎮</span><br />
      Connect with me on <a href="https://www.linkedin.com/in/saikat-das-13674166/" target="_blank" rel="noopener noreferrer"><span role="img" aria-label="LinkedIn" class="align-text-bottom"><LinkedinComponent className="inline h-5" /></span></a>
      or <a href="https://github.com/saikatdas0790" target="_blank" rel="noopener noreferrer"><span role="img" aria-label="github" class="align-text-bottom"><GithubComponent className="inline h-5" /></span></a>
    </p>
  </section>
  <article>
    <h2 class="text-3xl my-8 mt-16">Find me at</h2>
    <ul class="grid grid-cols-2 md:grid-cols-3">
      {#each socialLinks as link (link.href)}
        <li class="mb-4"><a href={link.href} target="_blank" rel="noopener noreferrer" class="flex gap-2 items-center text-xl p-4 border-l-2 {link.border} hover:shadow-md transition duration-300"><link.icon className="w-5 h-5" /><span>{link.label}</span></a></li>
      {/each}
    </ul>
  </article>
  <h2 class="text-3xl my-8">A bit about me</h2>
  <article class="prose prose-emerald">
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
  <h2 class="text-3xl my-8">Orthogonal Skills</h2>
  <article class="prose prose-emerald"><p>Have worked as a product manager before, so I understand what it takes to build, manage, scale a product and the team behind it. Worked closely with customer support and on occasion, taken customer chats/calls to speak directly to end users and get feedback on products. Managed engineering teams with direct reportees, able to manage expectations and build rapport.</p></article>
  <h2 class="text-3xl my-8">What I'm Learning</h2>
  <article class="prose prose-emerald"><ul>
    <li>Test driven development (TDD) especially in the context of testing frontend and backend apps. Exploring unit tests, integration tests and end-to-end (e2e) tests. As a library I'm favouring Jest for unit and integration and Playwright for end-to-end testing.</li>
    <li>Blockchains and building decentralized tokenized apps and smart contracts. I'm favouring Dfinity's Internet Computer (ICP) for this.</li>
    <li>WebAssembly and how to use them in web apps. Still exploring this space.</li>
  </ul></article>
  <h2 class="text-3xl my-8">What I'm Working On</h2>
  <article class="prose prose-emerald"><p>I'm currently building the Go Bazzinga app as a progressive web app (PWA). You can check out what it's about <a href="/projects/entries/go-bazzinga" target="_blank" rel="noopener noreferrer">here</a> and the app <a href="https://gobazzinga.io" target="_blank" rel="noopener noreferrer">here</a></p></article>
</main>
