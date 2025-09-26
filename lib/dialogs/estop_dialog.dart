import 'package:flutter/material.dart';

class EstopDialog extends StatelessWidget {
  final VoidCallback onRestart;

  const EstopDialog({super.key, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(75),
        width: 950,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'EMERGENCY STOP ACTIVATED',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            Padding(
              padding: EdgeInsetsGeometry.fromLTRB(0, 60, 0, 100),
              child: const Text(
                'The park\'s emergency shutoff was activated. This has disabled all active water features. '
                    'Please use the Restart Waterpark button below to disable to emergency shutoff and restart the features that were previously on.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AlertDialog(
                    title: const Text(
                      'Restart Waterpark?',
                      textAlign: TextAlign.center,
                    ),
                    titleTextStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 45,
                    ),
                    titlePadding: EdgeInsetsGeometry.fromLTRB(100, 75, 100, 25),
                    content: const Text(
                      'Are you sure you want to restart the water features?\nThis will turn everything that was on before back on.',
                      textAlign: TextAlign.center,
                    ),
                    contentPadding: EdgeInsetsGeometry.fromLTRB(
                      100,
                      50,
                      100,
                      75,
                    ),
                    contentTextStyle: TextStyle(
                      fontSize: 24,
                      color: Colors.black,
                    ),
                    actionsAlignment: MainAxisAlignment.center,
                    actions: [
                      Row(
                        spacing: 75,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(60, 15, 60, 15),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 28,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(50, 15, 50, 15),
                              child: Text(
                                'Confirm',
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
                  ),
                );
                if (ok == true) onRestart();
              },
              child: Padding(
                padding: EdgeInsetsGeometry.fromLTRB(75, 20, 75, 20),
                child: Text(
                  'Restart Waterpark',
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
      ),
    );
  }
}