import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htmlviewer/services/html_service.dart';

class SearchBar extends StatelessWidget {
  const SearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<HtmlService>(context);
    final query = service.searchQuery;
    final results = service.searchResults;
    final current = service.currentSearchIndex;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search',
                hintText: 'Search in file...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => service.searchText(''),
                      )
                    : null,
              ),
              onChanged: service.searchText,
              controller: TextEditingController(text: query),
            ),
          ),
          if (results.isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              tooltip: 'Previous',
              onPressed: () => service.navigateSearchResults(false),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward),
              tooltip: 'Next',
              onPressed: () => service.navigateSearchResults(true),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('${current + 1}/${results.length}'),
            ),
          ],
        ],
      ),
    );
  }
}