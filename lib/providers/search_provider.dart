import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';  // Import Dio service

// Model đơn giản cho kết quả PDF (sau mở rộng)
class PdfResult {
  final String id;
  final String filename;
  final String url;  // URL PDF từ server

  PdfResult({required this.id, required this.filename, required this.url});

  // Mock factory để test
  static List<PdfResult> mockResults(String query) {
    return [
      PdfResult(id: '1', filename: 'Bản vẽ nhà ở - $query.pdf', url: 'https://example.com/pdf1.pdf'),
      PdfResult(id: '2', filename: 'Bản vẽ nội thất - $query.pdf', url: 'https://example.com/pdf2.pdf'),
      PdfResult(id: '3', filename: 'Bản vẽ kỹ thuật - $query.pdf', url: 'https://example.com/pdf3.pdf'),
    ];
  }
}

// State class
class SearchState {
  final bool isLoading;
  final List<PdfResult> results;
  final String? error;

  const SearchState({this.isLoading = false, this.results = const [], this.error});

  SearchState copyWith({bool? isLoading, List<PdfResult>? results, String? error}) {
    return SearchState(
      isLoading: isLoading ?? this.isLoading,
      results: results ?? this.results,
      error: error ?? this.error,
    );
  }
}

// Notifier
class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() {
    return const SearchState();
  }

  Future<void> performSearch(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(results: [], error: null);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final apiService = ApiService();
      final jsonData = await apiService.searchPdfs(query);  // Gọi Dio đến Heroku /search

      // Parse JSON từ Heroku thành List<PdfResult>
      final List<PdfResult> parsedResults = jsonData.map<PdfResult>((json) {
        return PdfResult(
          id: json['id'].toString(),
          filename: json['filename'],  // Tên file thật từ backend
          url: json['url'],  // Signed URL từ GCS (load PDF thật)
        );
      }).toList();

      state = state.copyWith(isLoading: false, results: parsedResults);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// Provider
final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  () => SearchNotifier(),
);