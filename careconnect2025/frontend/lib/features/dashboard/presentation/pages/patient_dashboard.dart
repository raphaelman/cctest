import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:care_connect_app/widgets/common_drawer.dart';
import 'package:care_connect_app/widgets/app_bar_helper.dart';
import 'package:care_connect_app/config/theme/app_theme.dart';
import 'package:care_connect_app/providers/user_provider.dart';
import 'package:care_connect_app/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../widgets/ai_chat_improved.dart';
import '../../../../widgets/family_member_card.dart';
import '../../../../widgets/add_family_member_dialog.dart';
import '../../../../widgets/responsive_container.dart';
import 'package:care_connect_app/services/communication_service.dart';
import 'package:care_connect_app/services/call_notification_service.dart';
import '../../../../widgets/call_notification_status_indicator.dart';
import '../../../../utils/call_integration_helper.dart';

class PatientDashboard extends StatefulWidget {
  final int? userId;
  const PatientDashboard({super.key, this.userId});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  Map<String, dynamic>? patient;
  List<Map<String, dynamic>> caregivers = [];
  List<Map<String, dynamic>> familyMembers = [];
  bool loading = true;
  bool isLoading = false;
  String? error;

  // Mood and pain selection (UI only)
  String? selectedMood;
  String? selectedPain;

  // Real-time call notification state
  bool _callNotificationInitialized = false;

  @override
  void initState() {
    super.initState();
    fetchPatientAndCaregivers();
    _loadFamilyMembers();
    _initializeCallNotifications();
  }

  /// Initialize real-time call notification service for patient
  Future<void> _initializeCallNotifications() async {
    try {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      final patientId = user?.patientId;

      if (patientId == null) {
        print('❌ Cannot initialize call notifications - no patient ID');
        return;
      }

      print(
        '🔔 Initializing call notification service for patient: $patientId',
      );

      // Initialize call notification service
      try {
        await CallNotificationService.initialize(
          userId: patientId.toString(),
          userRole: 'PATIENT',
          context: context,
        );
        _callNotificationInitialized = true;
        setState(() {
          // Update state with initialization status
        });
        print('✅ Patient call notification service initialized successfully');
      } catch (e) {
        print('❌ Error initializing patient call notification service: $e');
        _callNotificationInitialized = false;
      }
    } catch (e) {
      print('❌ Error initializing patient dashboard services: $e');
    }
  }

  Future<void> fetchPatientAndCaregivers() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      final int? patientId = user?.patientId;
      if (patientId == null) {
        setState(() {
          error = 'User not logged in.';
          loading = false;
        });
        return;
      }

      // Fetch patient details
      final authHeaders = await ApiService.getAuthHeaders();
      print(
        'DEBUG: Making patient API call with headers: ${authHeaders.keys.join(', ')}',
      );

      final patientRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}patients/$patientId'),
        headers: authHeaders,
      );
      print('DEBUG: Patient API response status: ${patientRes.statusCode}');
      print('DEBUG: Patient API response body: ${patientRes.body}');

      if (patientRes.statusCode != 200) {
        setState(() {
          error =
              'Failed to load patient details (${patientRes.statusCode}): ${patientRes.body}';
          loading = false;
        });
        return;
      }
      patient = json.decode(patientRes.body);

      // Fetch caregivers
      print(
        'DEBUG: Making caregivers API call with headers: ${authHeaders.keys.join(', ')}',
      );

      final caregiversRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}patients/$patientId/caregivers'),
        headers: authHeaders,
      );
      print(
        'DEBUG: Caregivers API response status: ${caregiversRes.statusCode}',
      );
      print('DEBUG: Caregivers API response body: ${caregiversRes.body}');

      if (caregiversRes.statusCode != 200) {
        setState(() {
          error =
              'Failed to load caregivers (${caregiversRes.statusCode}): ${caregiversRes.body}';
          loading = false;
        });
        return;
      }
      caregivers = List<Map<String, dynamic>>.from(
        json.decode(caregiversRes.body),
      );

      setState(() {
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        loading = false;
      });
    }
  }

  Future<void> _loadFamilyMembers() async {
    if (!isLoading) {
      setState(() {
        isLoading = true;
        error = null;
      });
    }

    try {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      final userId = widget.userId ?? user?.patientId ?? 1;

      print('🔍 Loading family members for userId: $userId');

      final response = await ApiService.getFamilyMembers(userId);

      print('🔍 Family members response: ${response.statusCode}');
      print('🔍 Family members body: ${response.body}');

      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          setState(() {
            familyMembers = List<Map<String, dynamic>>.from(data);
            isLoading = false;
            error = null;
          });
          print(
            '🔍 Family members loaded successfully: ${familyMembers.length} members',
          );
        } else {
          setState(() {
            error = 'Failed to load family members: ${response.statusCode}';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('🔍 Error loading family members: $e');
      if (mounted) {
        setState(() {
          error = 'Error loading family members: ${e.toString()}';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _addFamilyMember() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddFamilyMemberDialog(),
    );

    if (result != null) {
      try {
        // Show loading message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Adding family member...'),
              duration: Duration(seconds: 1),
            ),
          );
        }

        final user = Provider.of<UserProvider>(context, listen: false).user;
        final userId = widget.userId ?? user?.patientId ?? 1;

        print('🔍 Adding family member for userId: $userId');
        print('🔍 Family member data: $result');

        final response = await ApiService.addFamilyMember(userId, result);

        print('🔍 Add family member response: ${response.statusCode}');
        print('🔍 Add family member body: ${response.body}');

        if (response.statusCode == 201) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Family member added successfully!'),
                backgroundColor: AppTheme.success,
                duration: Duration(seconds: 2),
              ),
            );
          }

          // Force refresh the list
          await _loadFamilyMembers();
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(
            errorData['message'] ?? 'Failed to add family member',
          );
        }
      } catch (e) {
        print('🔍 Error adding family member: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppTheme.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  void dispose() {
    // Clean up services
    CallNotificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBarHelper.createAppBar(
        context,
        title: 'Patient Dashboard',
        additionalActions: [
          CallNotificationStatusIndicator(
            isInitialized: _callNotificationInitialized,
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: user == null
          ? null
          : const CommonDrawer(currentRoute: '/dashboard'),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.chat_bubble_outline),
        onPressed: () {
          final double sheetHeight = MediaQuery.of(context).size.height * 0.75;
          showModalBottomSheet(
            isScrollControlled: true,
            context: context,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width,
            ),
            builder: (context) => SizedBox(
              height: sheetHeight,
              child: const AIChat(role: 'patient', isModal: true),
            ),
          );
        },
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : SafeArea(
              child: SingleChildScrollView(
                child: ResponsiveContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${greeting()} ${patient?['firstName'] ?? 'Patient'}!',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'How are you feeling today?',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      _buildMoodSelector(),
                      const SizedBox(height: 16),
                      Text(
                        'How is your pain today?',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      _buildPainSelector(),
                      const Divider(height: 30, thickness: 2),
                      Text(
                        'Your Caregivers',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      ...caregivers.map(
                        (caregiver) => _buildCaregiverCard(caregiver),
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 30, thickness: 2),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Family Members',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addFamilyMember,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Family Member'),
                              ),
                            ],
                          ),
                          if (isLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (error != null)
                            Text(
                              'Error: $error',
                              style: const TextStyle(color: Colors.red),
                            )
                          else if (familyMembers.isEmpty)
                            const Text('No family members added yet')
                          else
                            ...familyMembers.map(
                              (f) => FamilyMemberCard(
                                firstName: f['firstName'] ?? '',
                                lastName: f['lastName'] ?? '',
                                relationship: f['relationship'] ?? '',
                                phone: f['phone'] ?? '',
                                email: f['email'] ?? '',
                                lastInteraction:
                                    f['lastSeen'] ?? 'Not available',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () => context.go('/tasks/today'),
                        child: const Text(
                          'View Today\'s Task',
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // SOS Emergency Button
                      // SOS Emergency Button with improved modal UX
                      Builder(
                        builder: (context) {
                          return ElevatedButton.icon(
                            icon: const Icon(Icons.sos),
                            label: const Text('SOS Emergency'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onError,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.white,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                builder: (context) {
                                  return SafeArea(
                                    child: StatefulBuilder(
                                      builder: (context, setState) {
                                        bool isLoadingLocation = false;
                                        String locationStatus = '';
                                        bool showLocation = false;
                                        double sheetHeight =
                                            MediaQuery.of(context).size.height *
                                            0.6;
                                        return LayoutBuilder(
                                          builder: (context, constraints) {
                                            return SizedBox(
                                              height: sheetHeight,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              16.0,
                                                            ),
                                                        child: Text(
                                                          'SOS Emergency Options',
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .titleMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.error,
                                                              ),
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.close,
                                                        ),
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              context,
                                                            ).pop(),
                                                      ),
                                                    ],
                                                  ),
                                                  const Divider(),
                                                  Flexible(
                                                    child: SingleChildScrollView(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          ListTile(
                                                            leading: Icon(
                                                              Icons.warning,
                                                              color: Theme.of(
                                                                context,
                                                              ).colorScheme.error,
                                                            ),
                                                            title: const Text(
                                                              'SOS Emergency',
                                                            ),
                                                            subtitle: const Text(
                                                              'Select emergency type and send alert',
                                                            ),
                                                            onTap: () {
                                                              Navigator.of(
                                                                context,
                                                              ).pop();
                                                              CallIntegrationHelper.showSOSDialog(
                                                                context:
                                                                    context,
                                                                currentPatient:
                                                                    patient,
                                                              );
                                                            },
                                                          ),
                                                          ListTile(
                                                            leading: Icon(
                                                              Icons.location_on,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary,
                                                            ),
                                                            title: const Text(
                                                              'Share My Location (Quick)',
                                                            ),
                                                            onTap: () async {
                                                              setState(() {
                                                                isLoadingLocation =
                                                                    true;
                                                                locationStatus =
                                                                    'Getting geolocation...';
                                                                showLocation =
                                                                    true;
                                                              });
                                                              await CallIntegrationHelper.sendSOSEmergencyAlert(
                                                                context:
                                                                    context,
                                                                currentUser:
                                                                    patient,
                                                                additionalInfo:
                                                                    'Location shared (quick)',
                                                              );
                                                              setState(() {
                                                                isLoadingLocation =
                                                                    false;
                                                                locationStatus =
                                                                    'Location shared and alert sent!';
                                                              });
                                                            },
                                                          ),
                                                          if (showLocation)
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    16.0,
                                                                  ),
                                                              child: SingleChildScrollView(
                                                                scrollDirection:
                                                                    Axis.horizontal,
                                                                child: Column(
                                                                  children: [
                                                                    if (isLoadingLocation)
                                                                      Row(
                                                                        children: [
                                                                          CircularProgressIndicator(
                                                                            color: Theme.of(
                                                                              context,
                                                                            ).colorScheme.primary,
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                12,
                                                                          ),
                                                                          Expanded(
                                                                            child: Text(
                                                                              locationStatus,
                                                                            ),
                                                                          ),
                                                                          IconButton(
                                                                            icon: const Icon(
                                                                              Icons.close,
                                                                            ),
                                                                            onPressed: () {
                                                                              setState(
                                                                                () {
                                                                                  showLocation = false;
                                                                                },
                                                                              );
                                                                            },
                                                                          ),
                                                                        ],
                                                                      )
                                                                    else
                                                                      Row(
                                                                        children: [
                                                                          Icon(
                                                                            Icons.check_circle,
                                                                            color: Theme.of(
                                                                              context,
                                                                            ).colorScheme.secondary,
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                12,
                                                                          ),
                                                                          Expanded(
                                                                            child: Text(
                                                                              locationStatus,
                                                                            ),
                                                                          ),
                                                                          IconButton(
                                                                            icon: const Icon(
                                                                              Icons.close,
                                                                            ),
                                                                            onPressed: () {
                                                                              setState(
                                                                                () {
                                                                                  showLocation = false;
                                                                                },
                                                                              );
                                                                            },
                                                                          ),
                                                                        ],
                                                                      ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      // Send SMS Notification Button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.sms),
                        label: const Text('Send SMS Notification'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSecondary,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () async {
                          // Pick the first caregiver with a phone number
                          final caregiver = caregivers.firstWhere(
                            (c) =>
                                c['phone'] != null &&
                                c['phone'].toString().isNotEmpty,
                            orElse: () => {},
                          );
                          final user = Provider.of<UserProvider>(
                            context,
                            listen: false,
                          ).user;
                          if (caregiver.isNotEmpty && user != null) {
                            _showSendMessageDialog(context, caregiver, user);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'No caregiver with phone number found.',
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // Auto-save when both mood and pain are selected
  void _autoSaveWhenBothSelected() {
    if (selectedMood != null && selectedPain != null) {
      _saveMoodAndPain();
    }
  }

  Future<void> _saveMoodAndPain() async {
    if (selectedMood == null || selectedPain == null) return;

    try {
      // Convert mood to number value
      final moodValue = _getMoodValueFromLabel(selectedMood!);
      final painValue = _getPainLevelFromLabel(selectedPain!);

      final response = await ApiService.submitMoodAndPainLog(
        moodValue: moodValue,
        painValue: painValue,
        note: 'Daily mood and pain check-in',
        timestamp: DateTime.now(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Status saved automatically'),
              backgroundColor: AppTheme.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['error'] ?? 'Failed to save mood and pain data',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _getMoodValueFromLabel(String mood) {
    switch (mood.toLowerCase()) {
      case 'angry':
        return 1;
      case 'sad':
        return 2;
      case 'tired':
        return 3;
      case 'fearful':
        return 4;
      case 'neutral':
        return 5;
      case 'happy':
        return 6;
      default:
        return 5; // Default to neutral
    }
  }

  int _getPainLevelFromLabel(String label) {
    // Extract the number from the beginning of the label
    final match = RegExp(r'^(\d+)').firstMatch(label);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0; // Default to no pain
  }

  Widget _buildMoodSelector() {
    final moods = [
      {'emoji': '😡', 'label': 'Angry'},
      {'emoji': '😐', 'label': 'Sad'},
      {'emoji': '😫', 'label': 'Tired'},
      {'emoji': '😨', 'label': 'Fearful'},
      {'emoji': '😑', 'label': 'Neutral'},
      {'emoji': '😊', 'label': 'Happy'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: moods.map((mood) {
          final isSelected = selectedMood == mood['label'];
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedMood = mood['label'] as String;
              });
              _autoSaveWhenBothSelected(); // Auto-save when both mood and pain are selected
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue[100] : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: Colors.blue.shade900, width: 2)
                          : null,
                    ),
                    child: Text(
                      mood['emoji'] as String,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mood['label'] as String,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPainSelector() {
    final pains = [
      {'emoji': '😊', 'label': '0\nNo Pain', 'description': 'No pain'},
      {
        'emoji': '🙂',
        'label': '1\nVery Mild',
        'description': 'Pain is very mild, barely noticeable',
      },
      {
        'emoji': '😐',
        'label': '2\nMinor',
        'description': 'Minor pain, annoying',
      },
      {
        'emoji': '😕',
        'label': '3\nNoticeable',
        'description': 'Noticeable pain, may distract you',
      },
      {
        'emoji': '😒',
        'label': '4\nModerate',
        'description': 'Moderate pain, can ignore while active',
      },
      {
        'emoji': '😞',
        'label': '5\nMod. Strong',
        'description': 'Moderately strong pain',
      },
      {
        'emoji': '😖',
        'label': '6\nStronger',
        'description': 'Moderately stronger pain',
      },
      {
        'emoji': '😫',
        'label': '7\nStrong',
        'description': 'Strong pain, prevents normal activities',
      },
      {
        'emoji': '😰',
        'label': '8\nVery Strong',
        'description': 'Very strong pain, hard to do anything',
      },
      {
        'emoji': '😭',
        'label': '9\nHard to Tolerate',
        'description': 'Very hard to tolerate',
      },
      {
        'emoji': '😱',
        'label': '10\nWorst Pain',
        'description': 'Worst pain possible',
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: pains.map((pain) {
          final isSelected = selectedPain == pain['label'];
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedPain = pain['label'] as String;
              });
              _autoSaveWhenBothSelected(); // Auto-save when both mood and pain are selected
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.red[100] : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: Colors.red, width: 2)
                          : null,
                    ),
                    child: Text(
                      pain['emoji'] as String,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 65,
                    child: Text(
                      pain['label'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCaregiverCard(Map<String, dynamic> caregiver) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.blue.shade900),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        leading: const CircleAvatar(child: Text("D")),
        title: Text(
          '${caregiver['firstName'] ?? ''} ${caregiver['lastName'] ?? ''}',
          style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Status: Available', style: AppTheme.bodyMedium),
            Text(
              'Last Interaction: ${caregiver['lastSeen'] ?? 'Recently'}',
              style: AppTheme.bodyMedium,
            ),
            if (caregiver['phone'] != null)
              Text('Phone: ${caregiver['phone']}', style: AppTheme.bodyMedium),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            final phone = caregiver['phone'];
            final email = caregiver['email'];
            final caregiverId = caregiver['id'];

            if (value == 'call' && phone != null) {
              // Use CommunicationService for phone call
              CommunicationService.makePhoneCall(phone, context);
            } else if (value == 'videocall' && caregiverId != null) {
              // Use the enhanced video call integration
              final user = Provider.of<UserProvider>(
                context,
                listen: false,
              ).user;
              CallIntegrationHelper.startVideoCallToCaregiver(
                context: context,
                currentUser: user,
                targetCaregiver: caregiver,
                isVideoCall: true,
              );
            } else if (value == 'email' && email != null) {
              final uri = Uri(
                scheme: 'mailto',
                path: email,
                queryParameters: {
                  'subject': 'CareConnect Inquiry',
                  'body': 'Hello...',
                },
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not launch email client.'),
                  ),
                );
              }
            } else if (value == 'sms' && phone != null) {
              // Use the enhanced SMS integration
              final user = Provider.of<UserProvider>(
                context,
                listen: false,
              ).user;
              _showSendMessageDialog(context, caregiver, user);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'call', child: Text('Call')),
            const PopupMenuItem(value: 'videocall', child: Text('Video Call')),
            const PopupMenuItem(value: 'email', child: Text('Email')),
            const PopupMenuItem(value: 'sms', child: Text('Send SMS')),
          ],
        ),
      ),
    );
  }

  // Add this method to handle sending messages
  void _showSendMessageDialog(
    BuildContext context,
    Map<String, dynamic> caregiver,
    dynamic currentUser,
  ) {
    final TextEditingController messageController = TextEditingController();
    final String name = '${caregiver['firstName']} ${caregiver['lastName']}';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Send message to $name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Write your message here...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Use enhanced SMS integration
                CallIntegrationHelper.sendSMSToCaregiver(
                  currentUser: currentUser,
                  targetCaregiver: caregiver,
                  message: messageController.text,
                );

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('SMS sent to $name')));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade900,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }
}
