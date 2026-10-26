# Script décompilé depuis le bytecode du jeu (Ruby 3.0) — fichier d'origine : RMXP/99999_Dex_Specie_Count.rb
# Les commentaires et la mise en forme d'origine ne sont pas récupérables.

module Raty
  module DexSpeciesCountPokemonExt
    def pokedex_nb_captured
      count = $pokedex.creature_caught_count(db_symbol)
      count = 1 if count.zero?
      word = $options.language == "en" ? "Captured" : count == 1 ? "Capturé" : "Capturés"

      if count > 50
        "#{word} : 50+"
      else
        "#{word} : #{count}"
      end
    end

    def pokedex_shiny_rate
      count = $pokedex.creature_caught_count(db_symbol)
      shiny_rate = case count
      when (0..9) then "1/4096"
      when (10..19) then "1/2048"
      when (20..29) then "1/1024"
      when (30..49) then "1/512"
      else
        "1/256"
      end

      "Shiny : #{shiny_rate}"
    end
  end
end

PFM::Pokemon.prepend(Raty::DexSpeciesCountPokemonExt)
