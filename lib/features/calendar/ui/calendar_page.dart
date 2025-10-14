import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:after30/features/calendar/models/medication.dart';
import 'package:after30/features/calendar/data/medication_service.dart';
import 'package:after30/features/common/navigationBar.dart';

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
          TableCalendar<Medication>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) {
              final provider = context.read<MedicationProvider>();
              return provider.getMedicationsForDate(day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              // 클릭(선택)한 날을 기준으로 앞뒤 한 달 범위 조회
              context.read<MedicationProvider>().fetchMedications(
                selectedDay.subtract(const Duration(days: 30)),
                selectedDay.add(const Duration(days: 30)),
              );
            },
            onFormatChanged: (format) => setState(() {
              _calendarFormat = format;
            }),
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
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
          Expanded(
            child: Consumer<MedicationProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final medications = provider.getMedicationsForDate(_selectedDay)
                  ..sort((a, b) => a.time.compareTo(b.time));
                final total = medications.length;
                final done = medications
                    .where((m) => m.status == 'taken')
                    .length;

                if (medications.isEmpty) {
                  return const Center(
                    child: Text(
                      '복용 기록이 없습니다.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${_selectedDay.month}월 ${_selectedDay.day}일 (${_weekdayKor(_selectedDay.weekday)})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9F0FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$done/$total',
                              style: const TextStyle(
                                color: Color(0xFF3761FF),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...medications.map((m) {
                      final isDone = m.status == 'taken';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE6E6E6)),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Row(
                              children: [
                                Text(
                                  m.time.substring(0, 5),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (m.takenAt != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Colors.green[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '복약 ${m.takenAt!.hour.toString().padLeft(2, '0')}:${m.takenAt!.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Row(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '상태: ${m.status}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black45,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (m.nfcEnabled) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.nfc,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 2),
                                    const Text(
                                      'NFC',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                if (isDone) {
                                  await context
                                      .read<MedicationProvider>()
                                      .unmarkCompleted(m.id);
                                } else {
                                  await context
                                      .read<MedicationProvider>()
                                      .markCompleted(m.id);
                                }
                              },
                              child: Icon(
                                isDone
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: isDone
                                    ? const Color(0xFF39C36E)
                                    : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AlarmBottomNavigation(currentIndex: 3),
    );
  }

  String _weekdayKor(int weekday) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final idx = (weekday - 1).clamp(0, 6);
    return days[idx];
  }
}
