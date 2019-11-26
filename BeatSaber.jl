module BeatSaber
  using WAV
  using JSON

  export createMap

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

  function createNote(pattern::String, ntime::Number)
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
      patternlength = length(pattern)

      for j=1:patternlength
        subpattern = pattern[j]
        foreach(n -> push!(notes, createNote(n, noteTimes[i])), subpattern)
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

  function createMap(filename::String)
    rawdata, bps = wavread(filename)
    data = (rawdata[:,1] + rawdata[:,2]) .^ 2 # Merge two channels into one
    sweep = convert(Int, round(bps / 50))

    peaks = getPeaks(data, sweep)
    maxtimes = peaks / bps
    json = createMapJSON(maxtimes)

    write("Expert.dat", json)
  end

end
