import os

base_dir = r"C:\Users\ACER\Desktop\schedly\.antigravity"

files = {
    # REFERENCES
    r"references\inspira-ui.md": """# Inspira UI Reference
- **Summary**: A curated collection of beautifully designed, reusable components for Vue & Nuxt.
- **Purpose**: Provides aesthetics and functionality of Aceternity UI and Magic UI within the Vue ecosystem.
- **Important Concepts**: 
  - Framework-agnostic styling approach (Tailwind).
  - Pick and customize (copy-paste) rather than importing a rigid library.
- **Best Practices**: Use scoped composition, decouple logic from styling.
- **Implementation Ideas**: Great source for complex interactive components like bento grids, animated beam connectors, and text reveals.
- **Ignored**: Vue-specific compiler boilerplate (we want framework-agnostic rules).
- **Licensing**: MIT.
""",

    r"references\animate-ui.md": """# Animate UI Reference
- **Summary**: Fully animated, open-source component distribution (React, Tailwind, Motion).
- **Purpose**: To provide ready-to-use, highly polished micro-interactions and transitions.
- **Important Concepts**: Spring physics over linear durations. Component composability.
- **Best Practices**: Use `framer-motion` (or equivalent) for fluid layout transitions.
- **Implementation Ideas**: Excellent reference for dialog reveals, dynamic islands, and interactive hover states.
- **Ignored**: React-specific `useEffect` hooks. We extracted the physics values instead.
- **Licensing**: MIT.
""",

    r"references\lenis.md": """# Lenis Reference
- **Summary**: Lightweight, robust, performant smooth scroll library.
- **Purpose**: Replaces janky native scroll with smooth interpolation for parallax and WebGL syncing.
- **Important Concepts**: `requestAnimationFrame` syncing, scroll snapping without fighting physics.
- **Best Practices**: Do not hijack scroll natively; wrap the browser's own scroll so accessibility (sticky, anchors) keeps working.
- **Implementation Ideas**: Use for premium landing pages requiring scroll-linked animations.
- **Ignored**: Framework wrappers. We focus on the core mathematics of the lerp function.
- **Licensing**: MIT.
""",

    r"references\ui-ux-pro-max-skill.md": """# UI UX Pro Max Skill Reference
- **Summary**: An AI coding prompt/skill designed to enforce premium UI/UX standards in AI generation.
- **Purpose**: Elevate AI-generated frontend code from "functional" to "world-class".
- **Important Concepts**: Aggressive emphasis on visual hierarchy, standard breakpoints, and modern aesthetics (glassmorphism, meshes).
- **Best Practices**: AI must evaluate its own design before submitting it to the user.
- **Implementation Ideas**: We adapted its persona definitions into our `critics/` folder.
- **Ignored**: Generic coding rules. We only extracted UI-specific directives.
- **Licensing**: Open Source / Community.
""",

    # MCP
    r"mcp\21st_dev\installation_guide.md": """# 21st.dev MCP Installation Guide
**Do NOT execute this automatically. Prepare the environment only.**

To add the 21st.dev server to Claude:
`claude mcp add --transport http 21st https://21st.dev/api/mcp --header "x-api-key: $API_KEY_21ST"`

## Setup Steps
1. Obtain the API key from 21st.dev.
2. Export it to the terminal environment variables.
3. Run the command above.
4. Restart the Claude/Antigravity host if required.
""",

    r"mcp\21st_dev\usage_guide.md": """# 21st.dev MCP Usage Guide
- **Purpose**: Accessing a vast library of UI components directly through the AI's context.
- **Best Practices**: 
  - Query for components using specific descriptors (e.g., "Get a glassmorphism pricing card").
  - Do not blindly dump the output. Pass the output through the `Component Architect` skill.
- **Limitations**: The components might use conflicting Tailwind configurations. Always normalize spacing to our 8pt grid.
- **When to Use**: When a complex, standard component is requested (e.g., calendar, rich text editor).
- **When NOT to Use**: For simple atomic elements like standard Buttons or Inputs (use our Design System instead).
""",

    r"mcp\21st_dev\prompt_templates.md": """# MCP Prompt Templates
1. **Fetch Request**: "Use the 21st MCP to search for a highly polished 'authentication layout' built with Tailwind."
2. **Integration Request**: "I fetched a component from 21st.dev. Use our `Apple Design Critic` to audit its spacing and typography before integrating it."
""",

    # CHECKLISTS
    r"checklists\production-ui.md": """# Production UI Checklist
- [ ] Responsive across mobile, tablet, desktop.
- [ ] No layout shift on load.
- [ ] Contrast meets WCAG AA.
- [ ] Hover and focus states exist for all interactable elements.
- [ ] Loading and empty states are designed.
- [ ] Spacing aligns to the 8pt grid.
- [ ] Animations are performant (no layout thrashing).
""",

    # DESIGN SYSTEM
    r"design-system\tokens.md": """# Design System Tokens
- **Spacing**: `sm: 8px`, `md: 16px`, `lg: 24px`, `xl: 32px`
- **Radius**: `sm: 4px`, `md: 8px`, `lg: 12px`, `full: 9999px`
- **Typography**: Inter (Sans). `base: 16px`, `lg: 18px`, `xl: 20px`, `2xl: 24px`, `3xl: 30px`
- **Elevation**: `shadow-sm` (1px y), `shadow-md` (4px y), `shadow-lg` (10px y, heavily blurred).
"""
}

for path, content in files.items():
    with open(os.path.join(base_dir, path), "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")
