module PFM
  class ShadowHeart
    # Amount each purification source removes, per nature, as taken from Pokemon XD.
    # A nature that fights well opens slowly when soothed, and the other way around.
    # @return [Hash{ Symbol => Hash{ Symbol => Integer } }]
    RATES = {
      hardy: { battle: 110, call: 300, walk: 100, scent: 90 },
      lonely: { battle: 70, call: 330, walk: 100, scent: 130 },
      brave: { battle: 130, call: 270, walk: 90, scent: 80 },
      adamant: { battle: 110, call: 270, walk: 110, scent: 80 },
      naughty: { battle: 120, call: 270, walk: 110, scent: 70 },
      bold: { battle: 110, call: 270, walk: 90, scent: 100 },
      docile: { battle: 100, call: 360, walk: 80, scent: 120 },
      relaxed: { battle: 90, call: 270, walk: 110, scent: 100 },
      impish: { battle: 120, call: 300, walk: 100, scent: 80 },
      lax: { battle: 100, call: 270, walk: 90, scent: 110 },
      timid: { battle: 70, call: 330, walk: 110, scent: 120 },
      hasty: { battle: 130, call: 300, walk: 70, scent: 100 },
      serious: { battle: 100, call: 330, walk: 110, scent: 90 },
      jolly: { battle: 120, call: 300, walk: 90, scent: 90 },
      naive: { battle: 100, call: 300, walk: 120, scent: 80 },
      modest: { battle: 70, call: 300, walk: 120, scent: 110 },
      mild: { battle: 80, call: 270, walk: 100, scent: 120 },
      quiet: { battle: 100, call: 300, walk: 100, scent: 100 },
      bashful: { battle: 80, call: 300, walk: 90, scent: 130 },
      rash: { battle: 90, call: 300, walk: 90, scent: 120 },
      calm: { battle: 80, call: 300, walk: 110, scent: 110 },
      gentle: { battle: 70, call: 300, walk: 130, scent: 100 },
      sassy: { battle: 130, call: 240, walk: 100, scent: 70 },
      careful: { battle: 90, call: 300, walk: 100, scent: 110 },
      quirky: { battle: 130, call: 270, walk: 80, scent: 90 }
    }

    # Pace used when the nature is unknown, the median of the official table.
    # @return [Hash{ Symbol => Integer }]
    NEUTRAL_RATES = { battle: 100, call: 300, walk: 100, scent: 100 }
  end
end
