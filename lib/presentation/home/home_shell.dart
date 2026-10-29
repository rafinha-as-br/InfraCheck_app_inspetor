import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/app_services.dart';
import '../inspections/inspections_page.dart';
import '../profile/profile_page.dart';
import '../sync/sync_page.dart';

/// Estrutura das telas de primeiro nível: barra inferior com três destinos
/// (Inspeções, Sincronização, Perfil). Telas de execução usam barra de ação própria.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    return Scaffold(
      body: IndexedStack(index: _index, children: const [InspectionsPage(), SyncPage(), ProfilePage()]),
      bottomNavigationBar: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final pending = repo.unsent.length;
          return Container(
            decoration: const BoxDecoration(
                color: IcColors.surface0,
                border: Border(top: BorderSide(color: IcColors.borderSubtle)),
                boxShadow: IcShadows.md),
            child: SafeArea(
              child: Row(children: [
                _NavButton(
                    icon: Icons.fact_check_outlined, label: 'Inspeções', selected: _index == 0, onTap: () => setState(() => _index = 0)),
                _NavButton(
                    icon: Icons.sync,
                    label: 'Sincronização',
                    selected: _index == 1,
                    badge: pending,
                    onTap: () => setState(() => _index = 1)),
                _NavButton(
                    icon: Icons.person_outline, label: 'Perfil', selected: _index == 2, onTap: () => setState(() => _index = 2)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, required this.selected, required this.onTap, this.badge = 0});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? IcColors.primary700 : IcColors.ink600;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 64,
          decoration: BoxDecoration(border: Border(top: BorderSide(color: selected ? IcColors.signal500 : Colors.transparent, width: 3))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              backgroundColor: IcColors.signal500,
              textColor: IcColors.ink900,
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
