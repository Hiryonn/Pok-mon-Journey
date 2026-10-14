module GamePlay
  class << self
    # Open the party menu to purify a Shadow Pokemon
    # @param party [Array<PFM::Pokemon>] party to manage
    # @yieldparam party_menu_scene [PartyMenuMixin]
    def open_party_menu_to_purify_pokemon(party = PFM.game_state.actors, &block)
      current_scene.call_scene(party_menu_class, party, :purification, &block)
    end
  end
end
