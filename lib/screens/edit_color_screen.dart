import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'color_history_screen.dart';

class EditColorScreen extends StatefulWidget {
  final Map<String, dynamic> colorItem;
  final String tableName;

  const EditColorScreen({
    super.key,
    required this.colorItem,
    required this.tableName,
  });

  @override
  State<EditColorScreen> createState() => _EditColorScreenState();
}

class _EditColorScreenState extends State<EditColorScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  
  // Controllers for each field
  late TextEditingController _nameController;
  late TextEditingController _statusController;
  late TextEditingController _notesController;
  late TextEditingController _referenceController;
  late TextEditingController _refColorController;
  late TextEditingController _codeItemsController;
  late TextEditingController _dateSignedOffController;
  late TextEditingController _proController;
  late TextEditingController _poController;
  late TextEditingController _supplierController;
  late TextEditingController _orderNoController;
  late TextEditingController _collectionController;
  late TextEditingController _refToneCodeController;
  late TextEditingController _colorNameController;
  late TextEditingController _swatchNameController;
  late TextEditingController _processController;
  late TextEditingController _qtyController;
  late TextEditingController _approvedDayController;
  late TextEditingController _supInchartController;
  
  @override
  void initState() {
    super.initState();
    // Pre-populate with current values
    _nameController = TextEditingController(text: widget.colorItem['name'] ?? '');
    _statusController = TextEditingController(text: widget.colorItem['status'] ?? '');
    _notesController = TextEditingController(text: widget.colorItem['notes'] ?? '');
    _referenceController = TextEditingController(text: widget.colorItem['reference'] ?? '');
    _refColorController = TextEditingController(text: widget.colorItem['ref_color'] ?? '');
    _codeItemsController = TextEditingController(text: widget.colorItem['code_items'] ?? '');
    _dateSignedOffController = TextEditingController(text: widget.colorItem['date_signed_off'] ?? '');
    _proController = TextEditingController(text: widget.colorItem['pro'] ?? '');
    _poController = TextEditingController(text: widget.colorItem['po'] ?? '');
    _supplierController = TextEditingController(text: widget.colorItem['supplier'] ?? '');
    _orderNoController = TextEditingController(text: widget.colorItem['order_no'] ?? '');
    _collectionController = TextEditingController(text: widget.colorItem['collection'] ?? '');
    _refToneCodeController = TextEditingController(text: widget.colorItem['ref_tone_code'] ?? '');
    _colorNameController = TextEditingController(text: widget.colorItem['color_name'] ?? '');
    _swatchNameController = TextEditingController(text: widget.colorItem['swatch_name'] ?? '');
    _processController = TextEditingController(text: widget.colorItem['process'] ?? '');
    _qtyController = TextEditingController(text: widget.colorItem['qty']?.toString() ?? '');
    _approvedDayController = TextEditingController(text: widget.colorItem['approved_day'] ?? '');
    _supInchartController = TextEditingController(text: widget.colorItem['sup_inchart'] ?? '');
  }

  bool _isCustomColor() {
    return widget.colorItem['ref_color'] != null || 
           widget.colorItem['code_items'] != null || 
           widget.colorItem['date_signed_off'] != null ||
           widget.colorItem['pro'] != null ||
           widget.colorItem['po'] != null ||
           widget.tableName == 'custom_color';
  }

  bool _isSupplierTable() {
    return widget.tableName == 'thien_hong' || 
           widget.tableName == 'tam_viet' || 
           widget.tableName == 'dinh_thieu' || 
           widget.tableName == 'mai_home';
  }

  @override
  Widget build(BuildContext context) {
    String displayName = widget.tableName.replaceAll('_', ' ').toUpperCase();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit $displayName'),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Common fields
                  _buildTextField(
                    controller: _nameController,
                    label: 'Name',
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  
                  // Fields for supplier tables
                  if (_isSupplierTable()) ...[
                    _buildTextField(
                      controller: _refColorController,
                      label: 'Ref Color',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _orderNoController,
                      label: 'ORDER NO.',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _dateSignedOffController,
                      label: 'Date Signed Off',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _statusController,
                      label: 'Status',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _proController,
                      label: 'Pro',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _poController,
                      label: 'PO',
                    ),
                    const SizedBox(height: 16),
                  ] else if (_isCustomColor()) ...[
                    // Fields for custom_color table
                    _buildTextField(
                      controller: _refColorController,
                      label: 'Ref Color',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _codeItemsController,
                      label: 'Code Items',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _dateSignedOffController,
                      label: 'Date Signed Off',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _statusController,
                      label: 'Status',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _proController,
                      label: 'PRO',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _poController,
                      label: 'PO',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _supplierController,
                      label: 'Supplier',
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    // Fields for other tables (lacquer_fin, metal_fin, wood_fin, effect_color_swatch_statistics)
                    _buildTextField(
                      controller: _collectionController,
                      label: 'Collection',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _refToneCodeController,
                      label: 'Ref Tone Code',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _colorNameController,
                      label: 'Color Name',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _swatchNameController,
                      label: 'Swatch Name',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _statusController,
                      label: 'Status',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _processController,
                      label: 'Process',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _qtyController,
                      label: 'Qty',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _approvedDayController,
                      label: 'Approved Day',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _supInchartController,
                      label: 'Sup-inchart',
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Notes field (common for all)
                  _buildTextField(
                    controller: _notesController,
                    label: 'Notes',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  
                  // Save Button
                  ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // View History Button
                  OutlinedButton(
                    onPressed: _viewHistory,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('View Change History'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required ? (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      } : null,
    );
  }

  void _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Prepare updated data based on table type
      Map<String, dynamic> updatedData = {};
      
      // Common fields
      if (_nameController.text.trim().isNotEmpty) {
        updatedData['name'] = _nameController.text.trim();
      }
      if (_notesController.text.trim().isNotEmpty) {
        updatedData['notes'] = _notesController.text.trim();
      }
      
      // Table-specific fields
      if (_isSupplierTable()) {
        if (_refColorController.text.trim().isNotEmpty) {
          updatedData['ref_color'] = _refColorController.text.trim();
        }
        if (_orderNoController.text.trim().isNotEmpty) {
          updatedData['order_no'] = _orderNoController.text.trim();
        }
        if (_dateSignedOffController.text.trim().isNotEmpty) {
          updatedData['date_signed_off'] = _dateSignedOffController.text.trim();
        }
        if (_statusController.text.trim().isNotEmpty) {
          updatedData['status'] = _statusController.text.trim();
        }
        if (_proController.text.trim().isNotEmpty) {
          updatedData['pro'] = _proController.text.trim();
        }
        if (_poController.text.trim().isNotEmpty) {
          updatedData['po'] = _poController.text.trim();
        }
      } else if (_isCustomColor()) {
        if (_refColorController.text.trim().isNotEmpty) {
          updatedData['ref_color'] = _refColorController.text.trim();
        }
        if (_codeItemsController.text.trim().isNotEmpty) {
          updatedData['code_items'] = _codeItemsController.text.trim();
        }
        if (_dateSignedOffController.text.trim().isNotEmpty) {
          updatedData['date_signed_off'] = _dateSignedOffController.text.trim();
        }
        if (_statusController.text.trim().isNotEmpty) {
          updatedData['status'] = _statusController.text.trim();
        }
        if (_proController.text.trim().isNotEmpty) {
          updatedData['pro'] = _proController.text.trim();
        }
        if (_poController.text.trim().isNotEmpty) {
          updatedData['po'] = _poController.text.trim();
        }
        if (_supplierController.text.trim().isNotEmpty) {
          updatedData['supplier'] = _supplierController.text.trim();
        }
      } else {
        if (_collectionController.text.trim().isNotEmpty) {
          updatedData['collection'] = _collectionController.text.trim();
        }
        if (_refToneCodeController.text.trim().isNotEmpty) {
          updatedData['ref_tone_code'] = _refToneCodeController.text.trim();
        }
        if (_colorNameController.text.trim().isNotEmpty) {
          updatedData['color_name'] = _colorNameController.text.trim();
        }
        if (_swatchNameController.text.trim().isNotEmpty) {
          updatedData['swatch_name'] = _swatchNameController.text.trim();
        }
        if (_statusController.text.trim().isNotEmpty) {
          updatedData['status'] = _statusController.text.trim();
        }
        if (_processController.text.trim().isNotEmpty) {
          updatedData['process'] = _processController.text.trim();
        }
        if (_qtyController.text.trim().isNotEmpty) {
          updatedData['qty'] = int.tryParse(_qtyController.text.trim()) ?? 0;
        }
        if (_approvedDayController.text.trim().isNotEmpty) {
          updatedData['approved_day'] = _approvedDayController.text.trim();
        }
        if (_supInchartController.text.trim().isNotEmpty) {
          updatedData['sup_inchart'] = _supInchartController.text.trim();
        }
      }
      
      // Get user email from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      String userEmail = prefs.getString('user_email') ?? 'unknown@example.com';
      
      // Validate ID
      if (widget.colorItem['id'] == null) {
        throw Exception('Color ID is missing');
      }
      
      // Convert ID to int if it's a string
      int colorId;
      if (widget.colorItem['id'] is int) {
        colorId = widget.colorItem['id'];
      } else if (widget.colorItem['id'] is String) {
        colorId = int.parse(widget.colorItem['id']);
      } else {
        throw Exception('Invalid color ID type: ${widget.colorItem['id'].runtimeType}');
      }
      
      print('🔍 About to update:');
      print('   Table: ${widget.tableName}');
      print('   ID: $colorId');
      print('   User: $userEmail');
      print('   Data: $updatedData');
      
      // Make PUT request to backend
      await _apiService.updateColor(
        widget.tableName,
        colorId,
        updatedData,
        userEmail,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Changes saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate changes were made
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _viewHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ColorHistoryScreen(
          colorId: widget.colorItem['id'],
          tableName: widget.tableName,
          colorName: widget.colorItem['name'] ?? 'Unknown',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
    _notesController.dispose();
    _referenceController.dispose();
    _refColorController.dispose();
    _codeItemsController.dispose();
    _dateSignedOffController.dispose();
    _proController.dispose();
    _poController.dispose();
    _supplierController.dispose();
    _orderNoController.dispose();
    _collectionController.dispose();
    _refToneCodeController.dispose();
    _colorNameController.dispose();
    _swatchNameController.dispose();
    _processController.dispose();
    _qtyController.dispose();
    _approvedDayController.dispose();
    _supInchartController.dispose();
    super.dispose();
  }
}
