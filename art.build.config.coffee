module.exports =
  webpack:
    common: {}
    targets:
      index: {}
      test: {}

  package:
    description: "The ArtEngine is a layout, rendering and event engine for creating user interfaces in HTML5 Canvas elements."
    dependencies:
      "art-foundation": "git://github.com/imikimi/art-foundation.git"
      "art-canvas":     "git://github.com/imikimi/art-canvas.git"
      "art-events":     "git://github.com/imikimi/art-events.git"
      "art-xbd":        "git://github.com/imikimi/art-xbd.git"
      "art-text":       "git://github.com/imikimi/art-text.git"
      "keyboardevent-key-polyfill": "^1.0.2",
      "javascript-detect-element-resize": "^0.5.3"