import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  bool _showEditor = false;

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
      final XFile? image =
          await picker.pickImage(source: source, imageQuality: 80);
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
          SnackBar(
              content: Text(
                  'Logo upload failed: ${e.toString().replaceAll("Exception: ", "")}')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_storeNameController.text.trim().isEmpty ||
        _ownerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Store Name and Owner Name are required.'),
          backgroundColor: Color(0xFFE75C5C),
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
            backgroundColor: Color(0xFF12A594),
          ),
        );
        setState(() => _showEditor = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: const Color(0xFFE75C5C),
          ),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF365FF4)));
    }

    final isMobile = MediaQuery.of(context).size.width < 700;
    if (!_showEditor) return _buildBusinessPage(isMobile);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 750),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6E8EF)),
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
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172033),
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              const Text(
                'This information appears on generated invoice PDFs',
                style: TextStyle(color: Color(0xFF6C7486), fontSize: 13),
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
                              leading: const Icon(Icons.photo_library,
                                  color: Color(0xFF365FF4)),
                              title:
                                  const Text('Choose Store Logo from Gallery'),
                              onTap: () {
                                Navigator.pop(context);
                                _pickLogo(ImageSource.gallery);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.camera_alt,
                                  color: Color(0xFF365FF4)),
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
                          color: const Color(0xFFF6F7FB),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFD2D6E0), width: 2),
                          image: _pickedLogoFile != null
                              ? DecorationImage(
                                  image: FileImage(_pickedLogoFile!),
                                  fit: BoxFit.cover)
                              : (_logoUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(_logoUrl),
                                      fit: BoxFit.cover)
                                  : null),
                        ),
                        child: _isUploadingLogo
                            ? const CircularProgressIndicator(
                                color: Color(0xFF365FF4))
                            : (_pickedLogoFile == null && _logoUrl.isEmpty
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.store,
                                          color: Color(0xFF365FF4), size: 36),
                                      SizedBox(height: 4),
                                      Text('Store Logo',
                                          style: TextStyle(
                                              color: Color(0xFF6C7486),
                                              fontSize: 11)),
                                    ],
                                  )
                                : null),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF365FF4),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildResponsiveRow(
                isMobile,
                _buildTextField(
                    'Store Name *', _storeNameController, Icons.store),
                _buildTextField(
                    'Owner Name *', _ownerNameController, Icons.person),
              ),
              const SizedBox(height: 14),
              _buildResponsiveRow(
                isMobile,
                _buildTextField(
                    'GSTIN Number', _gstController, Icons.assignment_outlined),
                _buildTextField('Phone Number', _phoneController, Icons.phone),
              ),
              const SizedBox(height: 14),
              _buildTextField('Email Address', _emailController, Icons.email),
              const SizedBox(height: 14),
              _buildTextField('Address', _addressController, Icons.location_on,
                  maxLines: 2),
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
                    Expanded(
                        child: _buildTextField(
                            'City', _cityController, Icons.location_city)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: _buildTextField(
                            'District', _districtController, Icons.map)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: _buildTextField(
                            'Pincode', _pincodeController, Icons.pin_drop)),
                  ],
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      (_isSaving || _isUploadingLogo) ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF365FF4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save Store Profile',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessPage(bool isMobile) {
    final location = [
      _addressController.text,
      _cityController.text,
      _districtController.text,
      _pincodeController.text
    ].where((part) => part.trim().isNotEmpty).join(', ');
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Business profile',
                        style: TextStyle(
                            color: Color(0xFF172033),
                            fontWeight: FontWeight.w800,
                            fontSize: 27)),
                    SizedBox(height: 4),
                    Text('The details your customers see on every invoice.',
                        style:
                            TextStyle(color: Color(0xFF6C7486), fontSize: 12))
                  ])),
              FilledButton.icon(
                  onPressed: () => setState(() => _showEditor = true),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit details'))
            ]),
            const SizedBox(height: 22),
            Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 24 : 36),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1D2B5C), Color(0xFF365FF4)]),
                    borderRadius: BorderRadius.circular(24)),
                child: Wrap(
                    spacing: 28,
                    runSpacing: 20,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              image: _pickedLogoFile != null
                                  ? DecorationImage(
                                      image: FileImage(_pickedLogoFile!),
                                      fit: BoxFit.cover)
                                  : (_logoUrl.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(_logoUrl),
                                          fit: BoxFit.cover)
                                      : null)),
                          child: _pickedLogoFile == null && _logoUrl.isEmpty
                              ? const Icon(Icons.storefront_rounded,
                                  color: Color(0xFF365FF4), size: 42)
                              : null),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                _storeNameController.text.isEmpty
                                    ? 'Your Business'
                                    : _storeNameController.text,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 30,
                                    letterSpacing: -1)),
                            const SizedBox(height: 7),
                            Text(
                                _ownerNameController.text.isEmpty
                                    ? 'Independent business'
                                    : 'Founded and managed by ${_ownerNameController.text}',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(.78),
                                    fontSize: 13)),
                            const SizedBox(height: 16),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.14),
                                    borderRadius: BorderRadius.circular(99)),
                                child: const Text('ABOUT OUR BUSINESS',
                                    style: TextStyle(
                                        color: Color(0xFF82E9DE),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1)))
                          ])
                    ])),
            const SizedBox(height: 18),
            Wrap(spacing: 14, runSpacing: 14, children: [
              _detailCard(Icons.location_on_outlined, 'Address',
                  location.isEmpty ? 'Add your business address' : location),
              _detailCard(
                  Icons.phone_outlined,
                  'Contact',
                  _phoneController.text.isEmpty
                      ? 'Add a contact number'
                      : _phoneController.text),
              _detailCard(
                  Icons.mail_outline_rounded,
                  'Email',
                  _emailController.text.isEmpty
                      ? 'Add an email address'
                      : _emailController.text),
              _detailCard(
                  Icons.verified_outlined,
                  'Tax registration',
                  _gstController.text.isEmpty
                      ? 'GSTIN not added'
                      : _gstController.text)
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _detailCard(IconData icon, String label, String value) => SizedBox(
      width: 220,
      child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE6E8EF)),
              borderRadius: BorderRadius.circular(18)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: const Color(0xFF365FF4), size: 21),
            const SizedBox(height: 16),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF6C7486),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 13,
                    fontWeight: FontWeight.w700))
          ])));

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

  Widget _buildTextField(
      String label, TextEditingController controller, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Color(0xFF172033)),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF365FF4)),
      ),
    );
  }
}
