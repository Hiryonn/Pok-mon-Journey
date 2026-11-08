# Advanced Pokédex : ouverture depuis la fiche du Pokédex (DROITE)
module AdvancedPokedex
  # Ajouts à GamePlay::Dex
  module DexHook
    # Pokémon précédent / suivant pour les pages Taille et Poids
    # @param delta [Integer]
    # @return [PFM::Pokemon, nil]
    def advanced_dex_step(delta)
      return nil if @selected_creatures.nil? || @selected_creatures.size <= 1

      @index = (@index + delta) % @selected_creatures.size
      update_index_descr
      return @pokemon
    end

    private

    def update_descr_navigation
      return open_advanced_dex if Input.trigger?(:RIGHT)

      return super
    end

    # @return [Boolean] false (touche utilisée)
    def open_advanced_dex
      unless AdvancedPokedex.available?(@pokemon)
        play_buzzer_se
        return false
      end
      play_decision_se
      call_scene(GamePlay::AdvancedPokedex, @pokemon, self)
      return false
    end
  end

  # Ajouts à GamePlay::DexInfo (fiche seule, ouverte depuis l'équipe ou un évent)
  module DexInfoHook
    def update_inputs
      if Input.trigger?(:RIGHT)
        if AdvancedPokedex.available?(@pokemon)
          play_decision_se
          call_scene(GamePlay::AdvancedPokedex, @pokemon, nil)
        else
          play_buzzer_se
        end
        return false
      end
      return super
    end
  end

  module_function

  # @param pokemon [PFM::Pokemon, nil]
  # @return [Boolean] si les pages Taille / Poids peuvent s'ouvrir pour ce Pokémon
  def available?(pokemon)
    return false unless pokemon
    return true unless get(:require_caught)

    return $pokedex.creature_caught?(pokemon.db_symbol)
  rescue StandardError
    return true
  end
end

GamePlay::Dex.prepend(AdvancedPokedex::DexHook)
GamePlay::DexInfo.prepend(AdvancedPokedex::DexInfoHook)
