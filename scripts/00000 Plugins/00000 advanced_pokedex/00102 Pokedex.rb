# Advanced Pokédex : ouverture depuis la fiche du Pokédex (DROITE : page Données avec le Pokédex Horizon, sinon Taille)
module AdvancedPokedex
  # Ajouts à GamePlay::Dex
  module DexHook
    # Pokémon précédent / suivant pour les pages Données, Taille et Poids
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

    public

    # Onglets de la barre du bas de la fiche (Pokédex Horizon) : ouvrent la page voulue
    def advanced_data = open_advanced_dex(:data)
    def advanced_tasks = open_advanced_dex(:tasks)
    def advanced_height = open_advanced_dex(:height)
    def advanced_weight = open_advanced_dex(:weight)

    private

    # @param page [Symbol, nil] page à ouvrir (nil : la première)
    # @return [Boolean] false (touche utilisée)
    def open_advanced_dex(page = nil)
      unless AdvancedPokedex.available?(@pokemon)
        play_buzzer_se
        return false
      end
      play_decision_se
      call_scene(GamePlay::AdvancedPokedex, @pokemon, self, page)
      return false
    end
  end

  # Ajouts à GamePlay::DexInfo (fiche seule, ouverte depuis l'équipe ou un évent)
  module DexInfoHook
    def advanced_data = open_advanced_info(:data)
    def advanced_tasks = open_advanced_info(:tasks)
    def advanced_height = open_advanced_info(:height)
    def advanced_weight = open_advanced_info(:weight)

    # @param page [Symbol, nil]
    def open_advanced_info(page = nil)
      return play_buzzer_se unless AdvancedPokedex.available?(@pokemon)

      play_decision_se
      call_scene(GamePlay::AdvancedPokedex, @pokemon, nil, page)
    end

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

  # Les pages s'ouvrent pour tout Pokémon vu ; s'il n'est pas capturé et que « require_caught » est coché, sa taille
  # et son poids restent « ??? » (voir GamePlay::AdvancedPokedex#known?)
  # @param pokemon [PFM::Pokemon, nil]
  # @return [Boolean] si les pages peuvent s'ouvrir pour ce Pokémon
  def available?(pokemon)
    return false unless pokemon

    return $pokedex.creature_seen?(pokemon.db_symbol) || $pokedex.creature_caught?(pokemon.db_symbol)
  rescue StandardError
    return true
  end
end

GamePlay::Dex.prepend(AdvancedPokedex::DexHook)
GamePlay::DexInfo.prepend(AdvancedPokedex::DexInfoHook)
