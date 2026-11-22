# Secret Insight (secret_insight)
# The Pokémon relies on its mystical power to navigate. Its Sp. Atk stat is boosted, but accuracy is lowered.
# Atq. Spé. x1,5 ; la précision de ses capacités baisse (x0,8).
ExtraAbilitiesAdditions.define(:secret_insight) do
  def ats_modifier
    return 1.5
  end

  def chance_of_hit_multiplier(user, _target, _move)
    return user == @target ? 0.8 : 1
  end
end
