import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../widgets/ui_breakpoints.dart';

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

    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: Ui.pagePadding(context),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 750),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Store & Business Profile',
                style: TextStyle(
                    fontSize: Ui.headingSize(context),
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 3),
              Text(
                'This information appears on generated invoice PDFs',
                style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .6), fontSize: 12),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 18),
              _buildResponsiveRow(
                isMobile,
                _buildTextField(
                    'Store Name *', _storeNameController, Icons.store),
                _buildTextField(
                    'Owner Name *', _ownerNameController, Icons.person),
              ),
              const SizedBox(height: 10),
              _buildResponsiveRow(
                isMobile,
                _buildTextField(
                    'GSTIN Number', _gstController, Icons.assignment_outlined),
                _buildTextField('Phone Number', _phoneController, Icons.phone),
              ),
              const SizedBox(height: 10),
              _buildTextField('Email Address', _emailController, Icons.email),
              const SizedBox(height: 10),
              _buildTextField('Address', _addressController, Icons.location_on,
                  maxLines: 2),
              const SizedBox(height: 10),
              if (isMobile) ...[
                _buildTextField('City', _cityController, Icons.location_city),
                const SizedBox(height: 10),
                _buildTextField('District', _districtController, Icons.map),
                const SizedBox(height: 10),
                _buildTextField('Pincode', _pincodeController, Icons.pin_drop),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(
                            'City', _cityController, Icons.location_city)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildTextField(
                            'District', _districtController, Icons.map)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildTextField(
                            'Pincode', _pincodeController, Icons.pin_drop)),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  onPressed:
                      (_isSaving || _isUploadingLogo) ? null : _saveProfile,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save Store Profile',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800)),
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
      padding: Ui.pagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Business profile',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: Ui.headingSize(context),
                            letterSpacing: -1)),
                    const SizedBox(height: 3),
                    Text('The details your customers see on every invoice.',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: .62),
                            fontSize: 12))
                  ])),
              FilledButton.icon(
                  onPressed: () => setState(() => _showEditor = true),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Edit details'))
            ]),
            const SizedBox(height: 12),
            Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 14 : 18),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1D2B5C), Color(0xFF365FF4)]),
                    borderRadius: BorderRadius.circular(18)),
                child: Wrap(
                    spacing: 22,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                          width: 66,
                          height: 66,
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
                                  color: Color(0xFF365FF4), size: 34)
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
                                    fontSize: 20,
                                    letterSpacing: -.8)),
                            const SizedBox(height: 5),
                            Text(
                                _ownerNameController.text.isEmpty
                                    ? 'Independent business'
                                    : 'Founded and managed by ${_ownerNameController.text}',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(.78),
                                    fontSize: 12)),
                            const SizedBox(height: 12),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.14),
                                    borderRadius: BorderRadius.circular(99)),
                                child: const Text('ABOUT OUR BUSINESS',
                                    style: TextStyle(
                                        color: Color(0xFF82E9DE),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1)))
                          ])
                    ])),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [
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

  Widget _detailCard(IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
        width: 205,
        child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
                color: scheme.surface,
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(13)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: scheme.primary, size: 19),
              const SizedBox(height: 10),
              Text(label,
                  style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: .55),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700))
            ])));
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
