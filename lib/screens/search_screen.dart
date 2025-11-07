import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';
import '../widgets/pdf_thumbnail.dart';
import 'pdf_viewer_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text;
    ref.read(searchProvider.notifier).performSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFC00000),
        title: const Text(
          'TLC DRAWINGS SEARCH APP',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Nhập từ khóa tìm bản vẽ...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (value) => _performSearch(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _performSearch,
              child: const Text('Tìm Kiếm'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: searchState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : searchState.error != null
                      ? Center(child: Text('Lỗi: ${searchState.error}'))
                      : searchState.results.isEmpty
                          ? const Center(
                              child: Text(
                                'Chưa có kết quả. Hãy tìm kiếm!',
                                style: TextStyle(fontSize: 16),
                              ),
                            )
                          : ListView.builder(
                              itemCount: searchState.results.length,
                              itemBuilder: (context, index) {
                                final result = searchState.results[index];
                                return ListTile(
                                  leading: PdfThumbnail(pdfUrl: result.url),
                                  title: Text(result.filename),
                                  onTap: () {
                                    if (result.url.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('URL PDF không hợp lệ!')),
                                      );
                                      return;
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PdfViewerScreen(
                                          pdfUrl: result.url,
                                          filename: result.filename,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}