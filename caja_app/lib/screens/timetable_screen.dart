import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimetableScreen extends StatefulWidget {
  @override
  _TimetableScreenState createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  DateTime _selectedDate = DateTime.now();
  final List<String> _koreanDays = ['월', '화', '수', '목', '금'];
  final List<String> _periodsData = ['1교시', '2교시', '3교시', '4교시', '5교시', '6교시', '7교시'];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            SizedBox(height: 16),
            _buildDateSelector(),
            SizedBox(height: 16),
            Expanded(
              child: _buildTimetable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // You can replace this with your actual logo
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: Color(0xFF0D47A1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '학교',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Text(
            '학교 시간표',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
            ),
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.notifications_none_outlined, 
                 color: Color(0xFF0D47A1)),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, 
                 color: Color(0xFF0D47A1)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    String formattedDate = '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일(${_getDayText()})';
    
    return Container(
      height: 48,
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: Color(0xFF0D47A1)),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(Duration(days: 1));
              });
            },
          ),
          Expanded(
            child: Center(
              child: Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: Color(0xFF0D47A1)),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(Duration(days: 1));
              });
            },
          ),
          Container(
            height: 24,
            width: 1,
            color: Colors.grey.withOpacity(0.3),
            margin: EdgeInsets.symmetric(horizontal: 4),
          ),
          IconButton(
            icon: Icon(Icons.calendar_today, color: Color(0xFF0D47A1)),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
    );
  }

  String _getDayText() {
    // Convert to Korean day (Monday=0, Sunday=6)
    int dayIndex = _selectedDate.weekday - 1;
    if (dayIndex >= 0 && dayIndex < 5) {
      return _koreanDays[dayIndex];
    } else if (dayIndex == 5) {
      return '토';
    } else {
      return '일';
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2026),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF0D47A1),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0D47A1),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF0D47A1),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildTimetable() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              _buildTimetableHeader(),
              Expanded(
                child: _buildTimetableBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimetableHeader() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Color(0xFF0D47A1),
      ),
      child: Row(
        children: [
          _buildHeaderCell('교시', isFirst: true),
          ...List.generate(5, (index) {
            return _buildHeaderCell(_koreanDays[index]);
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {bool isFirst = false}) {
    return Expanded(
      flex: isFirst ? 3 : 2,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimetableBody() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _periodsData.length,
      itemBuilder: (context, rowIndex) {
        return _buildTimetableRow(rowIndex);
      },
    );
  }

  Widget _buildTimetableRow(int rowIndex) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1),
        ),
        color: rowIndex.isEven ? Color(0xFFF5F7FA) : Colors.white,
      ),
      child: Row(
        children: [
          _buildPeriodCell(_periodsData[rowIndex]),
          ...List.generate(5, (dayIndex) {
            return _buildLessonCell(rowIndex, dayIndex);
          }),
        ],
      ),
    );
  }

  Widget _buildPeriodCell(String text) {
    return Expanded(
      flex: 3,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Color(0xFFEBF3F5),
          border: Border(
            right: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1),
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: Color(0xFF0D47A1),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLessonCell(int rowIndex, int dayIndex) {
    // 5교시까지만 수업이 있다고 가정 (주말 체크 제거)
    final bool hasLesson = rowIndex < 5;
    
    if (!hasLesson) {
      return Expanded(
        flex: 2,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1),
            ),
          ),
        ),
      );
    }
    
    // Sample lesson data
    final List<String> subjects = ['수학', '국어', '영어', '과학', '사회', '음악', '체육', '미술', '역사'];
    final List<String> teachers = ['김선생', '이선생', '박선생', '정선생', '최선생'];
    final List<String> rooms = ['1-1', '1-2', '1-3', '2-1', '2-2', '3-1', '3-2'];
    
    final String subject = subjects[(rowIndex * 3 + dayIndex) % subjects.length];
    final String teacher = teachers[(rowIndex + dayIndex) % teachers.length];
    final String room = rooms[(rowIndex * 2 + dayIndex) % rooms.length];
    
    return Expanded(
      flex: 2,
      child: Container(
        padding: EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                subject,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2),
              Text(
                teacher,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  room,
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}