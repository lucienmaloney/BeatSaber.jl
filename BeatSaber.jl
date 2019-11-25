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

  function createMapJSON(noteTimes::Array{T})::String where {T<:Number}
    notes = map(t -> createNote(rand(0:1), rand(0:8), t, rand(0:3), 0), noteTimes)

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
