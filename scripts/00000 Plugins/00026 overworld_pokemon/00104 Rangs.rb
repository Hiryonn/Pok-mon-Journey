# Overworld Pokémon : Barons (Légendes Arceus), Dominants (Soleil / Lune) et apparitions massives
#
# Le rang d'un Pokémon (:monarch, :baron ou :dominant) est mémorisé dans le Pokémon lui-même (@pj_rank) : il est donc conservé tant
# que le Pokémon existe (sauvegarde d'un chromatique, combat, équipe si on le capture).
#   Monarque  comme un Baron, en un peu mieux et plus rare, avec une lueur dorée en combat
#   Baron     niveau et IV bonus, expérience bonus quand on le bat, icône rouge au-dessus de lui sur la carte
#   Dominant  niveau bonus, aura en combat (une statistique augmente au début), expérience bonus, même icône en blanc
# L'icône est un second évènement qui suit le Pokémon, une case au-dessus.
module OverworldPokemon
  RANKS = %i[monarch baron dominant].freeze
  STATS = %i[atk dfe spd ats dfs].freeze
  IVS = %i[iv_hp iv_atk iv_dfe iv_spd iv_ats iv_dfs].freeze

  module_function

  # @param baron_rate [Integer, nil] % de Barons (nil : réglage)
  # @return [Symbol, nil]
  def pick_rank(baron_rate = nil)
    baron_rate = setting('baron_rate').to_i if baron_rate.nil?
    return :monarch if setting('monarch_rate').to_i > 0 && rand(100) < setting('monarch_rate').to_i
    return :baron if baron_rate > 0 && rand(100) < baron_rate
    return :dominant if setting('dominant_rate').to_i > 0 && rand(100) < setting('dominant_rate').to_i

    return nil
  end

  # @return [Integer] niveaux en plus
  def rank_bonus(rank)
    return setting('baron_level_bonus').to_i if rank == :baron
    return setting('monarch_level_bonus').to_i if rank == :monarch
    return setting('dominant_level_bonus').to_i if rank == :dominant

    return 0
  end

  # Donne un rang au Pokémon (IV parfaits pour un Baron)
  def apply_rank(pokemon, rank)
    return unless RANKS.include?(rank)

    pokemon.instance_variable_set(:@pj_rank, rank)
    perfect_ivs(pokemon, setting('baron_perfect_ivs').to_i) if rank == :baron
    perfect_ivs(pokemon, setting('monarch_perfect_ivs').to_i) if rank == :monarch
  end

  def perfect_ivs(pokemon, count)
    IVS.sample(count.clamp(0, 6)).each do |iv|
      if pokemon.respond_to?("#{iv}=")
        pokemon.send("#{iv}=", 31)
      else
        pokemon.instance_variable_set("@#{iv}", 31)
      end
    end
    pokemon.hp = pokemon.max_hp if pokemon.respond_to?(:max_hp) && pokemon.respond_to?(:hp=)
  rescue StandardError => e
    log_error("IV parfaits impossibles (#{e.message})")
  end

  # @return [Symbol, nil] rang d'un Pokémon ou d'un combattant
  def rank_of(pokemon)
    source = pokemon.respond_to?(:original) && pokemon.original ? pokemon.original : pokemon
    rank = source.instance_variable_get(:@pj_rank)
    return RANKS.include?(rank) ? rank : nil
  rescue StandardError
    return nil
  end

  # @return [String, nil] image de l'icône du rang
  def rank_icon(pokemon)
    rank = rank_of(pokemon)
    name = rank && setting("#{rank}_icon").to_s
    return name.nil? || name.empty? ? nil : name
  end

  # Son joué quand un Baron / Dominant apparaît
  def rank_alert(pokemon)
    rank = rank_of(pokemon)
    sound = rank && setting("#{rank}_se").to_s
    Audio.se_play(sound) unless sound.nil? || sound.empty?
  rescue StandardError
    nil
  end

  # Son joué à l'arrivée sur une carte avec apparition massive
  def outbreak_alert
    sound = setting('outbreak_se').to_s
    Audio.se_play(sound) unless sound.empty?
  rescue StandardError
    nil
  end

  # Statistique du passif du rang (aura du Dominant, force du Baron)
  # @return [Symbol, nil] nil : aucun bonus
  def rank_stat(rank)
    wanted = setting("#{rank}_boost").to_s.downcase
    return nil if wanted == 'none'

    return STATS.include?(wanted.to_sym) ? wanted.to_sym : STATS.sample
  end

  # @return [Integer] crans gagnés à l'entrée au combat
  def rank_stages(rank)
    return setting("#{rank}_boost_stages").to_i.clamp(0, 6)
  end

  # @return [String, nil] image (graphics/interface) de l'icône de combat
  def battle_icon(pokemon)
    return nil unless setting('battle_icon')

    rank = rank_of(pokemon)
    name = rank && setting("#{rank}_battle_icon").to_s
    return name.nil? || name.empty? ? nil : name
  end

  # @return [Integer] % d'expérience pour le rang
  def exp_percent(rank)
    return 100 unless rank

    return [setting("#{rank}_exp_percent").to_i, 0].max
  end

  # Évènement de l'icône : suit le Pokémon d'une case au-dessus, par-dessus tout
  # @return [Game_OverworldIcon]
  def build_icon(map, id, owner, icon)
    rpg = RPG::Event.new(owner.x, [owner.y - 1, 0].max)
    rpg.id = id
    rpg.name = 'pokemon_visible_icone'
    page = rpg.pages[0]
    page.graphic.character_name = icon
    page.graphic.direction = 2
    page.graphic.pattern = 0
    page.move_type = 0
    page.move_speed = setting('move_speed').to_i.clamp(1, 6)
    page.move_frequency = 5
    page.walk_anime = false
    page.step_anime = false
    page.direction_fix = true
    page.through = true
    page.always_on_top = true
    page.trigger = 0
    page.list = [RPG::EventCommand.new(0, 0, [])]
    return Game_OverworldIcon.new(map.map_id, rpg, owner)
  end

  # Commande d'évènement : combat immédiat contre un Pokémon de rang
  def rank_battle(interpreter, rank, species, level)
    pokemon = PFM::Pokemon.new(species, [level.to_i + rank_bonus(rank), 100].min)
    apply_rank(pokemon, rank)
    interpreter.call_battle_wild(pokemon, nil)
  end
end

class Game_OverworldIcon < Game_Event
  # @param owner [Game_OverworldPokemon]
  def initialize(map_id, event, owner)
    @ow_owner = owner
    super(map_id, event)
  end

  def update
    super
    ow_follow
  rescue StandardError => e
    OverworldPokemon.log_error("icône : #{e.message}") unless @ow_failed
    @ow_failed = true
  end

  private

  def ow_follow
    owner = @ow_owner
    return erase if owner.nil? || owner.erased
    return if moving? || jumping?

    tx = owner.x
    ty = [owner.y - 1, 0].max
    dx = tx - x
    dy = ty - y
    return if dx == 0 && dy == 0

    if dx.abs + dy.abs == 1
      move_straight(dx > 0 ? 6 : dx < 0 ? 4 : dy > 0 ? 2 : 8, false)
    else
      moveto(tx, ty)
    end
  end
end

# Combat : annonce du Pokémon sauvage, passif caché (une statistique monte à l'entrée), expérience bonus, icône
module Battle
  class Logic
    class SwitchHandler
      module OverworldRankAnnounce
        def execute_switch_events(who, with)
          super
          return unless with&.alive?

          rank = OverworldPokemon.rank_of(with)
          return unless rank

          announced = @logic.instance_variable_get(:@pj_rank_announced) || @logic.instance_variable_set(:@pj_rank_announced, [])
          return if announced.include?(with.original)

          announced << with.original
          announce_rank(with, rank) if with.bank == 1
          stat = OverworldPokemon.rank_stat(rank)
          stages = OverworldPokemon.rank_stages(rank)
          @logic.stat_change_handler.stat_change_with_process(stat, stages, with) if stat && stages > 0
        end

        private

        def announce_rank(pokemon, rank)
          if rank == :monarch
            @scene.display_message_and_wait(OverworldPokemon.t("#{pokemon.given_name} est un Pokémon Monarque !",
                                                              "#{pokemon.given_name} is a Noble Pokémon!"))
          elsif rank == :baron
            @scene.display_message_and_wait(OverworldPokemon.t("#{pokemon.given_name} est un Pokémon Baron !",
                                                              "#{pokemon.given_name} is an Alpha Pokémon!"))
          else
            @scene.display_message_and_wait(OverworldPokemon.t("Une aura enveloppe #{pokemon.given_name} !",
                                                              "An aura surrounds #{pokemon.given_name}!"))
          end
        end
      end
      prepend OverworldRankAnnounce
    end

    class ExpHandler
      module OverworldRankExp
        # Un Baron / Dominant donne plus d'expérience
        def distribute_exp_for(enemy)
          data = super
          percent = OverworldPokemon.exp_percent(OverworldPokemon.rank_of(enemy))
          return data if percent == 100

          data.each_key { |receiver| data[receiver] = (data[receiver] * percent / 100.0).round }
          return data
        end
      end
      prepend OverworldRankExp
    end
  end
end

module PFM
  class Pokemon
    # @return [Boolean] Pokémon Baron ?
    def baron?
      return instance_variable_get(:@pj_rank) == :baron
    end

    # @return [Boolean] Pokémon Monarque ?
    def monarch?
      return instance_variable_get(:@pj_rank) == :monarch
    end

    # @return [Boolean] Pokémon Dominant ?
    def dominant?
      return instance_variable_get(:@pj_rank) == :dominant
    end
  end
end

# Icône du rang sur la boîte d'infos du combat (Pokémon sauvage, Pokémon de l'équipe capturé)
module BattleUI
  class InfoBar
    # Petite image (16 px) affichée quand le Pokémon est Baron ou Dominant
    class RankIcon < Sprite
      # @param pokemon [PFM::Pokemon, nil]
      def data=(pokemon)
        name = pokemon && OverworldPokemon.battle_icon(pokemon)
        self.visible = !name.nil?
        return unless name

        self.bitmap = RPG::Cache.interface(name)
        zoom = OverworldPokemon.setting('battle_icon_zoom').to_i.clamp(10, 400) / 100.0
        self.zoom_x = self.zoom_y = zoom
      rescue StandardError
        self.visible = false
      end
    end

    module OverworldRankIcon
      def data=(pokemon)
        super
        return unless OverworldPokemon.setting('battle_icon')

        unless @pj_rank_icon
          ax, ay = pj_rank_anchor
          @pj_rank_icon = add_sprite(ax + OverworldPokemon.setting('battle_icon_x').to_i, ay + OverworldPokemon.setting('battle_icon_y').to_i, nil, type: RankIcon)
        end
        @pj_rank_icon.data = pokemon
      rescue StandardError => e
        OverworldPokemon.log_error("icône de combat : #{e.message}") unless @pj_rank_failed
        @pj_rank_failed = true
      end
    end
    prepend OverworldRankIcon

    private

    # Position de la marque (par rapport à la boîte) : à droite de la barre de vie, sinon à côté de la marque chromatique
    # @return [Array(Integer, Integer)]
    def pj_rank_anchor
      bar = instance_variable_get(:@hp_bar)
      if bar.respond_to?(:x) && bar.respond_to?(:y)
        width = bar.respond_to?(:bar_width) ? bar.bar_width : (bar.respond_to?(:width) ? bar.width : 0)
        return [bar.x - x + width.to_i, bar.y - y - 6]
      end
      star = instance_variable_get(:@star)
      return [star.x - x + 8, star.y - y] if star.respond_to?(:x) && star.respond_to?(:y)

      return [0, 0]
    rescue StandardError
      return [0, 0]
    end
  end
end

# Lueur dorée autour d'un Monarque en combat
module BattleUI
  class PokemonSprite
    module OverworldMonarchGlow
      def update
        super
        pokemon = @pokemon
        return unless pokemon && OverworldPokemon.rank_of(pokemon) == :monarch && OverworldPokemon.setting('monarch_glow')
        return if @animation_tone && !@stop_status_tone
        return if pokemon.dead? || !visible

        @pj_glow = (@pj_glow || 0) + 1
        alpha = 0.28 + 0.16 * Math.sin(@pj_glow / 14.0)
        shader&.set_float_uniform('color', [1.0, 0.78, 0.2, alpha])
      rescue StandardError
        nil
      end
    end
    prepend OverworldMonarchGlow
  end
end
