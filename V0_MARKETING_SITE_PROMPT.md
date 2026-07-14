# Foco marketing site prompt for v0.dev

```text
Design and build a premium, adoption-focused marketing website for the free “Foco” two-app ecosystem, a private native macOS workspace where everything stays local. Both apps are completely free. The site should make the Foco editor feel like a polished, desirable professional Mac app while positioning Foco View as the effortless way for anyone to open and experience a shared workspace. Do not make this look like a generic SaaS template or a Notion clone.

PRODUCT TRUTH
Foco is a two-app native macOS system for people who want the flexibility of Notion without accounts, servers, tracking, or cloud lock-in:

- “Foco” is the free creator/editor. It creates and edits `.bulb` workspaces, with pages, Markdown-friendly writing, links, saved AI prompts, PDFs, images, video, audio, and other attachments.
- “Foco View” is the free companion viewer. Anyone can install it to open, navigate, read, and experience a `.bulb` workspace. Clearly communicate that editing requires the separate Foco app, but that both apps are free.

Every workspace is one portable `.bulb` file. Move or share the file and the entire workspace moves with it. This creates a powerful distribution loop: creators make polished, self-contained workspaces in Foco; recipients experience them in Foco View. Both apps are free, work offline, require no account, and make no network requests. Foco uses the native macOS document system and requires macOS 14 or newer.

CORE POSITIONING
Lead with this idea: “Create in Foco. Share with anyone.”
Supporting message: “Build a complete private workspace in one portable `.bulb` file. Anyone can open it free with Foco View.”
Use “Your ideas. One file. Entirely yours.” as a recurring supporting line.
The emotional promise is calm ownership: no account, no subscription anxiety, no sync spinner, no surveillance, and no wondering where your work lives.
The adoption promise is equally important: create and edit for free; share finished `.bulb` workspaces with clients, collaborators, students, or friends who can view them free.

TARGET CUSTOMERS
- Privacy-conscious creators, researchers, writers, designers, developers, consultants, and students
- People who like Notion-style organization but do not want their knowledge base stored on someone else’s servers
- Mac users who value beautiful native software, durable files, offline access, and data ownership
- Professionals building research libraries, client workspaces, creative bibles, personal wikis, and project archives
- Teams and independent professionals who need to deliver rich, organized project files without accounts, subscriptions, or seat licenses

DESIGN DIRECTION
Create a sophisticated editorial Mac aesthetic: warm, minimal, tactile, and quietly confident. Use a warm ivory background (#F7F6F1), near-black text (#1C1C1A), soft stone surfaces, subtle 1px borders, and a restrained terracotta/coral accent close to #D15C40. Use generous whitespace, crisp typography, delicate shadows, and rounded corners between 14–24px. The visual identity includes a warm bulb/pen mark; represent it with a tasteful abstract bulb icon if the actual asset is unavailable.

Avoid neon gradients, purple AI styling, glassmorphism overload, giant empty headlines, fake enterprise logos, generic stock photography, and generic dashboard cards. Make the page feel designed for an excellent indie Mac app. Use subtle grain or paper texture only if performance remains excellent.

Use a refined sans-serif such as Geist or Inter for UI and a characterful editorial serif such as Newsreader for selective emphasis. Typography should be bold and highly legible. Keep the maximum content width around 1200px.

SITE STRUCTURE

1. STICKY NAVIGATION
- Left: Foco bulb mark and wordmark
- Center/right links: Why Foco, Foco View, How it works, Features, Privacy, FAQ
- Secondary CTA: “Download Foco View — Free”
- Primary CTA: “Download Foco — Free”
- Small platform note near CTA: “macOS 14+”
- On mobile, use a clean accessible menu

2. HERO — SELL CREATION AND FRICTIONLESS SHARING
Eyebrow: “Create privately. Share freely.”
Headline: “Create in Foco. Share with anyone.”
Body: “Build notes, research, media, and project context into one portable `.bulb`. Send the file anywhere—anyone can open it free with Foco View.”
Primary CTA: “Download Foco — Free”
Secondary CTA: “Download Foco View — Free”
Tertiary text link: “See how a .bulb works”
Trust row: “Free viewer” · “No account” · “Works offline” · “No analytics” · “Native macOS”

Show a large, highly polished product mockup of Foco in a realistic macOS window. It should include:
- Warm left sidebar with a workspace named “Brand Research”
- Pages such as Overview, Customer Interviews, Visual References, Launch Plan
- A focused editor with a strong page title, clean body copy, and inline PDF/image previews
- A slash-command menu displaying Text, Heading, Prompt, Board, PDF, Image, Video, and File
- A subtle top-bar status reading “Private” and “Saved locally”
- A small floating `.bulb` file card moving visually from the Foco editor window to a second, simpler “Foco View” window
Use CSS/HTML mock UI rather than relying on an external screenshot so the result is responsive and sharp.

3. PROBLEM / CONTRAST SECTION
Headline: “Your workspace shouldn’t disappear when the Wi-Fi does.”
Create a tasteful two-column comparison:
Typical cloud workspace: account required, data on company servers, internet dependency, proprietary cloud silo, tracking and analytics.
Foco: open the file, work offline, keep every asset together, move or back it up anywhere, no telemetry.
Keep the tone confident and factual, not alarmist.

4. TWO APPS, ONE SEAMLESS FORMAT
Headline: “Make it in Foco. Open it free in Foco View.”
Create a highly legible two-column product presentation:

Foco — Free editor
- Create new `.bulb` workspaces
- Write, organize, and edit pages
- Add PDFs, images, video, audio, prompts, and files
- Designed for creators, professionals, and anyone producing work worth sharing
- CTA: “Get the Foco editor”

Foco View — Free viewer
- Open and navigate any `.bulb` workspace
- Read pages and experience included media
- Works locally and offline
- Designed for clients, collaborators, students, friends, and every recipient
- CTA: “Download Foco View free”

Between the two product cards, show a `.bulb` file traveling from creator to recipient. Add the line: “Free to create. Free to share. Free to view.” Make the distinction between the editor and viewer unmissable while showing that neither requires payment.

5. THE `.BULB` DIFFERENTIATOR
Headline: “A whole workspace in one file.”
Explain that `Research.bulb` is a real portable file containing readable Markdown pages and original attachments. Moving, duplicating, archiving, or backing up that one file moves the entire workspace.
Build an animated or interactive exploded-file visual:
Research.bulb → Pages / Notes / PDFs / Images / Video / Audio / Prompts
Include three concise benefits: “Portable by default,” “Built from durable formats,” and “Back up anywhere you choose.”
Do not overexplain ZIP internals on the main page; keep deeper technical detail in a disclosure labeled “For the curious.”

6. FEATURE STORY — ONE CONTINUOUS WORKFLOW
Headline: “Everything your project needs. Nothing it doesn’t.”
Use an alternating editorial layout with product UI scenes for:
- Organize naturally: page hierarchy and focused navigation
- Write at the speed of thought: Markdown-friendly editor and `/` command menu
- Keep source material close: drag in PDFs, images, video, audio, and files from Finder
- Preview without leaving your work: inline native media and PDF previews, including offline video playback
- Save prompts beside the work they support: locally stored prompt blocks, without pretending Foco itself is an AI service
- Trust the save: native macOS autosave and standard document behavior
- Share without seat licenses: recipients use Foco View, while creators use the separate free Foco editor

7. USE-CASE CARDS
Headline: “One calm home for work worth keeping.”
Create four premium cards with miniature UI previews:
- Research vault — notes, papers, interviews, and citations
- Creative project bible — references, drafts, images, and footage
- Client workspace — briefs, deliverables, decisions, and source files
- Course or resource pack — lessons, readings, references, and media that students can open free
- Personal knowledge base — durable notes without a cloud landlord
Each card should have outcome-led copy, not a feature dump.

8. PRIVACY MANIFESTO
Use a dark near-black section with warm ivory type and restrained coral accents.
Headline: “Private isn’t a setting. It’s the architecture.”
Copy: “Foco and Foco View have no account system, server, sync engine, analytics SDK, or required internet connection. Your URLs remain text until you choose to open them. Your work lives where you put it.”
Add a simple privacy checklist and a visual of a Mac → `.bulb` file → user-chosen backup destination. Do not imply encryption unless explicitly implemented.

9. TESTIMONIAL / SOCIAL PROOF PLACEHOLDERS
Include a compact testimonial area, but clearly use editable placeholder content such as “[Customer quote]” and “[Name, role]”. Do not invent customer counts, ratings, publications, company logos, or endorsements. Make it easy to replace this section when real proof exists.

10. FREE DOWNLOAD CTA
Use two complementary product cards with the Foco editor visually primary. Make “Free” prominent on both cards. Do not include pricing, checkout language, trials, subscriptions, license tiers, or purchase UI.
Headline: “Create for free. Share without friction.”

Primary card — Foco
Label: “Create + Edit”
Price: “Free”
Include: native macOS editor, offline use, unlimited local workspaces, all current core editing features, and no account required.
CTA: “Download Foco — Free”

Companion card — Foco View
Label: “View”
Price: “Free”
Include: open and navigate `.bulb` workspaces, experience included content and media, offline use, and no account required. Do not suggest that Foco View can edit files.
CTA: “Download Foco View — Free”

Secondary microcopy: “Requires macOS 14 or later.”
Do not claim lifetime updates unless supplied later.

11. FAQ
Include accessible accordion answers for:
- What is a `.bulb` file?
- What is the difference between Foco and Foco View?
- Are both Foco apps really free?
- Can people view my workspace without installing the editor?
- Can I edit a `.bulb` in Foco View?
- Does Foco work without internet?
- Where is my data stored?
- Can I use iCloud Drive, Dropbox, or an external drive?
- What happens if Foco goes away?
- Does Foco collect analytics?
- Which Mac versions are supported?
Keep answers grounded in the product truth. Explain that users may place the portable file in a folder managed by their preferred storage provider, but do not claim that Foco currently ships its own sync service.

12. FINAL CTA AND FOOTER
Headline: “Make something worth sharing.”
Supporting copy: “Create it privately in Foco. Send one file. Let anyone open it free.”
Primary CTA: “Download Foco — Free”
Secondary CTA: “Download Foco View — Free”
Footer links: Product, Privacy, Changelog, Support, Terms
Add a small line: “Two native Mac apps. One portable format. Your work stays local.”

INTERACTIONS AND MOTION
- Smooth anchor navigation
- Restrained scroll reveals using opacity and 12–20px vertical movement
- Gentle parallax or layered motion on the `.bulb` exploded-file visual
- Hover states that feel native and precise
- Respect `prefers-reduced-motion`
- Avoid excessive animation that undermines trust or performance

IMPLEMENTATION REQUIREMENTS
- Build with Next.js App Router, TypeScript, Tailwind CSS, and shadcn/ui where useful
- Create clean reusable sections and components
- Use Lucide icons sparingly
- Responsive from 360px mobile through large desktop
- Excellent accessibility: semantic landmarks, keyboard navigation, visible focus, meaningful labels, strong contrast
- Aim for Lighthouse-ready performance; avoid heavy libraries and remote assets unless essential
- Include complete polished copy rather than lorem ipsum, except for explicitly labeled testimonial placeholders
- Use separate configurable download URL placeholders for Foco and Foco View
- Add sensible SEO metadata: title, description, Open Graph copy, and product-focused structured data without fabricated ratings
- Make the final result feel launch-ready, highly credible, emotionally resonant, and premium

COPY TONE
Concise, intelligent, reassuring, and specific. Write for discerning Mac users. Sell freedom, permanence, focus, ownership, and frictionless sharing. Consistently distinguish the free Foco editor from the free Foco View app. Avoid fearmongering, empty superlatives, startup jargon, “revolutionary,” “second brain,” and unsupported claims.
```
