<p align="center"><img width="200" src="README/crab.png"></p>

Crab is a Game Boy Advance emulator written in Crystal. Currently, this project is still clearly a work-in-progress, although some games are currently playable.

This would not be possible without [GBATEK](http://problemkaputt.de/gbatek.htm), [Tonc](https://www.coranac.com/tonc), [mGBA](https://mgba.io/), or the wonderful emudev community.

<p align="center"><img width="800" src="README/GoldenSun.png"></p>

## Building

[SDL2](https://www.libsdl.org/) is the only library you should need to install. It is available on every major package manager. Of course, the assumption is also that you have the [Crystal](https://crystal-lang.org/install/) compiler installed.

After cloning the repository, all you'll need to do is run `shards build --release` to build the emulator in release mode. This will place the binary at `bin/crab`.

## Usage

Running the emulator simply consists of `bin/crab /path/to/bios /path/to/rom`.

At the moment, the BIOS _is_ a required argument, although I may ship with an open-source replacement BIOS at some point in the future. If you cannot dump the official BIOS from your own console, you can pick up [Normatt's replacement BIOS](https://github.com/Nebuleon/ReGBA/tree/master/bios) or the [one created by DenSinH and fleroviux](https://github.com/Cult-of-GBA/BIOS). Both of these BIOSes should be compatible in 99% of use-cases.

## Features and Remaining Work

### Features

- Accurate sound emulation (both Direct Sound and PSGs)
- GLSL shaders for color reproduction
- PPU features
  - Modes 0-5 are mostly implemented
  - Affine backgrounds and sprites
  - Alpha blending
  - Windowing
- CPU core
  - Passing [armwrestler](https://github.com/destoer/armwrestler-gba-fixed)
  - Passing [FuzzARM](https://github.com/DenSinH/FuzzARM)
  - Passing [gba-suite](https://github.com/jsmolka/gba-suite)
- Storage
  - Flash and SRAM implemented (although Golden Sun refuses to save..)

### Remaining Work

- Timers need improvement
- PPU
  - Mosaic
  - Blending code needs cleanup
- Storage
  - EEPROM
  - Fix Flash for Golden Sun
  - Game database to support odd cases like Classic NES
- Timing
  - Cycle counting
  - DMA timing
  - Prefetch
  - Etc, etc, etc.

## Special Thanks

A special thanks goes out to those in the emudev community who are always helpful, both with insightful feedback and targeted test ROMs.

- https://github.com/ladystarbreeze
- https://github.com/DenSinH
- https://github.com/fleroviux
- https://github.com/destoer

## Contributing

1. Fork it (<https://github.com/mattrberry/crab/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Matthew Berry](https://github.com/mattrberry) - creator and maintainer
