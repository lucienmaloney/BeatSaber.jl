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

  function getnotedata(note::Int)::Tuple
    x = (note - 1) % 4
    y = div((note - 1), 4) % 3
    direction = div((note - 1), 12)

    return (x, y, direction)
  end

  function timestonotes(notetimes::Array{<:Number})::Array{Dict}
    matrix = readdlm("notes.csv")
    note = rand(1:96)
    notes = []

    for n in notetimes
      index = rand(1:96)
      while matrix[note,index] != 1
        index = index % 96 + 1
      end
      note = index
      push!(notes, createnote(getnotedata(note)..., 0, n))
    end

    return notes
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
