import 'package:flutter/material.dart';
import 'package:mechanix_browser/features/browser/bloc/browser_bloc.dart';
import 'package:mechanix_browser/features/browser/data/models/browser_history.dart';

class BrowserSuggestionsPanel extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode focusNode;
  final BrowserBloc bloc;
  final BrowserState state;
  final VoidCallback onTapItem;

  const BrowserSuggestionsPanel({
    super.key,
    required this.textController,
    required this.focusNode,
    required this.bloc,
    required this.state,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161616).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 280),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: state.searchResults.length,
          separatorBuilder: (context, index) =>
              const Divider(color: Colors.white10, height: 1),
          itemBuilder: (context, index) {
            final item = state.searchResults[index];
            return ListTile(
              leading: _buildLeadingIcon(item),
              title: Text(
                item.title,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                item.url,
                style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              dense: true,
              visualDensity: VisualDensity.compact,
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.white38),
                onPressed: () {
                  bloc.add(
                    BrowserHistoryItemDeleted(item, textController.text),
                  );
                },
              ),
              onTap: () {
                final isUri = Uri.tryParse(item.url)?.isAbsolute;

                if (isUri!) {
                  textController.text = item.url;
                  bloc.add(BrowserUrlLoadRequested(item.url));
                } else {
                  textController.text = item.title;
                  bloc.add(BrowserUrlLoadRequested(item.title));
                }

                bloc.add(const BrowserSearchQueryChanged(''));
                onTapItem();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(BrowserHistory item) {
    return const Icon(Icons.history, color: Color(0xFF8E8E93), size: 20);
  }
}
