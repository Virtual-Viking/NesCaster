# Static Profile Pictures

Place PNG or SVG images here for profile pictures.

## Format Requirements

- **File format:** `.png` (with transparency) or `.svg`
- **Recommended size:** 200x200 pixels (PNG) or scalable (SVG)
- **Background:** Transparent preferred
- **Color space:** sRGB

## Guidelines

- Images should be square or will be center-cropped
- Use transparent backgrounds for best results
- Keep file sizes reasonable (< 500KB for PNG)
- Simple, bold designs work best at small sizes

## Adding to App

1. Place the image file in this folder
2. Add an entry to `../manifest.json`:

```json
{
  "id": "my_picture",
  "name": "My Picture",
  "type": "static",
  "file": "Static/my_picture.png",
  "category": "custom"
}
```

3. Rebuild the app

## Default Pictures

The app ships with these default avatars:

| ID | Name | Color |
|----|------|-------|
| `default_player1` | Player 1 | Red |
| `default_player2` | Player 2 | Blue |
| `default_player3` | Player 3 | Green |
| `default_player4` | Player 4 | Purple |

These placeholders need to be replaced with actual PNG files.

