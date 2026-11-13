# Variantes : sprites chromatiques faits dans Studio (Données > Pokémon > Variantes > Shiny / Radiant)
#
# Studio écrit le sprite chromatique sous le nom donné dans la fiche du Pokémon (Ressources), ou sous
# « <sprite normal>s » quand la fiche n'en a pas : PSDK le trouve alors ici (sinon il montrerait « 000 »).
module PFM
  class Pokemon
    class << self
      module PJChromatiquesStudio
        def front_filename(id, form, female, shiny, egg)
          name = super
          return name unless shiny && !egg && name == '000'

          return Variantes.shiny_fallback(id, form, :front) || name
        end

        def back_filename(id, form, female, shiny, egg)
          name = super
          return name unless shiny && !egg && name == '000'

          return Variantes.shiny_fallback(id, form, :back) || name
        end

        def icon_filename(id, form, female, shiny, egg)
          res = data_creature_form(id, form).resources
          if shiny && !egg && res && res.icon_shiny.to_s.empty? && !res.icon.to_s.empty?
            alt = "#{res.icon}s"
            return alt if RPG::Cache.b_icon_exist?(alt)
          end
          return super
        end
      end
      prepend PJChromatiquesStudio
    end
  end
end

module Variantes
  module_function

  # @param kind [Symbol] :front ou :back
  # @return [String, nil] « <sprite normal>s » s'il existe dans pokefrontshiny / pokebackshiny
  def shiny_fallback(id, form, kind)
    res = data_creature_form(id, form).resources
    base = res && (kind == :front ? res.front : res.back).to_s
    return nil if base.nil? || base.empty?

    alt = "#{base}s"
    exist = kind == :front ? RPG::Cache.poke_front_exist?(alt, 1) : RPG::Cache.poke_back_exist?(alt, 1)
    return exist ? alt : nil
  rescue StandardError
    return nil
  end
end
