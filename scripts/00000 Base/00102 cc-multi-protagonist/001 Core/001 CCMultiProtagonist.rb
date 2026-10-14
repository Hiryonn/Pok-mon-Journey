# cc-multi-protagonist: clean, reusable multi-protagonist system as a plugin.
# Lives alongside the native (incomplete) system and ignores it entirely.
module CCMultiProtagonist
  # Player id assigned to the starting protagonist at game initialization.
  DEFAULT_PLAYER_ID = 1
  # Game variable mirroring the current Integer player id, for event Conditional Branches.
  CURRENT_PLAYER_VAR = 51
  # Domains swapped per player by default. A project script may remove a key to share a domain,
  # or push a new key when adding a custom slot.
  PER_PLAYER_SLOTS = %i[bag party trainer appearance money pokedex storage daycare battle_sprite position]
  # Registry of slot instances by key; each slot file self-registers.
  SLOT_REGISTRY = {}
end
