module BeatSaber
  using WAV
  using JSON

  export mapSong

  function getPeaks(arr::Array{T}, sweepRadius::Int)::Array{T} where {T<:Number}
    longRadius = sweepRadius * 5

    shortRolling = sum(arr[1:sweepRadius])
    longRolling = sum(arr[1:longRadius])
    arrLength = length(arr)

    peaks = []
    beenBelow = true

    for i=1:arrLength
      shortAdd = i + sweepRadius > arrLength ? 0 : arr[i + sweepRadius]
      shortSubtract = i - sweepRadius < 1 ? 0 : arr[i - sweepRadius]
      longAdd = i + longRadius > arrLength ? 0 : arr[i + longRadius]
      longSubtract = i - longRadius < 1 ? 0 : arr[i - longRadius]

      shortRolling = shortRolling + shortAdd - shortSubtract
      longRolling = longRolling + longAdd - longSubtract

      if beenBelow && shortRolling > longRolling * (1.3 / 5)
        beenBelow = false
        push!(peaks, i)
      elseif !beenBelow && shortRolling < longRolling / 5
        beenBelow = true
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

  function createMapJSON(noteTimes::Array{T})::String where {T<:Number}
    notes = mapNotes(noteTimes)

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
    data = (rawdata[:,1] + rawdata[:,2]) .^ 2 # Merge two channels into one
    sweep = convert(Int, round(bps / 50))

    peaks = getPeaks(data, sweep)
    maxtimes = peaks / bps
    json = createMapJSON(maxtimes)

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
      cp(songname, wavfile)
    end

    write("$songname/ExpertPlus.dat", createMap(wavfile))

    run(`ffmpeg -i $wavfile $songname/$songname.ogg`)
    rm(wavfile)
    mv("$songname/$songname.ogg", "$songname/song.egg")

    infostring = String(read("info.dat"))
    write("$songname/info.dat", replace(infostring, "<SongName>" => songname))
  end

end
