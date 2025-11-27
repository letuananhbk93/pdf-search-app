import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';
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
        iconTheme: const IconThemeData(color: Colors.white),
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
                                print('UI rendering - Filename: ${result.filename}, ThumbnailURL: ${result.thumbnailUrl}');
                                return GestureDetector(
                                  onTap: () async {
                                    if (result.url.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('URL PDF không hợp lệ!')),
                                      );
                                      return;
                                    }
                                    // Navigate immediately without waiting
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PdfViewerScreen(
                                          pdfUrl: result.url,
                                          filename: result.filename,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 50,
                                            height: 50,
                                            child: result.thumbnailUrl != null && result.thumbnailUrl!.isNotEmpty
                                                ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Image.network(
                                                      result.thumbnailUrl!,
                                                      width: 50,
                                                      height: 50,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) {
                                                        print('Error loading thumbnail: $error');
                                                        print('Thumbnail URL was: ${result.thumbnailUrl}');
                                                        return Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors.grey[200],
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: const Icon(
                                                            Icons.picture_as_pdf,
                                                            color: Colors.red,
                                                            size: 30,
                                                          ),
                                                        );
                                                      },
                                                      loadingBuilder: (context, child, loadingProgress) {
                                                        if (loadingProgress == null) {
                                                          print('Thumbnail loaded successfully: ${result.thumbnailUrl}');
                                                          return child;
                                                        }
                                                        return Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors.grey[200],
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: const Center(
                                                            child: SizedBox(
                                                              width: 20,
                                                              height: 20,
                                                              child: CircularProgressIndicator(strokeWidth: 2),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  )
                                                : Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[200],
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Icon(
                                                      Icons.picture_as_pdf,
                                                      color: Colors.red,
                                                      size: 30,
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              result.filename,
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          ),
                                          const Icon(Icons.arrow_forward_ios, size: 16),
                                        ],
                                      ),
                                    ),
                                  ),
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