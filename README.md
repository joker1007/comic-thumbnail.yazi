# comic-thumbnail.yazi 

Plugin for yazi filer to preview images in the archive.

this plugin supports linux only.

## Features
- Supports any archive format that lsar can handle (zip, rar, 7z, tar.gz, etc.)
- Resizes images with ImageMagick to match the preview's `max_width` before caching, keeping cache size small

## Requirements
- unar
- imagemagick

## Install

```
ya pkg add joker1007/comic-thumbnail
```

## Usage

```toml
[plugin]
prepend_previewers = [
  { url = "*.zip", exec = "comic-thumbnail" },
  { url = "*.rar", exec = "comic-thumbnail" },
]
```
