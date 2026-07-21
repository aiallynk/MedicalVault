import 'package:flutter/material.dart';
import 'package:hello/api_service.dart';
import 'package:hello/screens/appointment_detail_screen.dart';
import 'package:hello/screens/doctor_detail_screen.dart';
import 'package:hello/widgets/app_text.dart';
import 'package:hello/widgets/custom_card.dart';
import 'package:hello/widgets/doctor_card.dart';
import 'package:hello/widgets/past_appointment_card.dart';
import 'package:hello/widgets/upcoming_appointment_card.dart';

class AppointmentsPage extends StatefulWidget {
  final int initialTab;

  const AppointmentsPage({super.key, this.initialTab = 0});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _upcoming = [];
  List<dynamic> _past = [];
  List<Map<String, dynamic>> _doctors = [];
  String _selectedSpecialization = 'All';

  bool _loadingUpcoming = true;
  bool _loadingPast = true;
  bool _loadingDoctors = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTab.clamp(0, 2);
    _tabController =
        TabController(length: 3, vsync: this, initialIndex: initial);
    _searchController.addListener(_onSearchChanged);
    _loadUpcoming();
    _loadPast();
    _loadDoctors();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUpcoming() async {
    setState(() => _loadingUpcoming = true);
    final list = await ApiService.fetchUpcomingAppointments();
    if (!mounted) return;
    setState(() {
      _upcoming = list;
      _loadingUpcoming = false;
    });
  }

  Future<void> _loadPast() async {
    setState(() => _loadingPast = true);
    final list = await ApiService.fetchPastAppointments();
    if (!mounted) return;
    setState(() {
      _past = list;
      _loadingPast = false;
    });
  }

  Future<void> _loadDoctors() async {
    setState(() => _loadingDoctors = true);
    final doctors = await ApiService.fetchDoctorDirectory();
    if (!mounted) return;
    setState(() {
      _doctors = doctors;
      _loadingDoctors = false;
    });
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  List<String> get _specializations {
    final specs = _doctors
        .map((doc) => doc['specialization']?.toString() ?? '')
        .where((spec) => spec.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...specs];
  }

  List<Map<String, dynamic>> get _filteredDoctors {
    final query = _searchController.text.trim().toLowerCase();
    return _doctors.where((doctor) {
      final name = doctor['name']?.toString().toLowerCase() ?? '';
      final specialization = doctor['specialization']?.toString() ?? '';
      final specMatch = _selectedSpecialization == 'All' ||
          specialization == _selectedSpecialization;
      final queryMatch = query.isEmpty ||
          name.contains(query) ||
          specialization.toLowerCase().contains(query);
      return specMatch && queryMatch;
    }).toList();
  }

  List<Map<String, dynamic>> _appointmentsForDoctor(
      Map<String, dynamic> doctor) {
    final doctorId = doctor['id']?.toString() ?? '';
    return [..._upcoming, ..._past]
        .whereType<Map>()
        .map((appointment) => appointment.map(
              (key, value) => MapEntry(key.toString(), value),
            ))
        .where((appointment) {
      final appointmentDoctor = appointment['doctorId'];
      final appointmentDoctorId = appointmentDoctor is Map
          ? appointmentDoctor['_id']?.toString() ??
              appointmentDoctor['id']?.toString()
          : appointmentDoctor?.toString();
      return appointmentDoctorId == doctorId;
    }).toList(growable: false);
  }

  void _openDetail(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentDetailScreen(
          appointmentId: id,
          onUpdated: () {
            _loadUpcoming();
            _loadPast();
          },
        ),
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _specializations.map((spec) {
                return ChoiceChip(
                  selected: _selectedSpecialization == spec,
                  label: Text(spec),
                  onSelected: (_) {
                    setState(() {
                      _selectedSpecialization = spec;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText(
          'Doctors & Appointments',
          variant: AppTextVariant.subtitle,
          fontWeight: FontWeight.w700,
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Doctors'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadDoctors(), _loadUpcoming(), _loadPast()]);
        },
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDoctorsTab(),
            _buildUpcomingTab(),
            _buildPastTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorsTab() {
    final doctors = _filteredDoctors;
    final loading = _loadingDoctors;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search doctor or specialty',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 10),
            CustomCard(
              onTap: _openFilterSheet,
              radius: 14,
              padding: const EdgeInsets.all(12),
              child: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              selected: _selectedSpecialization == 'All',
              label: const Text('All'),
              onSelected: (_) {
                setState(() {
                  _selectedSpecialization = 'All';
                });
              },
            ),
            ..._specializations.where((s) => s != 'All').take(4).map((spec) {
              return ChoiceChip(
                selected: _selectedSpecialization == spec,
                label: Text(spec),
                onSelected: (_) {
                  setState(() {
                    _selectedSpecialization = spec;
                  });
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 14),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 50),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (doctors.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Center(
              child: Column(
                children: [
                  const AppText('No doctors found for this filter.'),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _loadDoctors,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: doctors.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              return DoctorCard(
                name: doctor['name']?.toString() ?? 'Doctor',
                specialization: doctor['specialization']?.toString() ?? '',
                imageUrl: doctor['profilePictureUrl']?.toString(),
                onTap: () async {
                  final booked = await Navigator.push<bool>(
                    context,
                    _buildFadeSlideRoute(
                      DoctorDetailScreen(
                        doctor: doctor,
                        appointments: _appointmentsForDoctor(doctor),
                      ),
                    ),
                  );
                  if (booked == true && mounted) {
                    await _loadUpcoming();
                  }
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildUpcomingTab() {
    if (_loadingUpcoming) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_upcoming.isEmpty) {
      return const Center(
        child: AppText('No upcoming appointments'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _upcoming.length,
      itemBuilder: (context, index) {
        final apt = _upcoming[index] as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: UpcomingAppointmentCard(
            appointment: apt,
            onTap: () => _openDetail(apt['_id']?.toString() ?? ''),
            onCancel: () async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cancel Appointment'),
                  content: const Text(
                    'Are you sure you want to cancel this appointment?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('No'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Yes'),
                    ),
                  ],
                ),
              );
              if (ok == true && mounted) {
                final success = await ApiService.cancelAppointment(
                  apt['_id']?.toString() ?? '',
                );
                if (success && mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Appointment cancelled')),
                  );
                  _loadUpcoming();
                }
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildPastTab() {
    if (_loadingPast) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_past.isEmpty) {
      return const Center(
        child: AppText('No past appointments'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _past.length,
      itemBuilder: (context, index) {
        final apt = _past[index] as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PastAppointmentCard(
            appointment: apt,
            onTap: () => _openDetail(apt['_id']?.toString() ?? ''),
            onAskAI: () => _openDetail(apt['_id']?.toString() ?? ''),
          ),
        );
      },
    );
  }

  Route<T> _buildFadeSlideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.03, 0.05),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
