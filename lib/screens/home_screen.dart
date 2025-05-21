import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  // 탭 선택 콜백 함수
  final Function(int)? onTabSelected;
  
  HomeScreen({this.onTabSelected});
  
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingTimetable = true;
  bool _isLoadingMeal = true;
  
  // 시간표 관련 변수
  Map<String, dynamic> _todayTimetable = {};
  
  // 급식 관련 변수
  List<String> _todayLunch = [];
  String _allergyInfo = '';
  Set<int> _selectedAllergies = {};
  
  // NEIS API 관련 변수
  final String _apiKey = "d07f995a158c46b4abd01cf3acc903d9";
  final String _eduOfficeCode = "N10";
  final String _schoolCode = "8140070";
  
  // 학년 및 반 정보
  int _selectedGrade = 1;
  String _selectedClass = "1";
  bool _isCustomTimetable = false;
  Map<String, Map<String, String>> _customTimetable = {};
  
  // 한글 요일
  final List<String> _koreanDays = ['월', '화', '수', '목', '금'];
  
  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _loadAllergySettings();
    _loadCustomTimetable();
  }
  
  // 사용자 설정 로드
  Future<void> _loadUserPreferences() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedGrade = prefs.getInt('grade') ?? 1;
        _selectedClass = prefs.getString('class') ?? "1";
        _isCustomTimetable = prefs.getBool('is_custom_timetable') ?? false;
      });
      
      // 사용자 설정을 로드한 후, 데이터 가져오기
      _fetchTodayData();
    } catch (e) {
      print('사용자 설정 로드 실패: $e');
      // 기본값으로 데이터 가져오기
      _fetchTodayData();
    }
  }
  
  // 커스텀 시간표 로드
  Future<void> _loadCustomTimetable() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, Map<String, String>> customData = {};
      
      for (String day in _koreanDays) {
        customData[day] = {};
        for (int i = 1; i <= 7; i++) {
          String period = i.toString();
          String? savedSubject = prefs.getString('custom_${day}_$period');
          if (savedSubject != null) {
            customData[day]![period] = savedSubject;
          } else {
            customData[day]![period] = '';
          }
        }
      }
      
      setState(() {
        _customTimetable = customData;
      });
      
      // 3학년이고 커스텀 모드인 경우 커스텀 시간표 표시
      if (_selectedGrade == 3 && _isCustomTimetable) {
        _processTodayCustomTimetable();
      }
    } catch (e) {
      print('커스텀 시간표 로드 실패: $e');
    }
  }
  
  // 오늘 날짜의 커스텀 시간표 처리
  void _processTodayCustomTimetable() {
    // 오늘 요일 구하기
    DateTime today = DateTime.now();
    String koreanDay = _getKoreanDayOfWeek(today);
    
    // 주말인 경우 처리
    if (koreanDay == '토' || koreanDay == '일') {
      setState(() {
        _todayTimetable = {};
        _isLoadingTimetable = false;
      });
      return;
    }
    
    // 오늘 요일의 커스텀 시간표 가져오기
    Map<String, dynamic> todayLessons = {};
    
    if (_customTimetable.containsKey(koreanDay)) {
      _customTimetable[koreanDay]!.forEach((period, subject) {
        if (subject.isNotEmpty) {
          todayLessons[period] = {
            'subject': subject,
            'room': '${_selectedGrade}-${_selectedClass}'
          };
        }
      });
    }
    
    setState(() {
      _todayTimetable = todayLessons;
      _isLoadingTimetable = false;
    });
  }
  
  // 알레르기 설정 로드
  Future<void> _loadAllergySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedAllergies = Set<int>.from(
          prefs.getStringList('selected_allergies')?.map((e) => int.parse(e)) ?? []
        );
      });
    } catch (e) {
      print('알레르기 설정 로드 실패: $e');
    }
  }
  
  // 오늘의 데이터(시간표, 급식) 가져오기
  Future<void> _fetchTodayData() async {
    // 3학년이고 커스텀 모드인 경우 API를 호출하지 않고 커스텀 시간표 표시
    if (_selectedGrade == 3 && _isCustomTimetable) {
      _processTodayCustomTimetable();
    } else {
      _fetchTodayTimetable();
    }
    
    _fetchTodayMeal();
  }
  
  // 오늘의 시간표 가져오기
  Future<void> _fetchTodayTimetable() async {
    setState(() {
      _isLoadingTimetable = true;
    });
    
    try {
      // 오늘 날짜
      DateTime today = DateTime.now();
      
      // 주말인 경우 빈 데이터 반환
      if (today.weekday > 5) {
        setState(() {
          _todayTimetable = {};
          _isLoadingTimetable = false;
        });
        return;
      }
      
      String formattedDate = DateFormat('yyyyMMdd').format(today);
      
      // 먼저 캐시된 데이터가 있는지 확인
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String cacheKey = 'api_response_${_selectedGrade}_${_selectedClass}_$formattedDate';
      String? cachedData = prefs.getString(cacheKey);
      
      if (cachedData != null) {
        // 캐시된 데이터가 있으면 사용
        _processTimetableData(json.decode(cachedData), formattedDate);
        return;
      }
      
      // 이번 주 월요일과 금요일 계산
      int weekday = today.weekday; // 1: 월요일, 7: 일요일
      DateTime mondayOfWeek = today.subtract(Duration(days: weekday - 1));
      DateTime fridayOfWeek = mondayOfWeek.add(Duration(days: 4));
      
      String fromDate = DateFormat('yyyyMMdd').format(mondayOfWeek);
      String toDate = DateFormat('yyyyMMdd').format(fridayOfWeek);
      
      // API 요청 파라미터
      final Map<String, String> params = {
        'KEY': _apiKey,
        'ATPT_OFCDC_SC_CODE': _eduOfficeCode,
        'SD_SCHUL_CODE': _schoolCode,
        'GRADE': _selectedGrade.toString(),
        'CLASS_NM': _selectedClass,
        'TI_FROM_YMD': fromDate,
        'TI_TO_YMD': toDate,
        'Type': 'json'
      };
      
      // 학기 설정
      final int currentMonth = today.month;
      String semester = (currentMonth >= 3 && currentMonth <= 8) ? '1' : '2';
      params['AY'] = today.year.toString();
      params['SEM'] = semester;
      
      // API 요청
      Uri uri = Uri.https('open.neis.go.kr', '/hub/hisTimetable', params);
      var response = await http.get(uri);
      
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        
        // 응답 데이터 캐싱
        prefs.setString(cacheKey, response.body);
        
        // 데이터 처리
        _processTimetableData(data, formattedDate);
      } else {
        setState(() {
          _todayTimetable = {};
          _isLoadingTimetable = false;
        });
        print('시간표 API 오류: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _todayTimetable = {};
        _isLoadingTimetable = false;
      });
      print('시간표 데이터 가져오기 실패: $e');
    }
  }
  
  // 시간표 데이터 처리
  void _processTimetableData(dynamic data, String formattedDate) {
    try {
      // 데이터가 있는 경우
      if (data.containsKey('hisTimetable') && 
          data['hisTimetable'] != null && 
          data['hisTimetable'][1]['row'] != null) {
        
        Map<String, dynamic> todayLessons = {};
        
        for (var item in data['hisTimetable'][1]['row']) {
          // 날짜 확인 (오늘 날짜와 일치하는지)
          String itemDate = item['ALL_TI_YMD'] ?? '';
          if (itemDate == formattedDate) {
            int period = int.parse(item['PERIO']);
            String subject = item['ITRT_CNTNT'];
            String room = item['CLRM_NM'] ?? '미정';
            
            // 2학년이고 제2외국어 과목인 경우 처리
            if (_selectedGrade == 2) {
              subject = _convertSecondLanguageSubject(subject);
            }
            
            todayLessons[period.toString()] = {
              'subject': subject,
              'room': room
            };
          }
        }
        
        setState(() {
          _todayTimetable = todayLessons;
          _isLoadingTimetable = false;
        });
      } else {
        setState(() {
          _todayTimetable = {};
          _isLoadingTimetable = false;
        });
      }
    } catch (e) {
      setState(() {
        _todayTimetable = {};
        _isLoadingTimetable = false;
      });
      print('시간표 데이터 처리 실패: $e');
    }
  }
  
  // 제2외국어 과목 이름 변환 (2학년용)
  String _convertSecondLanguageSubject(String subject) {
    if (_selectedGrade != 2) return subject;
    
    try {
      SharedPreferences prefs = SharedPreferences.getInstance() as SharedPreferences;
      String selectedLanguage = prefs.getString('subject_제2외국어') ?? "일본어";
      
      // 정확한 패턴 매칭을 위한 다양한 케이스 처리
      if (selectedLanguage == "일본어") {
        if (subject.contains('중국어I')) {
          return subject.replaceAll('중국어I', '일본어I');
        } else if (subject == '중국어') {
          return '일본어';
        } else if (subject.contains('중국어 I')) {
          return subject.replaceAll('중국어 I', '일본어 I');
        } else if (subject == '제2외국어') {
          return '일본어I';
        }
      } else if (selectedLanguage == "중국어") {
        if (subject.contains('일본어I')) {
          return subject.replaceAll('일본어I', '중국어I');
        } else if (subject == '일본어') {
          return '중국어';
        } else if (subject.contains('일본어 I')) {
          return subject.replaceAll('일본어 I', '중국어 I');
        } else if (subject == '제2외국어') {
          return '중국어I';
        }
      }
    } catch (e) {
      print('제2외국어 변환 실패: $e');
    }
    
    return subject;
  }
  
  // 오늘의 급식(중식만) 가져오기
  Future<void> _fetchTodayMeal() async {
    setState(() {
      _isLoadingMeal = true;
    });
    
    try {
      // 오늘 날짜
      DateTime today = DateTime.now();
      String formattedDate = DateFormat('yyyyMMdd').format(today);
      
      // API 요청 파라미터
      final Map<String, String> params = {
        'KEY': _apiKey,
        'Type': 'json',
        'pIndex': '1',
        'pSize': '100',
        'ATPT_OFCDC_SC_CODE': _eduOfficeCode,
        'SD_SCHUL_CODE': _schoolCode,
        'MLSV_YMD': formattedDate
      };
      
      // API 요청
      Uri uri = Uri.https('open.neis.go.kr', '/hub/mealServiceDietInfo', params);
      var response = await http.get(uri);
      
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        
        // 데이터가 있는 경우
        if (data.containsKey('mealServiceDietInfo') && 
            data['mealServiceDietInfo'] != null && 
            data['mealServiceDietInfo'][1]['row'] != null) {
          
          List<dynamic> meals = data['mealServiceDietInfo'][1]['row'];
          List<String> lunchMenu = [];
          String allergyData = '';
          
          for (var meal in meals) {
            // 중식 데이터만 추출 (MMEAL_SC_CODE: 2는 중식)
            if (meal['MMEAL_SC_CODE'] == '2') {
              String dishNames = meal['DDISH_NM'] ?? '';
              List<String> dishes = [];
              
              if (dishNames.contains('<br/>')) {
                dishes = dishNames.split('<br/>');
              } else {
                dishes = [dishNames];
              }
              dishes = dishes.map((dish) => dish.trim()).toList();
              
              lunchMenu = dishes;
              
              // 알러지 정보 추출
              // 중식 메뉴에서 (1.5.6) 과 같은 형태로 알러지 정보 추출
              RegExp regExp = RegExp(r'\(([0-9\.\s]+)\)');
              Iterable<RegExpMatch> matches = regExp.allMatches(dishNames);
              List<String> allergyNumbers = [];
              
              for (var match in matches) {
                if (match.groupCount >= 1) {
                  String allergyText = match.group(1) ?? '';
                  List<String> numbers = allergyText.split('.');
                  allergyNumbers.addAll(numbers);
                }
              }
              
              if (allergyNumbers.isNotEmpty) {
                allergyData = '알러지: ${allergyNumbers.join(',')}';
              }
              
              break; // 중식 데이터를 찾았으면 반복 종료
            }
          }
          
          setState(() {
            _todayLunch = lunchMenu;
            _allergyInfo = allergyData;
            _isLoadingMeal = false;
          });
        } else {
          setState(() {
            _todayLunch = [];
            _allergyInfo = '';
            _isLoadingMeal = false;
          });
        }
      } else {
        setState(() {
          _todayLunch = [];
          _allergyInfo = '';
          _isLoadingMeal = false;
        });
        print('급식 API 오류: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _todayLunch = [];
        _allergyInfo = '';
        _isLoadingMeal = false;
      });
      print('급식 데이터 가져오기 실패: $e');
    }
  }
  
  // 요일 숫자를 한글 요일로 변환
  String _getKoreanDayOfWeek(DateTime date) {
    final List<String> koreanDays = ['월', '화', '수', '목', '금', '토', '일'];
    int dayIndex = date.weekday - 1; // 1 (월요일) ~ 7 (일요일)
    
    if (dayIndex >= 0 && dayIndex < koreanDays.length) {
      return koreanDays[dayIndex];
    }
    return '';
  }
  
  // 텍스트에서 알레르기 코드 추출
  List<int> _extractAllergyCodes(String menuText) {
    List<int> codes = [];
    
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: _buildHomeContent(),
              ),
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
            '천안중앙고등학교 홈',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
            ),
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.notifications_none_outlined, color: Color(0xFF0D47A1)),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: Color(0xFF0D47A1)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 왼쪽 - 오늘의 시간표
        Expanded(
          child: _buildTodayTimetable(),
        ),
        
        SizedBox(width: 16),
        
        // 오른쪽 - 오늘의 급식 (중식만)
        Expanded(
          child: _buildTodayLunch(),
        ),
      ],
    );
  }

  Widget _buildTodayTimetable() {
    return Container(
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
          // 헤더
          Container(
            height: 50,
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Color(0xFF0D47A1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.white),
                SizedBox(width: 8),
                Row(
                  children: [
                    Text(
                      '오늘의 시간표',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$_selectedGrade학년 $_selectedClass반',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Spacer(),
                GestureDetector(
                  onTap: () {
                    // 시간표 화면으로 이동
                    if (widget.onTabSelected != null) {
                      widget.onTabSelected!(1);
                    }
                  },
                  child: Text(
                    '전체보기',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          
          // 시간표 내용
          Expanded(
            child: _isLoadingTimetable
              ? Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF0D47A1),
                  ),
                )
              : _todayTimetable.isEmpty
                ? Center(
                    child: Text(
                      '오늘은 시간표가 없습니다.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(12),
                    itemCount: 7, // 최대 7교시
                    itemBuilder: (context, index) {
                      String period = (index + 1).toString();
                      bool hasLesson = _todayTimetable.containsKey(period);
                      
                      return Container(
                        height: 48,
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: index.isEven ? Color(0xFFF5F7FA) : Colors.white,
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              decoration: BoxDecoration(
                                color: Color(0xFFEBF3F5),
                                borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}교시',
                                  style: TextStyle(
                                    color: Color(0xFF0D47A1),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: hasLesson
                                  ? Row(
                                      children: [
                                        Text(
                                          _todayTimetable[period]['subject'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Spacer(),
                                        Text(
                                          _todayTimetable[period]['room'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF0D47A1),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Center(
                                      child: Text(
                                        '-',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayLunch() {
    return Container(
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
          // 헤더
          Container(
            height: 50,
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Color(0xFF0D47A1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.restaurant, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  '오늘의 급식',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () {
                    // 급식 화면으로 이동
                    if (widget.onTabSelected != null) {
                      widget.onTabSelected!(2);
                    }
                  },
                  child: Text(
                    '전체보기',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          
          // 중식 정보
          Expanded(
            child: _isLoadingMeal
              ? Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF0D47A1),
                  ),
                )
              : _todayLunch.isEmpty
                ? Center(
                    child: Text(
                      '오늘의 급식 정보가 없습니다.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 중식 헤더
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFFEBF3F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '중식',
                                style: TextStyle(
                                  color: Color(0xFF0D47A1),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              // 알레르기 정보 표시 부분 제거
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 16),
                        
                        // 메뉴 목록
                        ..._todayLunch.map<Widget>((item) {
                          List<int> allergyCodes = _extractAllergyCodes(item);
                          bool containsSelectedAllergy = allergyCodes.any((code) => _selectedAllergies.contains(code));
                          
                          return Container(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            margin: EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.circle, size: 8, color: Color(0xFF0D47A1)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: containsSelectedAllergy ? Colors.red : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                              ),
                          );
                        }).toList(),
                        
                        // 날짜 정보
                        SizedBox(height: 16),
                        Center(
                          child: Text(
                            '${DateFormat('yyyy년 MM월 dd일').format(DateTime.now())}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
  // async method 내에서 SharedPreferences가 Future를 반환하는 문제를 해결하기 위한 helper 메소드
  Future<String> _getSecondLanguage() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('subject_제2외국어') ?? "일본어";
    } catch (e) {
      print('제2외국어 설정 로드 실패: $e');
      return "일본어";
    }
  }
}