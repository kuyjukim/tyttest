import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paper/paper.dart';

import '../../domain/money.dart';

/// A text field that reads an amount.
///
/// Validation happens on every keystroke and the error only shows once the
/// field has content, so a user typing `12.` is not told off mid-number.
class MoneyField extends StatelessWidget {
  const MoneyField({
    required this.controller,
    required this.currency,
    required this.label,
    required this.errorText,
    this.autofocus = false,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final Currency currency;
  final String label;

  /// Shown when the text is neither empty nor a valid amount.
  final String errorText;

  final bool autofocus;
  final ValueChanged<Money>? onSubmitted;

  /// The current value, or null when the field does not hold an amount.
  static Money? valueOf(TextEditingController controller, Currency currency) =>
      Money.tryParse(controller.text, currency);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final parsed = Money.tryParse(value.text, currency);
        final showError = value.text.trim().isNotEmpty && parsed == null;
        return TextField(
          controller: controller,
          autofocus: autofocus,
          // No decimal key for a currency without decimals, so the keyboard
          // does not invite an amount that cannot exist.
          keyboardType: currency.digits == 0
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            // The decimal point is allowed through even for won. Stripping it
            // silently turned a pasted `1500.50` into `150050` - a tenfold
            // error with no warning. Letting it through means the validation
            // below rejects it visibly, which is the only safe direction for
            // a field that holds money.
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,\s-]')),
          ],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            final amount = Money.tryParse(value.text, currency);
            if (amount != null) onSubmitted?.call(amount);
          },
          decoration: InputDecoration(
            labelText: label,
            prefixText: '${currency.symbol} ',
            errorText: showError ? errorText : null,
          ),
        );
      },
    );
  }
}

/// A row of money: a label on the left, an amount on the right.
class MoneyRow extends StatelessWidget {
  const MoneyRow({
    required this.label,
    required this.amount,
    this.tone,
    this.strong = false,
    super.key,
  });

  final String label;
  final String amount;
  final Color? tone;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: strong ? context.type.bodyStrong : context.type.body,
            ),
          ),
          Text(
            amount,
            style: context.type.numeric.copyWith(
              color: tone,
              fontWeight: strong ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}
