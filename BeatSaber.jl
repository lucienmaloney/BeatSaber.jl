module BeatSaber
  using WAV
  using JSON
  using DSP
  using StatsBase

  export mapsong

  function getpeaksfromaudio(data::Array{T}, bps::Number)::Array{T} where {T<:Number}
    audiorange = 1024
    spec = spectrogram(data, audiorange * 2)

    flux = [0.0]

    for i=2:size(spec.power)[2]
      push!(flux, sum((spec.power[:,i] - spec.power[:,i-1]) .|> (x -> max(x, 0))))
    end

    rolling = []
    window = 20
    len = length(flux)
    for i=1:len
      wmin = max(1, i - window)
      wmax = min(len, i + window)
      push!(rolling, sum(flux[wmin:wmax]) / (wmax - wmin + 1))
    end

    seconds = length(flux) * audiorange / bps
    times = LinRange(0, seconds, length(flux))
    difference = (flux - rolling) .|> (x -> max(x, 0))

    peaks = []

    for i=2:(length(difference) - 1)
      val = difference[i]
      if val > difference[i - 1] && val > difference[i + 1]
        push!(peaks, times[i])
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
      directions = [0 1 3 2 5 4 7 6 8]
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

  function createnote(note::Int, color::Int, ntime::Number)
    return createnote(getnotedata(note, color)..., color, ntime)
  end

  function desirability(note::Number)::Number
    positions = [2 2 1 0.5 1 0.01 0.01 0.1 0.5 0.3 0.2 0.1]
    directions = [2 2 1 1 0.5 0.5 0.5 0.5]
    return positions[(note - 1) % 12 + 1] * directions[div(note - 1, 12) + 1]
  end

  function randnote(notes::Array)::Int
    return sample(notes, Weights(notes .|> desirability))
  end

  function timestonotes(notetimes::Array{<:Number})::Array{Dict}
    patterns = JSON.parsefile("patterns.json")
    α = patterns["sequence"]
    β = patterns["concurrent"]
    notes = [2, 2]
    notesequence = []
    prevtime = 0

    for n ∈ notetimes
      timediff = n - prevtime
      note = rand(1:2)
      redrange = α[notes[1]] ∩ β[notes[2]]
      red = randnote(length(redrange) > 0 ? redrange : α[notes[1]])

      bluerange = α[notes[2]] ∩ β[notes[1]]
      blue = randnote(length(bluerange) > 0 ? bluerange : α[notes[2]])

      rednote = createnote(red, 0, n)
      bluenote = createnote(blue, 1, n)

      if rand() > 0.4 && blue ∈ β[red] && timediff > 0.2
        notes = [red, blue]
        push!(notesequence, rednote)
        push!(notesequence, bluenote)
      elseif rand(1:2) == 1
        notes[1] = red
        push!(notesequence, rednote)
      else
        notes[2] = blue
        push!(notesequence, bluenote)
      end
      prevtime = n
    end

    return notesequence
  end

  function createbeatmapJSON(notetimes::Array{T})::String where {T<:Number}
    notes = timestonotes(notetimes)

    songData = Dict(
      "_version" => "2.0.0",
      "_BPMChanges" => [],
      "_events" => [],
      "_notes" => notes,
      "_obstacles" => [],
      "_bookmarks" => [],
    )

    return json(songData)
  end

  function createmap(filename::String)::String
    rawdata, bps = wavread(filename)
    data = reduce(+, rawdata, dims=2)[:,1] # Merge channels down to mono

    peaks = getpeaksfromaudio(data, bps)
    json = createbeatmapJSON(peaks)

    return json
  end

  function mapsong(filename::String, songname::String)
    if !isdir(songname)
      mkdir(songname)
    end

    wavfile = "$songname/$songname.wav"
    # dynamic range compression flag borrowed from https://medium.com/@jud.dagnall/dynamic-range-compression-for-audio-with-ffmpeg-and-compand-621fe2b1a892
    run(`ffmpeg -i $filename -filter_complex "compand=attacks=0:points=-80/-900|-45/-15|-27/-9|0/-7|20/-7:gain=5" $wavfile`)

    write("$songname/ExpertPlus.dat", createmap(wavfile))

    run(`ffmpeg -i $filename $songname/$songname.ogg`)
    rm(wavfile)
    mv("$songname/$songname.ogg", "$songname/song.egg")

    infostring = String(read("info.dat"))
    write("$songname/info.dat", replace(infostring, "<SongName>" => songname))
    cp("cover.jpg", "$songname/cover.jpg")
  end

end
