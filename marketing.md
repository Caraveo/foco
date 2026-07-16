# Foco Marketing Site Prompt for v0.dev

This document contains a structured, high-fidelity prompt optimized for [v0.dev](https://v0.dev). Copy and paste the block below directly into v0 to generate a premium, native-feeling, responsive React landing page styled with Tailwind CSS.

***

```text
Create a premium, responsive landing page in React for "Foco" (a native macOS, document-based local-first workspace). The landing page must feel like a high-end editorial site for a polished, independent macOS application—warm, minimal, tactile, and highly professional. Avoid generic SaaS templates, generic neon dashboards, or direct Notion clones.

### 1. DESIGN SYSTEM & COLOR PALETTE
Implement a warm editorial Mac aesthetic:
- Background: Warm Ivory (`#F7F6F1`)
- Text Primary: Near-black (`#1C1C1A`)
- Text Secondary: Muted charcoal (`#55534E`)
- Accent color: Restrained Terracotta / Coral (`#D15C40` or Tailwind equivalent `bg-[#D15C40]`, `text-[#D15C40]`)
- Secondary surfaces: Warm Stone (`#ECEAE4` or `bg-[#ECEAE4]`)
- Borders: Subtle 1px lines (`#E2DFD7` or `border-[#E2DFD7]`)
- Shadows: Minimal, delicate, elevation-based.
- Fonts: Use a clean modern sans-serif (e.g., Inter/Geist) for UI/body, and a classic editorial serif (e.g., Newsreader/Playfair Display) for headlines and selective emphasis.
- Border radius: Highly rounded cards (16px to 24px) to feel tactile and modern.

### 2. PAGE STRUCTURE & SECTIONS

#### NAVIGATION HEADER
- Sticky header with background blur (`backdrop-blur-md bg-[#F7F6F1]/80`) and a subtle bottom border.
- Left: An abstract vector pen/bulb logo (representing the `.bulb` format) and "Foco" in a semi-bold serif.
- Center: Navigation links: "Why Foco", "Foco View", "How It Works", "Features", "Privacy", "FAQ".
- Right:
  - Text button: "Download Foco View (Free)"
  - Button: "Download Foco (Free)" (styled in terracotta background with white text, hover effect).
  - Subtext below buttons: "macOS 14+" in size 10px.

#### HERO SECTION
- Eyebrow: "Create privately. Share freely." (serif, italic, terracotta text)
- Headline: "Create in Foco. Share with anyone." (large, bold sans-serif, size 4xl to 6xl, tracking tight)
- Body: "Build notes, research, media, and project context into a single portable .bulb file. Send the file anywhere—anyone can open and experience it free with Foco View."
- CTAs (centered):
  - Primary button: "Download Foco — Free Editor" (Terracotta bg, large, rounded-full)
  - Secondary button: "Download Foco View — Free Viewer" (Stone outline, large, rounded-full)
  - Text link: "See how a .bulb works →"
- Trust badges below: "Free Editor & Viewer" · "No Accounts" · "Works 100% Offline" · "No Telemetry" · "Native macOS"
- Mockup Showcase:
  Render a detailed, responsive CSS-only macOS window mockup representing the Foco Editor:
  - Top bar with macOS traffic lights (red, yellow, green dots), a page path/title header reading "Brand Research > Public Relations", and a status badge: "Saved locally".
  - Sidebar: Left pane with a clean folders list: "Brand Research", "Overview", "Customer Interviews", "Visual References", "Launch Plan".
  - Editor area: Large serif page title "Launch Strategy", folder metadata path reading "Category: Research", followed by a clean text editor with formatted bullet checklists, an inline PDF card attachment, and a bottom-centered "/" slash command menu floating above the text (displaying options like: "Text", "Heading", "Table", "Kanban Board", "PDF").
  - Floating asset: A small overlay graphic of a `.bulb` document icon moving visually from the editor window toward a second, simpler, read-only window representing "Foco View".

#### PROBLEM / COMPARE SECTION
- Headline: "Your workspace shouldn’t disappear when the Wi-Fi does."
- A neat two-column side-by-side comparison table:
  - Column 1: "The Cloud Workspace" (Account required, data on remote servers, internet dependent, subscription seats, tracking SDKs).
  - Column 2: "Foco (Local First)" (Zero accounts, files reside on your disk, 100% offline, free forever, zero telemetry).

#### DUAL-APP CAPABILITY
- Headline: "Make it in Foco. Open it free in Foco View."
- Two adjacent product description columns/cards:
  - **Foco (Free Editor)**: Create `.bulb` files, write markdown, drag-and-drop media, attach PDFs/videos. Designed for creators. (CTA: "Get Foco Editor")
  - **Foco View (Free Viewer)**: Double-click to open any `.bulb` file, read pages, play offline audio/video, navigate sidebars. Designed for clients and collaborators. (CTA: "Get Foco View")
- Intermediary graphic: An animated or visual pipeline showing a `.bulb` file moving from Foco to Foco View. Subtitle: "Free to create. Free to share. Free to view."

#### THE .BULB STRUCTURE (EXPLODED VIEW)
- Headline: "A whole workspace in one file."
- Description: "A .bulb file is a real portable archive on your hard drive containing plain text files, JSON block structures, and raw attachments."
- Exploded-file visual: An interactive or layered diagram:
  - `Research.bulb` at the top.
  - Branches showing: `/manifest.json`, `/Pages/`, `/Blocks/`, `/Assets/` (PDFs, Images, Videos).
- Bullet highlights: "Portable by default", "Built from durable formats", "Back up anywhere you choose".
- A collapsible accordion block at the bottom labeled "For the curious" explaining the ZIP-compatible archive mechanism.

#### FEATURE HIGHLIGHTS
- Headline: "Everything your project needs. Nothing it doesn't."
- Alternating rows showing:
  - **Organize naturally**: Page hierarchy, sidebar categories, and direct navigation.
  - **Write at the speed of thought**: Markdown-friendly keyboard actions and the "/" block-insertion menu.
  - **Keep source material close**: Drag in PDFs, images, video, and audio directly from Finder.
  - **Save prompts beside the work**: A unique "Prompt" block designed specifically to store your local AI prompt instructions right next to your research.

#### USE CASES
- Headline: "One calm home for work worth keeping."
- A grid of 4 cards with neat border frames and minimal layout previews:
  - **Research Vault**: Compile source PDFs, notes, and citations.
  - **Creative Project Bible**: Store reference images, audio moodboards, and script drafts.
  - **Client Workspaces**: Ship complete project handoffs with source files without forcing clients to register for accounts.
  - **Course Resource Packs**: Distribute study guides, exercises, and media that students can open free.

#### PRIVACY MANIFESTO
- A full-width dark near-black section (`bg-[#121211] text-[#F7F6F1]`) with coral accents.
- Headline: "Private isn’t a setting. It’s the architecture."
- Manifesto Text: "Foco and Foco View have no account system, no cloud servers, no sync engine, and no tracking scripts. Your work lives exactly where you save it."
- Checklist: "Zero data collected", "No connection required", "No third-party trackers".

#### SOCIAL PROOF (PLACEHOLDER)
- Title: "Loved by detail-oriented creators."
- Labeled placeholders for editable quotes:
  - `"[Insert customer quote here]"` — `[Name, Role]`

#### DOWNLOAD SECTION
- A beautiful dual-card footer layout.
- Left card: Foco Editor (highlighting creation, editing, offline use, free, no login).
- Right card: Foco View (highlighting read-only navigation, offline media playback, free, no login).

#### FAQ
- Interactive accordion FAQ containing:
  - What is a `.bulb` file?
  - What is the difference between Foco and Foco View?
  - Are both Foco apps really free?
  - Can I edit a `.bulb` in Foco View?
  - Where is my data stored? Can I use iCloud or Dropbox?
  - What happens if Foco goes away?

#### FOOTER
- Simple horizontal line.
- Product links, terms, changelog, and license info.
- Bottom copy: "Two native Mac apps. One portable format. Your work stays local."
```
