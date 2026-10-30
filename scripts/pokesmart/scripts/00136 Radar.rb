# PokeSmart : Pokémon sauvages de la zone et écran de l'appli Troupeaux
module UI
  module PokeSmart
    module_function

    # Groupes de Pokémon sauvages actifs ici (zone actuelle, conditions de carte / interrupteur remplies)
    # @return [Array<Studio::Group>]
    def wild_groups
      zone = $env&.current_zone_data
      return [] unless zone

      return zone.wild_groups.to_a.map { |db_symbol| data_group(db_symbol) }.compact.select { |group| group_active?(group) }
    rescue StandardError
      return []
    end

    # @param group [Studio::Group]
    # @return [Boolean]
    def group_active?(group)
      return group.custom_conditions.to_a.reduce(true) do |previous, condition|
        current = condition_ok?(condition)
        condition.relation_with_previous_condition.to_s.casecmp?('OR') ? (previous || current) : (previous && current)
      end
    rescue StandardError
      return true
    end

    # @return [Boolean]
    def condition_ok?(condition)
      value = condition.value.to_i
      case condition.type.to_s
      when 'mapId' then return $game_map.map_id == value
      when 'enabledSwitch' then return $game_switches[value] ? true : false
      when 'disabledSwitch' then return !$game_switches[value]
      end
      return true
    end

    # @param group [Studio::Group]
    # @return [Boolean]
    def water_group?(group)
      return WATER_TAGS.include?(group.system_tag.to_s) || WATER_TOOLS.include?(group.tool.to_s)
    end

    # Pokémon sauvages de la zone, sans doublon (ceux sur terre d'abord)
    # @return [Array<Array(Symbol, Integer)>] [espèce, forme]
    def wild_species
      groups = wild_groups.sort_by { |group| water_group?(group) ? 1 : 0 }
      list = groups.flat_map { |group| group.encounters.to_a.map { |encounter| [encounter.specie, encounter.form.to_i] } }
      return list.uniq
    end

    # Écran de l'appli Troupeaux : Pokémon sauvages de la zone
    class Radar < SpriteStack
      # @param viewport [Viewport]
      # @param phone [Phone]
      def initialize(viewport, phone)
        @color = phone.text_color
        super(viewport, phone.x + phone.theme[:radar][0], phone.y + phone.theme[:radar][1], default_cache: :interface)
        @species = PokeSmart.wild_species
        @water = (groups = PokeSmart.wild_groups).any? && groups.all? { |group| PokeSmart.water_group?(group) }
        @scroll = 0
        create_panel
        create_slots
        create_daynight
        refresh
      end

      # Fait défiler d'une ligne (haut / bas)
      # @param delta [Integer]
      # @return [Boolean] si la liste a bougé
      def scroll(delta)
        max = [(@species.size + COLUMNS - 1) / COLUMNS - RADAR_ROWS, 0].max
        target = (@scroll + delta).clamp(0, max)
        return false if target == @scroll

        @scroll = target
        refresh
        return true
      end

      private

      def create_panel
        rows = ((@species.size + COLUMNS - 1) / COLUMNS).clamp(1, RADAR_ROWS)
        name = @species.empty? ? (PokeSmart.french? ? 'group_items_empty' : 'group_items_empty_en') : "group_items_#{rows}"
        add_sprite(4, 22, PokeSmart.file(name))
        return if @species.empty?

        add_sprite(-2, 16, PokeSmart.file(@water ? 'radar_water' : 'radar_ground'))
      end

      def create_slots
        @slots = Array.new(RADAR_ROWS * COLUMNS) do |i|
          x = 4 + (i % COLUMNS) * 32
          y = 22 + (i / COLUMNS) * 32
          unknown = add_sprite(x, y, nil)
          unknown.set_bitmap('000', :b_icon)
          icon = push(x + 16, y + 16, nil, true, type: UI::PokemonIconSprite)
          ball = add_sprite(x + 22, y + 22, PokeSmart.file('wild_captured'))
          [unknown, icon, ball]
        end
        @slots.flatten.each { |sprite| sprite.visible = false }
      end

      def create_daynight
        image, fr, en = DAYNIGHT[PokeSmart.time_of_day]
        add_sprite(24, 124, PokeSmart.file(image))
        add_text(46, 128, 56, 14, PokeSmart.french? ? fr : en, 0, color: @color)
      end

      def refresh
        @slots.each_with_index do |(unknown, icon, ball), i|
          specie, form = @species[@scroll * COLUMNS + i]
          seen = specie && $pokedex&.creature_seen?(specie)
          unknown.visible = specie && !seen ? true : false
          icon.visible = false
          ball.visible = seen && $pokedex.creature_caught?(specie) ? true : false
          icon.data = creature(specie, form) if seen
        end
      end

      # @return [PFM::Pokemon, nil]
      def creature(specie, form)
        @creatures ||= {}
        return @creatures[[specie, form]] ||= PFM::Pokemon.new(specie, 5, false, true, form)
      rescue StandardError
        return nil
      end
    end
  end
end
