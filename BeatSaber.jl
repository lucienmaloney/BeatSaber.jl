module BeatSaber
  using WAV
  using JSON
  using PyPlot
  export createMap

  function getRollingAverage(arr::Array{T}, sweepRadius::Int)::Array{T} where {T<:Number}
    rolling = sum(arr[1:sweepRadius])
    avgArr = []
    arrLength = length(arr)

    for i=1:arrLength
      toAdd = i + sweepRadius > arrLength ? 0 : arr[i + sweepRadius]
      toSubtract = i - sweepRadius < 1 ? 0 : arr[i - sweepRadius]
      rolling = rolling + toAdd - toSubtract
      push!(avgArr, rolling)
    end

    return avgArr
  end

  function getMaxes(arr::Array{T}, lookahead::Int)::Array{T} where {T<:Number}
    direction = true
    extremavalue = 0
    extremaindex = 1
    postcount = 0
    maxtimes = []
    minextrema = 0

    i = 1
    while i <= length(arr)
      if xor(arr[i] < extremavalue, direction)
        extremavalue = arr[i]
        extremaindex = i
        postcount = 0
      else
        postcount += 1
      end

      if postcount >= lookahead
        if direction
          push!(maxtimes, extremaindex)
        else
          i -= lookahead
          minextrema = extremavalue
        end
        direction = !direction
        postcount = 0
      end

      i += 1
    end

    return maxtimes
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

    rollavg = getRollingAverage(data, sweep)
    maxindices = getMaxes(rollavg, sweep * 5)
    maxtimes = maxindices / bps
    json = createMapJSON(maxtimes)

    write("Expert.dat", json)
  end

end
