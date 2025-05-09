import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MealScreen extends StatefulWidget {
  @override
  _MealScreenState createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  late DateTime _selectedDate;
  late List<DateTime> _weekDays;
  final List<String> _koreanDays = ['월', '화', '수', '목', '금'];
  
  // 식사 유형 순서와 표시명 (MMEAL_SC_CODE 기준)
  final Map<String, String> _mealTypeMap = {
    '1': '조식',
    '2': '중식',
    '3': '석식'
  };
  
  // NEIS API 관련 변수
  final String _apiKey = "d07f995a158c46b4abd01cf3acc903d9";
  final String _eduOfficeCode = "N10"; // 교육청 코드 
  final String _schoolCode = "8140070";
    // 급식 데이터 저장 변수 - 2차원 맵으로 [날짜][식사코드] 형식으로 저장
  Map<String, Map<String, List<String>>> _mealData = {};
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _weekDays = _getWeekDays(_selectedDate);
    _fetchMealData();
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
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0D47A1),
                      ),
                    )
                  : _buildScrollableMealTable(),
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
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: AssetImage('assets/images/logo.jpg'),
                fit: BoxFit.cover, // 로고를 박스 크기에 맞게 조절
              ),
            ),
          ),

            SizedBox(width: 12),
            Text(
              '천안중앙고등학교 급식표',
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

  // 급식 데이터 가져오기
  Future<void> _fetchMealData() async {
    setState(() {
      _isLoading = true;
      _mealData = {}; // 데이터 초기화
    });
    
    try {
      // 월요일부터 금요일까지의 날짜 범위
      String fromDate = DateFormat('yyyyMMdd').format(_weekDays.first);
      String toDate = DateFormat('yyyyMMdd').format(_weekDays.last);
      
      // API 파라미터 설정
      final Map<String, String> params = {
        'KEY': _apiKey,
        'Type': 'json',
        'pIndex': '1',
        'pSize': '100',
        'ATPT_OFCDC_SC_CODE': _eduOfficeCode,
        'SD_SCHUL_CODE': _schoolCode,
        'MLSV_FROM_YMD': fromDate,
        'MLSV_TO_YMD': toDate
      };
      
      // URI 구성
      Uri uri = Uri.https('open.neis.go.kr', '/hub/mealServiceDietInfo', params);
      print('API 요청 URL: ${uri.toString()}');
      
      // API 요청
      var response = await http.get(uri);
      
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        
        
        // 응답에 RESULT 객체가 있는지 확인 (데이터 없음 응답인 경우)
        if (data.containsKey('RESULT') && data['RESULT']['CODE'] == 'INFO-200') {
          print('급식 데이터 없음: ${data['RESULT']['MESSAGE']}');
          setState(() {
            _mealData = {};
            _isLoading = false;
          });
          
          // 데이터 없음 알림
          _showNoDataSnackbar();
          return;
        }
        
        // 데이터가 있는 경우 정상 처리
        if (data['mealServiceDietInfo'] != null && data['mealServiceDietInfo'][1]['row'] != null) {
          // 급식 데이터 구성
          List<dynamic> meals = data['mealServiceDietInfo'][1]['row'];
          Map<String, Map<String, List<String>>> newMealData = {};
          
          for (var meal in meals) {
            // 급식일자 처리 (YYYYMMDD 형식으로 통일)
            String dateStr = meal['MLSV_YMD'] ?? '';
            // 하이픈 제거 (YYYY-MM-DD → YYYYMMDD)
            dateStr = dateStr.replaceAll('-', '');
            
            // 식사코드 (1: 조식, 2: 중식, 3: 석식)
            String mealCode = meal['MMEAL_SC_CODE'] ?? '';
            
            // 요리명
            String dishNames = meal['DDISH_NM'] ?? '';
            
            // 날짜별 맵 초기화
            if (!newMealData.containsKey(dateStr)) {
              newMealData[dateStr] = {};
            }
            
            // 요리명 분리 (요리명은 보통 <br/>로 구분됨)
            List<String> dishes = [];
            if (dishNames.contains('<br/>')) {
              dishes = dishNames.split('<br/>');
            } else {
              dishes = [dishNames];
            }
            dishes = dishes.map((dish) => dish.trim()).toList();
            
            // 데이터 저장 (식사코드를 키로 사용)
            newMealData[dateStr]![mealCode] = dishes;
          }
          
          setState(() {
            _mealData = newMealData;
            _isLoading = false;
          });
          
          // 결과 로깅
          print('파싱된 급식 데이터: $_mealData');
        } else {
          // 급식 데이터가 없을 경우 빈 맵 설정
          setState(() {
            _mealData = {};
            _isLoading = false;
          });
          _showNoDataSnackbar();
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        print('API 오류: ${response.statusCode}');
        _showErrorSnackbar('API 오류: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('데이터 가져오기 실패: $e');
      _showErrorSnackbar('데이터 가져오기 실패: $e');
    }
  }
  
  // 날짜를 문자열로 변환 (YYYYMMDD 형식)
  String _formatDateToString(DateTime date) {
    return DateFormat('yyyyMMdd').format(date);
  }
  
  // 데이터 없음 알림 Snackbar
  void _showNoDataSnackbar() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // 이전 Snackbar 닫기
    scaffoldMessenger.hideCurrentSnackBar();
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          '해당 기간의 급식 데이터가 없습니다.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xFF0D47A1),
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: '확인',
          textColor: Colors.white,
          onPressed: () {
            scaffoldMessenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  // 오류 알림 Snackbar
  void _showErrorSnackbar(String message) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // 이전 Snackbar 닫기
    scaffoldMessenger.hideCurrentSnackBar();
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red[700],
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: '확인',
          textColor: Colors.white,
          onPressed: () {
            scaffoldMessenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
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
              _fetchMealData();
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
              _fetchMealData();
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
      _fetchMealData();
    }
  }

  // 스크롤 가능한 급식표 구현
  Widget _buildScrollableMealTable() {
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
        child: Column(
          children: [
            // 헤더 (날짜)
            _buildTableHeader(),
            
            // 구분선
            Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.2)),
            
            // 스크롤 가능한 본문 (식사 유형별 데이터)
            Expanded(
              child: _buildScrollableTableBody(),
            ),
          ],
        ),
      ),
    );
  }

  // 테이블 헤더 (날짜)
  Widget _buildTableHeader() {
    return Container(
      height: 50,
      color: Color(0xFF0D47A1),
      child: Row(
        children: [
          // 식사 유형 셀
          Container(
            width: 80, // 식사 유형 셀 너비 증가
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
            ),
            child: Center(
              child: Text(
                '구분',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          
          // 날짜 셀 (월~금)
          Expanded(
            child: Row(
              children: List.generate(5, (index) {
                String dayText = '${_koreanDays[index]}';
                String dateText = '${_formatDayNumber(_weekDays[index])}';
                bool isToday = _isToday(_weekDays[index]);
                
                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: index < 4 
                              ? Colors.white.withOpacity(0.2) 
                              : Colors.transparent,
                        ),
                      ),
                      color: isToday ? Color(0xFF1565C0) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayText,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          dateText,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // 스크롤 가능한 테이블 본문
  Widget _buildScrollableTableBody() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _mealTypeMap.length,
      itemBuilder: (context, index) {
        String mealCode = (index + 1).toString(); // 1: 조식, 2: 중식, 3: 석식
        String mealType = _mealTypeMap[mealCode] ?? '기타';
        
        return Column(
          children: [
            _buildMealRow(mealCode, mealType),
            if (index < _mealTypeMap.length - 1)
              Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.1)),
          ],
        );
      },
    );
  }

  // 식사 유형별 행
  Widget _buildMealRow(String mealCode, String mealType) {
    // 각 요일별 최대 메뉴 항목 수 구하기
    List<int> menuCounts = [];
    for (int dayIndex = 0; dayIndex < 5; dayIndex++) {
      String dateKey = _formatDateToString(_weekDays[dayIndex]);
      if (_mealData.containsKey(dateKey) && _mealData[dateKey]!.containsKey(mealCode)) {
        menuCounts.add(_mealData[dateKey]![mealCode]!.length);
      } else {
        menuCounts.add(0);
      }
    }
    
    int maxItems = menuCounts.isNotEmpty ? menuCounts.reduce((a, b) => a > b ? a : b) : 0;
    double rowHeight = max(100.0, 20.0 + maxItems * 22.0);
    
    return Container(
      height: rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 식사 유형 셀
          Container(
            width: 80, // 식사 유형 셀 너비 증가
            decoration: BoxDecoration(
              color: Color(0xFFEBF3F5),
              border: Border(
                right: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
            ),
            child: Center(
              child: Text(
                mealType,
                style: TextStyle(
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          
          // 각 요일별 급식 데이터
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(5, (dayIndex) {
                return Expanded(
                  child: _buildDayMealCell(mealCode, dayIndex),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // 특정 요일, 특정 식사의 셀
  Widget _buildDayMealCell(String mealCode, int dayIndex) {
    DateTime cellDate = _weekDays[dayIndex];
    String dateKey = _formatDateToString(cellDate);
    bool isToday = _isToday(cellDate);
    bool hasRightBorder = dayIndex < 4;
    
    // API에서 가져온 데이터가 있는지 확인
    if (_mealData.containsKey(dateKey) && _mealData[dateKey]!.containsKey(mealCode)) {
      List<String> meals = _mealData[dateKey]![mealCode]!;
      
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: isToday ? Color(0xFFECF3FB) : null,
          border: Border(
            right: BorderSide(
              color: hasRightBorder ? Colors.grey.withOpacity(0.2) : Colors.transparent,
            ),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ...meals.map((menu) => 
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    menu,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: menu == meals.first ? FontWeight.w600 : FontWeight.normal,
                      color: menu == meals.first 
                          ? Colors.black.withOpacity(0.8) 
                          : Colors.black.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              ).toList(),
            ],
          ),
        ),
      );
    } else {
      // 데이터가 없는 경우 '급식 정보 없음' 표시
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isToday ? Color(0xFFECF3FB) : null,
          border: Border(
            right: BorderSide(
              color: hasRightBorder ? Colors.grey.withOpacity(0.2) : Colors.transparent,
            ),
          ),
        ),
        child: Center(
          child: Text(
            '급식 정보 없음',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  String _formatDayNumber(DateTime date) {
    return '${date.month}/${date.day}';
  }

  bool _isToday(DateTime date) {
    DateTime now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  // 최대값 계산 helper 함수
  double max(double a, double b) {
    return a > b ? a : b;
  }
}