# Animated Profile Pictures

Place Lottie JSON animation files here.

## Format Requirements

- **File format:** `.json` (Lottie animation)
- **Recommended size:** 200x200 pixels
- **Frame rate:** 24-30 fps
- **Duration:** 1-3 seconds (will loop)
- **Background:** Transparent

## How to Create

1. Design in Adobe After Effects or similar
2. Export using Bodymovin/Lottie plugin
3. Or download free animations from [LottieFiles](https://lottiefiles.com/)

## Adding to App

1. Place the `.json` file in this folder
2. Add an entry to `../manifest.json`:

```json
{
  "id": "my_animation",
  "name": "My Animation",
  "type": "animated",
  "file": "Animated/my_animation.json",
  "category": "custom"
}
```

3. Rebuild the app

## Example Entry

```json
{
  "id": "coin_spin",
  "name": "Spinning Coin",
  "type": "animated",
  "file": "Animated/coin_spin.json",
  "category": "retro"
}
```

