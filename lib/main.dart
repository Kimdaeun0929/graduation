import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  runApp(const CalendarApp());
}

class CalendarApp extends StatelessWidget {
  const CalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iOS 스타일 캘린더',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        fontFamily: 'SF Pro Display',
      ),
      home: const CalendarScreen(),
    );
  }
}

// ------------------------ CalendarScreen ------------------------

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<String>> _events = {};

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddEventDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            locale: 'ko_KR',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) =>
                isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.indigoAccent,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.indigo,
                shape: BoxShape.circle,
              ),
              defaultTextStyle: const TextStyle(fontWeight: FontWeight.w500),
              weekendTextStyle: const TextStyle(color: Colors.redAccent),
            ),
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(thickness: 1),
          Expanded(child: _buildEventList()),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final normalizedDay = _selectedDay != null ? _normalizeDate(_selectedDay!) : null;
    List<String> originalEvents = List.from(_events[normalizedDay] ?? []);
    List<String> sortedEvents = List.from(originalEvents);

    sortedEvents.sort((a, b) {
      TimeOfDay? timeA = _extractTime(a);
      TimeOfDay? timeB = _extractTime(b);
      if (timeA == null || timeB == null) return 0;
      return _compareTimeOfDay(timeA, timeB);
    });

    if (sortedEvents.isEmpty) {
      return const Center(child: Text('일정이 없습니다.', style: TextStyle(fontSize: 16)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: sortedEvents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(sortedEvents[index], style: const TextStyle(fontSize: 16)),
            trailing: const Icon(Icons.edit, size: 20),
            onTap: () => _showEditEventDialog(sortedEvents[index]),
          ),
        );
      },
    );
  }

  int _compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
    if (a.hour != b.hour) return a.hour.compareTo(b.hour);
    return a.minute.compareTo(b.minute);
  }

  TimeOfDay? _extractTime(String eventText) {
    RegExp regex = RegExp(r'\((\d{1,2}):(\d{2})\)$');
    final match = regex.firstMatch(eventText);
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      int minute = int.parse(match.group(2)!);
      return TimeOfDay(hour: hour, minute: minute);
    }
    return null;
  }

  void _showAddEventDialog() {
    TextEditingController controller = TextEditingController();
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '일정 제목',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (picked != null) {
                  setState(() {
                    selectedTime = picked;
                  });
                }
              },
              icon: const Icon(Icons.access_time),
              label: const Text('시간 선택'),
            ),
            if (selectedTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('선택한 시간: ${selectedTime!.format(context)}'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isEmpty || _selectedDay == null) return;
              String eventText = controller.text;
              if (selectedTime != null) {
                eventText += " (${selectedTime!.hour}:${selectedTime!.minute.toString().padLeft(2, '0')})";
              }
              DateTime normalized = _normalizeDate(_selectedDay!);
              setState(() {
                _events[normalized] = (_events[normalized] ?? []) + [eventText];
              });
              Navigator.pop(context);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _showEditEventDialog(String eventText) {
    if (_selectedDay == null) return;
    DateTime normalized = _normalizeDate(_selectedDay!);
    List<String>? dayEvents = _events[normalized];
    if (dayEvents == null) return;

    int index = dayEvents.indexOf(eventText);
    if (index == -1) return;

    RegExp regex = RegExp(r'^(.*?) \((\d{1,2}):(\d{2})\)$');
    String initialTitle = eventText;
    TimeOfDay? selectedTime;

    final match = regex.firstMatch(eventText);
    if (match != null) {
      initialTitle = match.group(1)!;
      int hour = int.parse(match.group(2)!);
      int minute = int.parse(match.group(3)!);
      selectedTime = TimeOfDay(hour: hour, minute: minute);
    }

    TextEditingController controller = TextEditingController(text: initialTitle);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, localSetState) => AlertDialog(
            title: const Text('일정 수정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: '일정 제목',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime ?? TimeOfDay.now(),
                    );
                    if (picked != null) {
                      localSetState(() {
                        selectedTime = picked;
                      });
                    }
                  },
                  icon: const Icon(Icons.access_time),
                  label: const Text('시간 선택'),
                ),
                if (selectedTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('선택한 시간: ${selectedTime!.format(context)}'),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _events[normalized]?.removeAt(index);
                  });
                  Navigator.pop(context);
                },
                child: const Text('삭제'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    String updatedEvent = controller.text;
                    if (selectedTime != null) {
                      updatedEvent +=
                          " (${selectedTime!.hour}:${selectedTime!.minute.toString().padLeft(2, '0')})";
                    }
                    _events[normalized]![index] = updatedEvent;
                  });
                  Navigator.pop(context);
                },
                child: const Text('저장'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------ MyCalendarPage 추가 ------------------------

class MyCalendarPage extends StatefulWidget {
  const MyCalendarPage({super.key});

  @override
  State<MyCalendarPage> createState() => _MyCalendarPageState();
}

class _MyCalendarPageState extends State<MyCalendarPage> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _speechText = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _speech.initialize();
  }

  void startListening() async {
    _isListening = true;
    _speech.listen(onResult: (val) {
      if (!mounted) return;
      setState(() {
        _speechText = val.recognizedWords;
      });
    });
  }

  void stopListening() async {
    _isListening = false;
    await _speech.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("음성 일정 추가")),
      body: Column(
        children: [
          Text("인식된 텍스트: $_speechText"),
          IconButton(
            icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
            onPressed: () {
              _isListening ? stopListening() : startListening();
            },
          )
        ],
      ),
    );
  }
}