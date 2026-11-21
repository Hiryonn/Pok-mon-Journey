# Pokémon Obscurs : baisse de la jauge (pas, Pension, Parfums) et purification
#
# Jauge : walk_gauge par pas pour chaque Pokémon Obscur de l'équipe, daycare_gauge par pas à la Pension (sans
# expérience), Parfums (réglage scents : P. Doux, P. Excitant, P. Vivifiant), battle_gauge par combat livré, Appel.
# Purification (Pierre Relique ou Chambre de purification, jauge vide) : scène dédiée, capacités d'origine, nature
# dévoilée, expérience gardée rendue (niveaux, capacités, évolution), ruban (réglage ribbon).
module Obscurs
  module_function

  # Chaque pas : équipe et Chambre de purification
  def on_step
    return unless $actors

    walk = setting('walk_gauge').to_i
    $actors.each { |pokemon| pokemon.change_heart_gauge(-walk) if pokemon&.shadow? } if walk > 0
    chamber_step
  rescue StandardError => e
    log_error("Obscurs : #{e.message}") if respond_to?(:log_error, true)
  end

  # Purifie un Pokémon (avec la scène)
  # @param pokemon [PFM::Pokemon]
  # @return [Boolean]
  def purify(pokemon)
    return false unless pokemon&.purifiable?

    $scene.call_scene(PurifyScene, pokemon)
    return !pokemon.shadow?
  end
end

Scheduler::EventTasks.on(:end_step, 'Obscurs', -1) { Obscurs.on_step }

module PFM
  class Daycare
    module ObscursDaycare
      private

      # À la Pension, la jauge d'un Pokémon Obscur baisse (il ne gagne pas d'expérience)
      def exp_pokemon(pokemon)
        return pokemon.change_heart_gauge(-Obscurs.setting('daycare_gauge').to_i) if pokemon.shadow?

        super
      end

      # Un Pokémon Obscur ne pond pas
      def layable_check(daycare, parents)
        if parents.any?(&:shadow?)
          daycare[:rate] = 0
          return daycare[:layable] = 0
        end

        super
      end
    end
    prepend ObscursDaycare
  end
end

# Parfums
Obscurs::DEFAULTS['scents'].each_key do |scent|
  PFM::ItemDescriptor.define_on_creature_usability(scent.to_sym) do |_item, creature|
    next creature.shadow? && creature.heart_gauge > 0
  end
  PFM::ItemDescriptor.define_on_creature_use(scent.to_sym) do |item, creature, scene|
    value = Obscurs.fetch(Obscurs.setting('scents'), item.db_symbol.to_s).to_i
    value = Obscurs::DEFAULTS['scents'][item.db_symbol.to_s].to_i if value <= 0
    creature.change_heart_gauge(-value)
    text = if creature.purifiable?
             Obscurs.t("Le cœur de #{creature.given_name} s’est complètement ouvert ! Il peut être purifié !",
                       "#{creature.given_name}'s heart is now fully open! It can be purified!")
           else
             Obscurs.t("#{creature.given_name} se détend un peu. Son cœur s’ouvre !", "#{creature.given_name} relaxed a little. Its heart opened up!")
           end
    scene.display_message_and_wait(text)
  end
end

# Super Bonbon : pas sur un Pokémon Obscur
level_wrapper = PFM::ItemDescriptor::EXTEND_DATAS[Studio::LevelIncreaseItem] if defined?(Studio::LevelIncreaseItem)
if level_wrapper
  old_check = level_wrapper.instance_variable_get(:@on_creature_choice)
  if old_check
    level_wrapper.on_creature_choice = proc do |item, creature, scene|
      next false if creature.respond_to?(:shadow?) && creature.shadow?

      next old_check.call(item, creature, scene)
    end
  end
end

module Obscurs
  # Scène de purification
  class PurifyScene < GamePlay::BaseCleanUpdate
    WHITE = 10

    # @param pokemon [PFM::Pokemon]
    def initialize(pokemon)
      super()
      @pokemon = pokemon
      @steps = [[:wait, 30], [:intro], [:wait, 20], [:aura_out], [:flash], [:wait, 30], [:purify]]
      @wait = 0
      @aura = 1.0
      @fading = false
      @flash = 0
      @tick = 0
    end

    def update_inputs
      return true if (@wait -= 1) > 0
      return true if @fading

      until @steps.empty?
        kind, *args = @steps.shift
        run_step(kind, *args)
        return true if @wait > 0 || @fading
      end
      @running = false
      return true
    end

    def update_graphics
      @tick += 1
      if @fading
        @aura -= 0.02
        @fading = false if @aura <= 0
      end
      @aura_sprite.opacity = (150 + 60 * Math.sin(@tick / 10.0)) * @aura.clamp(0, 1)
      @aura_sprite.zoom = 1.0 + 0.04 * Math.sin(@tick / 8.0)
      @white.opacity = @flash > 0 ? (@flash * 12).clamp(0, 255) : 0
      @flash -= 1 if @flash > 0
      return true
    end

    private

    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_sprite(0, 0, Obscurs.file('purification'))
      @aura_sprite = @stack.add_sprite(160, 120, Obscurs.file('aura'))
      @aura_sprite.set_origin(@aura_sprite.width / 2, @aura_sprite.height / 2)
      @face = UI::PokemonFaceSprite.new(@viewport)
      @face.data = @pokemon
      @face.set_position(160, 160)
      @stack.push_sprite(@face)
      @white = @stack.add_sprite(0, 0, Obscurs.file('blanc'))
      @white.opacity = 0
    end

    def name
      return @pokemon.given_name
    end

    def run_step(kind, *args)
      case kind
      when :wait then @wait = args[0].to_i
      when :intro
        display_message(Obscurs.t("Le cœur de #{name} s’ouvre...", "#{name}'s heart is opening..."))
      when :aura_out
        @fading = true
      when :flash
        @flash = 24
        Obscurs.play_se('055-right01')
        me = Obscurs.setting('purify_me').to_s
        Audio.me_play("audio/me/#{me}") unless me.empty?
      when :purify then purify
      end
    end

    def purify
      exp = @pokemon.purify_shadow
      display_message(Obscurs.t("#{name} a ouvert la porte de son cœur ! Il est redevenu un Pokémon normal !",
                                "#{name} opened the door to its heart! It became a normal Pokémon again!"))
      display_message(Obscurs.t("#{name} est de nature #{@pokemon.nature_name} !", "#{name}'s nature is #{@pokemon.nature_name}!"))
      give_exp(exp)
      ribbon = Obscurs.setting('ribbon').to_s
      if !ribbon.empty? && @pokemon.respond_to?(:ribbon?) && @pokemon.ribbon?(ribbon.to_sym)
        name_text = (PFM::RIBBONS_DATA[ribbon.to_sym].name rescue ribbon)
        display_message(Obscurs.t("#{name} reçoit le #{name_text} !", "#{name} received the #{name_text}!"))
      end
    end

    # Expérience gardée : niveaux, capacités, évolution
    def give_exp(exp)
      return if exp <= 0

      display_message(Obscurs.t("#{name} récupère #{exp} points d’expérience !", "#{name} regained #{exp} Exp. Points!"))
      target = @pokemon.exp + exp
      while @pokemon.level < PFM.game_state.level_max_limit && target >= @pokemon.exp_lvl
        list = @pokemon.level_up_stat_refresh
        $game_system.me_play(Configs.sounds.level_up_me)
        display_message(parse_text(22, 128, PFM::Text::PKNICK[0] => name, PFM::Text::NUM3[1] => @pokemon.level.to_s))
        @pokemon.level_up_window_call(list[0], list[1], @viewport.z + 100)
        @pokemon.check_skill_and_learn
      end
      @pokemon.exp = [target, @pokemon.exp_lvl].min if @pokemon.level >= PFM.game_state.level_max_limit
      @pokemon.exp = target if @pokemon.level < PFM.game_state.level_max_limit
      id, form = @pokemon.evolve_check(:level_up)
      GamePlay.make_pokemon_evolve(@pokemon, id, form, false) if id
    end
  end
end
