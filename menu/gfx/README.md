# Menu Graphics

## Font Requirements

The menu system requires a 320A mode font graphic.

### Creating menufont.png

1. **Dimensions**: 
   - Width: 32 pixels (8 characters × 4 pixels each)
   - Height: 8 pixels (single row for now)

2. **Format**:
   - Indexed color PNG
   - 4 colors maximum (including transparent)
   - Color index 0 = transparent
   - Color indices 1-3 = visible colors

3. **Characters Needed**:

Space, A-Z, 0-9, period, hyphen (40 characters total)

### Quick Font Creation

You can use an online pixel art tool like Piskel or Aseprite to create the font:

1. Create 32×8 canvas
2. Set to indexed color mode
3. Draw 8 characters: ` ABCDEFG`
4. Each character is 4 pixels wide × 8 pixels tall
5. Use colors: transparent, white, light gray, dark gray
6. Save as menufont.png

### Alternative: Use Included Font

The 7800basic samples include fonts you can modify:
```bash
cp /Users/rowe/Software/Atari7800/7800basic/samples/samplegfx/atascii.png menufont.png
```

Then edit with your favorite image editor to customize.

### Simple Text Font

For a quick start, here's a simple monospaced font layout:

```
Row 1: Space A B C D E F G
```

Each character should be clearly distinguishable at 4×8 pixels.

## Status

⚠️ **TODO**: Create initial menufont.png graphic

You can create a placeholder by:
```bash
convert -size 32x8 xc:black -colorspace RGB -type Palette PNG8:menufont.png
```

Then edit it with a pixel editor to add the actual font glyphs.
