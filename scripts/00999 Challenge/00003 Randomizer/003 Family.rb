module PFM
  class Randomizer
    module Family
      module_function

      # Reverse evolution index, built once from the compiled database
      # @return [Hash{Symbol => Symbol}] child db_symbol => parent db_symbol
      def list_of_children
        return @child if @child

        @child = {}
        each_data_creature.each do |creature|
          creature.forms.each do |form|
            form.evolutions.each do |evolution|
              parent = evolution.db_symbol
              next if parent.nil? || parent == :__undef__

              # Keep the lowest symbol so a creature reachable from two families stays deterministic
              known = @child[parent]
              @child[parent] = creature.db_symbol if known.nil? || creature.db_symbol < known
            end
          end
        end

        # Shedinja is spawned by code, not by an evolution entry
        @child[:shedinja] = :nincada
        return @child
      end

      # @param db_symbol [Symbol]
      # @return [Symbol] db_symbol of the first stage of the family
      def root(db_symbol)
        seen = {} # Infinite loop security (if a Pokémon evolves into its base)
        current = db_symbol

        while (child = list_of_children[current]) && !seen[current]
          seen[current] = true
          current = child
        end

        return current
      end
    end
  end
end
