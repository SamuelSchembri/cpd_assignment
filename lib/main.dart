import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

late FirebaseAnalytics firebaseAnalytics;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  firebaseAnalytics = FirebaseAnalytics.instance;

  if (kDebugMode) {
    await firebaseAnalytics.setAnalyticsCollectionEnabled(true);
    await Future.delayed(const Duration(milliseconds: 500));
    await firebaseAnalytics.logEvent(
      name: 'app_started',
      parameters: {'debug_mode': 'true'},
    );
  }

  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosInitSettings =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initSettings = InitializationSettings(
    android: androidInitSettings,
    iOS: iosInitSettings,
  );

await flutterLocalNotificationsPlugin.initialize(
  settings: initSettings,
  onDidReceiveNotificationResponse: (details) {},
);


  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'timezone_tracker_channel',
    'Timezone Notifications',
    description: 'Timezone reminder notifications',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timezone Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TimezoneTrackerApp(),
    );
  }
}

class TimezoneTrackerApp extends StatefulWidget {
  const TimezoneTrackerApp({super.key});

  @override
  State<TimezoneTrackerApp> createState() => _TimezoneTrackerAppState();
}

class _TimezoneTrackerAppState extends State<TimezoneTrackerApp> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          TimezoneTrackerScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() => _selectedIndex = index);
          firebaseAnalytics.logEvent(
            name: 'navigation_tab_selected',
            parameters: {'tab_index': index},
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.schedule),
            label: 'Tracker',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class TimeZoneCity {
  final String name;
  final String country;
  final int utcOffset;
  final String id;

  TimeZoneCity({
    required this.name,
    required this.country,
    required this.utcOffset,
    required this.id,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'country': country,
        'utcOffset': utcOffset,
        'id': id,
      };

  factory TimeZoneCity.fromJson(Map<String, dynamic> json) => TimeZoneCity(
        name: json['name'],
        country: json['country'],
        utcOffset: json['utcOffset'],
        id: json['id'],
      );
}

class TimezoneTrackerScreen extends StatefulWidget {
  const TimezoneTrackerScreen({super.key});

  @override
  State<TimezoneTrackerScreen> createState() => _TimezoneTrackerScreenState();
}

class _TimezoneTrackerScreenState extends State<TimezoneTrackerScreen> {
  late Timer _timer;
  late DateTime _currentTime;
  List<TimeZoneCity> _displayedCities = [];
  bool _isLoading = true;
  String? _userTimezone;
  bool _detectingLocation = false;

  final List<TimeZoneCity> _defaultCities = [
    TimeZoneCity(name: 'Valletta', country: 'Malta', utcOffset: 1, id: 'valletta'),
    TimeZoneCity(name: 'Berlin', country: 'Germany', utcOffset: 1, id: 'berlin'),
    TimeZoneCity(name: 'London', country: 'United Kingdom', utcOffset: 0, id: 'london'),
    TimeZoneCity(name: 'New York', country: 'USA', utcOffset: -5, id: 'newyork'),
    TimeZoneCity(name: 'Tokyo', country: 'Japan', utcOffset: 9, id: 'tokyo'),
    TimeZoneCity(name: 'Sydney', country: 'Australia', utcOffset: 11, id: 'sydney'),
    TimeZoneCity(name: 'Dubai', country: 'UAE', utcOffset: 4, id: 'dubai'),
    TimeZoneCity(name: 'Singapore', country: 'Singapore', utcOffset: 8, id: 'singapore'),
  ];

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _loadCities();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _currentTime = DateTime.now());
    });
  }

  Future<void> _loadCities() async {
    final prefs = await SharedPreferences.getInstance();
    final citiesJson = prefs.getStringList('favorite_cities');

    setState(() {
      if (citiesJson != null && citiesJson.isNotEmpty) {
        _displayedCities = citiesJson
            .map((json) => TimeZoneCity.fromJson(jsonDecode(json)))
            .toList();
      } else {
        _displayedCities = _defaultCities;
      }
      _isLoading = false;
    });

    await firebaseAnalytics.logEvent(
      name: 'cities_loaded',
      parameters: {'city_count': _displayedCities.length},
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  Future<void> _showAddCityDialog() async {
    final availableCities = _defaultCities
        .where((city) =>
            !_displayedCities.any((displayed) => displayed.id == city.id))
        .toList();

    if (availableCities.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All cities already added')),
        );
      }
      return;
    }

    if (!mounted) return;

    final selectedCity = await showDialog<TimeZoneCity>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add City'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: availableCities.length,
            itemBuilder: (context, index) {
              final city = availableCities[index];
              return ListTile(
                title: Text(city.name),
                subtitle: Text(city.country),
                onTap: () => Navigator.pop(context, city),
              );
            },
          ),
        ),
      ),
    );

    if (selectedCity != null) {
      setState(() => _displayedCities.add(selectedCity));
      await _saveCities();
      await firebaseAnalytics.logEvent(
        name: 'city_added',
        parameters: {'city_name': selectedCity.name},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${selectedCity.name} added!')),
        );
      }
    }
  }

  Future<void> _saveCities() async {
    final prefs = await SharedPreferences.getInstance();
    final citiesJson =
        _displayedCities.map((city) => jsonEncode(city.toJson())).toList();
    await prefs.setStringList('favorite_cities', citiesJson);
  }

  Future<void> _removeCity(int index) async {
    final removedCity = _displayedCities[index].name;
    setState(() => _displayedCities.removeAt(index));
    await _saveCities();
    await firebaseAnalytics.logEvent(
      name: 'city_removed',
      parameters: {'city_name': removedCity},
    );
  }

  String _getTimezoneFromCoordinates(double latitude, double longitude) {
    if (latitude > 35 && latitude < 37 && longitude > 13 && longitude < 15) {
      return 'Europe/Malta';
    } else if (latitude > 51 && latitude < 52 && longitude > -1 && longitude < 1) {
      return 'Europe/London';
    } else if (latitude > 52 && latitude < 53 && longitude > 13 && longitude < 14) {
      return 'Europe/Berlin';
    } else if (latitude > 40 && latitude < 41 && longitude > -74 && longitude < -73) {
      return 'America/New_York';
    } else if (latitude > 35 && latitude < 36 && longitude > 139 && longitude < 140) {
      return 'Asia/Tokyo';
    } else if (latitude > -34 && latitude < -33 && longitude > 150 && longitude < 152) {
      return 'Australia/Sydney';
    } else if (latitude > 24 && latitude < 25 && longitude > 54 && longitude < 56) {
      return 'Asia/Dubai';
    } else if (latitude > 1 && latitude < 2 && longitude > 103 && longitude < 104) {
      return 'Asia/Singapore';
    } else {
      return 'Europe/Malta (UTC+1)';
    }
  }

  Future<void> _detectUserTimezone() async {
    setState(() => _detectingLocation = true);

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
      }
      setState(() => _detectingLocation = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    final timezone =
        _getTimezoneFromCoordinates(position.latitude, position.longitude);

    setState(() {
      _userTimezone = timezone;
      _detectingLocation = false;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_timezone', timezone);

    await firebaseAnalytics.logEvent(
      name: 'timezone_detected',
      parameters: {
        'timezone': timezone,
        'latitude': position.latitude,
        'longitude': position.longitude,
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Detected: $timezone')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timezone Tracker'),
        centerTitle: true,
        elevation: 4,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Center(
                            child: Text(
                              _formatTime(_currentTime),
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                            ),
                          ),
                          if (_userTimezone != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Your Timezone: $_userTimezone',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed:
                                _detectingLocation ? null : _detectUserTimezone,
                            icon: _detectingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.location_on),
                            label: Text(
                              _detectingLocation
                                  ? 'Detecting...'
                                  : 'Detect My Timezone',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _displayedCities.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text('No cities selected'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _showAddCityDialog,
                                child: const Text('Add a City'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _displayedCities.length,
                          itemBuilder: (context, index) {
                            final city = _displayedCities[index];
                            final utcTime = _currentTime.toUtc();
                            final cityTime =
                                utcTime.add(Duration(hours: city.utcOffset));

                            return Dismissible(
                              key: Key(city.id),
                              onDismissed: (direction) => _removeCity(index),
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16.0),
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              child: Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 8,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            city.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge,
                                          ),
                                          Text(
                                            city.country,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _formatTime(cityTime),
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                          ),
                                          Text(
                                            'UTC${city.utcOffset >= 0 ? '+' : ''}${city.utcOffset}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCityDialog,
        tooltip: 'Add City',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _scheduleNotification,
                    child: const Text('Test Notification'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Timezone Tracker v1.0.0'),
                  const SizedBox(height: 8),
                  const Text(
                    'A cross-platform Flutter application for tracking time across multiple timezones.',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Features:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('- Real-time timezone tracking'),
                  const Text('- GPS-based timezone detection'),
                  const Text('- Local data persistence'),
                  const Text('- Push notifications'),
                  const Text('- Analytics integration'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scheduleNotification() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImpl =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      final bool? grantedNotificationPermission =
          await androidImpl?.requestNotificationsPermission();

      if (grantedNotificationPermission != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permission denied')),
          );
        }
        return;
      }
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'timezone_tracker_channel',
      'Timezone Notifications',
      channelDescription: 'Timezone reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: 'Timezone Reminder',
      body: 'Check the current time across timezones!',
      notificationDetails: platformDetails,
    );

    await firebaseAnalytics.logEvent(name: 'notification_sent');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification sent!')),
      );
    }
  }
}
