module Battle
  module Effects
    class Ability
      class NaturesEssence < Ability
        def on_pre_drain(handler, hp, target, launcher, skill)
          return 1 unless launcher == @target
          return 1 unless skill
          return 1.3
        end
      end
      register(:natures_essence, NaturesEssence)
    end
  end
end
