module BeatSaber
  using WAV
  using JSON
  using DSP
  using StatsBase
  using DelimitedFiles

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

    for i=3:(length(difference) - 2)
      if difference[i] == maximum(difference[(i - 2):(i + 2)]) > 0
        push!(peaks, times[i])
      end
    end

    # 2 second delay to avoid "hot starts"
    audiooffset = 2
    return peaks .+ audiooffset
  end

  function getnotedata(note::Int, color::Int = 0)::Tuple
    x = (note - 1) % 4
    y = div((note - 1), 4) % 3
    direction = div((note - 1), 12)

    if color == 0
      return (x, y, direction)
    else
      # Flip the x-coordinate and direction if note is blue
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

  function createnote(note::Int, color::Bool, ntime::Number)
    return createnote(getnotedata(note, Int(color))..., Int(color), ntime)
  end

  function timestonotes(notetimes::Array{<:Number})::Array{Dict}
    samecolor = readdlm("samecolor.csv", Int)
    diffcolor = readdlm("diffcolor.csv", Int)

    notes = [2, 2]
    notesequence = []
    prevcolor = rand(Bool)

    function pushnote(color::Bool, t::Number)
      weights = samecolor[notes[1 + color], :] .* diffcolor[notes[2 - color], :]
      note = sample(1:96, Weights(weights .|> sqrt))
      notes[color + 1] = note
      prevcolor = color
      push!(notesequence, createnote(note, color, t))
    end

    t = 0
    for i in 1:length(notetimes)
      newtime = notetimes[i]
      if notetimes[i] - t < 0.2 # Have notes alternate between red and blue if timing is less than 0.2 seconds
        pushnote(!prevcolor, newtime)
      elseif rand() < 0.2 # Red and blue notes appearing concurrently one-fifth of the time is good mapping, yeah
        pushnote(rand(Bool), newtime)
        pushnote(!prevcolor, newtime)
      else
        pushnote(rand(Bool), newtime)
      end
      t = newtime
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
    # 2 second delay to avoid "hot starts"
    delay = `-af "adelay=2000|2000"`
    # dynamic range compression flag to improve fft processing
    # https://medium.com/@jud.dagnall/dynamic-range-compression-for-audio-with-ffmpeg-and-compand-621fe2b1a892
    drc = `-filter_complex "compand=attacks=0:points=-80/-900|-45/-15|-27/-9|0/-7|20/-7:gain=5"`

    run(`ffmpeg -i $filename $drc $wavfile`)

    write("$songname/ExpertPlus.dat", createmap(wavfile))

    run(`ffmpeg -i $filename $delay $songname/$songname.ogg`)
    rm(wavfile)
    mv("$songname/$songname.ogg", "$songname/song.egg")

    infostring = String(read("info.dat"))
    write("$songname/info.dat", replace(infostring, "<SongName>" => songname))
  end

end
