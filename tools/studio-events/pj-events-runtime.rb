# encoding: utf-8
# =============================================================================
# Studio Events — évents au format JSON (façon PSDK) édités dans Pokémon Studio
# -----------------------------------------------------------------------------
# Sources :
#   Data/Studio/map_events/<mapDbSymbol>.json   (klass "MapEvents")
#   Data/Studio/common_events.json              (klass "CommonEvents")
# Cache (créé automatiquement en mode debug, à livrer avec le jeu compilé) :
#   Data/studio_events.rxdata
#
# Les évents JSON sont ajoutés aux évents des fichiers MapXXX.rxdata. Si un évent
# JSON a le même ID qu'un évent RPG Maker, c'est l'évent JSON qui gagne.
# Les commandes sont converties en commandes RPG Maker classiques : l'interpréteur
# de PSDK les exécute sans aucune modification.
# =============================================================================
require 'json'

module StudioEvents
  # Hors de Data/Studio : PSDK y convertit chaque dossier au démarrage (Studio2PSDK)
  MAP_FOLDER = 'Data/studio_events/map_events'
  COMMON_FILE = 'Data/studio_events/common_events.json'
  # Ancien emplacement, encore lu si Studio n'a pas encore déplacé les fichiers
  LEGACY_MAP_FOLDER = 'Data/Studio/map_events'
  LEGACY_COMMON_FILE = 'Data/Studio/common_events.json'
  CACHE_FILE = 'Data/studio_events.rxdata'

  MOVE_TYPES = { 'fixed' => 0, 'random' => 1, 'approach' => 2, 'custom' => 3 }.freeze
  TRIGGERS = { 'action' => 0, 'playerTouch' => 1, 'eventTouch' => 2, 'autorun' => 3, 'parallel' => 4 }.freeze
  COMMON_TRIGGERS = { 'none' => 0, 'autorun' => 1, 'parallel' => 2 }.freeze
  OPERATORS = { '==' => 0, '>=' => 1, '<=' => 2, '>' => 3, '<' => 4, '!=' => 5 }.freeze
  VAR_OPERATIONS = { 'set' => 0, 'add' => 1, 'sub' => 2, 'mul' => 3, 'div' => 4, 'mod' => 5 }.freeze

  class << self
    # Données compilées : { maps: { map_id => String(Marshal d'un Array<RPG::Event>) }, common: Array<RPG::CommonEvent> }
    # @return [Hash]
    def data
      refresh_if_changed unless release?
      @data ||= load_all
    end

    # En test : si un fichier JSON a changé (sauvegarde depuis Studio), on recharge
    # les évents au prochain chargement de carte, sans relancer le jeu.
    def refresh_if_changed
      now = Time.now
      return if @last_check && now - @last_check < 0.5

      @last_check = now
      signature = json_sources.map { |f| [f, File.mtime(f).to_f] }
      if @signature && signature != @signature
        @data = nil
        @cache = nil
        if $data_common_events.is_a?(Array) && $data_common_events.instance_variable_defined?(:@studio_events_patched)
          $data_common_events.remove_instance_variable(:@studio_events_patched)
        end
        log_studio_events_info('Évents Studio modifiés : rechargement')
      end
      @signature = signature
    rescue StandardError
      nil
    end

    # Recharge les données (utile en debug après une sauvegarde dans Studio)
    def reload
      @data = nil
      $data_common_events&.remove_instance_variable(:@studio_events_patched) if $data_common_events&.instance_variable_defined?(:@studio_events_patched)
      data
    end

    # Ajoute les évents JSON à une carte RPG Maker
    # @param map [RPG::Map]
    # @param map_id [Integer]
    # @return [RPG::Map]
    def inject(map, map_id)
      return map if map_id.to_i <= 0 || !map.respond_to?(:events)

      dumped = data[:maps][map_id]
      return map unless dumped

      map.events ||= {}
      Marshal.load(dumped).each { |event| map.events[event.id] = event }
      return map
    rescue StandardError => e
      log_studio_events_error("Impossible d'ajouter les évents Studio à la carte #{map_id}", e)
      return map
    end

    # Fusionne les évents communs JSON dans $data_common_events (une seule fois par tableau)
    def patch_common_events
      return unless $data_common_events.is_a?(Array)

      common = data[:common] # (vérifie aussi si les fichiers ont changé)
      return if $data_common_events.instance_variable_defined?(:@studio_events_patched)

      common.each do |common_event|
        next unless common_event

        $data_common_events[common_event.id] = common_event
      end
      (1...$data_common_events.size).each do |index|
        $data_common_events[index] ||= empty_common_event_placeholder(index)
      end
      $data_common_events.instance_variable_set(:@studio_events_patched, true)
    rescue StandardError => e
      log_studio_events_error('Impossible de fusionner les évents communs Studio', e)
    end

    private

    def empty_common_event_placeholder(index)
      return nil if index.nil? || index == 0

      ce = RPG::CommonEvent.new
      ce.id = index
      ce.name = ''
      ce.trigger = 0
      ce.switch_id = 1
      ce.list = [command(0, 0, [])]
      return ce
    end

    def release?
      defined?(PSDK_CONFIG) && PSDK_CONFIG.respond_to?(:release?) && PSDK_CONFIG.release?
    end

    def disk_exist?(filename)
      File.respond_to?(:old_exist?) ? File.old_exist?(filename) : File.exist?(filename)
    end

    def load_all
      return load_cache || empty_data if release?

      sources = json_sources
      return empty_data if sources.empty? && !disk_exist?(CACHE_FILE)

      if disk_exist?(CACHE_FILE) && sources.all? { |f| File.mtime(f) <= File.mtime(CACHE_FILE) } && cache_sources_match?(sources)
        cached = load_cache
        return cached if cached
      end
      built = build(sources)
      begin
        File.binwrite(CACHE_FILE, Marshal.dump(built))
      rescue StandardError => e
        log_studio_events_error("Impossible d'écrire #{CACHE_FILE}", e)
      end
      return built
    end

    def cache_sources_match?(sources)
      cached = load_cache
      cached && cached[:sources] == sources.sort
    end

    def empty_data
      { maps: {}, common: [], sources: [] }
    end

    def json_sources
      files = [MAP_FOLDER, LEGACY_MAP_FOLDER].flat_map { |dir| Dir.exist?(dir) ? Dir[File.join(dir, '*.json')] : [] }
      files.uniq! { |f| File.basename(f) }
      common = [COMMON_FILE, LEGACY_COMMON_FILE].find { |f| File.exist?(f) }
      files << common if common
      return files.sort
    end

    def load_cache
      return @cache if @cache
      if disk_exist?(CACHE_FILE)
        @cache = Marshal.load(File.binread(CACHE_FILE))
      elsif release?
        @cache = load_data(CACHE_FILE)
      end
      return @cache
    rescue StandardError
      return nil
    end

    def build(sources)
      result = { maps: {}, common: [], sources: sources.sort }
      sources.each do |filename|
        json = JSON.parse(File.read(filename, encoding: 'utf-8'))
        if json['klass'] == 'CommonEvents'
          result[:common] = (json['events'] || []).map { |ce| build_common_event(ce) }
        else
          map_id = json['mapId'].to_i
          events = (json['events'] || []).map { |ev| build_event(ev) }
          result[:maps][map_id] = Marshal.dump(events) unless events.empty?
        end
      rescue StandardError => e
        log_studio_events_error("Fichier d'évents invalide : #{filename}", e)
      end
      return result
    end

    def log_studio_events_info(message)
      text = "[StudioEvents] #{message}"
      respond_to?(:log_info, true) ? log_info(text) : puts(text)
    end

    def log_studio_events_error(message, error)
      text = "[StudioEvents] #{message} : #{error.class} #{error.message}"
      respond_to?(:log_error, true) ? log_error(text) : puts(text)
    end

    # --- Construction des objets RPG ---------------------------------------

    def build_common_event(hash)
      ce = RPG::CommonEvent.new
      ce.id = hash['id'].to_i
      ce.name = hash['name'].to_s
      ce.trigger = COMMON_TRIGGERS[hash['trigger']] || 0
      ce.switch_id = (hash['switchId'] || 1).to_i
      ce.list = compile_list(hash['commands'] || [], 0) << command(0, 0, [])
      return ce
    end

    def build_event(hash)
      event = RPG::Event.new
      event.id = hash['id'].to_i
      event.name = hash['name'].to_s
      event.x = hash['x'].to_i
      event.y = hash['y'].to_i
      pages = hash['pages'] || []
      pages = [{}] if pages.empty?
      event.pages = pages.map { |page| build_page(page) }
      return event
    end

    def build_page(hash)
      page = RPG::Event::Page.new
      page.condition = build_condition(hash['conditions'] || {})
      page.graphic = build_graphic(hash['graphic'] || {})
      page.move_type = MOVE_TYPES[hash['moveType']] || hash['moveType'].to_i
      page.move_speed = (hash['moveSpeed'] || 3).to_i
      page.move_frequency = (hash['moveFrequency'] || 3).to_i
      page.move_route = build_move_route(hash['moveRoute'] || { 'repeat' => true, 'skippable' => false, 'commands' => [] })
      page.walk_anime = hash.fetch('walkAnime', true) ? true : false
      page.step_anime = hash['stepAnime'] ? true : false
      page.direction_fix = hash['directionFix'] ? true : false
      page.through = hash['through'] ? true : false
      page.always_on_top = hash['alwaysOnTop'] ? true : false
      page.trigger = TRIGGERS[hash['trigger']] || hash['trigger'].to_i
      page.list = compile_list(hash['commands'] || [], 0) << command(0, 0, [])
      return page
    end

    def build_condition(hash)
      c = RPG::Event::Page::Condition.new
      c.switch1_valid = !hash['switch1'].nil?
      c.switch1_id = (hash['switch1'] || 1).to_i
      c.switch2_valid = !hash['switch2'].nil?
      c.switch2_id = (hash['switch2'] || 1).to_i
      var = hash['variable']
      c.variable_valid = !var.nil?
      c.variable_id = var ? var['id'].to_i : 1
      c.variable_value = var ? var['value'].to_i : 0
      c.self_switch_valid = !hash['selfSwitch'].nil?
      c.self_switch_ch = (hash['selfSwitch'] || 'A').to_s
      return c
    end

    def build_graphic(hash)
      g = RPG::Event::Page::Graphic.new
      g.tile_id = (hash['tileId'] || 0).to_i
      g.character_name = hash['characterName'].to_s
      g.character_hue = (hash['hue'] || 0).to_i
      g.direction = (hash['direction'] || 2).to_i
      g.pattern = (hash['pattern'] || 0).to_i
      g.opacity = (hash['opacity'] || 255).to_i
      g.blend_type = (hash['blendType'] || 0).to_i
      return g
    end

    def build_move_route(hash)
      route = RPG::MoveRoute.new
      route.repeat = hash.fetch('repeat', true) ? true : false
      route.skippable = hash['skippable'] ? true : false
      route.list = (hash['commands'] || []).map do |mc|
        RPG::MoveCommand.new(mc['code'].to_i, (mc['parameters'] || []).map { |p| decode_value(p) })
      end
      route.list << RPG::MoveCommand.new(0, [])
      return route
    end

    def build_audio(hash)
      hash ||= {}
      RPG::AudioFile.new(File.basename(hash['name'].to_s, '.*'), (hash['volume'] || 100).to_i, (hash['pitch'] || 100).to_i)
    end

    # Décode une valeur « Raw » (objets RPG sérialisés en { "__rpg": ... })
    def decode_value(value)
      case value
      when Array then value.map { |v| decode_value(v) }
      when Hash
        case value['__rpg']
        when 'AudioFile' then RPG::AudioFile.new(value['name'].to_s, value['volume'].to_i, value['pitch'].to_i)
        when 'MoveRoute' then build_move_route(value)
        when 'MoveCommand' then RPG::MoveCommand.new(value['code'].to_i, (value['parameters'] || []).map { |p| decode_value(p) })
        when 'Tone' then Tone.new(value['red'].to_f, value['green'].to_f, value['blue'].to_f, value['gray'].to_f)
        when 'Color' then Color.new(value['red'].to_f, value['green'].to_f, value['blue'].to_f, value['alpha'].to_f)
        when 'Symbol' then value['name'].to_s.to_sym
        else value.transform_values { |v| decode_value(v) }
        end
      else value
      end
    end

    def command(code, indent, parameters)
      cmd = RPG::EventCommand.new
      cmd.code = code
      cmd.indent = indent
      cmd.parameters = parameters
      return cmd
    end

    # --- Compilation des commandes (arbre JSON -> liste RPG Maker) -----------

    # @param commands [Array<Hash>]
    # @param indent [Integer]
    # @return [Array<RPG::EventCommand>]
    def compile_list(commands, indent)
      list = []
      commands.each { |cmd| compile_command(cmd, indent, list) }
      return list
    end

    def block(list, commands, indent)
      list.concat(compile_list(commands || [], indent))
      list << command(0, indent, [])
    end

    def text_lines(text)
      lines = text.to_s.gsub("\r\n", "\n").split("\n", -1)
      lines = [''] if lines.empty?
      return lines
    end

    def script(list, indent, code)
      lines = text_lines(code)
      list << command(355, indent, [lines.first])
      lines[1..].each { |line| list << command(655, indent, [line]) }
    end

    # Place dans l'équipe (l'éditeur compte à partir de 1, les commandes à partir de 0)
    def party_index(cmd)
      return [cmd['index'].to_i - 1, 0].max
    end

    # « , variable: 12 » (rien si aucune variable)
    def variable_arg(cmd)
      return cmd['variable'].to_i > 0 ? ", variable: #{cmd['variable'].to_i}" : ''
    end

    # Identifiant d'un réglage de plugin : nombre ou texte
    def id_literal(value)
      return value.to_s =~ /\A-?\d+\z/ ? value.to_i.to_s : value.to_s.inspect
    end

    def ruby_symbol(value)
      ":#{value.to_s.gsub(/[^a-zA-Z0-9_]/, '')}"
    end

    VARIANTS = %w[copper silver gold prismatic radiant].freeze

    # Donner un Pokémon : forme et variante (chromatique, ou celles du plugin « variantes »)
    def give_pokemon_code(cmd)
      sym = ruby_symbol(cmd['pokemon'])
      level = cmd['level'].to_i
      variant = cmd['variant'].to_s
      variant = 'shiny' if variant.empty? && cmd['shiny']
      form = cmd['form'].nil? ? -1 : cmd['form'].to_i
      if VARIANTS.include?(variant)
        return "add_pokemon(PFM::Pokemon.new(#{sym}, #{level}, false, true, #{form}, variant: :#{variant}))"
      elsif form >= 0
        shiny = variant == 'shiny'
        return "add_pokemon(PFM::Pokemon.new(#{sym}, #{level}, #{shiny}, false, #{form}))"
      end
      return "add_pokemon(#{sym}, #{level}#{variant == 'shiny' ? ', true' : ''})"
    end

    def compile_command(cmd, indent, list)
      case cmd['klass']
      when 'ShowMessage'
        lines = text_lines(cmd['text'])
        list << command(101, indent, [lines.first])
        lines[1..].each { |line| list << command(401, indent, [line]) }
      when 'ShowChoices'
        choices = cmd['choices'] || []
        cancel = case cmd['cancel']
                 when 'branch' then 5
                 when 'disallow', nil then 0
                 else cmd['cancel'].to_i.clamp(0, choices.size)
                 end
        list << command(102, indent, [choices.map { |c| c['text'].to_s }, cancel])
        choices.each_with_index do |choice, index|
          list << command(402, indent, [index, choice['text'].to_s])
          block(list, choice['commands'], indent + 1)
        end
        if cancel == 5
          list << command(403, indent, [])
          block(list, cmd['cancelCommands'], indent + 1)
        end
        list << command(404, indent, [])
      when 'ConditionalBranch'
        list << command(111, indent, branch_parameters(cmd['condition'] || {}))
        block(list, cmd['commands'], indent + 1)
        if cmd['elseCommands']
          list << command(411, indent, [])
          block(list, cmd['elseCommands'], indent + 1)
        end
        list << command(412, indent, [])
      when 'Loop'
        list << command(112, indent, [])
        block(list, cmd['commands'], indent + 1)
        list << command(413, indent, [])
      when 'BreakLoop' then list << command(113, indent, [])
      when 'ExitEvent' then list << command(115, indent, [])
      when 'EraseEvent' then list << command(116, indent, [])
      when 'DeleteEventForever'
        script(list, indent, cmd['event'].to_i > 0 ? "delete_event_forever(#{cmd['event'].to_i})" : 'delete_this_event_forever')
      when 'CallCommonEvent' then list << command(117, indent, [cmd['id'].to_i])
      when 'Label' then list << command(118, indent, [cmd['name'].to_s])
      when 'JumpToLabel' then list << command(119, indent, [cmd['name'].to_s])
      when 'ControlSwitches'
        from = cmd['from'].to_i
        list << command(121, indent, [from, (cmd['to'] || from).to_i, cmd.fetch('value', true) ? 0 : 1])
      when 'ControlVariables'
        from = cmd['from'].to_i
        operand = cmd['operand'] || { 'type' => 'constant', 'value' => 0 }
        params = [from, (cmd['to'] || from).to_i, VAR_OPERATIONS[cmd['operation']] || 0]
        params.concat(
          case operand['type']
          when 'variable' then [1, operand['id'].to_i]
          when 'random' then [2, operand['min'].to_i, operand['max'].to_i]
          else [0, operand['value'].to_i]
          end
        )
        list << command(122, indent, params)
      when 'ControlSelfSwitch'
        list << command(123, indent, [cmd['ch'].to_s, cmd.fetch('value', true) ? 0 : 1])
      when 'Wait' then list << command(106, indent, [cmd['frames'].to_i])
      when 'Comment'
        lines = text_lines(cmd['text'])
        list << command(108, indent, [lines.first])
        lines[1..].each { |line| list << command(408, indent, [line]) }
      when 'TransferPlayer'
        list << command(201, indent, [0, cmd['mapId'].to_i, cmd['x'].to_i, cmd['y'].to_i, (cmd['direction'] || 0).to_i, cmd.fetch('fade', true) ? 0 : 1])
      when 'SetRespawn' # variables 47 / 48 / 49 (Yuki::Var::E_Return_ID / X / Y) : réapparition après une défaite
        if cmd['mode'] == 'here'
          script(list, indent, '$game_variables[47] = $game_map.map_id; $game_variables[48] = $game_player.x - Yuki::MapLinker.get_OffsetX; $game_variables[49] = $game_player.y - Yuki::MapLinker.get_OffsetY')
        else
          [cmd['mapId'], cmd['x'], cmd['y']].each_with_index { |value, n| list << command(122, indent, [47 + n, 47 + n, 0, 0, value.to_i]) }
        end
      when 'SetEventLocation'
        list << command(202, indent, [(cmd['target'] || 0).to_i, 0, cmd['x'].to_i, cmd['y'].to_i, (cmd['direction'] || 0).to_i])
      when 'SetMoveRoute'
        list << command(209, indent, [(cmd['target'] || 0).to_i, build_move_route(cmd['route'] || {})])
      when 'WaitForMoveCompletion' then list << command(210, indent, [])
      when 'ChangeTransparency' then list << command(208, indent, [cmd['transparent'] ? 0 : 1])
      when 'PlayBGM' then list << command(241, indent, [build_audio(cmd['audio'])])
      when 'FadeOutBGM' then list << command(242, indent, [cmd['seconds'].to_i])
      when 'PlayBGS' then list << command(245, indent, [build_audio(cmd['audio'])])
      when 'FadeOutBGS' then list << command(246, indent, [cmd['seconds'].to_i])
      when 'PlayME' then list << command(249, indent, [build_audio(cmd['audio'])])
      when 'PlaySE' then list << command(250, indent, [build_audio(cmd['audio'])])
      when 'Script' then script(list, indent, cmd['code'])
      when 'GivePokemon'
        script(list, indent, give_pokemon_code(cmd))
      when 'WildBattle'
        script(list, indent, "call_battle_wild(#{ruby_symbol(cmd['pokemon'])}, #{cmd['level'].to_i})")
      when 'TrainerBattle'
        extra = cmd['troopId'] && cmd['troopId'].to_i != 3 ? ", troop_id: #{cmd['troopId'].to_i}" : ''
        bgm = cmd['bgm'].to_s.empty? ? '' : ", bgm: #{cmd['bgm'].to_s.inspect}"
        script(list, indent, "start_trainer_battle(#{cmd['trainerId'].to_i}#{bgm}#{extra})")
      when 'PlantBerry'
        stage = cmd['stage'].to_i.clamp(0, 4)
        target = cmd['event'].to_i > 0 ? ", #{cmd['event'].to_i}" : ''
        target = ", #{cmd['event'].to_i > 0 ? cmd['event'].to_i : 'nil'}, #{cmd['map'].to_i}" if cmd['map'].to_i > 0
        script(list, indent, "planter_baie_depart(#{ruby_symbol(cmd['item'])}, #{stage}#{target})")
      when 'GiveItem'
        count = [cmd['count'].to_i, 1].max
        script(list, indent, "add_item(#{ruby_symbol(cmd['item'])}, false, count: #{count})")
      when 'OpenPC' then script(list, indent, 'start_pc')
      when 'HealParty'
        script(list, indent, '$actors.each { |pkm| pkm.cure; pkm.hp = pkm.max_hp; pkm.skills_set.each { |s| s.pp = s.ppmax if s.respond_to?(:ppmax) } }')
      # Raccourcis des plugins (onglet « Plugins » de l'éditeur)
      when 'PJ_CustomizePlayer'
        script(list, indent, "personnaliser_joueur(#{cmd['cancellable'] ? 'true' : 'false'})")
      when 'PJ_RandomPlayer'
        gender = %w[m f].include?(cmd['gender'].to_s) ? "'#{cmd['gender']}'" : ''
        script(list, indent, "personnage_joueur_au_hasard(#{gender})")
      when 'PJ_SetVariant'
        variant = cmd['variant'].to_s.empty? ? 'nil' : ruby_symbol(cmd['variant'])
        script(list, indent, "set_pokemon_variant(#{[cmd['index'].to_i - 1, 0].max}, #{variant})")
      when 'PJ_TriadGiveCard'
        script(list, indent, "give_triad_card(#{ruby_symbol(cmd['pokemon'])}, #{[cmd['count'].to_i, 1].max}, message: #{cmd['message'] ? 'true' : 'false'})")
      when 'PJ_TriadDuel'
        script(list, indent, "triple_triad_duel(#{cmd['name'].to_s.inspect}, #{cmd['minLevel'].to_i}, #{cmd['maxLevel'].to_i})")
      when 'PJ_TriadCollection'
        script(list, indent, 'triple_triad_collection')
      when 'PJ_TriadShop'
        script(list, indent, 'triple_triad_shop')
      when 'PJ_UnlockApp'
        script(list, indent, "smartphone_unlock(#{ruby_symbol(cmd['action'])})")
      when 'PJ_GimmickToggle'
        script(list, indent, "gimmick_actif(#{ruby_symbol(cmd['gimmick'])}, #{cmd['value'] ? 'true' : 'false'})")
      when 'PJ_GimmickWild'
        kinds = %w[mega zmove dynamax tera].select { |k| cmd[k] }.map { |k| ":#{k}" }
        script(list, indent, "gimmick_sauvage(#{kinds.join(', ')})")
      when 'PJ_TeraType'
        script(list, indent, "type_tera(#{[cmd['index'].to_i - 1, 0].max}, #{ruby_symbol(cmd['type'])})")
      when 'PJ_GmaxFactor'
        script(list, indent, "facteur_gigamax(#{[cmd['index'].to_i - 1, 0].max}, #{cmd['value'] ? 'true' : 'false'})")
      when 'PJ_DynamaxLevel'
        script(list, indent, "niveau_dynamax(#{[cmd['index'].to_i - 1, 0].max}, #{cmd['level'].to_i.clamp(0, 10)})")
      when 'PJ_TeraRecharge'
        script(list, indent, 'recharger_orbe_tera')
      when 'PJ_LockApp'
        script(list, indent, "smartphone_lock(#{ruby_symbol(cmd['action'])})")
      when 'PJ_FriendMeet'
        script(list, indent, "friend_meet(#{ruby_symbol(cmd['friend'])})")
      when 'PJ_FriendAffinity'
        script(list, indent, "friend_add_affinity(#{ruby_symbol(cmd['friend'])}, #{cmd['amount'].to_i})")
      when 'PJ_MasterMove'
        method = cmd['forget'] ? 'oublier_maitrise' : 'maitriser_capacite'
        script(list, indent, "#{method}(#{party_index(cmd)}, #{ruby_symbol(cmd['move'])})")
      when 'PJ_TriadDeckDuel'
        script(list, indent, "triple_triad_deck_duel(#{cmd['deck'].to_s.inspect}#{variable_arg(cmd)})")
      when 'PJ_AddVariantPokemon'
        script(list, indent, "add_pokemon_variant(#{ruby_symbol(cmd['pokemon'])}, #{[cmd['level'].to_i, 1].max}, #{ruby_symbol(cmd['variant'] || 'silver')})")
      when 'PJ_Berrydex' then script(list, indent, 'berrydex')
      when 'PJ_BerrydexRegister'
        script(list, indent, cmd['all'] ? 'berrydex_tout_enregistrer' : "berrydex_enregistrer(#{ruby_symbol(cmd['item'])})")
      when 'PJ_BerryPots' then script(list, indent, 'pots_a_baies')
      when 'PJ_AddPots' then script(list, indent, "ajouter_pots(#{[cmd['amount'].to_i, 1].max})")
      when 'PJ_RegionMap'
        map = cmd['worldmap'].to_i > 0 ? cmd['worldmap'].to_i.to_s : ''
        code = { 'fly' => 'carte_region_vol', 'wall' => "carte_murale(#{map})" }[cmd['mode'].to_s] || "carte_region(#{map})"
        script(list, indent, code)
      when 'PJ_BadgeCase'
        script(list, indent, "etui_badges(#{cmd['region'].to_s.empty? ? '' : id_literal(cmd['region'])})")
      when 'PJ_GiveBadge'
        script(list, indent, "obtenir_badge(#{ruby_symbol(cmd['badge'])}, #{cmd.fetch('show', true) ? 'true' : 'false'})")
      when 'PJ_RemoveBadge' then script(list, indent, "retirer_badge(#{ruby_symbol(cmd['badge'])})")
      when 'PJ_Store' then script(list, indent, "magasin(#{ruby_symbol(cmd['shop'])})")
      when 'PJ_StoreCheckout'
        script(list, indent, "magasin_caisse(#{cmd['seller'].to_s.empty? ? '' : ruby_symbol(cmd['seller'])})")
      when 'PJ_StoreRestock' then script(list, indent, "magasin_reassort(#{ruby_symbol(cmd['shop'])})")
      when 'PJ_GiveMemento'
        index = party_index(cmd)
        memento = ruby_symbol(cmd['memento'])
        if cmd['remove']
          script(list, indent, "retirer_souvenir(#{index}, #{memento})")
        else
          script(list, indent, cmd['title'] ? "donner_titre(#{index}, #{memento})" : "donner_souvenir(#{index}, #{memento})")
        end
      when 'PJ_ChooseBirthday' then script(list, indent, 'choisir_anniversaire')
      when 'PJ_ChooseHero'
        script(list, indent, "choisir_heros(nom: #{cmd.fetch('name', true) ? 'true' : 'false'}, annulable: #{cmd['cancellable'] ? 'true' : 'false'})")
      when 'PJ_ChangeHero'
        script(list, indent, "changer_heros(#{id_literal(cmd['hero'])}, nom: #{cmd['name'] ? 'true' : 'false'})")
      when 'PJ_AllyJoin' then script(list, indent, "allie_rejoint(#{id_literal(cmd['ally'])})")
      when 'PJ_AllyLeave' then script(list, indent, 'allie_quitte')
      when 'PJ_PokeRecre'
        script(list, indent, cmd['index'].to_i > 0 ? "poke_recre(#{cmd['index'].to_i - 1})" : 'poke_recre')
      when 'PJ_PokeRecreGame'
        call = "#{cmd['game'].to_s == 'jongle' ? 'jongle_tete' : 'cueille_baies'}(#{cmd['index'].to_i > 0 ? cmd['index'].to_i - 1 : 'nil'})"
        script(list, indent, cmd['variable'].to_i > 0 ? "$game_variables[#{cmd['variable'].to_i}] = #{call}.to_i" : call)
      when 'PJ_GivePuff'
        puff = cmd['puff'].to_s.empty? ? 'nil' : cmd['puff'].to_s.inspect
        script(list, indent, "donner_pofiterole(#{puff}, #{cmd['count'].to_i})")
      when 'PJ_GiveDecoration'
        script(list, indent, "donner_decoration(#{cmd['decoration'].to_s.empty? ? 'nil' : cmd['decoration'].to_s.inspect})")
      when 'PJ_GiveAffection'
        script(list, indent, "donner_affection(#{party_index(cmd)}, #{cmd['points'].to_i})")
      when 'PJ_WhosThat'
        script(list, indent, cmd['variable'].to_i > 0 ? "quel_est_ce_pokemon(variable: #{cmd['variable'].to_i})" : 'quel_est_ce_pokemon')
      when 'PJ_PunchBag'
        if cmd['session'].to_s.empty?
          bag = cmd['bag'].to_s.empty? ? '' : ", bag: #{cmd['bag'].to_s.inspect}"
          script(list, indent, "sac_de_frappe(#{[cmd['rounds'].to_i, 1].max}#{bag}#{variable_arg(cmd)})")
        else
          script(list, indent, "sac_de_frappe_seance(#{ruby_symbol(cmd['session'])}#{variable_arg(cmd)})")
        end
      when 'PJ_InflictStatus'
        script(list, indent, "infliger_statut(#{ruby_symbol(cmd['status'])}, #{party_index(cmd)}, forcer: #{cmd['force'] ? 'true' : 'false'})")
      when 'PJ_Achievements' then script(list, indent, 'succes')
      when 'PJ_UnlockAchievement' then script(list, indent, "succes_debloquer(#{ruby_symbol(cmd['achievement'])})")
      when 'PJ_AchievementCounter'
        method = cmd['set'] ? 'succes_compteur_fixer' : 'succes_compteur'
        script(list, indent, "#{method}(#{ruby_symbol(cmd['name'])}, #{cmd['amount'].to_i})")
      # Plugins ajoutés ensuite
      when 'PJ_SecretBase' then script(list, indent, 'base_secrete')
      when 'PJ_SecretBaseTheme' then script(list, indent, "base_secrete_theme(#{ruby_symbol(cmd['theme'])})")
      when 'PJ_SecretBaseClear' then script(list, indent, 'base_secrete_vider')
      when 'PJ_CasinoJp' then script(list, indent, "casino_jp(#{cmd['speed'].to_i.clamp(1, 6)})")
      when 'PJ_RiftOpen' then script(list, indent, 'faille_ouvrir')
      when 'PJ_RiftClose' then script(list, indent, 'faille_fermer')
      when 'PJ_PssIcon' then script(list, indent, cmd['cancellable'] ? 'creer_icone_pss(true)' : 'creer_icone_pss')
      when 'PJ_PssIconRandom'
        script(list, indent, %w[a b].include?(cmd['serie'].to_s) ? "icone_pss_au_hasard(#{cmd['serie'].to_s.inspect})" : 'icone_pss_au_hasard')
      when 'PJ_Insignia'
        case cmd['action'].to_s
        when 'remove' then script(list, indent, "retirer_insigne(#{party_index(cmd)}, #{ruby_symbol(cmd['insignia'])})")
        when 'all' then script(list, indent, "donner_tous_les_insignes(#{party_index(cmd)})")
        else script(list, indent, "donner_insigne(#{party_index(cmd)}, #{ruby_symbol(cmd['insignia'])})")
        end
      when 'PJ_SetSeason' then script(list, indent, "saison_fixer(#{ruby_symbol(cmd['season'] || 'spring')})")
      when 'PJ_RefreshWeather' then script(list, indent, 'meteo_actualiser')
      when 'PJ_WeatherMessage' then script(list, indent, 'meteo_zone')
      when 'PJ_ChooseModes' then script(list, indent, 'choisir_modes')
      when 'PJ_Graveyard' then script(list, indent, 'ouvrir_cimetiere')
      when 'PJ_NuzlockeRevive' then script(list, indent, 'nuzlocke_ressusciter')
      when 'PJ_VisiblePokemon' then script(list, indent, "pokemon_visibles(#{cmd.fetch('value', true) ? 'true' : 'false'})")
      when 'PJ_ClearVisiblePokemon' then script(list, indent, 'effacer_pokemon_visibles')
      when 'PJ_MassOutbreak'
        species = cmd['pokemon'].to_s.empty? ? 'nil' : ruby_symbol(cmd['pokemon'])
        count = cmd['count'].to_i > 0 ? ", #{cmd['count'].to_i}" : ''
        script(list, indent, "apparition_massive(#{species}#{count})")
      when 'PJ_RankBattle'
        method = { 'monarque' => 'combat_monarque', 'dominant' => 'combat_dominant' }[cmd['rank'].to_s] || 'combat_baron'
        script(list, indent, "#{method}(#{ruby_symbol(cmd['pokemon'])}, #{[cmd['level'].to_i, 1].max})")
      when 'PJ_Fishing'
        rod = %w[normal super mega].include?(cmd['rod'].to_s) ? cmd['rod'] : 'normal'
        call = "peche_minijeu(:#{rod})"
        script(list, indent, cmd['variable'].to_i > 0 ? "$game_variables[#{cmd['variable'].to_i}] = #{call} ? 1 : 0" : call)
      when 'PJ_PoffinCook' then script(list, indent, 'cuisiner_poffin')
      when 'PJ_PoffinFeed' then script(list, indent, 'nourrir_poffin')
      when 'PJ_GivePoffin'
        flavors = %w[spicy dry sweet bitter sour].map { |k| cmd[k].to_i.clamp(0, 255) }
        script(list, indent, "donner_poffin([#{flavors.join(', ')}], #{cmd['smoothness'].to_i.clamp(1, 255)})")
      when 'PJ_DexTask'
        target = cmd['target'].to_s.empty? ? 'nil' : ruby_symbol(cmd['target'])
        script(list, indent, "tache_pokedex(#{ruby_symbol(cmd['pokemon'])}, #{ruby_symbol(cmd['task'])}, #{target}, #{[cmd['amount'].to_i, 1].max})")
      when 'PJ_DexResearch'
        call = "recherche_pokedex(#{ruby_symbol(cmd['pokemon'])})"
        script(list, indent, cmd['variable'].to_i > 0 ? "$game_variables[#{cmd['variable'].to_i}] = #{call}.to_i" : call)
      when 'PJ_Television' then script(list, indent, cmd['channel'].to_i > 0 ? "tele_regarder(#{cmd['channel'].to_i.clamp(1, 8)})" : 'tele_regarder')
      when 'PJ_TvWithdraw' then script(list, indent, "tele_retirer(#{cmd['id'].to_s.inspect})")
      when 'PJ_Wardrobe' then script(list, indent, 'ouvrir_wardrobe')
      when 'PJ_WearOutfit' then script(list, indent, "porter_tenue(#{ruby_symbol(cmd['item'])})")
      when 'PJ_RemoveOutfit' then script(list, indent, 'retirer_tenue')
      when 'PJ_GiveOutfit' then script(list, indent, "donner_tenue(#{ruby_symbol(cmd['item'])})")
      when 'PJ_OnlineMenu' then script(list, indent, 'online_menu')
      when 'PJ_OnlineTrade' then script(list, indent, 'online_echange')
      when 'PJ_OnlineTeamDuel' then script(list, indent, 'online_defi')
      when 'PJ_OnlineBattle' then script(list, indent, 'online_combat')
      when 'PJ_OnlineSocial' then script(list, indent, 'online_social')
      when 'PJ_OnlineWorld' then script(list, indent, 'online_monde')
      when 'PJ_OnlineVisible' then script(list, indent, "online_presence(#{cmd.fetch('value', true) ? 'true' : 'false'})")
      # Raids
      when 'PJ_RaidDen'
        script(list, indent, cmd['style'].to_s.empty? ? 'antre_raid' : "antre_raid(#{ruby_symbol(cmd['style'])})")
      when 'PJ_RaidBattle'
        species = cmd['pokemon'].to_s.empty? ? 'nil' : ruby_symbol(cmd['pokemon'])
        rank = cmd['rank'].to_i > 0 ? ", rang: #{cmd['rank'].to_i}" : ''
        script(list, indent, "combat_raid(#{species}, style: #{ruby_symbol(cmd['style'] || 'basic')}#{rank}, " \
                             "capture: #{cmd.fetch('capture', true) ? 'true' : 'false'}, recompenses: #{cmd.fetch('rewards', true) ? 'true' : 'false'})")
      when 'PJ_RaidAdventure'
        map = cmd['map'].to_s =~ /\A\d+\z/ ? ", carte: #{cmd['map'].to_i}" : ''
        script(list, indent, "aventure_raid(#{ruby_symbol(cmd['style'] || 'max')}#{map})")
      when 'PJ_RaidRefill' then script(list, indent, 'remplir_antres')
      when 'PJ_RaidEmpty' then script(list, indent, 'vider_antre')
      # Tournois
      when 'PJ_Tournament'
        call = "tournoi(#{ruby_symbol(cmd['tournament'])})"
        script(list, indent, cmd['variable'].to_i > 0 ? "$game_variables[#{cmd['variable'].to_i}] = #{call}.to_i" : call)
      when 'PJ_SelectionBattle'
        method = cmd['only'] ? 'selection_equipe' : 'combat_selection'
        script(list, indent, "#{method}(#{cmd['trainerId'].to_i}, nombre: #{cmd['count'].to_i.clamp(1, 6)}#{cmd['double'] ? ', double: true' : ''})")
      # Pokéblocs
      when 'PJ_BerryBlender'
        code = { 'master' => 'mixeur_maitre', 'simple' => 'mixeur_simple', 'auto' => 'mixeur' }[cmd['mode'].to_s]
        code ||= cmd['players'].to_i > 0 ? "mixeur_baies(#{cmd['players'].to_i.clamp(1, 3)})" : 'mixeur_baies'
        script(list, indent, code)
      when 'PJ_PokeblockCase' then script(list, indent, 'boite_pokeblocs')
      when 'PJ_PokemonCondition' then script(list, indent, 'etat_pokemon')
      when 'PJ_GivePokeblock'
        script(list, indent, "donner_pokebloc(#{ruby_symbol(cmd['color'] || 'red')}, #{[cmd['count'].to_i, 1].max}#{cmd['plus'] ? ', plus: true' : ''})")
      # Concours
      when 'PJ_Contest'
        args = []
        args << (cmd['type'].to_s.empty? ? 'nil' : ruby_symbol(cmd['type'])) unless cmd['type'].to_s.empty? && cmd['rank'].to_s.empty?
        args << ruby_symbol(cmd['rank']) unless cmd['rank'].to_s.empty?
        call = "#{cmd['direct'] ? 'concours_direct' : 'concours'}(#{args.join(', ')})"
        script(list, indent, cmd['variable'].to_i > 0 ? "$game_variables[#{cmd['variable'].to_i}] = #{call}.to_i" : call)
      when 'PJ_FashionCase' then script(list, indent, 'mallette')
      when 'PJ_StarterCase' then script(list, indent, 'mallette_depart')
      when 'PJ_GiveAccessory'
        script(list, indent, "donner_accessoire(#{ruby_symbol(cmd['accessory'])}, #{[cmd['count'].to_i, 1].max}#{cmd['silent'] ? ', silencieux: true' : ''})")
      when 'PJ_GiveBackdrop'
        script(list, indent, "donner_fond(#{ruby_symbol(cmd['backdrop'])}#{cmd['silent'] ? ', silencieux: true' : ''})")
      when 'PJ_ContestWinners' then script(list, indent, 'tableau_gagnants')
      # Échange Miracle
      when 'PJ_WonderTrade'
        script(list, indent, cmd['variable'].to_i > 0 ? "$game_variables[#{cmd['variable'].to_i}] = echange_miracle ? 1 : 0" : 'echange_miracle')
      # Pique-nique
      when 'PJ_Picnic' then script(list, indent, 'pique_nique')
      when 'PJ_PicnicBasket'
        script(list, indent, cmd['variable'].to_i > 0 ? "$game_variables[#{cmd['variable'].to_i}] = panier_recuperer" : 'panier_recuperer')
      # Combats spéciaux
      when 'PJ_TripleBattle'
        call = "combat_triple(#{cmd['trainerId'].to_i}#{cmd['variable'].to_i > 0 ? ", variable: #{cmd['variable'].to_i}" : ''})"
        script(list, indent, call)
      when 'PJ_HordeBattle'
        script(list, indent, "combat_horde(#{ruby_symbol(cmd['pokemon'])}, #{[cmd['level'].to_i, 1].max}, taille: #{cmd['size'].to_i.clamp(2, 5)}#{cmd['variable'].to_i > 0 ? ", variable: #{cmd['variable'].to_i}" : ''})")
      # Pokémon Obscurs
      when 'PJ_GiveShadow', 'PJ_ShadowBattle'
        method = cmd['klass'] == 'PJ_GiveShadow' ? 'ajouter_pokemon_obscur' : 'combat_obscur'
        id = cmd['id'].to_s.strip.empty? ? '' : ", id: #{cmd['id'].to_s.strip.inspect}"
        script(list, indent, "#{method}(#{ruby_symbol(cmd['pokemon'])}, #{cmd['level'].to_i.clamp(1, 100)}#{id})")
      when 'PJ_RelicStone' then script(list, indent, 'pierre_relique')
      when 'PJ_PurifyChamber' then script(list, indent, 'chambre_purification')
      # Montures
      when 'PJ_GiveMount'
        script(list, indent, "donner_monture(#{cmd['mount'].to_s.inspect}#{cmd.fetch('message', true) ? '' : ', message: false'})")
      when 'PJ_RemoveMount' then script(list, indent, "retirer_monture(#{cmd['mount'].to_s.inspect})")
      when 'PJ_Ride' then script(list, indent, cmd['mount'].to_s.empty? ? 'monter' : "monter(#{cmd['mount'].to_s.inspect})")
      when 'PJ_Dismount' then script(list, indent, 'descendre')
      when 'PJ_MountWheel' then script(list, indent, 'roue_montures')
      when 'PJ_MountApp' then script(list, indent, 'appli_monture')
      # Pokéathlon
      when 'PJ_Pokeathlon'
        call = cmd['course'].to_s.empty? ? 'pokeathlon' : "pokeathlon(#{cmd['course'].to_s.inspect})"
        script(list, indent, cmd['variable'].to_i > 0 ? "$game_variables[#{cmd['variable'].to_i}] = (#{call} || {})[:rank].to_i" : call)
      when 'PJ_AprijuiceBlender' then script(list, indent, 'mixeur_noigrumes')
      when 'PJ_AthlonData' then script(list, indent, 'donnees_pokeathlon')
      when 'PJ_AthlonShop' then script(list, indent, 'boutique_pokeathlon')
      when 'PJ_AthlonPoints' then script(list, indent, "ajouter_points_pokeathlon(#{cmd['amount'].to_i})")
      when 'PJ_DodrioPicking'
        call = cmd['players'].to_i > 0 ? "cueillette_dodrio(#{cmd['players'].to_i.clamp(1, 3)})" : 'cueillette_dodrio'
        script(list, indent, cmd['variable'].to_i > 0 ? "$game_variables[#{cmd['variable'].to_i}] = #{call}.to_i" : call)
      when 'PJ_LanceBall'
        call = cmd['count'].to_i > 0 ? "lance_ball(#{cmd['count'].to_i.clamp(1, 6)})" : 'lance_ball'
        script(list, indent, cmd['variable'].to_i > 0 ? "$game_variables[#{cmd['variable'].to_i}] = #{call}.to_i" : call)
      when 'OpenShop'
        script(list, indent, "open_shop(#{ruby_symbol(cmd['shop'])})")
      when 'Raw'
        (cmd['commands'] || []).each do |raw|
          list << command(raw['code'].to_i, indent + raw['indent'].to_i, (raw['parameters'] || []).map { |p| decode_value(p) })
        end
      else
        list << command(108, indent, ["[StudioEvents] Commande inconnue : #{cmd['klass']}"])
      end
    end

    def branch_parameters(cond)
      case cond['type']
      when 'switch' then [0, cond['id'].to_i, cond.fetch('value', true) ? 0 : 1]
      when 'variable'
        operand = cond['operand'] || { 'type' => 'constant', 'value' => 0 }
        is_var = operand['type'] == 'variable'
        [1, cond['id'].to_i, is_var ? 1 : 0, is_var ? operand['id'].to_i : operand['value'].to_i, OPERATORS[cond['operator']] || 0]
      when 'selfSwitch' then [2, cond['ch'].to_s, cond.fetch('value', true) ? 0 : 1]
      when 'facing' then [6, (cond['target'] || -1).to_i, (cond['direction'] || 2).to_i]
      else [12, cond['code'].to_s]
      end
    end
  end
end

# --- Branchement dans PSDK --------------------------------------------------

if defined?(Yuki::MapLinker)
  module Yuki
    module MapLinker
      class << self
        alias studio_events_load_map_data load_map_data
        # Charge la carte puis ajoute les évents Studio
        def load_map_data(map_id)
          map = studio_events_load_map_data(map_id)
          return map if map_id == 0 || map.equal?(DEFAULT_MAP)

          return StudioEvents.inject(map, map_id)
        end
      end
    end
  end
end

class Game_Map
  alias studio_events_setup setup
  def setup(map_id)
    StudioEvents.patch_common_events
    studio_events_setup(map_id)
  end
end

# Sauvegarde : PSDK remet les évents de la carte à la position qu'ils avaient dans la sauvegarde (par ID).
# Si les évents Studio de la carte ont changé depuis (déplacés, remplacés, importés…), ces positions ne
# correspondent plus : on les ignore et chaque évent reprend la place réglée dans Studio.
module StudioEvents
  class << self
    # Empreinte des évents Studio d'une carte
    # @param map_id [Integer]
    # @return [Integer]
    def map_signature(map_id)
      require 'zlib'
      dumped = data[:maps][map_id.to_i]
      return dumped ? Zlib.crc32(dumped) : 0
    rescue StandardError
      return 0
    end
  end
end

class Game_Map
  alias studio_events_save_events_offset save_events_offset
  def save_events_offset
    studio_events_save_events_offset
    @events_info[:studio_events] = StudioEvents.map_signature(@map_id) if @events_info
  end

  alias studio_events_load_events load_events
  def load_events
    if @events_info && @events_info[:studio_events] != StudioEvents.map_signature(@map_id)
      @events_info = { player: @events_info[:player] }
    end
    studio_events_load_events
  end
end


# -----------------------------------------------------------------------------
# Plants de baies de départ (commande « Planter une baie » de l'éditeur d'évents)
#   planter_baie_depart(:oran_berry, 4)          -> plante la baie sur cet évènement (stade 0 graine … 4 mûre)
#   planter_baie_depart(:oran_berry, 4, 12)      -> sur l'évènement n° 12 de la carte
#   planter_baie_depart(:oran_berry, 4, 12, 5)   -> sur l'évènement n° 12 de la carte n° 5
# Chaque emplacement n'est planté qu'une fois dans la partie : la commande peut rester dans l'évent du plant.
# Plus besoin de cinématique : quand une carte est chargée, les plants dont un évent contient cette commande
# (pour lui-même ou pour un autre évènement de la carte) sont plantés tout seuls la première fois.
# -----------------------------------------------------------------------------
module StudioEvents
  module BerrySpots
    PATTERN = /planter_baie_depart\(\s*:?([a-z0-9_]+)\s*(?:,\s*(\d+))?\s*(?:,\s*(nil|\d+))?\s*(?:,\s*(\d+))?\s*\)/

    module_function

    # Emplacements déjà plantés une fois (« carte:évènement »)
    def done
      state = PFM.game_state
      list = state.instance_variable_get(:@studio_berry_spots)
      state.instance_variable_set(:@studio_berry_spots, list = []) unless list
      return list
    end

    # @return [Boolean] true si la baie a été plantée
    def plant(map_id, event_id, berry, stage)
      key = "#{map_id}:#{event_id}"
      return false if done.include?(key)

      done << key
      return false if Yuki::Berries.find_berry_data(map_id)[event_id] # déjà un plant (sauvegarde existante)

      Yuki::Berries.init_berry(map_id, event_id, berry.to_sym, stage.to_i.clamp(0, 4))
      return true
    rescue StandardError => e
      log_error("Planter une baie : #{e.message}") if respond_to?(:log_error, true)
      return false
    end

    # Plants de départ de la carte affichée
    def plant_current_map
      return unless $game_map && PFM.game_state

      map_id = $game_map.map_id
      $game_map.events.each do |event_id, event|
        pages = event.instance_variable_get(:@event)&.pages || []
        pages.each do |page|
          Array(page.list).each do |command|
            next unless command.code == 355 || command.code == 655

            command.parameters[0].to_s.scan(PATTERN) do |berry, stage, target, map|
              next if map && map.to_i != map_id

              plant(map_id, target && target != 'nil' ? target.to_i : event_id, berry, stage || 4)
            end
          end
        end
      end
    rescue StandardError => e
      log_error("Planter une baie : #{e.message}") if respond_to?(:log_error, true)
    end
  end
end

module Yuki
  module Berries
    class << self
      module StudioBerrySpots
        def init
          ::StudioEvents::BerrySpots.plant_current_map
          super
        end
      end
      prepend StudioBerrySpots
    end
  end
end

class Interpreter
  # Plante une baie au départ (une seule fois par emplacement)
  # @param berry [Symbol] baie
  # @param stage [Integer] 0 graine, 1 pousse, 2 grandit, 3 en fleur, 4 mûre
  # @param event_id [Integer, nil] évènement (nil : celui-ci)
  # @param map_id [Integer, nil] carte (nil : celle-ci)
  # @return [Boolean] true si la baie a été plantée
  def planter_baie_depart(berry, stage = 4, event_id = nil, map_id = nil)
    map_id ||= $game_map.map_id
    planted = StudioEvents::BerrySpots.plant(map_id, event_id || @event_id, berry, stage)
    Yuki::Berries.init if planted && map_id == $game_map.map_id
    return planted
  end
end
