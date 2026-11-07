import 'package:flutter/material.dart';
import '../models/match.dart';

class MatchDetailScreen extends StatelessWidget {
  final Match match;

  const MatchDetailScreen({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${match.homeTeam} vs ${match.awayTeam}'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Fejléc
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(match.league, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 8),
                  Text(match.time, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(child: Text(match.homeTeam, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      const Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(match.awayTeam, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Szögletek
          const Text('Szögletek (utolsó 10 meccs)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _StatRow('Saját szöglet', match.homeCornersFor, match.awayCornersFor),
          _StatRow('Engedett szöglet', match.homeCornersAgainst, match.awayCornersAgainst),
          _StatRow('Összes szöglet átlag', match.homeCornersAvg, match.awayCornersAvg),

          const SizedBox(height: 24),

          // Trend
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(child: Text(match.mainTrend, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('${match.trendStrength}/10', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Forma
          const Text('Forma (utolsó 5)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _FormRow(match.homeTeam, match.formHome)),
              const SizedBox(width: 12),
              Expanded(child: _FormRow(match.awayTeam, match.formAway)),
            ],
          ),

          const SizedBox(height: 24),

          // H2H
          const Text('Egymás ellen (utolsó 6)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _H2HBox('${match.h2hHomeWins}', 'Hazai győzelem'),
              _H2HBox('${match.h2hDraws}', 'Döntetlen'),
              _H2HBox('${match.h2hAwayWins}', 'Vendég győzelem'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _StatRow(String label, double home, double away) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(home.toStringAsFixed(1), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
          SizedBox(width: 90, child: Text(away.toStringAsFixed(1), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  final String team;
  final List<String> form;
  const _FormRow(this.team, this.form);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(team, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: form.map((r) {
            Color color = r == 'W' ? Colors.green : (r == 'D' ? Colors.grey : Colors.red);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(child: Text(r, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _H2HBox extends StatelessWidget {
  final String value;
  final String label;
  const _H2HBox(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
