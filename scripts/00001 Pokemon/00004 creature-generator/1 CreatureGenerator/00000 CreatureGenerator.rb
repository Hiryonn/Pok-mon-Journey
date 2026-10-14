class CreatureGenerator
  # Whether to allow legendary creatures (default: false)
  # @return [Boolean]
  attr_accessor :allow_legendary
  # Whether to allow mythical creatures (default: false)
  # @return [Boolean]
  attr_accessor :allow_mythical
  # Whether to allow ultra beasts (default: false)
  # @return [Boolean]
  attr_accessor :allow_ultra_beast
  # Whether to allow pseudo legendary creatures (default: false)
  # @return [Boolean]
  attr_accessor :allow_pseudo_legendary
  # Whether to allow baby creatures (default: false)
  # @return [Boolean]
  attr_accessor :allow_baby

  # List of legendary creatures db_symbols
  # @return [Array<Symbol>]
  LEGENDARY_CREATURE_DB_SYMBOL = %i[articuno zapdos moltres mewtwo raikou entei suicune lugia ho_oh regirock regice registeel latios latias kyogre
                                    groudon rayquaza uxie mesprit azelf dialga palkia giratina heatran regigigas cresselia cobalion terrakion virizion tornadus thundurus landorus reshiram zekrom kyurem xerneas yveltal zygarde type_null silvally tapu_koko tapu_lele tapu_bulu tapu_fini cosmog cosmoem solgaleo lunala necrozma zacian zamazenta eternatus kubfu urshifu regieleki regidrago calyrex glastrier spectrier enamorus wo_chien chien_pao ting_lu chi_yu koraidon miraidon okidogi munkidori fezandipiti ogerpon terapagos]

  # List of pseudo mythical creatures db_symbols
  # @return [Array<Symbol>]
  MYTHICAL_CREATURE_DB_SYMBOL = %i[mew celebi jirachi deoxys manaphy phione darkrai shaymin arceus victini keldeo meloetta genesect diancie hoopa
                                   volcanion magearna marshadow zeraora meltan melmetal zarude pecharunt]

  ULTRA_BEAST_CREATURE_DB_SYMBOL = %i[nihilego buzzwole pheromosa xurkitree celesteela kartana guzzlord poipole naganadel stakataka blacephalon]

  # List of pseudo legendary creatures db_symbols
  # @return [Array<Symbol>]
  PSEUDO_LEGENDARY_CREATURE_DB_SYMBOL = %i[dratini larvitar bagon beldum gible deino goomy jangmo_o dreepy frigibax]

  # List of baby creatures db_symbols
  # @return [Array<Symbol>]
  BABY_CREATURE_DB_SYMBOL = %i[pichu cleffa igglybuff togepi tyrogue smoochum elekid magby azurill wynaut budew chingling bonsly mime_jr happiny
                               munchlax riolu mantyke]

  # Initializes a new CreatureGenerator instance
  # @param allow_legendary [Boolean] Whether to allow legendary creatures (default: false)
  # @param allow_mythical [Boolean] Whether to allow mythical creatures (default: false)
  # @param allow_ultra_beast [Boolean] Whether to allow ultra beasts (default: false)
  # @param allow_pseudo_legendary [Boolean] Whether to allow pseudo legendary creatures (default: false)
  # @param allow_baby [Boolean] Whether to allow baby creatures (default: false)
  def initialize(allow_legendary: false, allow_mythical: false, allow_ultra_beast: false, allow_pseudo_legendary: false, allow_baby: false)
    @allow_legendary = allow_legendary
    @allow_mythical = allow_mythical
    @allow_ultra_beast = allow_ultra_beast
    @allow_pseudo_legendary = allow_pseudo_legendary
    @allow_baby = allow_baby
  end
end
