import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Search App',
      theme: ThemeData(
        primarySwatch: Colors.blue,  // Màu xanh cơ bản
      ),
      home: const SearchScreen(),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();  // Controller cho TextField
  List<String> _searchResults = [];  // Danh sách kết quả tạm (sau dùng model thật)

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {  // Hàm gọi khi nhấn button (sau connect API)
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    // Tạm mock data: Giả lập kết quả search
    setState(() {
      _searchResults = [
        'PDF 1: Bản vẽ nhà ở - $query',
        'PDF 2: Bản vẽ nội thất - $query',
        'PDF 3: Bản vẽ kỹ thuật - $query',
      ];
    });
    // Sau này: Gọi Dio API ở đây
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('PDF Search App'),  // Tiêu đề
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),  // Margin xung quanh
        child: Column(
          children: [
            // Ô tìm kiếm
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Nhập từ khóa tìm bản vẽ...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (value) => _performSearch(),  // Tự search khi enter
            ),
            const SizedBox(height: 16),  // Khoảng cách
            // Nút tìm kiếm
            ElevatedButton(
              onPressed: _performSearch,
              child: const Text('Tìm Kiếm'),
            ),
            const SizedBox(height: 16),
            // Danh sách kết quả
            Expanded(  // Chiếm hết không gian còn lại
              child: _searchResults.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có kết quả. Hãy tìm kiếm!',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: const Icon(Icons.picture_as_pdf),  // Icon PDF
                          title: Text(result),
                          onTap: () {
                            // Sau này: Mở PDF viewer ở đây
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Mở PDF: $result')),
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