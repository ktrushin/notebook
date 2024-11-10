# Obsidian

Some additional configuration
- `Settings/Editor/Display/Strict Line Breaks`: on
- `Settings/Editor/Behavior/Indent using tabs`: off
- `Settings/Editor/Behavior/Tab indent size`: `2`
- `Settings/Appearance/Interface/Show inline title`: off

Wider readable line length:
- go to the `Settings/Editor/Display` section and switch off the
  `Readable line length` setting, line length will be set via css (see below)
- add the following code to the end of the `.obsidian/themes/Minimal/theme.css`
  file if it doesn't already have that:
  ```css
  .markdown-preview-view { max-width: 1000px; margin: auto; }
  .markdown-source-view {
      font-family: 'Ubuntu Mono', monospace;
      max-width: 1000px; margin: auto;
  }
  ```
