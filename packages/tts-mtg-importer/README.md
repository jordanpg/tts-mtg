# TTS MTG Importer

This project is for creating a single bundled script to use in Tabletop Simulator. It provides a set of chat-based actions that allow users to spawn in decks and cards from Magic: The Gathering.

This is a rewrite of [Amuzet's original Importer.lua script](https://github.com/Amuzet/Tabletop-Simulator-Scripts/blob/master/Magic/Importer.lua), which shares the same purpose.

## File Extensions

This project uses `.ttslua` as an extension to refer to Lua scripts which directly rely on being run in the context of Tabletop Simulator, usually requiring the use of TTS-specific functions.

`.lua` files are general-purpose, and can be run standalone.