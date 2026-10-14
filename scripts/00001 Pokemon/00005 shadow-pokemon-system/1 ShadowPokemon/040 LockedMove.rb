module PFM
  # Slot of an original move a Shadow Pokemon cannot use yet, shown in place of the move its locked
  # heart still holds back. It answers the little the interfaces read of a move and nothing more, so
  # it never travels to the battle logic, which would have no idea what to do with it.
  class LockedMove
    # Name shown in place of the one of the move.
    # @return [String]
    NAME = '????'
    # Text shown in place of a value the move would carry.
    # @return [String]
    UNKNOWN_VALUE = '---'
    # Text shown in place of the remaining power points.
    # @return [String]
    UNKNOWN_PP = '??'
    # Type shown, the undefined one of the database, whose cell no game fills.
    # @return [Integer]
    TYPE = 0
    # Category shown, the status one, the games telling nothing of the category of a locked move.
    # @return [Integer]
    ATK_CLASS = 3

    # @return [String]
    def name
      return NAME
    end

    # @return [Integer]
    def type
      return TYPE
    end

    # @return [Integer]
    def atk_class
      return ATK_CLASS
    end

    # Power points left, none, which also draws the empty power point box.
    # @return [Integer]
    def pp
      return 0
    end

    # @return [Integer]
    def ppmax
      return 0
    end

    # @return [String]
    def pp_text
      return UNKNOWN_PP
    end

    # @return [String]
    def power_text
      return UNKNOWN_VALUE
    end

    # @return [String]
    def accuracy_text
      return UNKNOWN_VALUE
    end

    # @return [String]
    def description
      return ShadowTexts.message(:locked_move)
    end

    # Reason the move cannot be chosen, which the move choice asks for before taking it. A locked
    # slot is never usable, and it says why in its description rather than in a battle message.
    # @param _user [PFM::PokemonBattler] the lock owes nothing to the state of the creature
    # @return [Proc]
    def disable_reason(_user)
      return proc {}
    end
  end
end
