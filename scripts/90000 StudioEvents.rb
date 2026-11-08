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

    def ruby_symbol(value)
      ":#{value.to_s.gsub(/[^a-zA-Z0-9_]/, '')}"
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
        script(list, indent, "add_pokemon(#{ruby_symbol(cmd['pokemon'])}, #{cmd['level'].to_i}#{cmd['shiny'] ? ', true' : ''})")
      when 'WildBattle'
        script(list, indent, "call_battle_wild(#{ruby_symbol(cmd['pokemon'])}, #{cmd['level'].to_i})")
      when 'TrainerBattle'
        extra = cmd['troopId'] && cmd['troopId'].to_i != 3 ? ", troop_id: #{cmd['troopId'].to_i}" : ''
        bgm = cmd['bgm'].to_s.empty? ? '' : ", bgm: #{cmd['bgm'].to_s.inspect}"
        script(list, indent, "start_trainer_battle(#{cmd['trainerId'].to_i}#{bgm}#{extra})")
      when 'GiveItem'
        count = [cmd['count'].to_i, 1].max
        script(list, indent, "add_item(#{ruby_symbol(cmd['item'])}, false, count: #{count})")
      when 'HealParty'
        script(list, indent, '$actors.each { |pkm| pkm.cure; pkm.hp = pkm.max_hp; pkm.skills_set.each { |s| s.pp = s.ppmax if s.respond_to?(:ppmax) } }')
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
