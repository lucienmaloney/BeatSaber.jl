# BeatSaber.jl

An automatic mapping tool for quickly generating Beat Saber courses from audio files.

## Requirements

* The Julia Language (see https://julialang.org/downloads/)
* The following Julia packages: WAV, JSON, DSP, and StatsBase (see https://docs.julialang.org/en/v1/stdlib/Pkg/index.html)
* ffmpeg (see https://ffmpeg.org/download.html)
* BMBF (Quest only, see https://bsaber.com/oculus-quest-custom-songs/)
* youtube-dl (Optional, only needed for mapurl.jl, see https://youtube-dl.org/)

* if you are on windows FFmpeg and Julia must be added to PATH 
## Usage

You can download BeatSaber.jl as a zip or clone it with `git clone https://github.com/lucienmaloney/BeatSaber.jl.git`

The easiest entry point is mapsongs.jl, which can be used like so:

`julia src/mapsongs.jl songname.songextension`

This will create a folder songname containing a Beat Saber map

Any audio extension supported by ffmpeg should work, though the output will always be an .ogg file. Also, multiple songs can be mapped at once using a wildcard:

`julia src/mapsongs.jl ~/somefolder/*.mp3`

If you have youtube-dl installed, you can download songs or playlists from YouTube or elsewhere (there are a surprising number of sites supported) directly form a url:

`julia src/mapurl.jl "https://www.youtube.com/watch?v=MRJILK3NxSM"`

The utility runs in O(n) time and in fact takes less time actually generating the maps than it does converting the audio files to the correct formats. However, the first time the utility is run, it might take considerably longer as packages get compiled for the first time.

With the maps generated, the new folders should be moved or copied over into the CustomSongs directory of BeatSaber. On the Quest with BMBF installed, this can be found in QuestDrive:/BMBFData/CustomSongs. Next, unplug the quest, put it on, and run the BMBF app. Navigate to the tools tab at the top, and then click "Reload Songs Folder". Finally, click "Sync to Beat Saber", and the new songs should be ready to play.

Because of the messy nature of the Quest ecosystem, the BMBF app is understandably a bit buggy sometimes. It may be necessary to close and reopen the app or to hit "Reload Songs Folder" multiple times to get it working. Additionally, song names with special characters in them sometimes cause problems, so it's not a bad idea to remove those from song file names before running the utility. Asterisks especially should be removed from file names because the program will think it's a pattern match. Letters, numbers, spaces, dashes, underscores, brackets, and parentheses all seem to work fine, though.

## Patterns

For each color red and blue, there are 8 directions * 4 x-coordinates * 3 y-coordinates = 96 different notes possible (Note that dot-notes are intentionally excluded as they muddle the flow of maps). So each different kind of note can represented as an index from 1 to 96 where `noteindex = x + y * 4 + direction * 12 + 1`

#### Colors
0: Red, 1: Blue

#### Directions
0: Up, 1: Down, 2: Left, 3: Right, 4: UpLeft, 5: UpRight, 6: DownLeft, 7: DownRight

#### Locations
  0   |   1   |   2   |   3
------|-------|-------|-------
(0,2) | (1,2) | (2,2) | (3,2)
(0,1) | (1,1) | (2,1) | (3,1)
(0,0) | (1,0) | (2,0) | (3,0)

## Mapping

In `src/data.jl`, there are four UInt16 arrays each containing a 96 * 96 matrix representing a weighted, directed graph from every note to every other note. `samecolor` and `samecolor2` describe homogenous color patterns, red to red and blue to blue. `diffcolor` and `diffcolor2` describe the opposite, how a note of one color should affect the next note of the opposite color. Additionally, `samecolor` and `diffcolor` refer to immediate relationships, so for example how one red note will effect the next red note, whereas `samecolor2` and `diffcolor2` describe relationships once removed. For example, a blue note passed to `diffcolor2` affects the probability not of the next red note but of the red note after that.

A zero in the graph indicates a certain sequence should never happen. For example, there are zeros down the diagonal of `samecolor` as good mapping dictates that a note should never be followed by an identical note. The non-zero values had their weights determined by mining data from existing Beat Saber maps. This was approaced from a quality over quantity perspective, so only 12 of the best flowing maps were chosen for extraction:

* A Thousand Miles
* Bad Romance
* Call Me Maybe
* Firework
* Hardware Store
* Little Swing
* Mr. Blue Sky
* Numb
* Pumped Up Kicks
* Sk8er Boi
* The Nights
* Uprising

These maps were chosen not because they're necessarily the best of the best (although I think they're all pretty good), but because they contain simple and understandable flows for the algorithm to pick up on. As the program becomes more complex and robust, it may be possible to feed it more dynamic data to get a greater variety of maps. But for now, these are the ones being used.

A big thank you to the mappers of these songs for creating such useful training data!

## adding to path

open the file explorer 
right click on "this PC"
click on "properties" 
and then "advanced system settings" (it will be off to the left)
then go to "enviornment variables"
double click on "PATH"
click "browse"
go to the FFmpeg folder (you should have placed it in the "C:\Users\yourusername\FFmpeg" folder or "C:\FFmpeg") and click ok
Do the same thing for Julia
