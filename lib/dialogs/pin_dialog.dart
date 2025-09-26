import 'package:flutter/material.dart';

import '../services/settings_service.dart';

class PinDialog extends StatefulWidget {
  final Settings settings;

  const PinDialog({super.key, required this.settings});

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final enterCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  String? err;
  bool _pinObscured = true;
  bool _newPinObscured = false;

  @override
  Widget build(BuildContext context) {
    final mustChange = widget.settings.pinMustChange;
    return AlertDialog(
      title: Text(
        mustChange ? 'Configure Settings Pin' : 'Settings Login',
        textAlign: TextAlign.center,
      ),
      titleTextStyle: const TextStyle(
        fontSize: 45,
        color: Colors.black,
        fontWeight: FontWeight.bold,
      ),
      titlePadding: const EdgeInsets.fromLTRB(100, 75, 100, 25),
      contentPadding: const EdgeInsets.fromLTRB(100, 100, 100, 100),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 25,
        children: [
          if (!mustChange)
            TextField(
              controller: enterCtrl,
              obscureText: _pinObscured,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'PIN CODE',
                labelStyle: const TextStyle(fontSize: 24),
                suffixIcon: IconButton(
                  icon: Icon(
                    _pinObscured ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _pinObscured = !_pinObscured),
                ),
              ),
            ),
          if (mustChange)
            TextField(
              controller: newCtrl,
              obscureText: _newPinObscured,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'New PIN',
                labelStyle: const TextStyle(fontSize: 24),
                suffixIcon: IconButton(
                  icon: Icon(
                    _newPinObscured ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _newPinObscured = !_newPinObscured),
                ),
              ),
            ),
          if (err != null)
            Text(
              err!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
      actions: [
        Row(
          spacing: 50,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(60, 15, 60, 15),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: 28, color: Colors.red),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (mustChange) {
                  final newPin = newCtrl.text.trim();
                  if (newPin.length < 4) {
                    setState(() => err = 'Use 4+ digits');
                    return;
                  }
                  // Persist PIN immediately and clear the must-change flag
                  // (assumes you added SettingsStore.setPin in settings_service.dart)
                  await SettingsStore.setPin(newPin);
                  await SettingsStore.setPinMustChange(false);

                  // Optional: keep the full object in sync too (harmless duplicate write if desired)
                  // final s = widget.settings.copyWith(pin: newPin, pinMustChange: false);
                  // await SettingsStore.save(s);

                  if (context.mounted) Navigator.pop(context, true);
                } else {
                  if (enterCtrl.text.trim() == widget.settings.pin) {
                    if (context.mounted) Navigator.pop(context, true);
                  } else {
                    setState(() => err = 'Incorrect PIN');
                  }
                }
              },
              child: mustChange
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(50, 15, 50, 15),
                      child: Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 28,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const Padding(
                      padding: EdgeInsets.fromLTRB(65, 15, 65, 15),
                      child: Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 28,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ],
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(75, 0, 75, 50),
    );
  }
}
