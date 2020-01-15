module BeatSaber
  using WAV
  using JSON
  using DSP
  using DelimitedFiles

  export mapsong

  function getpeaksfromaudio(data::Array{T}, bps::Number)::Array{T} where {T<:Number}
    spec = spectrogram(data, 512 * 8)

    flux = [0.0]

    for i=2:size(spec.power)[2]
      push!(flux, sum((spec.power[:,i] - spec.power[:,i-1]) .|> (x -> max(x, 0))))
    end

    rolling = []
    window = 10
    len = length(flux)
    for i=1:len
      wmin = max(1, i - window)
      wmax = min(len, i + window)
      push!(rolling, sum(flux[wmin:wmax]) / (wmax - wmin + 1))
    end

    seconds = length(flux) * 512 * 4 / bps
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

  function createnote(x::Int, y::Int, direction::Int, color::Int, ntime::Number)
    return Dict(
      "_time" => ntime,
      "_cutDirection" => direction,
      "_type" => color,
      "_lineLayer" => y,
      "_lineIndex" => x,
    )
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

  function desirability(x::Int, y::Int, direction::Int)::Number
    desire = 1
    if y == 0 && (x == 1 || x == 2)
      desire *= 2
    end
    if y == 1 && (x == 1 || x == 2)
      desire /= 3
    end
    if y == 2
      desire *= 0.5
    end
    if direction >= 4
      desire /= 2
    end
    return desire
  end

  function timestonotes(notetimes::Array{<:Number})::Array{Dict}
    matrix = readdlm("notes.csv")
    notes = [rand(1:96), rand(1:96)]
    notesequence = []

    for n in notetimes
      index = rand(1:96)
      note = rand(1:2)
      notefound = false
      while !notefound
        notetuple = getnotedata(index, note - 1)
        desire = desirability(notetuple...)
        if matrix[notes[note],index] == 1 && desire > rand()
          notefound = true
          notes[note] = index
          push!(notesequence, createnote(notetuple..., note - 1, n))
        else
          index = (index + 12) % 96 + 1
        end
      end
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
    if match(r".wav$"i, filename) == nothing
      run(`ffmpeg -i $filename $wavfile`)
    else
      cp(filename, wavfile)
    end

    write("$songname/ExpertPlus.dat", createmap(wavfile))

    run(`ffmpeg -i $wavfile $songname/$songname.ogg`)
    rm(wavfile)
    mv("$songname/$songname.ogg", "$songname/song.egg")

    infostring = String(read("info.dat"))
    write("$songname/info.dat", replace(infostring, "<SongName>" => songname))
    cp("cover.jpg", "$songname/cover.jpg")
  end

end
