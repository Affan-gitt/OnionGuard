import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/simulation_service.dart';

class DeveloperPinDialog extends ConsumerStatefulWidget {
  const DeveloperPinDialog({super.key});

  @override
  ConsumerState<DeveloperPinDialog> createState() => _DeveloperPinDialogState();
}

class _DeveloperPinDialogState extends ConsumerState<DeveloperPinDialog> {
  final _pinController = TextEditingController();
  bool _isUnlocked = false;
  String _errorText = '';

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _verifyPin() {
    final settings = ref.read(settingsNotifierProvider);
    if (_pinController.text.trim() == settings.developerPin) {
      setState(() {
        _isUnlocked = true;
        _errorText = '';
      });
    } else {
      setState(() {
        _errorText = 'Invalid Developer PIN. Default is 1234.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final simService = ref.watch(simulationServiceProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryForest.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.developer_mode, color: AppConstants.primaryForest),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Developer Simulation',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Demonstration & Scenario Testing Engine',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              if (!_isUnlocked) ...[
                const Text(
                  'Enter 4-digit Developer PIN to access environmental simulation controls:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Developer PIN',
                    hintText: 'Enter 1234',
                    errorText: _errorText.isNotEmpty ? _errorText : null,
                  ),
                  onSubmitted: (_) => _verifyPin(),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _verifyPin,
                  child: const Text('Unlock Simulation Mode'),
                ),
              ] else ...[
                // Mode selector
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: simService.isActive
                        ? AppConstants.statusAmber.withOpacity(0.12)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: simService.isActive
                          ? AppConstants.statusAmber
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        simService.isActive ? Icons.science : Icons.sensors,
                        color: simService.isActive
                            ? AppConstants.statusAmber
                            : AppConstants.primaryForest,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          simService.isActive
                              ? 'SIMULATION MODE ACTIVE'
                              : 'LIVE HARDWARE MODE ACTIVE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: simService.isActive
                                ? AppConstants.statusAmber
                                : AppConstants.primaryForest,
                          ),
                        ),
                      ),
                      Switch(
                        value: simService.isActive,
                        activeColor: AppConstants.statusAmber,
                        onChanged: (val) {
                          setState(() {
                            if (val) {
                              simService.startSimulation();
                            } else {
                              simService.stopSimulation();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (simService.isActive) ...[
                  // Scenario dropdown
                  const Text(
                    'Select Simulation Scenario:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<SimulationScenario>(
                    value: simService.currentScenario,
                    isExpanded: true,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: SimulationScenario.values.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(s.displayName, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          simService.setScenario(val);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    simService.currentScenario.description,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 14),

                  // Speed multiplier
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Simulation Speed:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('${simService.speedMultiplier}x', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: simService.speedMultiplier,
                    min: 1.0,
                    max: 10.0,
                    divisions: 9,
                    label: '${simService.speedMultiplier}x',
                    activeColor: AppConstants.primaryForest,
                    onChanged: (val) {
                      setState(() {
                        simService.setSpeedMultiplier(val);
                      });
                    },
                  ),

                  // Manual sliders
                  const Divider(height: 16),
                  const Text('Manual Environmental Sliders:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),

                  // Temp Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Temperature', style: TextStyle(fontSize: 11)),
                      Text('${simService.simTemp.toStringAsFixed(1)} °C', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: simService.simTemp.clamp(14.0, 36.0),
                    min: 14.0,
                    max: 36.0,
                    activeColor: AppConstants.primaryForest,
                    onChanged: (val) {
                      setState(() {
                        simService.setManualTemp(val);
                      });
                    },
                  ),

                  // Humidity Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Humidity', style: TextStyle(fontSize: 11)),
                      Text('${simService.simHumidity.toStringAsFixed(1)} %', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: simService.simHumidity.clamp(35.0, 90.0),
                    min: 35.0,
                    max: 90.0,
                    activeColor: Colors.blue,
                    onChanged: (val) {
                      setState(() {
                        simService.setManualHumidity(val);
                      });
                    },
                  ),

                  // Gas ADC Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('MQ-3 Gas ADC (Proxy)', style: TextStyle(fontSize: 11)),
                      Text('${simService.simGasAdc} ADC', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: simService.simGasAdc.toDouble().clamp(500.0, 2500.0),
                    min: 500.0,
                    max: 2500.0,
                    activeColor: Colors.purple,
                    onChanged: (val) {
                      setState(() {
                        simService.setManualGasAdc(val.round());
                      });
                    },
                  ),

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(simService.isPaused ? Icons.play_arrow : Icons.pause, size: 16),
                          label: Text(simService.isPaused ? 'Resume' : 'Pause'),
                          onPressed: () {
                            setState(() {
                              if (simService.isPaused) {
                                simService.resumeSimulation();
                              } else {
                                simService.pauseSimulation();
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppConstants.statusRed),
                          icon: const Icon(Icons.stop, size: 16),
                          label: const Text('Stop Simulation'),
                          onPressed: () {
                            setState(() {
                              simService.stopSimulation();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
