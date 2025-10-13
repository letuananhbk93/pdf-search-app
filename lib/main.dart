import 'package:flutter/material.dart';
import 'providers/search_provider.dart';  // Import file mới
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/pdf_viewer_screen.dart';  // Import screen mới

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(  // Wrap ở đây
      child: MaterialApp(
        title: 'PDF Search App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const SearchScreen(),
      ),
    );
  }
}

class SearchScreen extends ConsumerStatefulWidget {  // Thay StatefulWidget
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {  // Thay State
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text;
    ref.read(searchProvider.notifier).performSearch(query);  // Gọi notifier
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);  // Listen state

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('PDF Search App'),
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
                  ? const Center(child: CircularProgressIndicator())  // Loading spinner
                  : searchState.error != null
                      ? Center(child: Text('Lỗi: ${searchState.error}'))  // Error message
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
                                  leading: const Icon(Icons.picture_as_pdf),
                                  title: Text(result.filename),
                                  subtitle: Text(result.url),  // Hiển thị URL tạm
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