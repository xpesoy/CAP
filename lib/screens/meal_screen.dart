// 1. 먼저 SharedPreferences를 사용하기 위한 의존성을 pubspec.yaml에 추가
// shared_preferences: ^2.2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// 2. 알레르기 정보를 담은 클래스 추가
class AllergyInfo {
  static const Map<int, String> allergyMap = {
    1: '난류',
    2: '우유',
    3: '메밀',
    4: '땅콩',
    5: '대두',
    6: '밀',
    7: '고등어',
    8: '게',
    9: '새우',
    10: '돼지고기',
    11: '복숭아',
    12: '토마토',
    13: '아황산류',
    14: '호두',
    15: '닭고기',
    16: '쇠고기',
    17: '오징어',
    18: '조개류',
  };
  
  // 알레르기 번호로부터 알레르기명 가져오기
  static String getAllergyName(int code) {
    return allergyMap[code] ?? '기타';
  }
  
  // 텍스트에서 알레르기 번호 추출
  static List<int> extractAllergyCodes(String menuText) {
    List<int> codes = [];
    
    // 괄호 안의 숫자 추출 정규식
    RegExp regExp = RegExp(r'\(([0-9\.\s]+)\)');
    Match? match = regExp.firstMatch(menuText);
    
    if (match != null && match.groupCount >= 1) {
      String allergyText = match.group(1) ?? '';
      List<String> allergyStrings = allergyText.split('.');
      
      for (String code in allergyStrings) {
        try {
          int allergyCode = int.parse(code.trim());
          codes.add(allergyCode);
        } catch (e) {
          // 숫자가 아닌 경우 무시
        }
      }
    }
    
    return codes;
  }
}

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
  
  // 알레르기 관련 변수 추가
  Set<int> _selectedAllergies = {};
  
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _weekDays = _getWeekDays(_selectedDate);
    _loadAllergySettings();
    _fetchMealData();
  }
  
  // 알레르기 설정 로드
  Future<void> _loadAllergySettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedAllergies = Set<int>.from(
        prefs.getStringList('selected_allergies')?.map((e) => int.parse(e)) ?? []
      );
    });
  }
  
  // 알레르기 설정 저장
  Future<void> _saveAllergySettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'selected_allergies', 
      _selectedAllergies.map((e) => e.toString()).toList()
    );
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
                fit: BoxFit.cover,
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
          // 알레르기 설정 아이콘 버튼 추가
          IconButton(
            icon: Icon(Icons.medical_services_outlined, 
                color: Color(0xFF0D47A1)),
            onPressed: () => _showAllergySettingsDialog(),
            tooltip: '알레르기 설정',
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

  // 알레르기 설정 다이얼로그
  Future<void> _showAllergySettingsDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        // 임시 선택 상태 저장
        Set<int> tempSelectedAllergies = Set.from(_selectedAllergies);
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.medical_services, color: Color(0xFF0D47A1)),
                  SizedBox(width: 8),
                  Text('알레르기 설정'),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '알레르기가 있는 항목을 선택하세요.',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 1,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (int i = 1; i <= 18; i++)
                              FilterChip(
                                label: Text(
                                  '${i}. ${AllergyInfo.getAllergyName(i)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: tempSelectedAllergies.contains(i) 
                                        ? Colors.white 
                                        : Colors.black87,
                                  ),
                                ),
                                selected: tempSelectedAllergies.contains(i),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      tempSelectedAllergies.add(i);
                                    } else {
                                      tempSelectedAllergies.remove(i);
                                    }
                                  });
                                },
                                selectedColor: Color(0xFF0D47A1),
                                backgroundColor: Colors.grey.withOpacity(0.1),
                                checkmarkColor: Colors.white,
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      height: 1,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '* 선택한 알레르기 항목이 포함된 메뉴는 빨간색으로 표시됩니다.',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('취소'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: Text('저장'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0D47A1),
                  ),
                  onPressed: () {
                    // 메인 상태 업데이트
                    this.setState(() {
                      _selectedAllergies = tempSelectedAllergies;
                    });
                    
                    // 설정 저장
                    _saveAllergySettings();
                    
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
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
              ...meals.map((menu) {
                // 알레르기 코드 추출
                List<int> allergyCodes = AllergyInfo.extractAllergyCodes(menu);
                
                // 알레르기 포함 여부 확인
                bool containsSelectedAllergy = allergyCodes.any((code) => _selectedAllergies.contains(code));
                
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    menu,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: menu == meals.first ? FontWeight.w600 : FontWeight.normal,
                      color: containsSelectedAllergy 
                          ? Colors.red 
                          : (menu == meals.first 
                              ? Colors.black.withOpacity(0.8) 
                              : Colors.black.withOpacity(0.7)),
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }).toList(),
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

  // 알레르기 정보 아이콘
  Widget _buildAllergyLegend() {
    if (_selectedAllergies.isEmpty) return SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          Icon(Icons.info_outline, size: 16, color: Colors.red),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '빨간색으로 표시된 메뉴는 설정한 알레르기 유발 성분을 포함하고 있습니다.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
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

// 알레르기 정보 카드 UI
class AllergyInfoCard extends StatelessWidget {
  final Set<int> selectedAllergies;
  
  const AllergyInfoCard({Key? key, required this.selectedAllergies}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (selectedAllergies.isEmpty) return SizedBox.shrink();
    
    // 선택된 알레르기 정보만 표시
    List<Widget> allergyTags = selectedAllergies.map((code) {
      return Container(
        margin: EdgeInsets.only(right: 8, bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Text(
          '${code}. ${AllergyInfo.getAllergyName(code)}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.red,
          ),
        ),
      );
    }).toList();
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text(
                '선택한 알레르기 성분',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Wrap(
            children: allergyTags,
          ),
        ],
      ),
    );
  }
}