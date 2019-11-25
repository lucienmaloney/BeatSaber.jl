module BeatSaber
  using WAV
  export createMap

  function createMap(filename::String)
    rawdata, rawbps = wavread(filename)

    println(rawbps)
  end

end
