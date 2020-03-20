"""
BeatSaber.jl

Convert audio files into folders containing Beat Saber maps

Three exported methods: mapsong, mapsongs, mapurl

mapurl requires youtube-dl installed and all three methods require ffmpeg

Examples:

```julia-repl
julia> mapsong("song1.mp3")
julia> mapsong("song2.mp3", "newsongname")
julia> mapsong("*.wav")
julia> mapsongs(["song1.mp3", "song2.mp3", "../music/song3.ogg"])
julia> mapsongs(["*.wav", "path/to/thing.mp3", "~/.secretmusic/song.ogg"])
julia> mapurl("https://www.youtube.com/watch?v=MRJILK3NxSM")
julia> mapurl("https://www.youtube.com/playlist?list=PLlt7a22v678y-fF2Usu3Q5sMxGWYz9xAL")
```
"""
module BeatSaber
  using WAV: wavread
  using JSON: json
  using DSP: spectrogram
  using StatsBase: sample, Weights
  using Random: randstring
  include("data.jl")

  export mapsong, mapsongs, mapurl

  function getpeaksfromaudio(data::Array{T}, bps::Number)::Array{Array{T}} where {T<:Number}
    audiorange = 1024 # The fft window
    spec = spectrogram(data, audiorange * 2).power
    len = size(spec)[2]
    times = LinRange(0, len * audiorange / bps, len)

    flux = reduce(+, spec, dims=1)
    difference = Float64[]
    rolling = 0
    window = 20
    # Get a rolling average of the flux and then calculate the difference between that and the flux
    rolling += sum(flux[1:window])
    for i=1:len
      if i - (window + 1) >= 1
        rolling -= flux[i - (window + 1)]
      end
      if i + window <= len
        rolling += flux[i + window]
      end
      avg = rolling / (window * 2 + 1) + 0.5
      push!(difference, flux[i] - avg)
    end

    # Get peaks (aka note placement times) from difference
    # 5 different arrays for 5 different difficulties
    peaks = [Float64[], Float64[], Float64[], Float64[], Float64[]]
    # The lower the difficulty, the larger the range a note has to dominate over
    ranges = [10 7 5 3 2]
    for j in 1:5
      r = ranges[j]
      for i=(r + 1):(len - r)
        if difference[i] == maximum(difference[(i - r):(i + r)]) > 0
          # 2 second delay to avoid "hot starts"
          push!(peaks[j], times[i] + 2)
        end
      end
    end

    return peaks
  end

  function getnotedata(note::Int, color::Int = 0)::Tuple
    x = (note - 1) % 4
    y = div((note - 1), 4) % 3
    direction = div((note - 1), 12)

    if color == 0
      return (x, y, direction)
    else
      # Flip the x-coordinate and direction if note is blue
      directions = Int[0 1 3 2 5 4 7 6 8]
      return (3 - x, y, directions[direction + 1])
    end
  end

  function createnote(x::Int, y::Int, direction::Int, color::Int, ntime::Number)
    return Dict(
      "_time" => ntime,
      "_cutDirection" => direction,
      "_type" => color,
      "_lineLayer" => y,
      "_lineIndex" => x,
    )
  end

  function createnote(note::Int, color::Bool, ntime::Number)
    return createnote(getnotedata(note, Int(color))..., Int(color), ntime)
  end

  function timestonotes(notetimes::Array{<:Number}, threshold::Number)::Array{Dict}
    notesb = Int[2, 2] # The previous red and blue notes, respectively
    notesa = Int[14, 14] # The red and blue notes before the previous red and blue notes, respectively
    notesequence = Dict{String, Number}[]
    prevcolor = rand(Bool)

    function pushnote(color::Bool, t::Number, ∇t::Number)
      # Multiply together 5 96-element weight arrays to get one ultimate array
      weights =
        samecolor[notesb[1 + color], :] .*
        diffcolor[notesb[2 - color], :] .*
        samecolor2[notesa[1 + color], :] .*
        diffcolor2[notesa[2 - color], :] .*
        notesallowed

      # Giving extra weight to mirrored red and blue notes helps keep hands in sync
      weights[notesb[2 - color]] *= 100

      # Capping the weight improves mapping
      # This fact was discovered on accident through a bug, but it's a feature now!
      cap = ∇t < 0.2 ? 2000 / (∇t ^ 2) : 50000
      weights = weights .|> x -> min(x, cap)

      # Raise weights to a fractional power so common patterns don't dominate
      # Fraction decreases linearly from 1 to 0.5 on domain 0:threshold and is 0.5 for all values above threshold
      power = ∇t > threshold ? 0.5 : 0.5 + 0.5 * (threshold - ∇t) / threshold
      note = sample(1:96, Weights(weights .^ power))

      # Set new previous notes and color
      notesa[color + 1] = notesb[color + 1]
      notesb[color + 1] = note
      prevcolor = color
      push!(notesequence, createnote(note, color, t))
    end

    t = 0
    timediff = 0
    for i in 1:length(notetimes)
      newtime = notetimes[i]
      timediff = newtime - t
      if timediff < 0.2 # Have notes alternate between red and blue if timing is less than 0.2 seconds
        pushnote(!prevcolor, newtime, timediff)
      elseif rand() < 0.2 # Red and blue notes appearing concurrently one-fifth of the time is good mapping, yeah
        pushnote(rand(Bool), newtime, timediff)
        pushnote(!prevcolor, newtime, timediff)
      else
        pushnote(rand(Bool), newtime, timediff)
      end
      t = newtime
    end

    return notesequence
  end

  function createbeatmapJSON(notes::Array{Dict})::String
    songdata = Dict(
      "_version" => "2.0.0",
      "_BPMChanges" => [],
      "_events" => [],
      "_notes" => notes,
      "_obstacles" => [],
      "_bookmarks" => [],
    )

    return json(songdata)
  end

  function createbeatmapJSONs(notetimes::Array{Array{T}})::Array{String} where {T<:Number}
    difficulties = Number[2, 1, 0.5, 0.3, 0.2]

    maps = String[]
    for i=1:5
      push!(maps, timestonotes(notetimes[i], difficulties[i]) |> createbeatmapJSON)
    end

    return maps
  end

  function createmaps(filename::String)::Array{String}
    rawdata, bps = wavread(filename)
    data = reduce(+, rawdata, dims=2)[:,1] # Merge channels down to mono

    peaks = getpeaksfromaudio(data, bps)
    return createbeatmapJSONs(peaks)
  end

  function mapsong(filename::String, songname::String)
    songname = replace(songname, "." => "") # Remove any periods because they screw up BMBF
    folder = randstring(['a':'z'; '0':'9'], 40) * "_" * songname
    if !isdir(folder)
      mkdir(folder)
    end

    wavfile = "$folder/$songname.wav"

    # Strip all metadata because it causes problems loading song
    clear = `-map_metadata -1 -vn`
    run(`ffmpeg -i $filename $clear $wavfile`)

    maps = createmaps(wavfile)
    write("$folder/Easy.dat", maps[1])
    write("$folder/Normal.dat", maps[2])
    write("$folder/Hard.dat", maps[3])
    write("$folder/Expert.dat", maps[4])
    write("$folder/ExpertPlus.dat", maps[5])

    # 2 second delay to avoid "hot starts"
    delay = `-af "adelay=2000|2000"`
    run(`ffmpeg -i $wavfile $delay $folder/song.ogg`)

    rm(wavfile)

    write("$folder/info.dat", replace(infostring, "<SongName>" => songname))
  end

  function expandasterisk(filename::String)::Array{String}
    path, file = splitdir(filename)
    fileregex = Regex("^\\Q" * replace(file, "*" => "\\E.*\\Q") * "\\E\$")
    files = filter(s -> occursin(fileregex, s), readdir(path))
    # After rejoining files to their paths,
    #   filter out any strings containing asterisks to prevent an infinite recursive loop
    return filter(f -> !occursin("*", f), map(f -> joinpath(path, f), files))
  end

  function mapsong(filename::String)
    # If provided name contains an asterisk, treat it as a wildcard
    if occursin("*", filename)
      mapsongs(expandasterisk(filename))
    else
      songname = splitext(splitdir(filename)[2])[1] # Isolate the name of the song itself
      mapsong(filename, songname)
    end
  end

  function mapsongs(filenames::Array{String})
    for file in filenames
      mapsong(file)
    end
  end

  function mapurl(url::String)
    temp = ".beatsaberjltempdir" # If this is an existing folder on anyone's system, I'll eat my hat
    mkdir(temp)
    try
      # Download files as wav.
      # They'll be big, but fast to process and end up deleted anyway, so size doesn't matter
      run(`youtube-dl -i --extract-audio --audio-format wav -o "$temp/%(title)s.%(ext)s" $url`)
    catch e
      @error "Error retrieving audio:"
      @error "Either youtube-dl is not installed, the url was malformed, or one or more videos were unavailable"
    end
    mapsongs("$temp/" .* readdir(temp))
    rm(temp, recursive=true)
  end

end
