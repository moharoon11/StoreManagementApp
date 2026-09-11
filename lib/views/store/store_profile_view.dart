import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../widgets/workspace_ui.dart';

class StoreProfileView extends StatefulWidget {
  const StoreProfileView({super.key});

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
      final image =
          await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (image == null) return;

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
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingLogo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Logo upload failed: ${e.toString().replaceAll("Exception: ", "")}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_storeNameController.text.trim().isEmpty ||
        _ownerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Store name and owner name are required.'),
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
          const SnackBar(content: Text('Store profile saved successfully.')),
        );
        setState(() => _showEditor = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
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

    return WorkspacePage(
      child: _showEditor ? _buildEditor() : _buildProfile(),
    );
  }

  Widget _buildProfile() {
    final location = [
      _addressController.text,
      _cityController.text,
      _districtController.text,
      _pincodeController.text,
    ].where((part) => part.trim().isNotEmpty).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageIntro(
          eyebrow: 'Business',
          title: 'Store identity',
          description:
              'Keep the details that appear on invoice PDFs clean, compact, and easy to update.',
          action: FilledButton.icon(
            onPressed: () => setState(() => _showEditor = true),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit details'),
          ),
        ),
        const SizedBox(height: 16),
        SurfacePanel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final identity = compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LogoBadge(
                          logoUrl: _logoUrl,
                          pickedLogoFile: _pickedLogoFile,
                        ),
                        const SizedBox(height: 14),
                        _IdentityText(
                          storeName: _storeNameController.text,
                          ownerName: _ownerNameController.text,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        _LogoBadge(
                          logoUrl: _logoUrl,
                          pickedLogoFile: _pickedLogoFile,
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _IdentityText(
                            storeName: _storeNameController.text,
                            ownerName: _ownerNameController.text,
                          ),
                        ),
                      ],
                    );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  const SizedBox(height: 18),
                  AdaptiveWrapGrid(
                    minItemWidth: 200,
                    children: [
                      _DetailCard(
                        icon: Icons.location_on_outlined,
                        label: 'Address',
                        value: location.isEmpty
                            ? 'Add your business address'
                            : location,
                      ),
                      _DetailCard(
                        icon: Icons.phone_outlined,
                        label: 'Contact',
                        value: _phoneController.text.isEmpty
                            ? 'Add a contact number'
                            : _phoneController.text,
                      ),
                      _DetailCard(
                        icon: Icons.mail_outline_rounded,
                        label: 'Email',
                        value: _emailController.text.isEmpty
                            ? 'Add an email address'
                            : _emailController.text,
                      ),
                      _DetailCard(
                        icon: Icons.verified_outlined,
                        label: 'Tax registration',
                        value: _gstController.text.isEmpty
                            ? 'GSTIN not added'
                            : _gstController.text,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageIntro(
          eyebrow: 'Business',
          title: 'Edit store profile',
          description:
              'Update the details used on customer invoices and store records.',
          action: OutlinedButton.icon(
            onPressed: () => setState(() => _showEditor = false),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back'),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: SectionPanel(
              title: 'Business details',
              subtitle: 'This information appears on generated invoice PDFs.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => SafeArea(
                            child: Wrap(
                              children: [
                                ListTile(
                                  leading:
                                      const Icon(Icons.photo_library_outlined),
                                  title: const Text('Choose from gallery'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickLogo(ImageSource.gallery);
                                  },
                                ),
                                ListTile(
                                  leading:
                                      const Icon(Icons.camera_alt_outlined),
                                  title: const Text('Take a photo'),
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
                        children: [
                          _LogoBadge(
                            logoUrl: _logoUrl,
                            pickedLogoFile: _pickedLogoFile,
                            large: true,
                            loading: _isUploadingLogo,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _FormPair(
                    first: _textField('Store name *', _storeNameController),
                    second: _textField('Owner name *', _ownerNameController),
                  ),
                  const SizedBox(height: 12),
                  _FormPair(
                    first: _textField('GSTIN number', _gstController),
                    second: _textField('Phone number', _phoneController),
                  ),
                  const SizedBox(height: 12),
                  _textField('Email address', _emailController),
                  const SizedBox(height: 12),
                  _textField('Address', _addressController, maxLines: 2),
                  const SizedBox(height: 12),
                  _FormPair(
                    first: _textField('City', _cityController),
                    second: _textField('District', _districtController),
                  ),
                  const SizedBox(height: 12),
                  _textField('Pincode', _pincodeController),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          (_isSaving || _isUploadingLogo) ? null : _saveProfile,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save store profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge({
    required this.logoUrl,
    required this.pickedLogoFile,
    this.large = false,
    this.loading = false,
  });

  final String logoUrl;
  final File? pickedLogoFile;
  final bool large;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final size = large ? 110.0 : 82.0;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .24),
        shape: BoxShape.circle,
        image: pickedLogoFile != null
            ? DecorationImage(image: FileImage(pickedLogoFile!), fit: BoxFit.cover)
            : (logoUrl.isNotEmpty
                ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover)
                : null),
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : (pickedLogoFile == null && logoUrl.isEmpty
              ? Icon(Icons.storefront_rounded, color: scheme.primary, size: size / 2.4)
              : null),
    );
  }
}

class _IdentityText extends StatelessWidget {
  const _IdentityText({
    required this.storeName,
    required this.ownerName,
  });

  final String storeName;
  final String ownerName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusPill(label: 'Business profile', color: scheme.primary),
        const SizedBox(height: 12),
        Text(
          storeName.isEmpty ? 'Your business' : storeName,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          ownerName.isEmpty
              ? 'Independent business'
              : 'Managed by $ownerName',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: .62),
              ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 20),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: .58),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _FormPair extends StatelessWidget {
  const _FormPair({
    required this.first,
    required this.second,
  });

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    if (narrow) {
      return Column(
        children: [
          first,
          const SizedBox(height: 12),
          second,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }
}
