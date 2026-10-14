module Battle
  class Logic
    # Hands the effects of the Shadow Pokemon every event the engine broadcasts. They cannot ride in
    # the effects of the battler, which the engine empties on every switch out, so they are dispatched
    # from their own slot, after the ones of the engine.
    module ShadowEffectDispatch
      # Execute a block on each effect depending on what to select as effect
      # @param battlers [Array<PFM::PokemonBattler>] list of battlers we want to see their effect executed
      # @yieldparam [Effects::EffectBase]
      # @return [Array<Effects::EffectBase>, Symbol, Integer, nil] the first block return that was a symbol
      # @note This returns an enumerator if no block is given
      # @note If the block returns a Symbol, this methods returns this symbol immediately without processing the other effects
      def each_effects(*battlers)
        return to_enum(__method__, *battlers) unless block_given?

        result = super
        return result if result.is_a?(Symbol)

        battlers.compact.uniq.sort_by(&:spd_basis).reverse_each do |battler|
          battler.shadow_effects.each do |effect|
            returned = yield(effect)
            return returned if returned.is_a?(Symbol)
          end
        end

        return nil
      end
    end

    prepend ShadowEffectDispatch
  end
end
