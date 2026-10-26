# Script décompilé depuis le bytecode du jeu (Ruby 3.0) — fichier d'origine : RMXP/00006_Shiny_OW.rb
# Les commentaires et la mise en forme d'origine ne sont pas récupérables.

class Interpreter
  def roll_for_shiny(event_id, self_switch_letter, db_symbol)
    caught_count = $pokedex.creature_caught_count(db_symbol)
    shiny_rate = 4096

    case caught_count
    when (0..9) then shiny_rate = 4096
    when (10..19) then shiny_rate = 2048
    when (20..29) then shiny_rate = 1024
    when (30..49) then shiny_rate = 512
    else
      shiny_rate = 256
    end

    shiny = rand(shiny_rate) == 0
    log_error("Roll for shiny : Event #{event_id} | Shiny: #{shiny}")

    if shiny
      Audio.se_play("audio/se/se_shiny")
      set_self_switch(true, self_switch_letter, event_id)
    else
      set_self_switch(false, "A", event_id)
      set_self_switch(false, "B", event_id)
      set_self_switch(false, "C", event_id)
      set_self_switch(false, "D", event_id)
    end
  end
end
