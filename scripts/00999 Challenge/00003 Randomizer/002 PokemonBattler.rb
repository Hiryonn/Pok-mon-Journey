module PFM
  class PokemonBattler
    module RandomizerPokemonBattler
      COPIED_PROPERTIES << :@randomizer_properties
      BACK_PROPERTIES << :@randomizer_properties
    end
  end

  PFM::PokemonBattler.prepend(PFM::PokemonBattler::RandomizerPokemonBattler)
end
