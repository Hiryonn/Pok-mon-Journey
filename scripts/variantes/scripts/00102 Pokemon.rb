# Variantes : le Pokémon garde sa variante (@variant = :silver, :gold, :radiant ou nil)
module Variantes
  # Ajouts à PFM::Pokemon
  module PokemonVariant
    # PFM::Pokemon.new(id, level, shiny, no_shiny, form, { variant: :gold }) force une variante
    def initialize(id, level, force_shiny = false, no_shiny = false, form = -1, opts = {})
      super
      wanted = opts.is_a?(Hash) ? (opts[:variant] || opts['variant']) : nil
      if wanted
        self.variant = wanted
      elsif !no_shiny
        @variant = Variantes.roll(@id, @form)
      end
    end

    # @return [Symbol, nil] :silver, :gold, :radiant ou nil
    def variant
      return @variant
    end

    # @param value [Symbol, String, nil]
    def variant=(value)
      value = value.to_s.empty? ? nil : value.to_sym
      value = nil unless Variantes::LIST.include?(value)
      @variant = value
      @character = nil
    end

    # @return [Boolean]
    def silver?
      return @variant == :silver
    end

    # @return [Boolean]
    def gold?
      return @variant == :gold
    end

    # @return [Boolean]
    def radiant?
      return @variant == :radiant
    end

    # @return [String] nom de la variante ('' si aucune)
    def variant_name
      return Variantes.name(@variant)
    end

    # Une variante compte aussi comme chromatique (réglable dans Studio)
    def shiny?
      return true if @variant && Variantes.count_as_shiny?

      return super
    end

    def shiny
      return shiny?
    end

    def icon
      return super if !@variant || egg?

      filename = PFM::Pokemon.icon_filename(id, form, female?, false, false)
      return Variantes.texture(:icon, filename, @variant) { RPG::Cache.b_icon(filename) } || super
    end

    def battler_face
      return super if !@variant || egg?

      filename = PFM::Pokemon.front_filename(id, form, female?, false, false)
      return Variantes.texture(:front, filename, @variant) { RPG::Cache.poke_front(filename, 0) } || super
    end
    alias battler_front battler_face

    def battler_back
      return super if !@variant || egg?

      filename = PFM::Pokemon.back_filename(id, form, female?, false, false)
      return Variantes.texture(:back, filename, @variant) { RPG::Cache.poke_back(filename, 0) } || super
    end

    # Les sprites animés (.gif) ne sont pas recolorés : le sprite fixe est utilisé
    def gif_face
      return super if !@variant || egg?

      return nil
    end

    def gif_back
      return super if !@variant || egg?

      return nil
    end
  end

  module_function

  # Tirage de la variante d'un nouveau Pokémon
  # @param creature_id [Integer]
  # @param form [Integer]
  # @return [Symbol, nil]
  def roll(creature_id, form)
    LIST.each do |variant|
      chance = rate(variant)
      next if chance <= 0 || rand(chance) != 0
      next if variant == :radiant && !radiant_available?(creature_id, form)

      return variant
    end
    return nil
  rescue StandardError
    return nil
  end
end

PFM::Pokemon.prepend(Variantes::PokemonVariant)

# La variante suit le Pokémon en combat
module PFM
  class PokemonBattler
    COPIED_PROPERTIES << :@variant unless COPIED_PROPERTIES.frozen? || COPIED_PROPERTIES.include?(:@variant)
  end
end
