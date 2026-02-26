# comic-thumbnail.yazi 

Plugin for yazi filer to preview images in the archive.

this plugin supports linux only.

## Requirements
- unar
- imagemagick

## Usage

```toml
[plugin]
prepend_previewers = [
  { url = "*.zip", exec = "comic-thumbnail" },
  { url = "*.rar", exec = "comic-thumbnail" },
]
```
