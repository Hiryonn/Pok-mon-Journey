class Interpreter < Interpreter_RMXP
  # Configurations:
  MYSTERY_GIFT_URL = "" # The URL to the raw version of your pastebin (ex: https://pastebin.com/raw/sAdusZdB)
  VAR_CHOICE = 26 # Temp variable 1, safe to not change

  # Text configs:
  ONE_MOMENT_PLEASE = [100998, 1] # Sure! One moment, please.
  CHECKING_FOR_GIFTS = [100998, 2] # Checking for new mystery gifts[WAIT 20].[WAIT 20].[WAIT 20].
  NEW_GIFT_MESSAGE = [100998, 3] # It looks like you have new gifts waiting to be claimed!
  WHAT_TO_CLAIM = [100998, 4] # Which gift would you like to claim?
  NO_GIFTS_AT_MOMENT = [100998, 5] # It looks like there are no mystery gifts available at the moment.
  NO_MORE_GIFTS = [100998, 6] # It looks like you have claimed all the currently available mystery gifts! Try again another time.
  NEVERMIND_MESSAGE = [100998, 7] # Nevermind
  MORE_GIFTS_AVAILABLE = [100998, 8] # There are more gifts available. Do you want to claim another?
  DONT_CLAIM_MESSAGE = [100998, 9] # So, you don't want to claim anything? That's okay!\nlYou can always claim them later.
  YES_TEXT = [0, 2] # Yes
  NO_TEXT = [0, 3] # No

  public

  # Quicker mystery gift method specifically for Pokemon
  # @param hash [Hash] the parameters of the Pokemon, see PFM::Pokemon#generate_from_hash.
  # @param mg_name [String] the name of the mystery gift
  # Example: S.MI.create_mystery_gift_pokemon({id: :pikachu, level: 12, shiny: true}, "pokemon_test")
  # If you want to use translated text for the name of the mystery gift, type it like: "[100000, 5]" instead of "pokemon_test"
  def create_mystery_gift_pokemon(hash, mg_name, overwrite = false)
    # Set default value for captured_with to cherish ball, if not provided
    hash = { captured_with: 6 }.merge(hash)
    # Checks if Pokemon exists
    pokemon_id = hash[:id]
    case pokemon_id
    when Integer
      raise "Database Error : The Pokémon ##{pokemon_id} doesn't exists." if each_data_creature.none? { |creature| creature.id == pokemon_id }
    when Symbol
      raise "Database Error : The Pokémon with db_symbol #{pokemon_id} doesn't exists." if each_data_creature.none? { |creature| creature.db_symbol == pokemon_id }
    end
    encode_please(hash, mg_name, 0, overwrite)
  end
  alias create_mg_pokemon create_mystery_gift_pokemon

  # Quicker mystery gift method specifically for items
  # @param item [Symbol] the db_symbol of the item.
  # @param quantity [Integer] the amount you want to give.
  # @param flag [Symbol] the name of the flag used to represent the mystery gift
  # Example: S.MI.create_mystery_gift_item(:potion, 5, "item_test")
  # If you want to use translated text for the name of the mystery gift, type it like: "[100000, 5]" instead of "item_test"
  def create_mystery_gift_item(item, quantity, mg_name, overwrite = false)
    log_debug("item: #{item} quantity: #{quantity}")
    encode_please(item, mg_name, quantity, overwrite)
  end
  alias create_mg_item create_mystery_gift_item

  # Checks if the player has a mystery gift available.
  # To disable mystery gifts, just have the pastebin say something random.
  def check_mystery_gift
    # Used to prevent the "It looks like you have new gifts" message from appearing twice
    seen_already = false
    # Sure! One moment, please.
    message(ext_text(*ONE_MOMENT_PLEASE))
    # Simulate checking and waiting
    message(ext_text(*CHECKING_FOR_GIFTS))
    decoded_gifts = decode_please
    log_debug("Decoded gifts: #{decoded_gifts}")
  
    # Initialize the mystery gifts array if it doesn't exist
    $user_data[:mystery_gifts] ||= []
    mystery_gifts = $user_data[:mystery_gifts]
  
    loop do
      # Create an array to store available gifts
      available_gifts = []
  
      decoded_gifts.each do |mg_name, _, _|
        unless mystery_gifts.include?(mg_name)
          available_gifts << mg_name
        end
      end

      unless available_gifts.empty?
        # It looks like you have new gifts waiting to be claimed!
        message(ext_text(*NEW_GIFT_MESSAGE)) unless seen_already
        seen_already = true
        has_claimed_gift = show_choices(available_gifts, decoded_gifts, mystery_gifts)
  
        # Check if there are remaining mystery gifts
        remaining_gifts = decoded_gifts.reject { |mg_name, _, _| mystery_gifts.include?(mg_name) }
  
        unless remaining_gifts.empty? || has_claimed_gift == false
          # There are more gifts available. Do you want to claim another?
          @choices = [ext_text(*YES_TEXT), ext_text(*NO_TEXT)]
          choice(VAR_CHOICE, @choices.length, *@choices)
          # There are more gifts available. Do you want to claim another?
          message(ext_text(*MORE_GIFTS_AVAILABLE))
          # So, you don't want to claim anything? That's okay!\nlYou can always claim them later.
          message(ext_text(*DONT_CLAIM_MESSAGE)) if $game_variables[VAR_CHOICE] == @choices.length
          break if $game_variables[VAR_CHOICE] == @choices.length || remaining_gifts.empty?
        else
          # Message shown when you exit and didn't choose a gift
          message(ext_text(*DONT_CLAIM_MESSAGE)) if has_claimed_gift == false
          # Message shown when you claim the last gift
          # It looks like you have claimed all the currently available mystery gifts! Try again another time.
          message(ext_text(*NO_MORE_GIFTS)) if remaining_gifts.empty?
          break
        end
      else
        # Message shown when all gifts have been claimed
        # It looks like you have claimed all the currently available mystery gifts! Try again another time.
        message(ext_text(*NO_MORE_GIFTS))
        break
      end
    end
  
    @wait_count = 2
  rescue StandardError => e
    # No mystery gift available at the moment
    message(ext_text(*NO_GIFTS_AT_MOMENT))
    @wait_count = 2
  end
  alias check_mg check_mystery_gift

  private
  
  # Shows the mystery gift choices
  # @param available_gifts [String] array of available gift info
  # @param decoded_gifts [String] all the currently available gifts
  # @param mystery_gifts [Hash] the user's mystery gift data
  # @return [Boolean] if the user made a choice or canceled
  def show_choices(available_gifts, decoded_gifts, mystery_gifts)
    # Use available_gifts to populate @choices
    @choices = available_gifts.map { |mg| mg.start_with?("[") ? ext_text(mg) : mg } + [ext_text(*NEVERMIND_MESSAGE)]
    # Ask user which gift they would like to claim
    choice(VAR_CHOICE, @choices.length, *@choices)
    # Which gift would you like to claim?
    message(ext_text(*WHAT_TO_CLAIM))
  
    # Reward the selected gift
    selected_gift_index = $game_variables[VAR_CHOICE] - 1
    selected_gift = available_gifts[selected_gift_index]
    decoded_gifts.each do |mg_name, quantity, gift|
      if mg_name == selected_gift
        claim_gift(gift, quantity.to_i)
        mystery_gifts << mg_name
        log_debug("Added mystery gift '#{mg_name}' to $user_data[:mystery_gifts]")
        @wait_count = 2
      end
    end
    return selected_gift_index != (@choices.length - 1)
  end

  # Gives the gifts to player
  # @param gift [String] text of data. Either Pokemon hash or item.
  # @param quantity [Integer] quantity of items.
  def claim_gift(gift, quantity)
    log_debug("Claiming gift: #{gift} quantity: #{quantity}")
    case quantity
    when 0 # Pokemon
      gift_hash = eval(gift)
      gift = PFM::Pokemon.generate_from_hash(gift_hash)
      receive_pokegift_sequence(gift)
      return
    when 1..Float::INFINITY # Item
      gift = gift.to_sym
      Audio.me_play(*RECEIVED_POKEMON_ME)
      add_item(gift, true, text_id: 4, count: quantity)
      return
    else # Error
      puts "Negative quantity?"
      return
    end
  end

  # Modified receieve Pokémon sequence w/ no nickname question
  # @param pokemon_or_id [Integer, Symbol, PFM::Pokemon] the ID of the pokemon in the database or a Pokemon
  # @param level [Integer] the level of the Pokemon (if ID given)
  # @param shiny [Boolean, Integer] true means the Pokemon will be shiny, 0 means it'll have no chance to be shiny, other number are the chance (1 / n) the pokemon can be shiny.
  # @return [PFM::Pokemon, nil] if nil, the Pokemon couldn't be stored in the PC or added to the party. Otherwise it's the Pokemon that was added.
  def receive_pokegift_sequence(pokemon_or_id, level = 5, shiny = false)
    pokemon = add_pokemon(pokemon_or_id, level, shiny)
    if pokemon
      Audio.me_play(*RECEIVED_POKEMON_ME)
      show_message(:received_pokemon, pokemon: pokemon, header: SYSTEM_MESSAGE_HEADER)
      original_name = pokemon.given_name
      pokemon_stored_sequence(pokemon) if $game_switches[Yuki::Sw::SYS_Stored]
      PFM::Text.reset_variables
    end
    return pokemon
  end

  # Reads from the MYSTERY_GIFT_URL, decodes and returns the mystery gifts
  # @return results [Array] decoded mystery gift data 
  def decode_please
    uri = URI(MYSTERY_GIFT_URL)

    # Disable SSL verification (for testing/development only)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http.get(uri)

    if response.is_a?(Net::HTTPSuccess)
      content = response.body
      content_array = content.split('//')
      log_debug("Content from Pastebin:")
      log_debug(content)
      log_debug("content_array: #{content_array}")

      decompressed_array = []
      content_array.each do |compressed_content|
        decompressed = Marshal.load(Zlib::Inflate.inflate(compressed_content.unpack('m').first))
        decompressed_array << decompressed
      end

      log_debug("Your decompressed array: #{decompressed_array}")

      results = []
      decompressed_array.each do |decompressed|
        # Check if mg_name starts with "[" to determine how to split
        if decompressed.start_with?("[")
          mg_name = decompressed[/\[(.*?)\]/, 1] # Extract mg_name from brackets
          rest_of_content = decompressed.sub(/\[.*?\]/, '') # Remove mg_name from the rest of the content
          split_data = [mg_name] + rest_of_content.match(/^.?(.+)$/)[1].split(',').map(&:strip)
        else
          # Split the message by commas
          split_data = decompressed.split(',')
        end

        # Extract mg_name, quantity, and gift
        mg_name = split_data.shift.strip
        quantity = split_data.shift.strip
        gift = split_data.join(',').strip

        results << [mg_name, quantity, gift]
      end

      return results
    else
      puts "Error: Unable to fetch Pastebin content. HTTP Status: #{response.code}"
      return nil
    end
  end

  # Encodes a Pokémon or Item for a mystery gift and saves the codes to "mystery_gift.txt"
  # @param data [String] the info we want to encode
  # @param mg_name [String] the name of the mystery gift
  # @param quantity [Integer] number of items to give
  def encode_please(data, mg_name, quantity, overwrite = false)
    export_file = "mystery_gift.txt"
    message = "#{mg_name},#{quantity},#{data}"
    log_debug("About to encode: #{message}")
    compressed_data = [Zlib::Deflate.deflate(Marshal.dump(message))].pack('m')

    if File.exist?(export_file) && !overwrite
      # Append to the existing file
      File.open(export_file, 'a') do |file|
        file.puts "[#{mg_name}]"
        file.puts compressed_data
      end
      log_debug("Encoded content appended to #{export_file}")
    else
      # Write the mg_name and compressed data to the file
      File.open(export_file, 'w') do |file|
        file.puts "[#{mg_name}]"
        file.puts compressed_data
      end
      log_debug("Encoded content exported to #{export_file}")
    end
  end
end