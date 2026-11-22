# Terrain Sale (terrain ajouté pour le talent Filthy Surge) : 5 tours, les capacités Poison sont renforcées de 30 %.
# Les règles du terrain (ex. « Toxic Fumes empoisonne toujours ») ne sont pas codées : ajoute-les ici si besoin.
module ExtraAbilitiesAdditions
  module FilthyTerrain
    module_function

    def start(logic, scene)
      handler = logic.fterrain_change_handler
      return if logic.field_terrain == :filthy_terrain

      handler.fterrain_change_with_process(:filthy_terrain, 5, no_message: true)
      scene.display_message_and_wait(ExtraAbilitiesAdditions.text('Le sol est recouvert de saleté !', 'The ground became filthy!'))
    end
  end
end

module Battle
  module Effects
    class FilthyTerrain < FieldTerrain
      def base_power_multiplier(user, _target, move)
        id = GameData::Type[:poison]&.id
        return 1 unless id && move.type == id

        return 1.3
      end
    end
    FieldTerrain.register(:filthy_terrain, FilthyTerrain)
  end
end
