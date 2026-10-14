#encoding: utf-8
#----------------------------------------
# Mod pour \pokemonsdk\scripts\00600 Script_RMXP\00200 Game_Variables.rb
#----------------------------------------

# Class that describe game variables
class Game_Variables < Array
  unless false
    # Setter
    # @param index [Integer] the index of the variable in the Array
    # @param v [Integer] the new value of the variable
    # @raise [TypeError] when maker or script attempt to store inconsistent value in the game variables.
    def []=(index, v)
      unless v.is_a?(Integer)
        raise TypeError, "Unexpected #{v.class} value. $game_variables store numbers and nothing else, use $option to store anything else."
      else
        super(size, 0) while size < index
        super(index, v)
      end
    end
  end

  # Setter
  # @param index [Integer] the index of the variable in the Array
  # @param v [Integer] the new value of the variable
  def []=(index, value)
    index = retrieve_id_from_alias(index) if index.is_a?(Symbol)
    super(index, value)
  end
end
