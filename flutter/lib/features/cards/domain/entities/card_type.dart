/// Card network, stored as [wireValue] in `wallet_cards.type`.
enum CardType {
  visa('visa'),
  mastercard('mastercard'),
  diners('diners'),
  discover('discover'),
  amex('amex'),
  other('other');

  const CardType(this.wireValue);

  final String wireValue;

  static CardType? fromWire(String? value) {
    for (final t in values) {
      if (t.wireValue == value) return t;
    }
    return null;
  }
}
