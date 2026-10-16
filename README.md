# Pocket Dex

A SwiftUI Pokédex replica for iPhone and iPad. Point the camera at a Pokémon toy, card or picture: the app removes the background, identifies the species, shows the Generation III Pokédex entry, reads it aloud in a Pokédex voice, and records the catch in a 386-entry National Pokédex.

This is a fork of [vincent-pradeilles/ios-pokedex](https://github.com/vincent-pradeilles/ios-pokedex), which was built for the foldable iPhone Duo. This version runs on ordinary iPhones and iPads.

## Devices

| Device | Layout | Identification |
| --- | --- | --- |
| iPhone 16 Pro Max | Two pages, swipe to turn the Pokédex over; landscape opens both halves | Card reader; Apple on-device model once on iOS 27 with Apple Intelligence |
| iPad Pro 12.9" M2 | Both halves open side by side | Card reader; Apple on-device model once on iOS 27 with Apple Intelligence |
| iPhone 12 Pro | Two pages, swipe to turn | Card reader; Claude over the internet for toys and plush (no Apple Intelligence on this phone) |

Minimum iOS 26. The card reader and background removal run on the device with Vision on every model listed and need no key. Apple's on-device image identification needs iOS 27 and Apple Intelligence. Anything the card reader cannot name can go to Claude with an API key, or be named by hand.

## What changed from the original

- The display is a live camera feed. Press the camera key to capture; press it again after a scan to bring the feed back.
- A card reader: on-device text recognition reads the species name printed on a trading card, for every species up to No. 1025, so a card needs no AI model and no key.
- Works on iPhone and iPad instead of the iPhone Duo. The iPad and large iPhones in landscape show both halves side by side with the hinge; smaller screens get one half per page.
- Real Pokédex data for all 386 species: name, category (for example "Seed Pokémon"), types and the Generation III entry text, bundled from PokeAPI. The AI only has to say which Pokémon it is; the entry text is the real one.
- A second identification route through the Claude API for devices without Apple Intelligence. Settings has a picker: Automatic, On this device, Claude.
- A scan index key on the blue keypad: every scan newest first, with its date, time and place, a thumbnail, and swipe to delete. Tap a row to show it on the display; tap the place to open the map.
- A pencil key on the blue keypad to name a Pokémon yourself when no model is sure, or got it wrong. The scan is saved under the species you choose.
- An Xcode project generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen), signed for the dhl84 team.

## Build and install

```sh
brew install xcodegen
xcodegen generate
open PocketDex.xcodeproj
```

Select the `Pocket Dex` scheme and the device, then Run. The first install on a new iPhone needs the phone to trust the developer certificate: Settings → General → VPN & Device Management.

From the command line:

```sh
xcodebuild -project PocketDex.xcodeproj -scheme "Pocket Dex" -destination "id=<device udid>" -allowProvisioningUpdates build
xcrun devicectl device install app --device <device udid> <path to Pocket Dex.app>
```

## Set up on a phone

1. Open the gear key on the right half.
2. Cards work straight away. For toys, plush and drawings, choose who identifies Pokémon: on an iPhone 12 Pro, or any phone still on iOS 26, choose Claude and paste a Claude API key, then tap Save key. The key stays in the device Keychain.
3. Leave Background removal on **On device**. Photoroom is optional and needs its own key.
4. Tap the camera key, or PHOTO for the photo library.

## Scan pipeline

1. The photo is resized to 1600 px and the background removed on the device with Vision's `VNGenerateForegroundInstanceMaskRequest` (or by Photoroom when selected). At the same time `VNRecognizeTextRequest` reads the photo's text; the largest printed species name wins.
2. The cutout appears on the display while identification runs.
3. Identification, only when no printed name was found: Apple's on-device model with an image attachment on iOS 27 with Apple Intelligence; otherwise a 768 px cutout goes to the Claude API (`claude-opus-5-5`, with the server-side refusal fallback enabled) and the reply is parsed as JSON.
4. A recognised number from 1 to 386 fills the entry from the bundled data. Any other recognised Pokémon keeps the AI's name, type and notes.
5. The cutout and entry are saved to the field journal, with the capture location if allowed. Automatic narration reads the entry.

## Data and credits

- Species names, categories, types and entry text for all 1025 species: [PokeAPI](https://github.com/PokeAPI/pokeapi) CSV data, regenerated with `gen_data.py` (see `Design/Pokedex.md`).
- Sprites: Pokémon Emerald front sprites from [PokeAPI/sprites](https://github.com/PokeAPI/sprites).
- Pokémon and Pokémon character names are trademarks of Nintendo, Creatures and GAME FREAK. This is an independent fan project.
