import 'package:flutter/material.dart';

/// Dialog for entering the payer's UPI ID.
class UpiInputDialog extends StatefulWidget {
  final String currentUpiId;

  const UpiInputDialog({super.key, this.currentUpiId = ''});

  @override
  State<UpiInputDialog> createState() => _UpiInputDialogState();
}

class _UpiInputDialogState extends State<UpiInputDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentUpiId);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _ctrl.text.trim();
    if (value.isEmpty || !value.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid UPI ID (e.g. name@upi)')),
      );
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your UPI ID'),
      content: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(
          labelText: 'UPI ID',
          hintText: 'yourname@paytm',
        ),
        keyboardType: TextInputType.emailAddress,
        autofocus: true,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
