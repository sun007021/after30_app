import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:after30/models/medication.dart';
import 'package:after30/services/medication_service.dart';
import 'package:after30/widgets/common/navigationBar.dart';

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
            eventLoader: (day) {
              final provider = context.read<MedicationProvider>();
              return provider.getMedicationsForDate(day);
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

                final medications = provider.getMedicationsForDate(_selectedDay)
                  ..sort((a, b) => a.time.compareTo(b.time));

                final total = medications.length;
                final done = medications
                    .where((m) => m.status == '복용완료')
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
                    // 헤더: 날짜 + 진행률 뱃지
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
                    // 아이템 리스트
                    ...medications.map((m) {
                      final isDone = m.status == '복용완료';
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
                            Text(
                              m.time,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    m.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
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
      bottomNavigationBar: const AlarmBottomNavigation(),
    );
  }

  String _weekdayKor(int weekday) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final idx = (weekday - 1).clamp(0, 6);
    return days[idx];
  }
}
