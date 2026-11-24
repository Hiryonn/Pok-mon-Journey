# Étui à badges (d'après « Badge Case » de Roei pour Essentials, refait pour PSDK)
#
# Les badges de PSDK restent ceux du dresseur ($trainer.set_badge(numéro, région)) : chaque badge de l'étui est relié
# à un numéro (1 à 8) et une région (1 à 6) de PSDK. Les commandes de Studio qui donnent un badge marchent donc aussi.
# Réglages faits dans Studio (Level design > Dresseurs > Étui à badges) : Data/configs/plugins/etui_badges.json
#   settings  show_unobtained (fiche des badges pas obtenus), name_always, location_always, type_always,
#             leader_always (montrer même sans le badge), obtain_me (musique quand on obtient un badge)
#   regions   [{ id: 1, name: { fr:, en: } }] : nom des régions de PSDK
#   badges    [{ id:, name:, region:, number:, image:, type:, leader:, leader_sprite:, location:, ace:, ace_form: }]
module Configs
  class EtuiBadgesConfig
    attr_accessor :settings, :regions, :badges

    def initialize
      @settings = {}
      @regions = []
      @badges = []
    end
  end
  register(:etui_badges, 'plugins/etui_badges', :json, false, EtuiBadgesConfig)
end

module EtuiBadges
  CONFIG_FILE = 'Data/configs/plugins/etui_badges.json'
  DIR = 'etui_badges/'
  DEFAULTS = {
    'show_unobtained' => false, 'name_always' => true, 'location_always' => true, 'type_always' => false,
    'leader_always' => false, 'obtain_me' => 'audio/me/rosa_badgeobtained'
  }.freeze

  module_function

  # @return [Configs::EtuiBadgesConfig]
  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.etui_badges
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::EtuiBadgesConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::EtuiBadgesConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Étui à badges : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::EtuiBadgesConfig.new
    end
  end

  def reload
    @config = nil
  end

  def fetch(hash, key)
    return nil unless hash.is_a?(Hash)

    value = hash[key.to_s]
    return value.nil? ? hash[key.to_sym] : value
  end

  def setting(key)
    value = fetch(config.settings, key)
    return value.nil? ? DEFAULTS[key.to_s] : value
  end

  def setting?(key)
    return setting(key) == true
  end

  def french?
    return !($options && $options.language.to_s != 'fr')
  end

  def t(fr, en = fr)
    return french? ? fr : en
  end

  def localized(value)
    return value.to_s unless value.is_a?(Hash)

    text = fetch(value, french? ? 'fr' : 'en')
    text = fetch(value, :fr) if text.to_s.empty?
    text = fetch(value, :en) if text.to_s.empty?
    return text.to_s
  end

  def file(name)
    return "#{DIR}#{name}"
  end

  # --- Badges --------------------------------------------------------------------------------------
  # Tous les badges, rangés par région puis par numéro
  # @return [Array<Hash>]
  def all
    return Array(config.badges).select { |b| b.is_a?(Hash) && !fetch(b, :id).to_s.empty? }
                               .sort_by { |b| [region_of(b), number_of(b)] }
  end

  def badge(id)
    return all.find { |b| fetch(b, :id).to_s == id.to_s }
  end

  def region_of(badge)
    return fetch(badge, :region).to_i.clamp(1, 6)
  end

  def number_of(badge)
    return fetch(badge, :number).to_i.clamp(1, 8)
  end

  # Régions qui ont au moins un badge, dans l'ordre
  def regions
    return all.map { |b| region_of(b) }.uniq.sort
  end

  def region_badges(region)
    return all.select { |b| region_of(b) == region.to_i }
  end

  def region_name(region)
    found = Array(config.regions).find { |r| r.is_a?(Hash) && fetch(r, :id).to_i == region.to_i }
    name = found ? localized(fetch(found, :name)) : ''
    return name.empty? ? t("Région #{region}", "Region #{region}") : name
  end

  def obtained?(badge)
    return false unless badge && $trainer

    return $trainer.badge_obtained?(number_of(badge), region_of(badge)) == true
  rescue StandardError
    return false
  end

  def count(region = nil)
    list = region ? region_badges(region) : all
    return list.count { |b| obtained?(b) }
  end

  # Donne / retire le badge (badges de PSDK)
  def give(badge)
    $trainer.set_badge(number_of(badge), region_of(badge), true)
  end

  def take(badge)
    $trainer.set_badge(number_of(badge), region_of(badge), false)
  end

  # --- Date d'obtention ($user_data[:pj_badges] : « région-numéro » => secondes) ----------------
  def times
    return ($user_data[:pj_badges] ||= {})
  end

  def record(number, region)
    key = "#{region}-#{number}"
    times[key] ||= Time.now.to_i
  end

  def forget(number, region)
    times.delete("#{region}-#{number}")
  end

  def obtained_time(badge)
    value = times["#{region_of(badge)}-#{number_of(badge)}"]
    return value ? Time.at(value) : nil
  end

  # --- Textes et images ----------------------------------------------------------------------------
  def name(badge)
    return localized(fetch(badge, :name))
  end

  def location(badge)
    return localized(fetch(badge, :location))
  end

  def leader(badge)
    return localized(fetch(badge, :leader))
  end

  def type(badge)
    sym = fetch(badge, :type).to_s
    return nil if sym.empty?

    return data_type(sym.to_sym).id
  rescue StandardError
    return nil
  end

  def ace(badge)
    sym = fetch(badge, :ace).to_s
    return sym.empty? ? nil : sym.to_sym
  end

  def ace_name(badge)
    sym = ace(badge)
    return '' unless sym

    return data_creature(sym).name
  rescue StandardError
    return sym.to_s
  end

  # Image du badge (version « pas obtenu » si elle existe)
  # @return [Array(String, Boolean)] fichier, silhouette à faire nous-mêmes ?
  def image(badge, obtained = true)
    base = fetch(badge, :image).to_s
    base = fetch(badge, :id).to_s if base.empty?
    on = file("badges/#{base}")
    off = file("badges/#{base}_off")
    return [on, false] if obtained && RPG::Cache.interface_exist?(on)
    return [off, false] if !obtained && RPG::Cache.interface_exist?(off)
    return [on, true] if RPG::Cache.interface_exist?(on)

    return [nil, false]
  end

  # Image du champion : etui_badges/leaders, sinon graphics/battlers
  # @return [Array(String, Symbol), nil]
  def leader_image(badge)
    name = fetch(badge, :leader_sprite).to_s
    return nil if name.empty?
    return [file("leaders/#{name}"), :interface] if RPG::Cache.interface_exist?(file("leaders/#{name}"))
    return [name, :battler] if RPG::Cache.battler_exist?(name)

    return nil
  rescue StandardError
    return nil
  end

  def date_text(time)
    return '' unless time

    return t(time.strftime('%d/%m/%Y'), time.strftime('%Y-%m-%d'))
  end

  # La petite police n'a pas l'apostrophe typographique
  def small(text)
    return text.to_s.tr('’‘', "''")
  end
end

# Date d'obtention de chaque badge, quelle que soit la façon de le donner (commande, évènement de Studio…)
module EtuiBadgesTrainerHook
  def set_badge(badge_num, region = 1, value = true)
    had = (badge_obtained?(badge_num, region) rescue false)
    super
    if value && !had
      EtuiBadges.record(badge_num, region)
    elsif !value
      EtuiBadges.forget(badge_num, region)
    end
  end
end
PFM::Trainer.prepend(EtuiBadgesTrainerHook)
