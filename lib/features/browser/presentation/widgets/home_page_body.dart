import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_browser/core/utils/constants.dart';
import 'package:mechanix_browser/features/browser/bloc/browser_bloc.dart';
import 'package:mechanix_browser/features/browser/presentation/widgets/dashed_shortcut_button.dart';

class BrowserHomePageBody extends StatelessWidget {
  const BrowserHomePageBody({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BrowserBloc>();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(AppImages.logo, width: 42, height: 42),
              const SizedBox(width: 14),
              const Text(
                "Comet Browser",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DashedShortcutButton(
                onTap: () =>
                    bloc.add(const BrowserUrlLoadRequested("google.com")),
              ),
              // BrowserShortcutItem(
              //   label: "foss.org",
              //   letter: "F",
              //   color: const Color(0xFFF5CDA7),
              //   onTap: () =>
              //       bloc.add(const BrowserUrlLoadRequested("foss.org")),
              // ),
              // const SizedBox(width: 16),
              DashedShortcutButton(
                onTap: () =>
                    bloc.add(const BrowserUrlLoadRequested("github.com")),
                // label: "monkeytype",
                // letter: "M",
                // color: const Color(0xFF4A90E2),
                // onTap: () =>
                //     bloc.add(const BrowserUrlLoadRequested("monkeytype.com")),
              ),
              // const SizedBox(width: 16),
              DashedShortcutButton(
                onTap: () =>
                    bloc.add(const BrowserUrlLoadRequested("flutter.dev")),
                // label: "heavypaint.app",
                // letter: "H",
                // color: const Color(0xFF4CB071),
                // onTap: () =>
                //     bloc.add(const BrowserUrlLoadRequested("heavypaint.app")),
              ),
              // const SizedBox(width: 16),
              DashedShortcutButton(
                onTap: () =>
                    bloc.add(const BrowserUrlLoadRequested("youtube.com")),
                // label: "wikipedia.org",
                // letter: "W",
                // color: const Color(0xFFEBB816),
                // onTap: () =>
                //     bloc.add(const BrowserUrlLoadRequested("wikipedia.org")),
              ),
              // const SizedBox(width: 16),
              DashedShortcutButton(
                onTap: () =>
                    bloc.add(const BrowserUrlLoadRequested("reddit.com")),
                // label: "github.com",
                // letter: "G",
                // color: const Color(0xFFC8BFE7),
                // onTap: () =>
                //     bloc.add(const BrowserUrlLoadRequested("github.com")),
              ),
              // BrowserShortcutItem(
              //   label: "foss.org",
              //   letter: "F",
              //   color: const Color(0xFFF5CDA7),
              //   onTap: () =>
              //       bloc.add(const BrowserUrlLoadRequested("foss.org")),
              // ),
              // const SizedBox(width: 16),
              // BrowserShortcutItem(
              //   label: "monkeytype",
              //   letter: "M",
              //   color: const Color(0xFF4A90E2),
              //   onTap: () =>
              //       bloc.add(const BrowserUrlLoadRequested("monkeytype.com")),
              // ),
              // const SizedBox(width: 16),
              // BrowserShortcutItem(
              //   label: "heavypaint.app",
              //   letter: "H",
              //   color: const Color(0xFF4CB071),
              //   onTap: () =>
              //       bloc.add(const BrowserUrlLoadRequested("heavypaint.app")),
              // ),
              // const SizedBox(width: 16),
              // BrowserShortcutItem(
              //   label: "wikipedia.org",
              //   letter: "W",
              //   color: const Color(0xFFEBB816),
              //   onTap: () =>
              //       bloc.add(const BrowserUrlLoadRequested("wikipedia.org")),
              // ),
              // const SizedBox(width: 16),
              // BrowserShortcutItem(
              //   label: "github.com",
              //   letter: "G",
              //   color: const Color(0xFFC8BFE7),
              //   onTap: () =>
              //       bloc.add(const BrowserUrlLoadRequested("github.com")),
              // ),
            ],
          ),
        ],
      ),
    );
  }
}
