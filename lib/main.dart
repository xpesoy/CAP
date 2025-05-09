import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/meal_screen.dart';
import 'screens/ticket_screen.dart';
import 'screens/calendar_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '학교 앱',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;  // 현재 선택된 탭 인덱스

  // 화면 목록
  final List<Widget> _screens = [
    HomeScreen(),
    TimetableScreen(),
    MealScreen(),
    TicketScreen(),
    CalendarScreen(),
  ];

  // 탭 변경 함수
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex], // 선택된 화면 표시
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue, // 선택된 아이콘 색상
        unselectedItemColor: Colors.grey, // 선택되지 않은 아이콘 색상
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: '시간표'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: '급식'),
          BottomNavigationBarItem(icon: Icon(Icons.airplane_ticket), label: '티켓'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '학사일정'),
        ],
      ),
    );
  }
}
