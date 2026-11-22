# Magasins : commandes d'évènement (Script)
#
#   magasin(:id)                 -> ouvre le magasin (comptoir ou étalage, selon son type dans Studio)
#   etalage(:id)                 -> ouvre un étalage (même chose que magasin pour un étalage)
#   magasin_caisse               -> passage en caisse : paye le panier des étalages (magasin_caisse(:vendeur) pour
#                                   les phrases d'un vendeur) ; true si payé
#   magasin_panier_vide?         -> true si le panier est vide (pour bloquer la sortie du magasin par exemple)
#   magasin_vider_panier         -> repose tout (vide le panier)
#   magasin_total                -> total du panier (en argent ; magasin_total(:jetons) pour une autre monnaie)
#   magasin_reassort(:id)        -> remet le stock du magasin au complet
class Interpreter
  def magasin(id)
    shop = Magasins.shop(id)
    unless shop
      log_error("Magasins : magasin « #{id} » introuvable") if respond_to?(:log_error, true)
      return false
    end
    klass = Magasins.fetch(shop, :kind).to_s == 'shelf' ? GamePlay::Etalage : GamePlay::Magasin
    $scene.call_scene(klass, id)
    @wait_count = 2
    return true
  end
  alias etalage magasin

  def magasin_caisse(seller_id = nil)
    seller = Magasins.seller(seller_id)
    lines = Magasins.basket_lines
    if lines.empty?
      message(Magasins.t('Ton panier est vide.', 'Your basket is empty.'))
      return false
    end
    shown = lines.first(4).map { |_s, e, qty| "#{Magasins.entry_name(e)} x#{qty}" }
    shown << '...' if lines.size > 4
    totals = Magasins.basket_totals.map { |cur, total| Magasins.amount_text(Magasins.currency(cur), total) }.join(' + ')
    question = Magasins.t("#{shown.join(', ')}.\nÇa fera #{totals}. Tu payes ?", "#{shown.join(', ')}.\nThat will be #{totals}. Will you pay?")
    return false unless yes_no_choice(question)

    case Magasins.checkout
    when :no_money
      message(Magasins.line(seller, :no_money))
      return false
    when :ok
      begin
        $game_system.se_play($data_system.shop_se)
      rescue StandardError
        nil
      end
      text = Magasins.line(seller, :thanks)
      bonus = Magasins.last_bonus
      text += " #{Magasins.line(seller, :bonus, bonus: Magasins.bonus_text(bonus))}" unless bonus.empty?
      message(text)
      return true
    end
    return false
  end

  def magasin_panier_vide?
    return Magasins.basket_lines.empty?
  end

  def magasin_vider_panier
    Magasins.clear_basket
    return true
  end

  def magasin_total(currency = :money)
    return Magasins.basket_totals[currency.to_s].to_i
  end

  def magasin_reassort(id)
    Magasins.save_data[:stock].delete(id.to_s)
    return true
  end
end
