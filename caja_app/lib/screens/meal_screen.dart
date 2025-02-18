import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MealScreen extends StatefulWidget {
  @override
  _MealScreenState createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  late DateTime _selectedDate;
  late List<DateTime> _weekDays;
  final List<String> _koreanDays = ['월', '화', '수', '목', '금'];
  final List<String> _mealTypes = ['조식', '중식', '석식'];
  
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _weekDays = _getWeekDays(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            SizedBox(height: 16),
            _buildWeekSelector(),
            SizedBox(height: 16),
            Expanded(
              child: _buildMealTable(),
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
            '학교 급식표',
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

  List<DateTime> _getWeekDays(DateTime date) {
    // 주어진 날짜의 요일을 확인 (월: 1, 화: 2, ... 일: 7)
    int weekday = date.weekday;
    
    // 해당 주의 월요일 계산
    DateTime monday = date.subtract(Duration(days: weekday - 1));
    
    // 월요일부터 금요일까지의 날짜 리스트 생성
    List<DateTime> weekDays = List.generate(
      5, 
      (index) => monday.add(Duration(days: index))
    );
    
    return weekDays;
  }

  // 토/일요일 처리 (가장 가까운 주로 이동)
  DateTime _handleWeekendSelection(DateTime date) {
    if (date.weekday == 6) { // 토요일
      return date.add(Duration(days: 2)); // 다음주 월요일
    } else if (date.weekday == 7) { // 일요일
      return date.add(Duration(days: 1)); // 다음주 월요일
    }
    return date;
  }

  Widget _buildWeekSelector() {
    String formattedPeriod = '${_formatDate(_weekDays.first)} ~ ${_formatDate(_weekDays.last)}';
    
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
                _selectedDate = _weekDays.first.subtract(Duration(days: 7));
                _weekDays = _getWeekDays(_selectedDate);
              });
            },
          ),
          Expanded(
            child: Center(
              child: Text(
                formattedPeriod,
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
                _selectedDate = _weekDays.last.add(Duration(days: 3)); // 금요일 + 3일 = 다음 주 월요일
                _weekDays = _getWeekDays(_selectedDate);
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

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
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
    if (picked != null) {
      setState(() {
        // 토/일요일인 경우 처리
        _selectedDate = _handleWeekendSelection(picked);
        _weekDays = _getWeekDays(_selectedDate);
      });
    }
  }

  Widget _buildMealTable() {
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
              _buildMealTableHeader(),
              Expanded(
                child: _buildMealTableBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealTableHeader() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Color(0xFF0D47A1),
      ),
      child: Row(
        children: [
          _buildHeaderCell('구분', isFirst: true),
          ...List.generate(5, (index) {
            String headerText = '${_koreanDays[index]}\n${_formatDayNumber(_weekDays[index])}';
            return _buildHeaderCell(headerText);
          }),
        ],
      ),
    );
  }

  String _formatDayNumber(DateTime date) {
    return '${date.month}/${date.day}';
  }

  Widget _buildHeaderCell(String text, {bool isFirst = false}) {
    return Expanded(
      flex: isFirst ? 3 : 4,
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
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildMealTableBody() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _mealTypes.length,
      itemBuilder: (context, rowIndex) {
        return _buildMealTableRow(rowIndex);
      },
    );
  }

  Widget _buildMealTableRow(int rowIndex) {
    return Container(
      height: rowIndex == 1 ? 120 : 100,  // 중식 칸을 더 크게 만듦
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1),
        ),
        color: rowIndex.isEven ? Color(0xFFF5F7FA) : Colors.white,
      ),
      child: Row(
        children: [
          _buildMealTypeCell(_mealTypes[rowIndex]),
          ...List.generate(5, (dayIndex) {
            return _buildMealCell(rowIndex, dayIndex);
          }),
        ],
      ),
    );
  }

  Widget _buildMealTypeCell(String text) {
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

  Widget _buildMealCell(int mealTypeIndex, int dayIndex) {
    DateTime cellDate = _weekDays[dayIndex];
    final meals = _getSampleMeals(mealTypeIndex, dayIndex);
    final bool hasAllergyInfo = meals.length > 2 && mealTypeIndex == 1; // 중식에만 알러지 정보 표시
    
    // 현재 날짜인지 확인
    final bool isToday = _isToday(cellDate);
    
    return Expanded(
      flex: 4,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isToday ? Color(0xFFECF3FB) : null,
          border: Border(
            right: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ...meals.map((menu) => 
              Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  menu,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: menu == meals.first ? FontWeight.w500 : FontWeight.normal,
                    color: menu == meals.first 
                        ? Colors.black.withOpacity(0.8) 
                        : Colors.black.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            ).toList(),
            if (hasAllergyInfo)
              Container(
                margin: EdgeInsets.only(top: 4),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "알러지: 1,5,6",
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  bool _isToday(DateTime date) {
    DateTime now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
  
  List<String> _getSampleMeals(int mealTypeIndex, int dayIndex) {
    final breakfastMenus = [
      ["백미밥", "미역국", "계란말이"],
      ["흑미밥", "김치찌개", "멸치볶음"],
      ["잡곡밥", "북어국", "애호박볶음"],
      ["백미밥", "콩나물국", "진미채볶음"],
      ["보리밥", "된장찌개", "무생채"],
    ];
    
    final lunchMenus = [
      ["백미밥", "육개장", "야채튀김", "배추김치", "요구르트"],
      ["짜장밥", "계란국", "단무지", "깍두기", "바나나"],
      ["김치볶음밥", "미소국", "만두", "열무김치", "사과"],
      ["백미밥", "부대찌개", "감자전", "배추김치", "수박"],
      ["비빔밥", "콩나물국", "잡채", "총각김치", "딸기"],
    ];
    
    final dinnerMenus = [
      ["백미밥", "시금치국", "고등어구이"],
      ["현미밥", "청국장", "두부조림"],
      ["백미밥", "감자국", "불고기"],
      ["잡곡밥", "미역국", "오징어볶음"],
      ["백미밥", "어묵탕", "제육볶음"],
    ];
    
    switch (mealTypeIndex) {
      case 0: return breakfastMenus[dayIndex];
      case 1: return lunchMenus[dayIndex];
      case 2: return dinnerMenus[dayIndex];
      default: return [];
    }
  }
}