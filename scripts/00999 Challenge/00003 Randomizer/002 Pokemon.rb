module PFM
  # The InGame Pokemon management
  class Pokemon
    module RandomizerPokemon
      # Properties that have been changed by the randomizer
      attr_accessor :randomizer_properties

      # Create a new Pokemon with specific parameters
      def initialize(*args)
        @randomizer_properties = {}
        super(*args)
      end

      # Return the max HP of the Pokemon
      # @return [Integer]
      def max_hp
        return 1 if ability_db_symbol == :wonder_guard

        return super
      end

      # Change the id of the Pokemon
      # @param new_id [Integer] the new id of the Pokemon
      def id=(new_id)
        # Randomizer: use base method if the evolution has the same experience type, otherwise update the exp
        if data_creature_form(id, @form).experience_type == data_creature_form(new_id, @form).experience_type
          super(new_id)
          return
        end

        @character = nil
        if new_id && (req = data_creature(new_id)).id != 0 && (forms = req.forms)
          # Randomizer: Fix the exp if different exp curve
          exp_last = exp_list[@level]
          delta = exp_lvl - exp_last
          exp_lvl_percent = (exp - exp_last).to_f / delta.to_f
          @id = req.id
          @db_symbol = forms.first.db_symbol
          @form = 0 if forms.none? { |creature_form| creature_form.form == @form }
          @form = form_generation(-1) if @form == 0
          @form = 0 if forms.none? { |creature_form| creature_form.form == @form }
          @exp = exp_list[@level] + (exp_lvl_percent * (exp_list[@level + 1] - exp_list[@level])).to_i
          update_ability
        end
      end
    end
  end

  PFM::Pokemon.prepend(PFM::Pokemon::RandomizerPokemon)
end
