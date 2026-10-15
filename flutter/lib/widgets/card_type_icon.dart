import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../features/cards/domain/entities/card_type.dart';

String cardTypeLabel(CardType type, AppLocalizations l10n) => switch (type) {
  CardType.visa => 'Visa',
  CardType.mastercard => 'Mastercard',
  CardType.diners => 'Diners Club',
  CardType.discover => 'Discover',
  CardType.amex => 'American Express',
  CardType.other => l10n.cardTypeOther,
};

/// Brand logo for [type]; a generic card when [type] is [CardType.other] or unset.
class CardTypeIcon extends StatelessWidget {
  const CardTypeIcon({super.key, required this.type, this.size = 24});

  final CardType? type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      CardType.visa => FontAwesomeIcons.ccVisa,
      CardType.mastercard => FontAwesomeIcons.ccMastercard,
      CardType.diners => FontAwesomeIcons.ccDinersClub,
      CardType.discover => FontAwesomeIcons.ccDiscover,
      CardType.amex => FontAwesomeIcons.ccAmex,
      CardType.other || null => FontAwesomeIcons.creditCard,
    };
    return SizedBox(
      width: size * 1.25,
      child: Center(child: FaIcon(icon, size: size)),
    );
  }
}
