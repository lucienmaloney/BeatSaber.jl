# BeatSaber.jl

An automatic mapping tool for quickly generating Beat Saber courses from audio files.

## Requirements

* The Julia Language (see https://julialang.org/downloads/)
* The following Julia packages: WAV, JSON, DSP, StatsBase, DelimitedFiles (see https://docs.julialang.org/en/v1/stdlib/Pkg/index.html)
* ffmpeg (see https://ffmpeg.org/download.html)
* BMBF (Quest only, see https://bsaber.com/oculus-quest-custom-songs/)

## Usage

The easiest entry point is mapsongs.jl, which can be used like so:

`julia mapsongs.jl songname.songextension`

This will create a folder songname containing a Beat Saber map

Any audio extension supported by ffmpeg should work, though the output will always be an .ogg file. Also, multiple songs can be mapped at once using a wildcard:

`julia mapsongs.jl ~/somefolder/*.mp3`

The utility runs in O(n) time and in fact takes less time actually generating the maps than it does converting the audio files to the correct formats. However, the first time the utility is run, it might take considerably longer as packages get compiled for the first time.

With the maps generated, the new folders should be moved or copied over into the CustomSongs directory of BeatSaber. On the Quest with BMBF installed, this can be found in QuestDrive:/BMBFData/CustomSongs. Next, unplug the quest, put it on, and run the BMBF app. Navigate to the tools tab at the top, and then click "Reload Songs Folder". Finally, click "Sync to Beat Saber", and the new songs should be ready to play.

Because of the messy nature of the Quest ecosystem, the BMBF app is understandably a bit buggy sometimes. It may be necessary to close and reopen the app or to hit "Reload Songs Folder" multiple times to get it working. Additionally, song names with special characters in them sometimes cause problems, so it's not a bad idea to remove those from song file names before running the utility. Letters, numbers, spaces, dashes, underscores, brackets, and parentheses all seem to work fine, though

## Patterns

For each color red and blue, there are 8 directions * 4 x-coordinates * 3 y-coordinates = 96 different notes possible (Note that dot-notes are intentionally excluded as they muddle the flow of maps). So each different kind of note can represented as an index from 1 to 96 where `noteindex = x + y * 4 + direction * 12 + 1`

#### Colors
0: Red
1: Blue

#### Directions
0: Up
1: Down
2: Left
3: Right
4: UpLeft
5: UpRight
6: DownLeft
7: DownRight

#### Locations
2: (0,2) | (1,2) | (2,2) | (3,2)
1: (0,1) | (1,1) | (2,1) | (3,1)
0: (0,0) | (1,0) | (2,0) | (3,0)
     0       1       2       3

## Mapping

There are two .csv files each containing a 96 * 96 matrix representing a weighted, directed graph from every note to every other note. `samecolor.csv` describes homogenous color patterns, red to red and blue to blue. `diffcolor.csv` describes the opposite, how a note of one color should affect the next note of the opposite color.

A zero in the graph indicates a certain sequence should never happen. For example, there are zeros down the diagonal of `samecolor.csv` as good mapping dictates that a note should never be followed by an identical note. The non-zero values had their weights determined by mining data from existing Beat Saber maps. This was approaced from a quality over quantity perspective, so only 12 of the best flowing maps were chosen for extraction: A Thousand Miles, Bad Romance, Call Me Maybe, Firework, Hardware Store, Little Swing, Mr. Blue Sky, Numb, Pumped Up Kicks, Sk8er Boi, The Nights, and Uprising. A big thank you to the mappers of these songs for creating such good training data!
