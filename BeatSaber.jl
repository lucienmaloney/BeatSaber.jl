module BeatSaber
  using WAV
  using JSON
  using DSP
  using DelimitedFiles

  export mapSong

  function getPeaks(data::Array{T}, bps::Number)::Array{T} where {T<:Number}
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

    seconds = length(data) / bps
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

  function createNote(color::Int, direction::Int, ntime::Number, x::Int, y::Int)
    return Dict(
      "_time" => ntime,
      "_cutDirection" => direction,
      "_type" => color,
      "_lineLayer" => y,
      "_lineIndex" => x,
    )
  end

  function createReversedNote(pattern::String, ntime::Number)::Dict
    args = map(c -> parse(Int, c), collect(pattern))
    color = args[4] == 1 ? 0 : 1
    dir = args[3]
    if dir == 2 || dir == 4 || dir == 6
      dir += 1
    elseif dir == 3 || dir == 5 || dir == 7
      dir -= 1
    end
    return createNote(color, dir, ntime, 3 - args[1], args[2])
  end

  function createNote(pattern::String, ntime::Number)::Dict
    args = map(c -> parse(Int, c), collect(pattern))
    return createNote(args[4], args[3], ntime, args[1], args[2])
  end

  function mapNotes(noteTimes::Array{<:Number})::Array{Dict}
    patterns = JSON.parsefile("patterns.json")["patterns"]
    patternslength = length(patterns)
    notes = []
    i = 1

    while i <= length(noteTimes)
      pattern = patterns[rand(1:patternslength)]
      reversed = rand(Bool)
      patternlength = length(pattern)

      for j=1:patternlength
        subpattern = pattern[j]
        foreach(n -> push!(notes, reversed ? createReversedNote(n, noteTimes[i]) : createNote(n, noteTimes[i])), subpattern)
        i += 1
        if i > length(noteTimes)
          return notes
        end
      end
    end

    return notes
  end

  function timesToNotes(noteTimes::Array{<:Number})::Array{Dict}
    patterns = JSON.parsefile("patterns.json")
    patternkeys = collect(keys(patterns))
    previousnote = missing
    penultimatenote = missing
    lastreddirection = -1
    lastbluedirection = -1
    notes = []

    for notetime in noteTimes
      if !haskey(patterns, previousnote)
        penultimatenote = missing
        previousnote = rand(patternkeys)
      end

      if !haskey(patterns[previousnote], penultimatenote)
        tempkeys = collect(keys(patterns[previousnote]))
        penultimatenote = rand(tempkeys)
      end

      unfiltereddict = patterns[previousnote][penultimatenote]
      dict = filter(function(p)
        for i=1:4:length(p[1])
          if (p[1][i + 3] == '0' && p[1][i + 2] == lastreddirection) || (p[1][i + 3] == '1' && p[1][i + 2] == lastbluedirection)
            return false
          end
        end
        return true
      end, unfiltereddict)

      if length(dict) == 0
        dict = unfiltereddict
      end

      total = values(dict) |> sum
      target = rand(1:total)
      counter = 0

      for k in keys(dict)
        counter += dict[k]
        if counter >= target
          penultimatenote = previousnote
          previousnote = k
          for i = 1:4:length(k)
            if k[i + 3] == '1'
              lastbluedirection = k[i + 2]
            else
              lastreddirection = k[i + 2]
            end
            newnote = createNote(k[i:(i + 3)], notetime)
            push!(notes, newnote)
          end
          counter = -1000000
        end
      end
    end

    return notes
  end

  function noteindex(x::Int, y::Int, dir::Int)::Int
    return x + y * 4 + dir * 12
  end

  function notedata(note::Int)::Tuple
    x = (note - 1) % 4
    y = div((note - 1), 4) % 3
    direction = div((note - 1), 12)

    return (x, y, direction)
  end

  function mapSingleHand(noteTimes::Array{<:Number})::Array{Dict}
    notepatterns = readdlm("notes.csv", Int8)
    starternote = (rand(1:2), rand(1:2), rand(0:7))
    nindex = noteindex(starternote...)
    notes = [createNote(0, starternote[3], noteTimes[1], starternote[1], starternote[2])]

    for i=2:length(noteTimes)
      timeDiff = noteTimes[i] - noteTimes[i - 1]
      index = rand(1:96)
      notefound = false
      while !notefound
        index = index % 96 + 1
        level = notepatterns[nindex, index]
        if (level == 0 && timeDiff <= 0.05) || (level == 1 && timeDiff <= 0.1) || (level == 2 && timeDiff > 0.1) || (level == 3 && timeDiff > 0.25) || (level == 4 && timeDiff > 0.75)
          nindex = index
          newnote = notedata(index)
          push!(notes, createNote(0, newnote[3], noteTimes[i], newnote[1], newnote[2]))
          notefound = true
        end
      end
    end

    return notes
  end

  function createMapJSON(noteTimes::Array{T})::String where {T<:Number}
    notes = timesToNotes(noteTimes)

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

  function createMap(filename::String)::String
    rawdata, bps = wavread(filename)
    data = reduce(+, rawdata, dims=2)[:,1] # Merge channels down to mono
    #sweep = convert(Int, round(bps / 50))

    peaks = getPeaks(data, bps)
    #maxtimes = peaks / bps
    json = createMapJSON(peaks)

    return json
  end

  function mapSong(filename::String, songname::String)
    if !isdir(songname)
      mkdir(songname)
    end

    wavfile = "$songname/$songname.wav"
    if match(r".wav$"i, filename) == nothing
      run(`ffmpeg -i $filename $wavfile`)
    else
      cp(filename, wavfile)
    end

    write("$songname/ExpertPlus.dat", createMap(wavfile))

    run(`ffmpeg -i $wavfile $songname/$songname.ogg`)
    rm(wavfile)
    mv("$songname/$songname.ogg", "$songname/song.egg")

    infostring = String(read("info.dat"))
    write("$songname/info.dat", replace(infostring, "<SongName>" => songname))
    cp("cover.jpg", "$songname/cover.jpg")
  end

end
