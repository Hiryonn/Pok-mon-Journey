# Magic Backlash (s_extra_magic_backlash) : contrecoup de la moitié des dégâts infligés au lanceur.
module Battle
  class Move
    class ExtraMagicBacklash < RecoilMove
      def recoil_factor
        return 2
      end
    end
    Move.register(:s_extra_magic_backlash, ExtraMagicBacklash)
  end
end
