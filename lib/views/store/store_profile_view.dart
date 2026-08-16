import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class StoreProfileView extends StatefulWidget {
  const StoreProfileView({Key? key}) : super(key: key);

  @override
  State<StoreProfileView> createState() => _StoreProfileViewState();
}

class _StoreProfileViewState extends State<StoreProfileView> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingLogo = false;

  final _storeNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _gstController = TextEditingController();

  String _logoUrl = '';
  File? _pickedLogoFile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _pincodeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get(ApiConfig.storeProfile);
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        _storeNameController.text = data['storeName'] ?? '';
        _ownerNameController.text = data['ownerName'] ?? '';
        _addressController.text = data['address'] ?? '';
        _cityController.text = data['city'] ?? '';
        _districtController.text = data['district'] ?? '';
        _pincodeController.text = data['pincode'] ?? '';
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _gstController.text = data['gstNumber'] ?? '';
        _logoUrl = data['logoUrl'] ?? '';
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _pickLogo(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
      if (image != null) {
        setState(() {
          _pickedLogoFile = File(image.path);
          _isUploadingLogo = true;
        });

        final url = await ApiService.uploadImage(image.path);
        if (url != null) {
          setState(() {
            _logoUrl = url;
            _isUploadingLogo = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isUploadingLogo = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logo upload failed: ${e.toString().replaceAll("Exception: ", "")}')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_storeNameController.text.trim().isEmpty || _ownerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Store Name and Owner Name are required.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final res = await ApiService.post(ApiConfig.storeProfile, {
        'storeName': _storeNameController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'district': _districtController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gstNumber': _gstController.text.trim(),
        'existingLogoUrl': _logoUrl,
      });

      if (res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store Profile saved successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Provider.of<AppProvider>(context, listen: false).setNavIndex(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }

    final isMobile = MediaQuery.of(context).size.width < 700;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 750),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Store & Business Profile',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              const Text(
                'This information appears on generated invoice PDFs',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 24),
              // Logo Picker Row
              Center(
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.photo_library, color: Color(0xFF2563EB)),
                              title: const Text('Choose Store Logo from Gallery'),
                              onTap: () {
                                Navigator.pop(context);
                                _pickLogo(ImageSource.gallery);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.camera_alt, color: Color(0xFF2563EB)),
                              title: const Text('Take a Photo of Logo'),
                              onTap: () {
                                Navigator.pop(context);
                                _pickLogo(ImageSource.camera);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                          image: _pickedLogoFile != null
                              ? DecorationImage(image: FileImage(_pickedLogoFile!), fit: BoxFit.cover)
                              : (_logoUrl.isNotEmpty
                                  ? DecorationImage(image: NetworkImage(_logoUrl), fit: BoxFit.cover)
                                  : null),
                        ),
                        child: _isUploadingLogo
                            ? const CircularProgressIndicator(color: Color(0xFF2563EB))
                            : (_pickedLogoFile == null && _logoUrl.isEmpty
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.store, color: Color(0xFF2563EB), size: 36),
                                      SizedBox(height: 4),
                                      Text('Store Logo', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                    ],
                                  )
                                : null),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF2563EB),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildResponsiveRow(
                isMobile,
                _buildTextField('Store Name *', _storeNameController, Icons.store),
                _buildTextField('Owner Name *', _ownerNameController, Icons.person),
              ),
              const SizedBox(height: 14),
              _buildResponsiveRow(
                isMobile,
                _buildTextField('GSTIN Number', _gstController, Icons.assignment_outlined),
                _buildTextField('Phone Number', _phoneController, Icons.phone),
              ),
              const SizedBox(height: 14),
              _buildTextField('Email Address', _emailController, Icons.email),
              const SizedBox(height: 14),
              _buildTextField('Address', _addressController, Icons.location_on, maxLines: 2),
              const SizedBox(height: 14),
              if (isMobile) ...[
                _buildTextField('City', _cityController, Icons.location_city),
                const SizedBox(height: 14),
                _buildTextField('District', _districtController, Icons.map),
                const SizedBox(height: 14),
                _buildTextField('Pincode', _pincodeController, Icons.pin_drop),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: _buildTextField('City', _cityController, Icons.location_city)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildTextField('District', _districtController, Icons.map)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildTextField('Pincode', _pincodeController, Icons.pin_drop)),
                  ],
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (_isSaving || _isUploadingLogo) ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Store Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveRow(bool isMobile, Widget child1, Widget child2) {
    if (isMobile) {
      return Column(
        children: [
          child1,
          const SizedBox(height: 14),
          child2,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: child1),
        const SizedBox(width: 14),
        Expanded(child: child2),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2563EB)),
      ),
    );
  }
}
