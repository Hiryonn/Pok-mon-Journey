# Variantes : sprites chromatiques faits dans Studio (Données > Pokémon > Variantes > Shiny / Radiant)
#
# Studio écrit le sprite chromatique sous le nom donné dans la fiche du Pokémon (Ressources), ou sous
# « <sprite normal>s » quand la fiche n'en a pas : PSDK le trouve alors ici (sinon il montrerait « 000 »).
module PFM
  class Pokemon
    module PJTauxChromatique
      private

      # Taux de chromatique réglé dans Studio (Métaux > Taux d'apparition) : 1 chance sur N, par essai
      # (Charme Chroma et chaîne de pêche donnent toujours plus d'essais). 4096 : tirage de PSDK.
      def code_initialize
        rate = Variantes.rate(:shiny)
        return super if rate == 4096

        attempts = shiny_attempts.clamp(1, 1000)
        win = rate > 0 && attempts.times.any? { rand(rate) == 0 }
        # PSDK : chromatique si les 16 bits bas du code sont sous 16
        @code = (rand(0xFFFF_FFFF) & 0xFFFF_0000) | (win ? rand(16) : 16 + rand(0xFFFF - 16))
      end
    end
    prepend PJTauxChromatique

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
