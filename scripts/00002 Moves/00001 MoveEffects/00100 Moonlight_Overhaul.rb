module Battle
    class Move
        class Moonlight < HealWeather
            def deal_effect(user, targets)
                targets.each do |target|
                  if $env.normal? || $env.strong_winds?
                    hp = target.max_hp / 2
                  else
                    if $env.sunny? || $env.hardsun?
                      hp = target.max_hp * 2 / 3
                    elsif $env.twilight?
                      hp = target.max_hp * 3 / 4
                    else
                      hp = target.max_hp / 4
                    end
                  end
                  hp = hp * 3 / 2 if pulse? && user.has_ability?(:mega_launcher)
                  logic.damage_handler.heal(target, hp)
                end
              end
            end
            Move.register(:s_moonlight, Moonlight)
        end
    end
    