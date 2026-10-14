module Battle
  class Visual
    # Hand the field back the way a knock out leaves it, once a creature has been snagged. The engine
    # ends the battle right after a capture, so it leaves the thrown ball on screen and, in 3D, the
    # camera on the creature it just caught. A snag lets the battle go on, so both have to be undone.
    # @param battler [PFM::PokemonBattler] creature that was snagged
    def show_snag(battler)
      battler_sprite(battler.bank, battler.position).go_out
      hide_info_bar(battler)
      # The 2D visual holds the thrown ball in @sprite and the 3D one in @ball, neither exposed.
      [@sprite, @ball].compact.reject(&:disposed?).each(&:dispose)
      start_center_animation
    end
  end
end
