# Obsidian

Some additional configuration
- go to the `Settings/Editor/Display` section and switch off the
  `Readable line length` setting, line length will be set via css (see below)
- go to the `Settings/Editor/Behavior` section, switch off `Indent using tabs`
  and set `Tab indent size` to `2`
- go to `Appearance/Advanced` and switch off `Show inline title`
- add the following code to the end of the `.obsidian/themes/Minimal/theme.css`
  file if it doesn't already have that:
  ```css
  .markdown-preview-view { max-width: 1000px; margin: auto; }
  .markdown-source-view {
      font-family: 'Ubuntu Mono', monospace;
      max-width: 1000px; margin: auto;
  }
  ```
