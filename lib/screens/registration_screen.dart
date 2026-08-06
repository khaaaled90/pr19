import 'package:flutter/material.dart';
import '../helpers/device_utils.dart';
import '../helpers/sync_manager.dart';

class RegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistrationComplete;

  const RegistrationScreen({super.key, required onRegistrationComplete})
      : onRegistrationComplete = onRegistrationComplete;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _networkController = TextEditingController();

  String _deviceId = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    String id = await DeviceUtils.getDeviceId();
    setState(() => _deviceId = id);
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // تسجيل الفترة التجريبية (10 أيام و 200 قسيمة)
    await SyncManager.registerTrialOnline(
      clientName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      networkName: _networkController.text.trim(),
      trialDays: 10,
      trialVouchersLimit: 200,
    );

    setState(() => _isLoading = false);
    widget.onRegistrationComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل بيانات الخدمة')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.app_registration, size: 80, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'أهلاً بك! يرجى إدخال البيانات لبدء الفترة التجريبية المجانية (10 أيام / 200 قسيمة)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم العميل / المالِك',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v!.isEmpty ? 'يرجى إدخال الاسم' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (v) => v!.isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _networkController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الشبكة / الخدمة (مثل: شبكة المازن)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.wifi),
                  ),
                  validator: (v) => v!.isEmpty ? 'يرجى إدخال اسم الشبكة' : null,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('معرف الجهاز:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SelectableText(_deviceId, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitRegistration,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('بدء استخدام الفترة التجريبية', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}