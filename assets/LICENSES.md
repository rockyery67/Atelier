# Atelier bundled assets

All assets ship locally; the app performs no runtime downloads.

Fonts: Caveat (handwriting), Newsreader (editorial headings), Plus Jakarta Sans
(controls and clean print), from the Google Fonts repository. Each is licensed
under the SIL Open Font License 1.1. Full copyright and license notices are in
assets/fonts/*-OFL.txt. Font binaries are unmodified variable fonts.
https://github.com/google/fonts/tree/main/ofl

Sound recordings are CC0 1.0 (public-domain dedication):
- Luckius, Various Paper Sound Effects: paper flip/shuffle and crumple excerpts.
  https://opengameart.org/content/various-paper-sound-effects
- lmbubec, Thumb Tack.wav: insertion/removal excerpts of a tack in corkboard.
  https://freesound.org/people/lmbubec/sounds/119798/
- moai15, Writing_Pen_01.wav: a short real pen-writing excerpt.
  https://freesound.org/people/moai15/sounds/336382/
- Jarebear1223, Peeling and Ripping Off Tape: peel excerpt and a reversed,
  shortened excerpt for attachment. Attachment is a designed approximation of
  sticky tape contact, not a separate recording of pressing down a sticky note.
  https://freesound.org/people/Jarebear1223/sounds/618541/
- aunrea, Paper Shredder: a short excerpt of an actual home shredder.
  https://freesound.org/people/aunrea/sounds/495666/

License: https://creativecommons.org/publicdomain/zero/1.0/
Clips are trimmed, faded, normalized, resampled to mono 22050 Hz WAV.
Save and completion are original quiet synthesized tones, dedicated to CC0 1.0.
They are feedback tones, not paper recordings. No missing runtime assets.
assets/asset_manifest.json records authors, source URLs, downloads and hashes.
The editable originals and minimal license receipts live in assets/sources and
are intentionally excluded from the runtime asset bundle. Receipts retain the
author, source/license URLs and source-page SHA-256. Full downloaded web pages
are excluded because unrelated site code can contain third-party credentials.
Ready-to-use WAV excerpts are included with this demo project.

The app was designed from the supplied Stitch screen.png/code.html references.
All paper, pins, tape, dots and pen decoration in the app are native Flutter
widgets and canvas drawing. Reference photos are not redistributed.
