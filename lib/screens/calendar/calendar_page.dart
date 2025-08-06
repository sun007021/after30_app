import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:after30/models/medication.dart';
import 'package:after30/services/medication_service.dart';
import 'package:after30/widgets/alarm_list/alarm_bottom_navigation.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late CalendarFormat _calendarFormat;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _calendarFormat = CalendarFormat.month;

    // 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MedicationProvider>().fetchMedications(
        _focusedDay.subtract(const Duration(days: 30)),
        _focusedDay.add(const Duration(days: 30)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('복용 기록'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 달력 위젯
          TableCalendar<Medication>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });

              // 선택된 날짜의 데이터 로드
              context.read<MedicationProvider>().fetchMedications(
                selectedDay.subtract(const Duration(days: 7)),
                selectedDay.add(const Duration(days: 7)),
              );
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });

              // 페이지 변경 시 해당 범위의 데이터 로드
              context.read<MedicationProvider>().fetchMedications(
                focusedDay.subtract(const Duration(days: 30)),
                focusedDay.add(const Duration(days: 30)),
              );
            },
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Color(0xFFFEE500),
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
            ),
          ),

          const Divider(height: 1),

          // 선택된 날짜의 복용 기록 리스트
          Expanded(
            child: Consumer<MedicationProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final medications = provider.getMedicationsForDate(
                  _selectedDay,
                );

                if (medications.isEmpty) {
                  return const Center(
                    child: Text(
                      '복용 기록이 없습니다.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: medications.length,
                  itemBuilder: (context, index) {
                    final medication = medications[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFFEBEE),
                          child: Icon(Icons.medication, color: Colors.red[300]),
                        ),
                        title: Text(
                          medication.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${medication.dosage} - ${medication.time}',
                        ),
                        trailing: Text(
                          medication.status,
                          style: TextStyle(
                            color: medication.status == '복용완료'
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AlarmBottomNavigation(),
    );
  }
}
