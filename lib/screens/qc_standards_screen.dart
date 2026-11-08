import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

const _bordeaux = Color(0xFFC00000);
const _finalAccent = Color(0xFF1E6FD9);
const _carcassAccent = Color(0xFFE67E22);
const _columns = ['Nhóm', 'STT', 'Hạng mục', 'Tiêu chuẩn', 'Phương pháp', 'Ảnh'];

class QcStandardsScreen extends StatefulWidget {
  const QcStandardsScreen({super.key});

  @override
  State<QcStandardsScreen> createState() => _QcStandardsScreenState();
}

class _QcStandardsScreenState extends State<QcStandardsScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  int _suggestSeq = 0;
  int _loadSeq = 0;

  List<Map<String, dynamic>> _suggestions = [];
  String? _selectedName;
  List<String> _types = [];
  String? _selectedType;
  Map<String, dynamic>? _standards;
  int _tab = 0;
  bool _loadingSuggest = false;
  bool _loadingStandards = false;
  String? _error;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (query.isEmpty) {
      _suggestSeq++;
      setState(() {
        _suggestions = [];
        _loadingSuggest = false;
      });
      return;
    }
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 200), () => _suggest(query));
  }

  Future<void> _suggest(String query) async {
    final seq = ++_suggestSeq;
    setState(() => _loadingSuggest = true);
    try {
      final items = await _api.qcSuggest(query);
      if (!mounted || seq != _suggestSeq) return;
      setState(() {
        _suggestions = items;
        _loadingSuggest = false;
      });
    } catch (e) {
      if (!mounted || seq != _suggestSeq) return;
      setState(() {
        _loadingSuggest = false;
        _error = _message(e);
      });
    }
  }

  void _choose(Map<String, dynamic> item) {
    final name = item['name'].toString();
    final types = List<String>.from(item['types'] as List);
    _debounce?.cancel();
    _suggestSeq++;
    _focus.unfocus();
    _controller.removeListener(_onQueryChanged);
    _controller.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    _controller.addListener(_onQueryChanged);
    setState(() {
      _suggestions = [];
      _selectedName = name;
      _types = types;
      _resetStandards();
    });
    if (types.length == 1) _loadType(types.first);
  }

  void _resetStandards() {
    _loadSeq++;
    _selectedType = null;
    _standards = null;
    _loadingStandards = false;
    _error = null;
  }

  Future<void> _loadType(String type) async {
    final name = _selectedName;
    if (name == null) return;
    final seq = ++_loadSeq;
    setState(() {
      _selectedType = type;
      _loadingStandards = true;
      _error = null;
    });
    try {
      final data = await _api.qcStandards(name, type);
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _standards = data;
        _loadingStandards = false;
        _tab = 0;
      });
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _loadingStandards = false;
        _error = _message(e);
      });
    }
  }

  Future<void> _showImage(String ref) async {
    final trimmed = ref.trim();
    if (trimmed.isEmpty) {
      await _showImageDialog(null, trimmed);
      return;
    }
    try {
      final url = await _api.qcImageUrl(trimmed);
      if (!mounted) return;
      await _showImageDialog(url, trimmed);
    } catch (_) {
      if (!mounted) return;
      await _showImageDialog(null, trimmed);
    }
  }

  Future<void> _showImageDialog(String? url, String ref) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: url == null
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Text('No image available', style: TextStyle(color: Colors.grey)),
                        )
                      : InteractiveViewer(
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) => progress == null
                                ? child
                                : const Padding(
                                    padding: EdgeInsets.all(40),
                                    child: CircularProgressIndicator(),
                                  ),
                            errorBuilder: (context, error, stack) => const Padding(
                              padding: EdgeInsets.all(40),
                              child: Text('No image available', style: TextStyle(color: Colors.grey)),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Text(ref, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _upload({required String endpoint, required List<String> extensions, required bool isWorkbook}) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final result = await _api.uploadQcFile(endpoint, picked.files.single);
      if (!mounted) return;
      setState(() => _uploading = false);
      if (isWorkbook) {
        await _showWorkbookReport(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded ${result['uploaded']} images'), backgroundColor: Colors.green),
        );
      }
      if (_selectedName != null && _selectedType != null) _loadType(_selectedType!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = _message(e);
      });
    }
  }

  Future<void> _showWorkbookReport(Map<String, dynamic> result) {
    final products = result['products'] as Map<String, dynamic>;
    final standardRows = result['standard_rows'] as Map<String, dynamic>;
    final emptyGroups = List<String>.from(result['empty_group_rows'] as List);
    final missing = List<String>.from(result['missing_images'] as List);

    Widget section(String title, List<String> items) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title (${items.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (items.isEmpty)
              const Text('None', style: TextStyle(color: Colors.grey))
            else
              Text(items.join('\n'), style: const TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workbook loaded'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Products (final / carcass)'),
              const SizedBox(height: 4),
              Text('LACQUER: ${products['LACQUER']['final']} / ${products['LACQUER']['carcass']}'),
              Text('WOODEN: ${products['WOODEN']['final']} / ${products['WOODEN']['carcass']}'),
              const SizedBox(height: 8),
              Text('Standard rows: final ${standardRows['final']}, carcass ${standardRows['carcass']}'),
              section('Rows with blank Nhóm', emptyGroups),
              section('Missing images', missing),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  String _message(Object e) => e.toString().replaceAll('Exception: ', '');

  Color _accentFor(int tab) => tab == 0 ? _finalAccent : _carcassAccent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QC STANDARDS', style: TextStyle(color: Colors.white)),
        backgroundColor: _bordeaux,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.image_outlined, color: Colors.white),
            tooltip: 'Upload images (.zip)',
            onPressed: _uploading
                ? null
                : () => _upload(endpoint: 'qc/upload-images', extensions: ['zip'], isWorkbook: false),
          ),
          IconButton(
            icon: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file, color: Colors.white),
            tooltip: 'Upload QC workbook (.xlsx)',
            onPressed: _uploading
                ? null
                : () => _upload(endpoint: 'qc/upload-workbook', extensions: ['xlsx'], isWorkbook: true),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchField(),
            if (_suggestions.isNotEmpty) _buildSuggestions(),
            if (_types.length > 1) ...[
              const SizedBox(height: 12),
              _buildTypeButtons(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: 'Enter product name',
        hintText: 'Example: BELLES RIVES',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _loadingSuggest
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : (_controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _selectedName = null;
                        _types = [];
                        _resetStandards();
                      });
                    },
                  )),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _suggestions.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = _suggestions[index];
            return ListTile(
              dense: true,
              title: Text(item['name'].toString()),
              onTap: () => _choose(item),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTypeButtons() {
    return Wrap(
      spacing: 8,
      children: _types
          .map((type) => ChoiceChip(
                label: Text(type),
                selected: _selectedType == type,
                selectedColor: _bordeaux,
                labelStyle: TextStyle(
                  color: _selectedType == type ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => _loadType(type),
              ))
          .toList(),
    );
  }

  Widget _buildBody() {
    if (_loadingStandards) return const Center(child: CircularProgressIndicator());
    if (_standards == null) {
      return const Center(
        child: Text('Search for a product to view its QC standards.', style: TextStyle(color: Colors.grey)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabBar(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey('$_loadSeq-$_tab'),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _accentFor(_tab), width: 2),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                  color: Colors.white,
                ),
                child: _buildStage(_tab == 0 ? 'final' : 'carcass', _accentFor(_tab)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    Widget tab(int index, String title, String badge, Color accent) {
      final selected = _tab == index;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _tab = index),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? accent : Colors.white,
              border: Border.all(color: accent, width: 2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : accent,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? accent : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(0, 'FINAL INSPECTION (Hangmuc)', 'Hangmuc', _finalAccent),
        const SizedBox(width: 8),
        tab(1, 'CARCASS INSPECTION (HangmucCarcass)', 'HangmucCarcass', _carcassAccent),
      ],
    );
  }

  Widget _buildStage(String stage, Color accent) {
    final info = _standards![stage] as Map<String, dynamic>;
    final rows = List<Map<String, dynamic>>.from(info['rows'] as List);
    if (rows.isEmpty) {
      return const Center(child: Text('No standards', style: TextStyle(color: Colors.grey)));
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            columnSpacing: 12,
            horizontalMargin: 12,
            headingRowColor: WidgetStateProperty.all(accent),
            headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            dataRowMinHeight: 40,
            dataRowMaxHeight: double.infinity,
            dividerThickness: 1,
            border: TableBorder.all(color: accent),
            columns: _columns.map((c) => DataColumn(label: Text(c))).toList(),
            rows: rows.map((row) => _buildRow(row, accent)).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(Map<String, dynamic> row, Color accent) {
    String cell(String key) => (row[key] ?? '').toString();
    final image = cell('image');
    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) return accent.withValues(alpha: 0.12);
        return null;
      }),
      onSelectChanged: (_) => _showImage(image),
      cells: [
        DataCell(_textCell(cell('group'))),
        DataCell(_textCell(cell('stt'), width: 32)),
        DataCell(_textCell(cell('item'), width: 110)),
        DataCell(_textCell(cell('standard'), width: 213)),
        DataCell(_textCell(cell('method'), width: 220)),
        DataCell(Text(image.isEmpty ? '' : image, style: TextStyle(color: accent))),
      ],
    );
  }

  Widget _textCell(String value, {double? width}) {
    final text = Text(value);
    if (width == null) return text;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(value),
      ),
    );
  }
}
