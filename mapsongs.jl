include("BeatSaber.jl")
using .BeatSaber

for file in ARGS
  mapsong(file, splitext(splitdir(file)[2])[1])
end
