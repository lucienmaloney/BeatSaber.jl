## Patterns

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
8: Middle/Dot

#### Locations
2: (0,2) | (1,2) | (2,2) | (3,2)
1: (0,1) | (1,1) | (2,1) | (3,1)
0: (0,0) | (1,0) | (2,0) | (3,0)
     0       1       2       3

#### Notes Mapping
0: Instant
1: Blitz
2: Rapid
3: Medium
4: Slow
5: None


Potentially Plausible Plan:

Take the last note sequence hit in the generated song
Find all instances of that in all training data
If the note sequence does not contain both colors, work backwards until it does, filtering as you go
Now there should be an array containing all instances of the sequence
Now work forwards, selecting the next sequence that most closely matches the time diff
