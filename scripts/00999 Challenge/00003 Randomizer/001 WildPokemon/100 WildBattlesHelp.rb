module PFM
  # The class responsible of managing the randomizer plugin
  class Randomizer
    # The class responsible of telling the state of the random wild battles mode
    class WildPokemon
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
          \e[31mReminder to always add $randomizer.wild_pokemon.[your_command] before the following commands!\e[0m
          Check if the random wild battles mode is enabled:\e[37m
            - enabled?\e[36m
          Enable the random wild battles mode:\e[37m
            - enable\e[36m
          Disable the random wild battles mode:\e[37m
            - disable\e[36m
          Get the current mode:\e[37m
            - mode\e[36m
          Switch between shuffle and full random mode:\e[37m
            - switch\e[36m
        EOLIST
      end
    end
  end
end
