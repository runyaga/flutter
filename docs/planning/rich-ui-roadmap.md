# Rich Chat Interface UX Roadmap

## Summary

Transform Soliplex from a basic chat into a showcase of AG-UI capabilities through
thoughtful UX design. Each phase adds user-facing features that demonstrate the
power of agent-driven interfaces.

This document includes **real-world examples** and links to help visualize each pattern.

---

## Phase Overview

| Phase | Theme | User Value |
|-------|-------|------------|
| 1 | Trust & Transparency | See where answers come from |
| 2 | Control & Feedback | Shape the conversation |
| 3 | Content Interaction | Work with rich responses |
| 4 | Visual Intelligence | See data, not just text |
| 5 | Awareness & Flow | Know what's happening |

---

## Phase 1: Trust & Transparency

> "Where did this come from? Can I verify it?"

### 1.1 Citation Display

**Real-World Example: Perplexity AI**

Perplexity is the gold standard for citation UI. See their interface:

- [Perplexity Getting Started Guide](https://www.perplexity.ai/hub/blog/getting-started-with-perplexity)
- [How to Use Perplexity (with screenshots)](https://www.byriwa.com/how-to-use-perplexity-ai/)
- [Perplexity Citation-Forward Design](https://www.unusual.ai/blog/perplexity-platform-guide-design-for-citation-forward-answers)

**Key patterns from Perplexity:**

- Numbered superscript references inline: "Revenue grew 15%[1]"
- "Sources" panel showing favicons + titles before the answer
- Clicking a number highlights the source and shows the excerpt
- Sources expandable to show full context

**Our Implementation:**

- Inline References: Superscript numbers in response text
- Source Cards below message with: document title, page number, pull quote, PDF thumbnail
- Full Page Viewer: Tap thumbnail to see PDF page full-screen with highlighted passage

### 1.2 Document Scope Control (Filter Chips)

**What are "Chips"?**

Chips are compact, interactive elements for selection/filtering. See:

- [Material Design 3 Chips](https://m3.material.io/components/chips) - Official spec with visuals
- [Flutter Chip Widget Guide](https://medium.com/flutter-community/chip-widget-material-design-with-flutter-4a834553c9ab)
- [MUI React Chips](https://mui.com/material-ui/react-chip/) - Interactive examples

**Types we'd use:**

- **Filter Chips**: Toggle documents on/off (checkmark when selected)
- **Input Chips**: Show selected documents with "x" to remove

**Our Implementation:**

- Filter button near input opens a bottom sheet
- Search bar to find documents by name
- Checkbox list of available documents
- Selected documents appear as chips above the input field
- "Searching 3 of 12 documents" indicator

---

## Phase 2: Control & Feedback

> "What is it thinking? Did that help?"

### 2.1 Thinking/Reasoning Panel

**What is a "Thinking Panel"?**

A collapsible section showing the AI's internal reasoning process. Examples:

- [Claude Extended Thinking](https://www.anthropic.com/news/visible-extended-thinking) - Anthropic's official announcement
- [Using Extended Thinking (Claude Help)](https://support.claude.com/en/articles/10574485-using-extended-thinking)
- [How Extended Thinking Works](https://claude-ai.chat/blog/extended-thinking-mode/)

**What it looks like:**

```text
┌─────────────────────────────────────────┐
│ Assistant                               │
├─────────────────────────────────────────┤
│ Based on Q3 reports, revenue grew 15%   │
│ compared to the previous quarter...     │
│                                         │
│ ▶ Show thinking                         │  ← Collapsed by default
└─────────────────────────────────────────┘

When expanded:
┌─────────────────────────────────────────┐
│ ▼ Thinking                              │
├─────────────────────────────────────────┤
│ • Searching 5 documents for "Q3 revenue"│
│ • Found 3 relevant sections             │
│ • Comparing figures from pages 12, 45   │
│ • Cross-referencing with Q2 data        │
│ • Synthesizing final answer             │
└─────────────────────────────────────────┘
```

**Key UX decisions:**

- Collapsed by default (don't overwhelm)
- "Thinking..." shown during processing
- Expandable after response completes
- Shows step-by-step reasoning with timestamps

### 2.2 Message Actions

**Real-World Example: ChatGPT**

ChatGPT shows actions on hover/tap. See discussions:

- [ChatGPT Feedback UI Discussion](https://community.openai.com/t/user-feedback-for-openai-chatgpt-ui-functionality-ios-web/1227506)
- [Thumbs Up/Down Feedback Patterns](https://community.openai.com/t/suggestion-for-improving-thumbs-up-thumbs-down-feedback-system/1228407)

**What it looks like:**

```text
┌─────────────────────────────────────────┐
│ Assistant                      📋 👍 👎 │  ← Actions appear on hover
├─────────────────────────────────────────┤
│ Here's your answer...                   │
└─────────────────────────────────────────┘

📋 = Copy to clipboard
👍 = Good response (filled when clicked)
👎 = Bad response (opens feedback form)
```

**Our Actions:**

- **Assistant messages**: Copy, thumbs up, thumbs down, regenerate
- **User messages**: Edit, copy, delete
- **Presentation**: Hidden by default, appear on hover (desktop) or long-press (mobile)

### 2.3 Feedback Flow

**Quick Feedback:**

- Single tap on 👍/👎
- Brief "Thanks!" toast notification
- Icon fills to show it was registered

**Detailed Feedback (on 👎):**

```text
┌─────────────────────────────────────────┐
│ What was wrong?                         │
├─────────────────────────────────────────┤
│ ☐ Inaccurate information                │
│ ☐ Incomplete answer                     │
│ ☐ Confusing or unclear                  │
│ ☐ Other                                 │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ Add details (optional)...           │ │
│ └─────────────────────────────────────┘ │
│                                         │
│                      [Cancel] [Submit]  │
└─────────────────────────────────────────┘
```

---

## Phase 3: Content Interaction

> "I need to use this content, not just read it."

### 3.1 Code Blocks

**Real-World Examples:**

- GitHub's code blocks with copy button
- VS Code's syntax highlighting
- Claude/ChatGPT code fence rendering

**What it looks like:**

```text
┌─ python ─────────────────────────── 📋 ┐
│ def hello():                            │
│     print("Hello, world!")              │
└─────────────────────────────────────────┘
         ↑                            ↑
    Language label              Copy button
```

**Features:**

- Copy button appears on hover
- "Copied!" feedback animation (checkmark replaces clipboard icon briefly)
- Syntax highlighting by language
- Horizontal scroll for wide code

### 3.2 Image Handling

**Real-World Example:**

- iOS Photos app zoom/pan gestures
- Slack image viewer
- Twitter/X image expansion

**Inline Display:**

```text
┌─────────────────────────────────────────┐
│ Here's the chart you requested:         │
│                                         │
│  ┌─────────────────────┐                │
│  │   [Chart Image]   🔍│ ← Expand icon  │
│  └─────────────────────┘                │
└─────────────────────────────────────────┘
```

**Full-Screen Viewer (on tap):**

- Pinch to zoom (up to 3x)
- Pan when zoomed
- Double-tap to zoom in/reset
- Swipe down to dismiss
- Download button in toolbar

### 3.3 Tables

**Features:**

- Horizontal scroll when table is wider than screen
- Sticky first column (stays visible while scrolling)
- Alternating row colors for readability
- Tap cell to copy individual value
- "Copy as CSV" action in overflow menu

---

## Phase 4: Visual Intelligence

> "Show me, don't just tell me."

### 4.1 Maps & GIS

**Real-World Examples:**

- Google Maps embedded in search results
- Uber's ride map view
- Weather app radar maps

**In-Message Display:**

```text
┌─────────────────────────────────────────┐
│ Here are the 3 office locations:        │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │        [Interactive Map]        │    │
│  │    📍 NYC    📍 SF    📍 Austin │    │
│  │                           [⛶]  │ ← Expand button
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

**Interactions:**

- Pinch to zoom
- Tap marker for popup with details
- Pan to explore
- "Open in Maps" button

### 4.2 Charts & Graphs

**Real-World Examples:**

- [fl_chart Flutter package](https://pub.dev/packages/fl_chart)
- Apple Stocks app charts
- Robinhood investment charts

**Chart Types:**

- Bar charts (horizontal/vertical)
- Line charts with multiple series
- Pie/donut charts
- Area charts

**Interactions:**

- Tap segment/bar for value tooltip
- Legend items toggle series visibility
- Expand to full-screen for detail
- Export as image option

### 4.3 Widget Presentation Pattern

**In-Message (default):**

- Widget renders inline in chat flow
- Sensible default size (e.g., 300px height for maps)
- Expand button (⛶) in corner

**Full-Screen Mode (on expand):**

- Maximum space for interaction
- Toolbar with widget-specific actions
- Close button (✕) returns to chat
- State preserved when returning

---

## Phase 5: Awareness & Flow

> "Is it working? What's happening? Can I type yet?"

### 5.1 Status Bar / Loading States

**Real-World Examples:**

- [AWS Cloudscape GenAI Loading States](https://cloudscape.design/patterns/genai/genai-loading-states/) - Excellent pattern guide
- [Flutter Typing Indicator Recipe](https://docs.flutter.dev/cookbook/effects/typing-indicator)
- [AI UI Patterns (patterns.dev)](https://www.patterns.dev/react/ai-ui-patterns/)

**What it looks like:**

```text
Processing stage (no output yet):
┌─────────────────────────────────────────┐
│ 🤔 Thinking...                          │
└─────────────────────────────────────────┘

Tool call stage:
┌─────────────────────────────────────────┐
│ 🔍 Searching documents...               │
└─────────────────────────────────────────┘

Generation stage:
┌─────────────────────────────────────────┐
│ ✍️ Writing response...                  │
└─────────────────────────────────────────┘

Error state:
┌─────────────────────────────────────────┐
│ ⚠️ Connection lost          [Retry]     │
└─────────────────────────────────────────┘
```

**State Mapping from AG-UI Events:**

| AG-UI Event | Status Display |
|-------------|----------------|
| `run_started` | "Thinking..." + disable input |
| `tool_call_start` | "Calling {tool_name}..." |
| `tool_call_end` | Brief checkmark, then next state |
| `text_message_start` | "Writing response..." |
| `run_finished` | Clear status, enable input |
| `run_error` | Error banner with retry |

### 5.2 Input State During Processing

**Visual Changes:**

- Input field slightly dimmed
- Send button shows spinner or is disabled
- Placeholder: "Waiting for response..."

**Interrupt Option:**

```text
┌─────────────────────────────────────────┐
│ ✍️ Writing response...         [Stop]   │
└─────────────────────────────────────────┘
```

- "Stop" button appears for long operations
- Partial response preserved if interrupted

### 5.3 Tool Call Visibility

**Minimal View (default):**

- Just status bar updates
- No persistent display of tool calls

**Detailed View (for power users):**

```text
┌─────────────────────────────────────────┐
│ 🔧 Tool: search_documents        2.3s   │
├─────────────────────────────────────────┤
│ ▶ Input: {"query": "Q3 revenue"}        │  ← Collapsed
│ ▶ Output: [3 documents found]           │  ← Collapsed
└─────────────────────────────────────────┘
```

**User Preference:**

- Toggle in settings: "Show tool details"
- Remembers preference per session

---

## Visual Design Principles

### Hierarchy

- **Primary**: User's question, AI's answer
- **Secondary**: Citations, actions, metadata
- **Tertiary**: Debugging info, tool calls

### Progressive Disclosure

- Start simple, reveal on demand
- Expand/collapse for complex content
- Settings for power users

### Feedback

- Every action has visible response
- Loading states for async operations
- Error states with recovery options

### Consistency

- Same interaction patterns throughout
- Predictable locations for actions
- Uniform animation timing

---

## Reference Links Summary

**Citations & Sources:**

- [Perplexity AI](https://www.perplexity.ai/) - Best-in-class citation UI
- [Perplexity Design Guide](https://www.unusual.ai/blog/perplexity-platform-guide-design-for-citation-forward-answers)

**Chips & Filters:**

- [Material Design 3 Chips](https://m3.material.io/components/chips)
- [Flutter Chip Widget](https://medium.com/flutter-community/chip-widget-material-design-with-flutter-4a834553c9ab)

**Thinking/Reasoning:**

- [Claude Extended Thinking](https://www.anthropic.com/news/visible-extended-thinking)
- [Using Extended Thinking](https://support.claude.com/en/articles/10574485-using-extended-thinking)

**Loading States:**

- [AWS Cloudscape GenAI Loading](https://cloudscape.design/patterns/genai/genai-loading-states/)
- [Flutter Typing Indicator](https://docs.flutter.dev/cookbook/effects/typing-indicator)
- [AI UI Patterns](https://www.patterns.dev/react/ai-ui-patterns/)

**General AI Chat UI:**

- [31 Chatbot UI Examples](https://www.eleken.co/blog-posts/chatbot-ui-examples)

---

## Success Metrics

| Phase | Metric |
|-------|--------|
| 1 | Citation click rate, time spent in page viewer |
| 2 | Feedback submission rate, regeneration usage |
| 3 | Code copy rate, image expansion rate |
| 4 | Widget interaction depth, export usage |
| 5 | Interrupt usage, time-to-next-message |

---

*Last updated: 2026-01-08*
