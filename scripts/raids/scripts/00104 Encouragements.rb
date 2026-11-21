# Raids : encouragements (à la place de la Fuite). Le niveau d'encouragement monte de 1 à chaque fin de tour (3 au
# plus) ; un encouragement utilise tout le niveau et son effet dépend du niveau au moment où il est lancé.
#   offense  Attaque : 1 dégâts x1,5 (3 tours) ; 2 + coups critiques assurés ; 3 + une barre de bouclier en plus par coup
#   defense  Défense : 1 dégâts reçus /2 (3 tours) ; 2 + pas de coup critique reçu ; 3 + tient le coup avec 1 PV
#   healing  Soin : 1 soigne 25 % des PV de l'équipe ; 2 50 % et les statuts ; 3 tous les PV, les statuts et les PP
#   raid     Encouragement du style : Raid (niveau 2 : +2 tours ; 3 : +2 tours et +2 K.O.) ; Ultra, Dynamax,
#            Téracristal (niveau 3) : recharge la mécanique du style pour le joueur (Bracelet Z, Poignet Dynamax, Orbe
#            Téracristal)
module Raids
  CHEERS = %i[offense defense healing raid].freeze
  CHEER_TURNS = 3
  CHEER_TEXTS = {
    offense: [['Encouragement Attaque', 'Offense Cheer'], ['À fond !', 'Go all-out!'],
              [['Dégâts de l’équipe x1,5 (3 tours).', 'The team deals 50% more damage.'],
               ['Dégâts x1,5 et coups critiques.', 'More damage, always critical hits.'],
               ['Critiques, et le bouclier casse plus vite.', 'Critical hits, breaks shields faster.']]],
    defense: [['Encouragement Défense', 'Defense Cheer'], ['Tenez bon !', 'Hang tough!'],
              [['Dégâts reçus divisés par 2 (3 tours).', 'The team takes less damage.'],
               ['Moins de dégâts, aucun coup critique.', 'Less damage, no critical hits.'],
               ['Et l’équipe tient avec 1 PV.', 'The team endures damage from moves.']]],
    healing: [['Encouragement Soin', 'Healing Cheer'], ['Soignez-vous !', 'Heal up!'],
              [['Rend 25 % des PV de l’équipe.', 'Heals some of the team’s HP.'],
               ['Rend 50 % des PV et soigne les statuts.', 'Heals HP and cures status.'],
               ['Rend tous les PV, les statuts et des PP.', 'Restores HP, PP and status.']]]
  }.freeze
  RAID_CHEER = {
    basic: [['Encouragement Raid', 'Basic Raid Cheer'], ['Continuez !', 'Keep it going!']],
    ultra: [['Encouragement Ultra', 'Ultra Raid Cheer'], ['Énergie Z !', 'Let’s use Z-Power!']],
    max: [['Encouragement Dynamax', 'Max Raid Cheer'], ['Dynamax !', 'Let’s Dynamax!']],
    tera: [['Encouragement Téra', 'Tera Raid Cheer'], ['Téracristal !', 'Let’s Terastallize!']]
  }.freeze

  module_function

  def pick(pair)
    return fr? ? pair[0] : pair[1]
  end

  # Icône (offense, défense, soin, contre, raid)
  def cheer_icon(cheer, _rules)
    return { offense: 0, defense: 1, healing: 2, raid: 4 }[cheer] || 3
  end

  def cheer_name(cheer, rules)
    return pick(RAID_CHEER[rules.style][0]) if cheer == :raid

    return pick(CHEER_TEXTS[cheer][0])
  end

  # Niveau d'encouragement nécessaire
  def cheer_min_level(cheer, rules)
    return 1 unless cheer == :raid

    return rules.style == :basic ? 2 : 3
  end

  def cheer_usable?(cheer, rules)
    return rules.cheer_level.to_i >= cheer_min_level(cheer, rules)
  end

  # @return [Array<String>] deux lignes
  def cheer_description(cheer, rules)
    level = rules.cheer_level.to_i
    need = cheer_min_level(cheer, rules)
    return [format(t('Niveau %d d’encouragement nécessaire.', 'Requires Cheer Lv.%d or higher.'), need), ''] if level < need

    if cheer == :raid
      return [t('Prolonge le compteur de tours.', 'Extends the raid turn counter.'), ''] if rules.style == :basic && level < 3
      return [t('Prolonge les compteurs de tours et de K.O.', 'Extends the raid turn & KO counters.'), ''] if rules.style == :basic

      kind = { ultra: t('les capacités Z', 'Z-Moves'), max: t('le Dynamax', 'Dynamax'), tera: t('le Téracristal', 'Terastallization') }[rules.style]
      return [format(t('Vous pourrez utiliser %s.', 'Allows you to use %s.'), kind), '']
    end
    return [pick(CHEER_TEXTS[cheer][2][level - 1]), '']
  end

  # Effet d'un encouragement (au tour où il est lancé)
  # @param scene [Battle::Scene]
  # @param user [PFM::PokemonBattler]
  # @param cheer [Symbol]
  def apply_cheer(scene, user, cheer)
    rules = rules_of(scene.logic)
    level = rules.cheer_level.to_i
    return if level < cheer_min_level(cheer, rules)

    shout = cheer == :raid ? pick(RAID_CHEER[rules.style][1]) : pick(CHEER_TEXTS[cheer][1])
    scene.display_message_and_wait(format(t('%s encourage %s : « %s »', '%s cheered on %s: "%s"'), $trainer.name, user.given_name, shout))
    rules.cheer_level = 0
    send(:"cheer_#{cheer}", scene, rules, level)
    scene.visual.pj_raid_hud&.refresh
  end

  def cheer_offense(scene, rules, level)
    rules.cheer_turns[:offense] = CHEER_TURNS
    rules.cheer_turns[:offense_level] = level
    rules.cheer_offense3 = level >= 3
    texts = [t('L’encouragement donne plus de force à l’équipe !', 'The cheer inspired your team to attack with more power!'),
             t('L’encouragement rend les attaques de l’équipe redoutables !', 'The cheer inspired your team to attack with more potency!'),
             t('L’encouragement pousse l’équipe à briser les protections !', 'The cheer inspired your team to break through protections!')]
    scene.display_message_and_wait(texts[level - 1])
  end

  def cheer_defense(scene, rules, level)
    rules.cheer_turns[:defense] = CHEER_TURNS
    rules.cheer_turns[:defense_level] = level
    rules.cheer_defense3 = level >= 3
    texts = [t('L’encouragement aide l’équipe à résister !', 'The cheer inspired your team to resist incoming attacks!'),
             t('L’encouragement protège l’équipe des coups critiques !', 'The cheer inspired your team to resist critical hits!'),
             t('L’encouragement aide l’équipe à tenir le coup !', 'The cheer inspired your team to endure incoming attacks!')]
    scene.display_message_and_wait(texts[level - 1])
  end

  def cheer_healing(scene, _rules, level)
    portion = { 1 => 4, 2 => 2, 3 => 1 }[level]
    scene.logic.alive_battlers(0).each do |battler|
      if battler.hp < battler.max_hp
        scene.logic.damage_handler.heal(battler, battler.max_hp / portion, test_heal_block: false)
      end
      next if level < 2

      battler.cure if battler.status != 0
      scene.visual.refresh_info_bar(battler)
      next if level < 3

      battler.moveset.each { |move| move.pp = [move.pp + (move.ppmax / 2.0).ceil, move.ppmax].min }
      scene.display_message_and_wait(format(t('Les PP de %s sont restaurés.', '%s’s PP was restored.'), battler.given_name))
    end
  end

  def cheer_raid(scene, rules, level)
    boss = boss_of(scene.logic)
    if rules.style == :basic
      scene.display_message_and_wait(format(t('L’énergie autour de %s semble faiblir…', 'The energy surrounding %s seems to have weakened...'), boss.given_name))
      change_turns(scene, 2)
      scene.display_message_and_wait(t('L’encouragement augmente le nombre de tours restants !', 'The cheer increased the number of remaining turns!'))
      return if level < 3

      change_kos(scene, 2, message: false)
      scene.display_message_and_wait(t('L’encouragement augmente le nombre de K.O. restants !', 'The cheer increased the number of remaining knock outs!'))
      return
    end
    kind = GIMMICK_OF[rules.style]
    rules.gimmick_unlocked = true
    state = scene.logic.pj_gimmicks if scene.logic.respond_to?(:pj_gimmicks)
    if state
      used = state.instance_variable_get(:@used)
      player = scene.logic.battler(0, 0)
      used[kind]&.delete_if { |owner| owner.equal?(state.send(:owner_of, player)) } if player
    end
    ::Gimmicks::Tera.recharge if kind == :tera && defined?(::Gimmicks::Tera) && ::Gimmicks::Tera.respond_to?(:recharge)
    key = { zmove: t('Bracelet Z', 'Z-Ring'), dynamax: t('Poignet Dynamax', 'Dynamax Band'), tera: t('Orbe Téracristal', 'Tera Orb') }[kind]
    what = { zmove: t('utiliser une capacité Z', 'use Z-Moves'), dynamax: t('utiliser le Dynamax', 'use Dynamax'), tera: t('Téracristalliser un Pokémon', 'Terastallize') }[kind]
    scene.display_message_and_wait(format(t("L’encouragement recharge l’objet %s de %s !\n%s peut maintenant %s !", "The cheer fully charged %s's %s!\n%s can %s now!"),
                                          key, $trainer.name, $trainer.name, what))
  end

  # Fin de tour : durée des encouragements Attaque / Défense
  def tick_cheer_effects(scene)
    rules = rules_of(scene.logic)
    %i[offense defense].each do |kind|
      next unless rules.cheer_turns[kind].to_i > 0

      rules.cheer_turns[kind] -= 1
      next if rules.cheer_turns[kind] > 0

      rules.cheer_offense3 = false if kind == :offense
      rules.cheer_defense3 = false if kind == :defense
      text = kind == :offense ? t('L’élan offensif de l’équipe retombe.', 'Your team’s inspiration to go all-out has faded!') : t('L’élan défensif de l’équipe retombe.', 'Your team’s inspiration to hang tough has faded!')
      scene.display_message_and_wait(text)
    end
  end

  # @return [Integer] niveau actif (0 : aucun)
  def cheer_active(rules, kind)
    return 0 unless rules && rules.cheer_turns[kind].to_i > 0

    return rules.cheer_turns[:"#{kind}_level"].to_i
  end
end

module Battle
  module Actions
    # Encouragement (passe avant les attaques, comme les objets)
    class PJRaidCheer < Mega
      # @return [Symbol]
      attr_reader :cheer

      def initialize(scene, user, cheer)
        super(scene, user)
        @cheer = cheer
      end

      def execute
        return if @user.dead?

        Raids.apply_cheer(@scene, @user, @cheer)
      end

      def to_s
        return "#<PJRaidCheer #{@cheer} #{@user}>"
      end
    end
  end

  class Logic
    module RaidsCheerCritical
      def calc_critical_hit(user, target, initial_critical_count)
        rules = Raids.rules_of(self)
        if rules
          return false if target&.bank == 0 && Raids.cheer_active(rules, :defense) >= 2
          return true if user&.bank == 0 && Raids.cheer_active(rules, :offense) >= 2
        end
        return super
      end
    end
    prepend RaidsCheerCritical

    class DamageHandler
      module RaidsCheerDamage
        def damage_change(hp, target, launcher = nil, skill = nil, &messages)
          rules = Raids.rules_of(@logic)
          if rules && skill
            hp = (hp * 1.5).floor if launcher&.bank == 0 && Raids.cheer_active(rules, :offense) >= 1
            hp = [(hp / 2.0).ceil, 1].max if target.bank == 0 && Raids.cheer_active(rules, :defense) >= 1
          end
          super(hp, target, launcher, skill, &messages)
        end
      end
      prepend RaidsCheerDamage
    end
  end
end

module Battle
  class Scene
    module RaidsCheerCancel
      private

      # Encouragement annulé (retour en arrière) : il redevient possible
      def clean_action(action)
        if action.is_a?(Actions::PJRaidCheer) && (rules = Raids.rules_of(@logic))
          rules.cheer_used = false
        end
        super
      end
    end
    prepend RaidsCheerCancel
  end
end
