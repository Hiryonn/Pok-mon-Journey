# Résumé Horizon : page Arbre familial (d'après « Family Tree » d'Essentials)
#
# Quand la pension donne un œuf, ses deux parents (et les parents de ses parents) sont notés dans l'œuf :
# espèce, forme, surnom, sexe, chromatique. La page les montre : à droite les deux parents (carte claire) et,
# sous chacun, ses propres parents (petites cases, « ? » quand on ne les connaît pas).
# Un Pokémon venu d'ailleurs (capturé, reçu) n'a pas d'arbre : ses parents sont inconnus.
#
# Commande d'évènement (Script) pour un œuf ou un Pokémon donné par un évènement :
#   arbre_familial(0, :pikachu, :raichu)  -> le Pokémon n° 0 de l'équipe a Pikachu pour père et Raichu pour mère
#   arbre_familial(0, { species: :ditto, name: 'Doudou' }, :vulpix)   (Hash : species, form, name, gender, shiny)
module UI
  module SummaryPE
    # Arbre familial des Pokémon
    module FamilyTree
      module_function

      # Fiche d'un Pokémon pour l'arbre de son enfant
      # @param pokemon [PFM::Pokemon]
      # @param with_parents [Boolean] garder aussi ses propres parents (grands-parents de l'enfant)
      # @return [Hash]
      def entry(pokemon, with_parents = true)
        data = { species: pokemon.db_symbol, form: pokemon.form.to_i, name: pokemon.given_name.to_s,
                 gender: pokemon.gender.to_i, shiny: pokemon.shiny ? true : false }
        parents = with_parents ? parents_of(pokemon) : nil
        data[:parents] = parents.map { |p| p&.reject { |key, _| key == :parents } } if parents
        return data
      end

      # @param pokemon [PFM::Pokemon]
      # @return [Array(Hash, Hash), nil] père, mère
      def parents_of(pokemon)
        family = pokemon.respond_to?(:pj_family) ? pokemon.pj_family : nil
        return family.is_a?(Hash) ? family[:parents] : nil
      end

      # Note les parents dans l'enfant (le père en premier)
      def record(child, father, mother)
        child.pj_family = { parents: [father && entry(father), mother && entry(mother)] }
      end

      # Fiche faite à la main (commande arbre_familial) : Symbol de l'espèce ou Hash
      # @return [Hash, nil]
      def manual_entry(value, default_gender)
        return nil if value.nil?

        value = { species: value } unless value.is_a?(Hash)
        species = (value[:species] || value['species']).to_sym
        name = value[:name] || value['name'] || data_creature(species).name
        return { species: species, form: (value[:form] || value['form']).to_i, name: name.to_s,
                 gender: (value[:gender] || value['gender'] || default_gender).to_i, shiny: (value[:shiny] || value['shiny']) ? true : false }
      rescue StandardError
        return nil
      end

      # Nom de l'espèce
      def species_name(entry)
        return data_creature(entry[:species]).name.to_s
      rescue StandardError
        return entry[:species].to_s
      end

      # Image de l'icône (graphics/pokedex/pokeicon)
      def icon_name(entry)
        id = data_creature(entry[:species]).id
        return PFM::Pokemon.icon_filename(id, entry[:form].to_i, entry[:gender] == 2, entry[:shiny], false)
      rescue StandardError
        return nil
      end
    end

    # Page 6 : arbre familial
    class FamilyPage < SpriteStack
      # Positions (graphismes : tools/interface-horizon/build_family_assets.py)
      CARD_X = 128
      CARD_Y = [58, 132]
      CARD_W = 184
      GRAND_X = [232, 274]
      GRAND_DY = 36
      TITLE_X = 10
      TITLE_Y = 56

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        SummaryPE.widen_page(add_sprite(0, 0, SummaryPE.file('page_family')), 'page_family')
        add_text(TITLE_X, TITLE_Y, 100, 16, SummaryPE.label(:family), color: DARK)
        @parents = CARD_Y.map { |y| create_card(y) }
        @grands = CARD_Y.map { |y| GRAND_X.map { |x| create_icon(x + SummaryPE.extra + 3, y + GRAND_DY + 1) } }
      end

      # @param pokemon [PFM::Pokemon]
      def data=(pokemon)
        @data = pokemon
        return unless (self.visible = pokemon ? true : false)

        parents = FamilyTree.parents_of(pokemon) || []
        @parents.each_with_index do |card, i|
          parent = parents[i]
          show_card(card, parent)
          grands = parent ? Array(parent[:parents]) : []
          @grands[i].each_with_index { |icon, j| show_icon(icon, grands[j]) }
        end
      end

      # @param value [Boolean]
      def visible=(value)
        super
        return unless value && @parents

        # Le sexe et l'étoile ne s'affichent que s'il le faut
        @parents.each do |card|
          card[:gender].visible = card[:show_gender] ? true : false
          card[:shiny].visible = card[:show_shiny] ? true : false
        end
      end

      private

      def create_card(y)
        card = {}
        card[:icon] = create_icon(CARD_X + 1, y - 2)
        card[:name] = add_text(CARD_X + 38, y + 1, 128 + SummaryPE.extra, 16, '', color: DARK)
        with_font(SMALL_FONT) { card[:species] = add_text(CARD_X + 38, y + 15, 128 + SummaryPE.extra, 13, '', color: DARK) }
        card[:gender] = add_sprite(CARD_X + CARD_W + SummaryPE.extra - 12, y + 5, SummaryPE.file('gender_m'))
        card[:shiny] = add_sprite(CARD_X + CARD_W + SummaryPE.extra - 25, y + 5, SummaryPE.file('shiny'))
        return card
      end

      def create_icon(x, y)
        return add_sprite(x, y, NO_INITIAL_IMAGE)
      end

      def show_card(card, entry)
        show_icon(card[:icon], entry)
        unless entry
          card[:name].text = SummaryPE.label(:unknown)
          card[:species].text = ''
          card[:show_gender] = card[:show_shiny] = false
          card[:gender].visible = card[:shiny].visible = false
          return
        end
        species = FamilyTree.species_name(entry)
        card[:name].text = entry[:name].to_s.empty? ? species : entry[:name].to_s
        card[:species].text = card[:name].text == species ? '' : "/ #{species}"
        card[:show_gender] = [1, 2].include?(entry[:gender])
        card[:show_shiny] = entry[:shiny] ? true : false
        card[:gender].set_bitmap(SummaryPE.file(entry[:gender] == 2 ? 'gender_f' : 'gender_m'), :interface) if card[:show_gender]
        card[:gender].visible = card[:show_gender] && visible
        card[:shiny].visible = card[:show_shiny] && visible
      end

      # Icône du Pokémon (première image) ou plaque « ? »
      def show_icon(sprite, entry)
        name = entry && FamilyTree.icon_name(entry)
        if name && RPG::Cache.b_icon_exist?(name)
          sprite.set_bitmap(name, :b_icon)
          w = sprite.bitmap.width
          h = sprite.bitmap.height
          sprite.src_rect.set(0, 0, w > h ? h : w, h)
        else
          sprite.set_bitmap(SummaryPE.file('family_unknown'), :interface)
        end
        sprite.visible = visible
      rescue StandardError
        sprite.set_bitmap(SummaryPE.file('family_unknown'), :interface)
      end
    end

    # Le grand sprite du Pokémon s'affiche dans le cadre gris de la page arbre familial
    Header::FACE_POSITIONS[FAMILY_PAGE] = [58, 198]
  end
end

module PFM
  class Pokemon
    # Arbre familial ({ parents: [père, mère] }, voir UI::SummaryPE::FamilyTree)
    # @return [Hash, nil]
    attr_accessor :pj_family
  end

  # La pension note les parents dans chaque œuf
  class Daycare
    module PJFamilyTree
      def inherit(pokemon, parents)
        super
        male, female = assign_gender(*parents)
        UI::SummaryPE::FamilyTree.record(pokemon, male, female)
      rescue StandardError => e
        log_error("Arbre familial : parents non notés (#{e.message})") if respond_to?(:log_error, true)
      end
    end
    prepend PJFamilyTree
  end
end

class Interpreter
  # Donne un arbre familial à un Pokémon de l'équipe (œuf offert par un évènement, etc.)
  # @param index [Integer] place dans l'équipe (0 = premier)
  # @param father [Symbol, Hash, nil]
  # @param mother [Symbol, Hash, nil]
  def arbre_familial(index, father, mother)
    pokemon = $actors[index]
    return false unless pokemon

    tree = UI::SummaryPE::FamilyTree
    pokemon.pj_family = { parents: [tree.manual_entry(father, 1), tree.manual_entry(mother, 2)] }
    return true
  end
end
