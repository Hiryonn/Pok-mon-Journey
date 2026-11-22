# Natures PV : les natures peuvent aussi modifier les PV
#
# Dans Data/Studio/natures/<nature>.json, ajoute "hp" dans "stats" (100 = neutre, 110 = +10 %, 90 = -10 %) :
#   "stats": { "hp": 110, "atk": 90, "dfe": 100, "spd": 100, "ats": 100, "dfs": 100 }
# Sans "hp", la nature ne touche pas aux PV (comme avant).
#
# Les PV max sont multipliés par ce taux (Munja garde toujours 1 PV). Quand la nature change (Menthe),
# les PV perdus sont conservés.
#
# Note : PSDK convertit les données de Studio dans Data/Studio/psdk.dat. En test, si une nature a été
# modifiée après ce fichier, il est supprimé au lancement pour être refait avec les nouvelles natures.
unless PSDK_CONFIG.release?
  dat = 'Data/Studio/psdk.dat'
  if File.exist?(dat) && Dir['Data/Studio/natures/*.json'].any? { |file| File.mtime(file) > File.mtime(dat) }
    begin
      File.delete(dat)
    rescue StandardError
      nil
    end
  end
end

module Studio
  class Nature
    # Modificateur des PV (100 = neutre)
    # @return [Integer]
    def hp
      value = stats.is_a?(Hash) ? stats[:hp] : nil
      return value ? value.to_i : 100
    end
  end
end

module PFM
  class Pokemon
    module NaturePV
      # PV max avec le modificateur de la nature
      # @return [Integer]
      def max_hp
        value = super
        return value if db_symbol == :shedinja

        rate = nature_hp
        return value if rate == 100

        return [value * rate / 100, 1].max
      end

      # Modificateur des PV de la nature (Menthe comprise)
      # @return [Integer] 100 = neutre
      def nature_hp
        nature = @mint_nature ? data_nature(mint_nature_db_symbol) : data_nature(nature_db_symbol)
        return nature.respond_to?(:hp) ? nature.hp : 100
      rescue StandardError
        return 100
      end

      # Menthe : garde les PV perdus quand les PV max changent
      def mint_nature=(value)
        lost = max_hp - hp
        alive = hp > 0
        super
        self.hp = (max_hp - lost).clamp(1, max_hp) if alive
      end
    end
    prepend NaturePV
  end
end
