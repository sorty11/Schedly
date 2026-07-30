# 21st.dev MCP Usage Guide
- **Purpose**: Accessing a vast library of UI components directly through the AI's context.
- **Best Practices**: 
  - Query for components using specific descriptors (e.g., "Get a glassmorphism pricing card").
  - Do not blindly dump the output. Pass the output through the `Component Architect` skill.
- **Limitations**: The components might use conflicting Tailwind configurations. Always normalize spacing to our 8pt grid.
- **When to Use**: When a complex, standard component is requested (e.g., calendar, rich text editor).
- **When NOT to Use**: For simple atomic elements like standard Buttons or Inputs (use our Design System instead).
