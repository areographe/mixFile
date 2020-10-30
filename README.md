# mixFile-master
Internal tool for batch processing multiple audio files

## What is this tool for?

This tool is intended for creating sample libraries. When recording an instrument, separate audio files are generated for every note the instrument can play, e.g. A2, Bb2, B2, C2, Db2, D2, etc. These audio files are created from multiple microphone sources, e.g. A2_close.wav, A2_room.wav, A2_overhead.wav; Bb2_close.wav, Bb2_room.wav, Bb2_overhead.wav; etc. Every set of audio files of the same note are recordings of the exact same performance at the same time, but capture different versions of the sound based on distance and the natural reverb (echo) of the room. This tool allows thousands of these sets of audio files to be merged into one file per note, that contains a mixdown of the files with each input file's volume and stereo panning set by the user.
