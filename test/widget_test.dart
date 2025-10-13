import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_search_app/main.dart';  // Import app chính
import 'package:pdf_search_app/providers/search_provider.dart';  // Import provider

// Mock SearchNotifier cho test (không gọi network thật)
class MockSearchNotifier extends SearchNotifier {
  @override
  Future<void> performSearch(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(results: [], error: null);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    // Mock delay
    await Future.delayed(const Duration(milliseconds: 100));

    // Mock data instead of calling real API
    final mockResults = [
      PdfResult(id: '1', filename: 'Mock PDF 1 - $query.pdf', url: 'https://example.com/mock1.pdf'),
      PdfResult(id: '2', filename: 'Mock PDF 2 - $query.pdf', url: 'https://example.com/mock2.pdf'),
    ];

    state = state.copyWith(isLoading: false, results: mockResults);
  }
}

void main() {
  // Test UI cơ bản (không cần provider)
  testWidgets('UI loads with search elements', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MyApp()),
    );

    // Kiểm tra các widget tồn tại
    expect(find.text('PDF Search App'), findsOneWidget);  // AppBar title
    expect(find.byType(TextField), findsOneWidget);  // Ô search
    expect(find.text('Tìm Kiếm'), findsOneWidget);  // Button
    expect(find.text('Chưa có kết quả. Hãy tìm kiếm!'), findsOneWidget);  // Empty list
  });

  // Test search state (với mock API)
  testWidgets('Search triggers loading and shows results', (WidgetTester tester) async {
    // Mock provider với MockSearchNotifier
    final container = ProviderScope(
      overrides: [
        searchProvider.overrideWith(() => MockSearchNotifier()),
      ],
      child: const MyApp(),
    );

    await tester.pumpWidget(container);

    // Nhập query và tap button
    await tester.enterText(find.byType(TextField), 'test');
    await tester.tap(find.text('Tìm Kiếm'));
    await tester.pump();  // Trigger build đầu

    // Kiểm tra loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Simulate async (Mock call with shorter delay)
    await tester.pump(const Duration(milliseconds: 200));

    // Kiểm tra results (ít nhất 2 items)
    expect(find.textContaining('Mock PDF'), findsNWidgets(2));
    expect(find.byType(ListTile), findsNWidgets(2));  // List items
    expect(find.byType(CircularProgressIndicator), findsNothing);  // Không loading nữa

    // Kiểm tra error không hiện
    expect(find.textContaining('Lỗi'), findsNothing);
  });

  // Test empty query
  testWidgets('Empty query clears results', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MyApp()),
    );

    // Search empty
    await tester.tap(find.text('Tìm Kiếm'));
    await tester.pump();

    // Vẫn empty
    expect(find.text('Chưa có kết quả. Hãy tìm kiếm!'), findsOneWidget);
  });
}