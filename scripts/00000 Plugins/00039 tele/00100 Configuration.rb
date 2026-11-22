# Télé : configuration et données des programmes
# La télé diffuse des programmes (titre, présentateur, pages de texte) répartis sur 8 chaînes ; on s'en sert pour informer le joueur.
# Les programmes viennent de deux endroits :
#   - STATIC_PROGRAMS ci-dessous : toujours disponibles ;
#   - la commande d'évent tele_diffuser : ajoute ou remplace un programme pendant la partie (sauvegardé avec la partie).
# Un texte peut être une chaîne ou un tableau [français, anglais]. Les chaînes sont numérotées de 1 à 8 (comme les images chaine_1 à 8).
module Television
  extend self

  DIR = 'tele/'
  SCREEN_X = 32
  SCREEN_Y = 24
  # Clé dans $user_data (sauvegardé avec la partie)
  STORAGE_KEY = :television
  # Programmes ajoutés pendant la partie, au maximum
  MAX_PROGRAMS = 60
  # Caractères par ligne et lignes par écran de texte
  LINE_CHARS = 32
  LINES = 3

  # Les 8 chaînes : image chaine_<n> et noms [français, anglais]
  CHANNELS = [
    {names: ['Mystères', 'Mysteries']},
    {names: ['Pokémon', 'Pokémon']},
    {names: ['Exploration', 'Exploration']},
    {names: ['Boutiques', 'Shops']},
    {names: ['Légendes', 'Legends']},
    {names: ['Habitats', 'Habitats']},
    {names: ['Concours', 'Contests']},
    {names: ['Région', 'Region']}
  ].freeze

  # Les 5 présentateurs : image presentateur_<n> et noms [français, anglais]
  PRESENTERS = [
    ['Léa', 'Lea'],
    ['Marc', 'Marc'],
    ['Pr Hector', 'Prof. Hector'],
    ['Rico', 'Rico'],
    ['Clara', 'Clara']
  ].freeze

  # Programmes toujours disponibles. 'id' unique, 'channel' de 1 à 8, 'presenter' de 1 à 5, 'pages' : un texte par page (découpé
  # automatiquement en écrans de LINES lignes).
  STATIC_PROGRAMS = [
    {
      'id' => 'bienvenue',
      'channel' => 2,
      'presenter' => 1,
      'title' => ['Bienvenue sur la Télé !', 'Welcome to TV!'],
      'pages' => [
        ['Bonjour à tous ! Ici Marc, pour vous présenter la nouvelle télé de la région.',
         'Hello everyone! This is Marc, here to present the region\'s new TV.'],
        ['Retrouvez ici les nouvelles, les conseils et les secrets de l\'aventure. À bientôt !',
         'Find news, tips and adventure secrets here. See you soon!']
      ]
    }
  ].freeze

  # @return [Integer] 0 français, 1 anglais
  def language_index
    return $options && $options.language.to_s != 'fr' ? 1 : 0
  end

  # @param value [String, Array<String>] texte ou [français, anglais]
  # @return [String]
  def localize(value)
    return (value[language_index] || value[0]).to_s if value.is_a?(Array)

    return value.to_s
  end

  # @param index [Integer] chaîne (0 à 7)
  # @return [String]
  def channel_name(index)
    return localize(CHANNELS[index][:names])
  end

  # @param index [Integer] présentateur (0 à 4)
  # @return [String]
  def presenter_name(index)
    return localize(PRESENTERS[index.clamp(0, PRESENTERS.size - 1)])
  end

  # @return [Hash] { 'programs' => [...], 'seen' => { id => true } }
  def storage
    return {'programs' => [], 'seen' => {}} unless $user_data

    data = ($user_data[STORAGE_KEY] ||= {})
    data['programs'] ||= []
    data['seen'] ||= {}
    return data
  end

  # @return [Array<Hash>] tous les programmes (fixes puis diffusés)
  def programs
    return STATIC_PROGRAMS.map { |program| program.dup } + storage['programs']
  end

  # @param channel [Integer, nil] chaîne (0 à 7)
  # @return [Array<Hash>]
  def channel_programs(channel)
    return programs.select { |program| channel_of(program) == channel }
  end

  # @param program [Hash]
  # @return [Integer] chaîne (0 à 7)
  def channel_of(program)
    return (program['channel'].to_i - 1).clamp(0, CHANNELS.size - 1)
  end

  # @param program [Hash]
  # @return [Integer] présentateur (0 à 4)
  def presenter_of(program)
    return (program['presenter'].to_i - 1).clamp(0, PRESENTERS.size - 1)
  end

  # @param program [Hash]
  # @return [String]
  def title_of(program)
    return localize(program['title'])
  end

  # @param id [String, Symbol]
  # @return [Hash, nil]
  def find(id)
    return programs.find { |program| program['id'].to_s == id.to_s }
  end

  # @param program [Hash]
  # @return [Boolean]
  def seen?(program)
    return storage['seen'][program['id'].to_s] ? true : false
  end

  # @param program [Hash]
  def mark_seen(program)
    storage['seen'][program['id'].to_s] = true
  end

  # @param channel [Integer, nil] chaîne (0 à 7), nil pour toutes
  # @return [Integer] programmes pas encore vus
  def unseen_count(channel = nil)
    list = channel ? channel_programs(channel) : programs
    return list.count { |program| !seen?(program) }
  end

  # Ajoute un programme, ou remplace celui qui a le même id (il redevient « nouveau »).
  # @param id [String, Symbol]
  # @param channel [Integer] 1 à 8
  # @param title [String, Array<String>]
  # @param presenter [Integer] 1 à 5
  # @param pages [Array<String, Array<String>>]
  # @return [Boolean] faux : trop de programmes
  def broadcast(id, channel, title, presenter, pages)
    list = storage['programs']
    program = {'id' => id.to_s, 'channel' => channel.to_i.clamp(1, CHANNELS.size), 'presenter' => presenter.to_i.clamp(1, PRESENTERS.size),
               'title' => title, 'pages' => Array(pages)}
    existing = list.index { |item| item['id'] == program['id'] }
    return false if !existing && list.size >= MAX_PROGRAMS

    existing ? list[existing] = program : list << program
    storage['seen'].delete(program['id'])
    return true
  end

  # @param id [String, Symbol]
  # @return [Boolean] un programme a été retiré
  def withdraw(id)
    list = storage['programs']
    index = list.index { |item| item['id'] == id.to_s }
    return false unless index

    list.delete_at(index)
    return true
  end

  # @param program [Hash]
  # @return [Array<Array<String>>] les écrans du programme : LINES lignes de LINE_CHARS caractères au plus
  def screens(program)
    result = []
    Array(program['pages']).each do |page|
      lines = wrap(localize(page))
      lines.each_slice(LINES) { |slice| result << slice }
    end
    return result.empty? ? [['']] : result
  end

  # @param text [String]
  # @param width [Integer]
  # @return [Array<String>] lignes coupées entre les mots ("\n" force un retour à la ligne)
  def wrap(text, width = LINE_CHARS)
    lines = []
    text.to_s.split("\n", -1).each do |paragraph|
      line = ''
      paragraph.split(' ').each do |word|
        if line.empty?
          line = word.dup
        elsif line.size + 1 + word.size <= width
          line << ' ' << word
        else
          lines << line
          line = word.dup
        end
      end
      lines << line
    end
    return lines
  end
end
