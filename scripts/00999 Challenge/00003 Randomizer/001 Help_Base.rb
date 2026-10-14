module PFM
  # The class responsible of managing the randomizer plugin
  class Randomizer
    # Method that shows the help
    def help
      cc 0x75
      puts "\r#{'PSDK Randomizer Help'.center(50)}"
      cc 0x07
      print <<~EODESCRIPTION
        Here's the list of the command you can enter in this terminal.
        Remember that you're executing actual Ruby code.
        When an ID is 005 or 023 you have to write 5 or 23, the 0-prefix should never appear in the command you enter.
      EODESCRIPTION
      cc 0x06
      print <<~EOLIST
        \e[31mReminder to always add $randomizer.[your_command] before the following commands!\e[0m
        Show all the different modes and their current state:\e[37m
          - list\e[36m
        Enable all modules:\e[37m
          - enable_all\e[36m
        Disable all modules:\e[37m
          - disable_all\e[36m
        Sub-class of the random encounters:\e[37m
          - wild_pokemon\e[36m
        Sub-class of the random trainers:\e[37m
          - trainers_pokemon\e[36m
        Sub-class of the random abilities:\e[37m
          - abilities\e[36m
        Sub-class of the random evolutions:\e[37m
          - evolutions\e[36m
        Sub-class of the random moves:\e[37m
          - moves\e[36m
        Sub-class of the random given Pokémon:\e[37m
          - given_pokemon\e[36m
        Get or configure the pokedex sampled in full random:\e[37m
          - pokedex_symbol
          - pokedex_symbol = :db_symbol\e[36m
        Get the current seed used:\e[37m
          - seed\e[36m
      EOLIST
    end
  end
end
