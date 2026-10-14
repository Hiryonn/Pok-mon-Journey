module PFM
    class PokemonBattler

      def initialize(original, scene, max_level = Float::INFINITY)
        @original = original
        @battle_properties = {}
        @transform = @illusion = nil
        @scene = scene
        copy_properties
        copy_moveset
        @battle_stage = Array.new(7, 0)
        reset_states
        @battle_max_level = max_level
        @level = original.level < max_level ? original.level : max_level
        @type3 = 0
        @bank = 0
        @position = -1
        @place_in_party = 0
        @battle_item_data = []
        @battle_item = @item_holding
        @last_battle_turn = -1
        @last_sent_turn = -1
        @move_history = []
        @damage_history = []
        @successful_move_history = []
        @stat_history = []
        @encounter_list = []
        @mega_evolved = false
        @exp_distributed = false
        @item_consumed = false
        @consumed_item = :__undef__
        @high_stat = nil
        @sub_base = false
        @add_base = false
        @ko_count = 0
        self.hp = hp_rate > 0 ? (max_hp * hp_rate).to_i.clamp(1, max_hp) : 0
        $game_switches[Yuki::Sw::FollowMe_LetsGoMode] ? initialize_letsgo_set_is_follower : initialize_set_is_follower
      end

      def calibrate_hp(rate)
        new_hp = (rate * max_hp).to_i
        new_hp = 1 if new_hp <= 1
        @hp = new_hp
      end

      def base_hp
        base = data.base_hp
        base += 50 if @add_base == true
        base -= 50 if @sub_base == true
        return base
      end
            attr_accessor :high_stat #Demoralize
            attr_accessor :sub_base #MindBreak
            attr_accessor :add_base #MindBuff
  
            
            def calc_regular_stat(base, iv, ev, nature_index, stat)
              base += 50 if @add_base == true
              base -= 50 if @sub_base == true
              base_stat =  super(base,iv ,ev, nature_index)
              return base_stat = base_stat/2 if @high_stat == stat
              return base_stat
            end

            def atk_basis
              return calc_regular_stat(base_atk, @iv_atk, @ev_atk, 1, :atk)
            end
            # Return the dfe stat without battle modifier
            # @return [Integer]
            def dfe_basis
              return calc_regular_stat(base_dfe, @iv_dfe, @ev_dfe, 2 , :dfe)
            end
            # Return the spd stat without battle modifier
            # @return [Integer]
            def spd_basis
              return calc_regular_stat(base_spd, @iv_spd, @ev_spd, 3, :spd)
            end
            # Return the ats stat without battle modifier
            # @return [Integer]
            def ats_basis
              return calc_regular_stat(base_ats, @iv_ats, @ev_ats, 4, :ats)
            end
            # Return the dfs stat without battle modifier
            # @return [Integer]
            def dfs_basis
              return calc_regular_stat(base_dfs, @iv_dfs, @ev_dfs, 5, :dfs)
            end

            alias toxiced? toxic?
    end
end