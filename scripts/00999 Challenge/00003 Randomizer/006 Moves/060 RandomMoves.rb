module PFM
  class Pokemon
    module RandomMoves
      # Check if the Pokemon can learn a new skill and make it learn the skill
      # @param silent [Boolean] if the skill is automatically learnt or not (false = show skill learn interface & messages)
      # @param level [Integer] The level to check in order to learn the moves (<= 0 = evolution)
      def check_skill_and_learn(silent = false, level = @level)
        return super unless PFM.game_state.randomizer.moves.enabled?

        @randomized = true

        learn_move = proc do |db_symbol|
          next if skill_learnt?(db_symbol)
          next GamePlay.open_move_teaching(self, db_symbol) unless silent

          @skills_set << PFM::Skill.new(db_symbol)
          @skills_set.shift if @skills_set.size > 4
          @skill_learnt << db_symbol unless @skill_learnt.include?(id) || @skill_learnt.include?(db_symbol)
        end

        if level <= 0
          data.move_set.select(&:evolution_learnable?).each do |move|
            learn_move.call(randomize_move(data_move(move.move)))
          end
        else
          data.move_set.select { |move| move.level_learnable? && move.level == level }.each do |move|
            learn_move.call(randomize_move(data_move(move.move)))
          end
        end

        @randomized = false
      end

      # Learn a new skill
      # @param db_symbol [Symbol] db_symbol of the move in the database
      # @return [Boolean, nil] true = learnt, false = already learnt, nil = couldn't learn
      def learn_skill(db_symbol)
        move = data_move(db_symbol)
        move = data_move(randomize_move(move)) if PFM.game_state.randomizer.moves.enabled? && !@randomized

        return false if skill_learnt?(move.db_symbol, only_in_move_set: false)

        if @skills_set.size < 4
          @skills_set << PFM::Skill.new(move.db_symbol)
          @skill_learnt << move.db_symbol unless @skill_learnt.include?(move.id) || @skill_learnt.include?(move.db_symbol)
          form_calibrate if data.db_symbol == :keldeo
          return true
        end
        return nil
      end

      # Get the list of all the skill the Pokemon can learn again
      # @param mode [Integer] Define the moves that can be learnt again :
      #   1 = breed_moves + learnt + potentially_learnt
      #   2 = all moves
      #   other = learnt + potentially_learnt
      # @return [Array<Symbol>]
      def remindable_skills(mode = 0)
        return super unless PFM.game_state.randomizer.moves.enabled?

        if randomizer_properties[:moves].nil? || randomizer_properties[:moves].empty?
          move_set = data.move_set
          level = mode == 2 ? Float::INFINITY : @level

          moves = move_set.select { |move| move.level_learnable? && level >= move.level }.map(&:move)
          moves.concat(move_set.select { |move| move.breed_learnable? || move.evolution_learnable? }.map(&:move)) if mode == 1 || mode == 2

          randomizer_properties[:moves] = moves.map { |m| randomize_move(data_move(m)) }.uniq
        end

        moves = Array(randomizer_properties[:moves]).dup
        moves.concat(@skill_learnt.map { |move| move.is_a?(Integer) ? data_move(move).db_symbol : move })

        return (moves - skills_set.map(&:db_symbol)).uniq
      end

      # Load the skill from an Array
      # @param skills [Array] the skills array (containing IDs or Symbols)
      def load_skill_from_array(skills)
        return super unless PFM.game_state.randomizer.moves.enabled?

        skills.each_with_index do |skill, j|
          next skills_set[j] = nil if skill == :__remove__
          next if skill == 0 || skill == :__undef__ || skill.is_a?(String)

          skill = randomize_move(data_move(skill))
          replace_skill_index(j, skill)
        end
        skills_set.compact!
      end

      private

      # Get a random move from the entire skill list, excluding moves with 1 pp that aren't status (Z Moves)
      # @param move [Studio::Move] the move to randomize
      # @return [Symbol] db_symbol of the move sampled
      def randomize_move(move)
        rng = Random.new(PFM.game_state.randomizer.seed ^ @id ^ move.id)

        return move_pool.sample(random: rng).db_symbol
      end

      # Get the move pool, which is all the moves in the game except those in Set SHOULD_NOT_BE_SELECTED
      # @return [Array<Studio::Move>] the move pool
      def move_pool
        return each_data_move.reject do |move|
          SHOULD_NOT_BE_SELECTED.include?(move.db_symbol)
        end
      end
    end
  end
end

PFM::Pokemon.prepend(PFM::Pokemon::RandomMoves)
