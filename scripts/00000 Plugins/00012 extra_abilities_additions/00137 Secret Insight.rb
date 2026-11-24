# Secret Insight (secret_insight)
# The Pokémon relies on its mystical power to navigate. Its Sp. Atk stat is boosted, but accuracy is lowered.
ExtraAbilitiesAdditions.define(:secret_insight) do
  # Atq. Spé. x1,5 (la baisse de précision n'est pas codée).
  def ats_modifier
    return 1.5
  end
end
