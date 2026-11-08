# Pokédex PE : variante du Pokédex toujours valide
module PFM
  class Pokedex
    # Pokédex utilisé quand la variante enregistrée n'existe pas dans Studio
    PE_FALLBACK_VARIANT = :national

    # Remet le Pokédex sur une variante qui existe et contient des créatures.
    # PSDK démarre sur :regional, qui n'existe pas dans ce projet : depuis PSDK 26.61 l'ouverture plante.
    # @return [Symbol] la variante retenue
    def pe_ensure_valid_variant
      return @variant if pe_valid_variant?(@variant)

      candidates = @seen_variants.to_a + [PE_FALLBACK_VARIANT]
      candidates.concat(each_data_dex.map(&:db_symbol))
      fallback = candidates.find { |variant| pe_valid_variant?(variant) }
      self.variant = fallback if fallback
      @seen_variants.delete_if { |variant| !pe_valid_variant?(variant) }
      return @variant
    end

    private

    # @param variant [Symbol]
    # @return [Boolean]
    def pe_valid_variant?(variant)
      dex = each_data_dex.find { |data| data.db_symbol == variant }
      return dex && !dex.creatures.empty? ? true : false
    end
  end
end
