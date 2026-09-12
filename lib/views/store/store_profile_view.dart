import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../widgets/workspace_ui.dart';

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
    if (mounted) setState(() => _isLoading = false);
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
        if (url != null && mounted) {
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
          backgroundColor: Color(0xFFB42318),
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
            backgroundColor: Color(0xFF157347),
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
            backgroundColor: const Color(0xFFB42318),
          ),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return _showEditor ? _buildEditorPage() : _buildBusinessPage();
  }

  void _showLogoSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickLogo(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () {
              Navigator.pop(context);
              _pickLogo(ImageSource.camera);
            },
          ),
        ]),
      ),
    );
  }

  Widget _logoPicker() {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _showLogoSourceSheet,
      child: Stack(
        children: [
          Container(
            width: 96,
            height: 96,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: _pickedLogoFile != null
                ? Image.file(_pickedLogoFile!, fit: BoxFit.cover)
                : _logoUrl.isNotEmpty
                    ? Image.network(_logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.storefront_outlined,
                            size: 34,
                            color: scheme.onSurface.withValues(alpha: .35)))
                    : Icon(Icons.storefront_outlined,
                        size: 34, color: scheme.primary),
          ),
          if (_isUploadingLogo)
            Positioned.fill(
              child: Container(
                color: scheme.scrim.withValues(alpha: .35),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.camera_alt_outlined,
                  size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorPage() {
    return WorkspacePage(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PageIntro(
              eyebrow: 'Business details',
              title: 'Edit store profile',
              description: 'This information appears on generated invoice PDFs.',
              action: TextButton.icon(
                onPressed: () => setState(() => _showEditor = false),
                icon: const Icon(Icons.arrow_back_rounded, size: 17),
                label: const Text('Back to profile'),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: SurfacePanel(
                  accent: true,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: _logoPicker()),
                        const SizedBox(height: 18),
                        const LedgerKicker('Identity'),
                        const SizedBox(height: 10),
                        _pairRow(
                          _field('Store name *', _storeNameController,
                              Icons.storefront_outlined),
                          _field('Owner name *', _ownerNameController,
                              Icons.person_outline),
                        ),
                        const SizedBox(height: 10),
                        _pairRow(
                          _field('GSTIN number', _gstController,
                              Icons.badge_outlined),
                          _field('Phone number', _phoneController,
                              Icons.phone_outlined),
                        ),
                        const SizedBox(height: 10),
                        _field('Email address', _emailController,
                            Icons.mail_outline),
                        const SizedBox(height: 10),
                        _field('Address', _addressController,
                            Icons.location_on_outlined,
                            maxLines: 2),
                        const SizedBox(height: 10),
                        _tripleRow(
                          _field('City', _cityController,
                              Icons.location_city_outlined),
                          _field('District', _districtController,
                              Icons.map_outlined),
                          _field('Pincode', _pincodeController,
                              Icons.pin_drop_outlined),
                        ),
                        const SizedBox(height: 18),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setState(() => _showEditor = false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 46,
                              child: FilledButton.icon(
                                onPressed: _isSaving ? null : _saveProfile,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.save_outlined,
                                        size: 18),
                                label: const Text('Save profile'),
                              ),
                            ),
                          ),
                        ]),
                      ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _pairRow(Widget a, Widget b) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 480) {
        return Row(children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ]);
      }
      return Column(children: [
        a,
        const SizedBox(height: 10),
        b,
      ]);
    });
  }

  Widget _tripleRow(Widget a, Widget b, Widget c) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 560) {
        return Row(children: [
          Expanded(child: a),
          const SizedBox(width: 8),
          Expanded(child: b),
          const SizedBox(width: 8),
          Expanded(child: c),
        ]);
      }
      if (constraints.maxWidth >= 360) {
        return Row(children: [
          Expanded(child: a),
          const SizedBox(width: 8),
          Expanded(child: b),
          const SizedBox(width: 8),
        ]);
      }
      return Column(children: [
        a,
        const SizedBox(height: 10),
        b,
        const SizedBox(height: 10),
        c,
      ]);
    });
  }

  Widget _field(String label, TextEditingController controller, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19),
        isDense: true,
      ),
    );
  }

  Widget _buildBusinessPage() {
    final scheme = Theme.of(context).colorScheme;
    final storeName = _storeNameController.text.isEmpty
        ? 'Your business'
        : _storeNameController.text;

    final location = [
      if (_addressController.text.isNotEmpty) _addressController.text,
      if (_cityController.text.isNotEmpty) _cityController.text,
      if (_districtController.text.isNotEmpty) _districtController.text,
      if (_pincodeController.text.isNotEmpty) _pincodeController.text,
    ].join(', ');

    Widget logo = Icon(Icons.storefront_outlined, size: 26, color: scheme.primary);
    if (_pickedLogoFile != null) {
      logo = Image.file(_pickedLogoFile!, fit: BoxFit.cover);
    } else if (_logoUrl.isNotEmpty) {
      logo = Image.network(_logoUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.storefront_outlined,
                  size: 26, color: scheme.onSurface.withValues(alpha: .4)));
    }

    return WorkspacePage(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageIntro(
          eyebrow: 'Business details',
          title: 'Store profile',
          description:
              'Your identity, contact and tax details used across invoices.',
          action: OutlinedButton.icon(
            onPressed: () => setState(() => _showEditor = true),
            icon: const Icon(Icons.edit_outlined, size: 17),
            label: const Text('Edit details'),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SurfacePanel(
                        accent: true,
                        child: Row(children: [
                          Container(
                            width: 58,
                            height: 58,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest
                                  .withValues(alpha: .5),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: scheme.outlineVariant),
                            ),
                            child: logo,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(storeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: scheme.onSurface,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 3),
                                Text(_ownerNameController.text.isEmpty
                                    ? 'Add an owner name'
                                    : 'Owned by ${_ownerNameController.text}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color:
                                            scheme.onSurface.withValues(alpha: .55),
                                        fontSize: 12.5)),
                              ],
                            ),
                          ),
                          if (_gstController.text.isNotEmpty)
                            LedgerTag(
                                label: _gstController.text,
                                color: scheme.secondary),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      SurfacePanel(
                        accent: false,
                        child: Column(children: [
                          _infoRow(
                              Icons.location_on_outlined,
                              'Address',
                              location.isEmpty
                                  ? 'Add your business address'
                                  : location),
                          Divider(height: 1, color: scheme.outlineVariant),
                          _infoRow(
                              Icons.phone_outlined,
                              'Contact',
                              _phoneController.text.isEmpty
                                  ? 'Add a contact number'
                                  : _phoneController.text),
                          Divider(height: 1, color: scheme.outlineVariant),
                          _infoRow(
                              Icons.mail_outline,
                              'Email',
                              _emailController.text.isEmpty
                                  ? 'Add an email address'
                                  : _emailController.text),
                          Divider(height: 1, color: scheme.outlineVariant),
                          _infoRow(
                              Icons.verified_outlined,
                              'Tax registration',
                              _gstController.text.isEmpty
                                  ? 'GSTIN not added'
                                  : _gstController.text),
                        ]),
                      ),
                    ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LedgerStamp(icon: icon, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .5),
                    fontSize: 10.5,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}