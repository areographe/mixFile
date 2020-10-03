# mixFile-master
Internal tool for batch processing multiple audio files

## What is this tool for?

This tool is intended for creating sample libraries. When recording an instrument, separate audio files are generated for every note the instrument can play, e.g. A2, Bb2, B2, C2, Db2, D2, etc. These audio files are created from multiple microphone sources, e.g. A2_close.wav, A2_room.wav, A2_overhead.wav; Bb2_close.wav, Bb2_room.wav, Bb2_overhead.wav; etc. Every set of audio files of the same note are recordings of the exact same performance at the same time, but capture different versions of the sound based on distance and the natural reverb (echo) of the room. This tool allows thousands of these sets of audio files to be merged into one file per note, that contains a mixdown of the files with each input file's volume and stereo panning set by the user.

## What needs to be done

In some cases, the microphones are 'out of phase' (see links) and do not mix together properly. In this case, one or more of the audio files needs to have its phase inverted (actually the polarity of the signal). I believe in Swift this can be done by essentially multiplying each sample's value by -1, but I'm not sure how to do this (with AVFoundation, an Accelerate vector function, both, or some other technique). In the interface of the program, the user specifies which (if any) audio file inputs should have the phase inverted. 

In other cases, the distance the sound has travelled to get to some microphones causes an audible delay. In this situation, the user can specify a delay amount in milliseconds, and if positive, that file's audio will have that many milliseconds of silence added at the start, or if negative, the file's audio will have that many milliseconds removed from its start. e.g. if the user enters 1000, that audio buffer will have 1 second of silence before the audio data from the file begans, whereas if they entered -500, the audio buffer will begin from 0.5 seconds into the audio file, with the first 0.5 seconds removed.

## Links that might be useful

https://music.stackexchange.com/questions/66737/what-is-the-purpose-of-phase-invert

https://stackoverflow.com/questions/8158075/invert-audio-coming-through-microphone

https://stackoverflow.com/questions/54308068/how-to-generate-phase-inverse-audio-file-from-input-audio-file-in-swift

## Original job posting

>I'm in the process of updating an existing tool written in Swift 4.0 to be deployed on a few computers running macOS 10.12 and above, and need to add two new features. The tool uses AVFoundation and Accelerate frameworks to read two audio files into buffers, mix them together, and output a new audio file. This job post is intended for someone with a thorough understanding of audio processing in Swift using the AVFoundation framework, as I am not familiar with it and am unable to create the required functionality.

>The two new features required are:
>1. to 'delay' the audio in a particular buffer (an AVAudioPCMBuffer object) by a specified number of seconds, i.e. to prepend a specified number of seconds of silence to the beginning of the audio buffer, extending the total length of the audio buffer by that number of seconds - if the number of seconds is negative, that number of seconds must be removed from the beginning, and the total length of the audio therefore shortened by that number of seconds as well
>2. to invert the phase/polarity of a particular buffer, in case the two audio files to be mixed together exhibit undesirable cancellation.

>The existing code to mix the two buffers together is attached, with placeholders for the two new features. Currently, the function that mixes two buffers is an extension of the class AVAudioPCMBuffer, a subclass of AVAudioBuffer, and uses the Accelerate framework's vDSP_vsma to perform the merger of the two audio buffers and return a single object with the original audio data mixed at the volume and panning specified. The function also takes a phase inversion and a delay argument, but these have not been implemented.
