# Overworld Pokémon : l'évènement d'un Pokémon visible (déplacements et contact)
class Game_OverworldPokemon < Game_Event
  # @return [PFM::Pokemon] le Pokémon de la carte (celui du combat)
  attr_reader :ow_pokemon
  # @return [Symbol] :wander, :flee ou :charge
  attr_reader :ow_nature
  # @return [Hash, nil] fiche sauvegardée d'un Pokémon chromatique (retirée de la sauvegarde au début du combat)
  attr_reader :ow_entry

  # @param map_id [Integer]
  # @param event [RPG::Event]
  # @param pokemon [PFM::Pokemon]
  # @param nature [Symbol]
  # @param tag [Integer, nil] tag système de la tuile d'origine (il ne quitte pas ce terrain)
  # @param entry [Hash, nil] fiche sauvegardée (Pokémon chromatique)
  def initialize(map_id, event, pokemon, nature, tag = nil, entry = nil)
    @ow_pokemon = pokemon
    @ow_nature = nature
    @ow_tag = tag
    @ow_entry = entry
    @ow_placed = false
    @ow_noticed = false
    super(map_id, event)
    @ow_sleeping = OverworldPokemon.sleeper?(nature, @id)
  end

  # @return [Boolean] le Pokémon dort (la nuit, tempérament wander) : il ne bouge pas tant que le joueur n'est pas tout près
  def ow_sleeping?
    return @ow_sleeping ? true : false
  end

  def update
    if @ow_sleeping
      return if (x - $game_player.x).abs + (y - $game_player.y).abs > OverworldPokemon.setting('wake_distance').to_i

      @ow_sleeping = false
    end
    super
    ow_update
  rescue StandardError => e
    OverworldPokemon.log_error("comportement : #{e.message}") unless @ow_failed
    @ow_failed = true
  end

  private

  def ow_update
    return if erased || @ow_pokemon.nil? || OverworldPokemon.busy?

    unless @ow_placed
      @ow_placed = true
      OverworldPokemon.keep_away_from_player(self)
      OverworldPokemon.shiny_alert(@ow_pokemon) if @ow_entry
      OverworldPokemon.rank_alert(@ow_pokemon)
    end
    return if moving? || jumping?

    distance = (x - $game_player.x).abs + (y - $game_player.y).abs
    notice = OverworldPokemon.setting('notice_distance').to_i
    if distance <= notice
      OverworldPokemon.notice(self, @ow_pokemon) unless @ow_noticed
      @ow_noticed = true
    else
      @ow_noticed = false
    end
    case @ow_nature
    when :flee
      ow_move(:away) if distance <= notice
    when :charge
      if distance <= 1
        start
      elsif distance <= notice
        ow_move(:toward)
      end
    end
  end

  # Un pas vers / loin du joueur, sans sortir de son terrain
  def ow_move(way)
    before = [x, y]
    way == :toward ? move_toward_player : (respond_to?(:move_away_from_player) ? move_away_from_player : turn_away_from_player)
    return if [x, y] == before || @ow_tag.nil?

    moveto(*before) unless $game_map.system_tag_here?(x, y, @ow_tag)
  end
end
