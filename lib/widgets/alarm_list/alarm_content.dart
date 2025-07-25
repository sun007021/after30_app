// 이 위젯은 alarm_list.dart(알람 목록 화면)에서 사용됩니다.
import 'package:flutter/material.dart';
import 'package:after30/screens/add_alarm.dart';
import 'package:after30/models/medicine_alarm.dart';

class AlarmContent extends StatefulWidget {
  const AlarmContent({super.key});

  @override
  State<AlarmContent> createState() => _AlarmContentState();
}

class _AlarmContentState extends State<AlarmContent> {
  final List<MedicineAlarm> _alarms = [];

  Future<void> _goToRegister() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MedicineRegisterPage()),
    );
    if (result is MedicineAlarm) {
      setState(() {
        _alarms.add(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_alarms.isEmpty) {
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication, size: 80, color: Colors.black),
            const SizedBox(height: 24),
            const Text(
              '등록된 약이 없어요',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '약을 등록한 후 알람을 받아보세요',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _goToRegister,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('약 등록하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA7B0),
                foregroundColor: Colors.white,
                minimumSize: const Size(180, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 24, top: 8),
                  child: Text(
                    'NFC 관리하기',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            ..._alarms.asMap().entries.map((entry) {
              final idx = entry.key;
              final alarm = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.grey),
                ),
                elevation: 0,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            alarm.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.circle,
                            color: Colors.green,
                            size: 10,
                          ),
                          const Spacer(),
                          PopupMenuButton<String>(
                            color: Colors.white,
                            icon: Icon(
                              Icons.more_vert,
                              color: Colors.grey[700],
                            ),
                            onSelected: (value) async {
                              if (value == 'edit') {
                                // 알람 수정: MedicineRegisterPage로 이동, 수정 후 갱신
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MedicineRegisterPage(
                                      initialAlarm: alarm,
                                    ),
                                  ),
                                );
                                if (result is MedicineAlarm) {
                                  setState(() {
                                    _alarms[idx] = result;
                                  });
                                }
                              } else if (value == 'delete') {
                                // 알람 삭제
                                setState(() {
                                  _alarms.removeAt(idx);
                                });
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('알람 수정'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('알람 삭제'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 18),
                          const SizedBox(width: 4),
                          ...alarm.times.map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Text(_formatTimeOfDay(t)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alarm.everyDay ? '매일' : alarm.days.join(', '),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 50),
            Center(
              child: Material(
                borderRadius: BorderRadius.circular(10),
                color: Colors.transparent,
                child: ElevatedButton(
                  onPressed: _goToRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA7B0),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(180, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: const Text('약 등록하기  +'),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? '오전' : '오후';
    return '$period $hour:$minute';
  }
}
