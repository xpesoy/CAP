import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TimetableScreen extends StatefulWidget {
  @override
  _TimetableScreenState createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  DateTime _selectedDate = DateTime.now();
  final List<String> _koreanDays = ['월', '화', '수', '목', '금'];
  final List<String> _periodsData = ['1교시', '2교시', '3교시', '4교시', '5교시', '6교시', '7교시'];
  Map<String, dynamic> _timetableData = {};
  bool _isLoading = false;
  
  // NEIS API 관련 변수
  final String _apiKey = "d07f995a158c46b4abd01cf3acc903d9";
  final String _schoolCode = "8140070";
  final String _eduOfficeCode = "N10";
  
  // 학년 및 과목 선택 관련 변수
  int _selectedGrade = 1;
  String _selectedClass = "1";
  Map<String, String> _selectedSubjects = {
    "제2외국어": "일본어",
  };
  
  // 커스텀 시간표 관련 변수
  bool _isCustomTimetable = false;
  Map<String, Map<String, String>> _customTimetable = {};
  List<String> _availableSubjects = [
    '미적분', '기하', '확률과 통계', '언어와 매체', '화법과 작문', '프로그래밍', '가정과학', '영어독해와작문', '영어회화', '진로영어', '물리학 실험', '화학 실험', '생명과학 실험', '음악 연주', '미술 창작', '경제 수학', '환경', '심리학', '진로와 직업', '진로', '자율'
    '한문II', '일본어II', '중국어II', '공학 일반', '지식 재산 일반', '물리II', '화학II', '생명과학II', '지구과학II', '현대문학감상', '융합과학', '사회문제탐구', '여행지리', '사회문화', '세계지리', '생활과 윤리', '동아시아사', '생활과 과학'
  ];
  
  @override
  void initState() {
    super.initState();
    _initCustomTimetable();
    _loadUserPreferences();
    _fetchTimetableData();
  }
  
  void _initCustomTimetable() {
    // 커스텀 시간표 초기화
    for (String day in _koreanDays) {
      _customTimetable[day] = {};
      for (int j = 0; j < _periodsData.length; j++) {
        String period = (j + 1).toString();
        _customTimetable[day]![period] = '';
      }
    }
  }
 
  Future<void> _loadUserPreferences() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedGrade = prefs.getInt('grade') ?? 1;
        _selectedClass = prefs.getString('class') ?? "1";
        _isCustomTimetable = prefs.getBool('is_custom_timetable') ?? false;
        
        // 저장된 과목 불러오기
        String? savedSecondLanguage = prefs.getString('subject_제2외국어');
        if (savedSecondLanguage != null) {
          _selectedSubjects["제2외국어"] = savedSecondLanguage;
        }
        
        // 커스텀 시간표 불러오기
        for (String day in _koreanDays) {
          for (int i = 1; i <= _periodsData.length; i++) {
            String period = i.toString();
            String? savedSubject = prefs.getString('custom_${day}_$period');
            if (savedSubject != null) {
              _customTimetable[day]![period] = savedSubject;
            }
          }
        }
      });
    } catch (e) {
      print('사용자 설정 로드 실패: $e');
    }
  }
  
  Future<void> _saveUserPreferences() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('grade', _selectedGrade);
      await prefs.setString('class', _selectedClass);
      await prefs.setBool('is_custom_timetable', _isCustomTimetable);
      
      // 과목 저장하기
      await prefs.setString('subject_제2외국어', _selectedSubjects["제2외국어"]!);
      
      // 커스텀 시간표 저장하기
      for (String day in _koreanDays) {
        for (int i = 1; i <= _periodsData.length; i++) {
          String period = i.toString();
          await prefs.setString('custom_${day}_$period', _customTimetable[day]![period]!);
        }
      }
    } catch (e) {
      print('사용자 설정 저장 실패: $e');
    }
  }

  // 제2외국어 과목 이름 변환 (2학년용)
  String _convertSecondLanguageSubject(String subject) {
    if (_selectedGrade != 2) return subject;
    
    final String selectedLanguage = _selectedSubjects["제2외국어"]!;
    
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
    
    return subject;
  }

  Future<void> _fetchTimetableData() async {
    // 만약 커스텀 모드이면 API 호출 안함
    if (_selectedGrade == 3 && _isCustomTimetable) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    // 캐시된 데이터 먼저 확인
    bool usedCache = await _loadCachedTimetableData();
    if (usedCache) {
      return; // 캐시된 데이터가 있으면 API 호출 중단
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 현재 선택된 날짜 기준으로 해당 주의 월요일과 금요일 계산
      DateTime selectedDate = _selectedDate;
      int weekday = selectedDate.weekday; // 1: 월요일, 7: 일요일
      
      // 이번 주 월요일 찾기 (현재 날짜가 월요일이면 그대로, 아니면 이전 월요일로)
      DateTime mondayOfWeek = selectedDate.subtract(Duration(days: weekday - 1));
      
      // 이번 주 금요일 찾기 (월요일 + 4일)
      DateTime fridayOfWeek = mondayOfWeek.add(Duration(days: 4));
      
      // 날짜 포맷팅
      String fromDate = DateFormat('yyyyMMdd').format(mondayOfWeek);
      String toDate = DateFormat('yyyyMMdd').format(fridayOfWeek);
      
      print('조회 기간: $fromDate(월) ~ $toDate(금)');
      
      // API URL 기본 구조
      final Map<String, String> params = {
        'KEY': _apiKey,  
        'ATPT_OFCDC_SC_CODE': _eduOfficeCode,    // 교육청 코드
        'SD_SCHUL_CODE': _schoolCode,            // 학교 코드
        'GRADE': _selectedGrade.toString(),      // 학년
        'CLASS_NM': _selectedClass,              // 학급
        'TI_FROM_YMD': fromDate,                 // 시작 날짜 (월요일)
        'TI_TO_YMD': toDate,                     // 종료 날짜 (금요일)
        'Type': 'json'                           // 응답 형식
      };
      
      // 선택적 파라미터 추가
      final DateTime now = DateTime.now();
      final String currentYear = now.year.toString();
      final int currentMonth = now.month;
      
      // 학기 설정 (1학기: 3-8월, 2학기: 9-2월)
      String semester = (currentMonth >= 3 && currentMonth <= 8) ? '1' : '2';
      
      params['AY'] = currentYear;     // 학년도
      params['SEM'] = semester;       // 학기
      
      // URI 구성
      Uri uri = Uri.https('open.neis.go.kr', '/hub/hisTimetable', params);
      print('API 요청 URL: ${uri.toString()}');
      
      // API 요청
      var response = await http.get(uri);
      
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        
        // API 응답 데이터 로그 출력
        print('API Response: ${response.body}');
        
        // 응답 데이터 저장
        await _saveApiResponseData(response.body);
        
        // 응답에 RESULT 객체가 있는지 확인 (데이터 없음 응답인 경우)
        if (data.containsKey('RESULT') && data['RESULT']['CODE'] == 'INFO-200') {
          print('시간표 데이터 없음: ${data['RESULT']['MESSAGE']}');
          setState(() {
            _timetableData = {};
            _isLoading = false;
          });
          return;
        }
        
        // 데이터가 있는 경우 정상 처리
        if (data['hisTimetable'] != null && data['hisTimetable'][1]['row'] != null) {
          // 시간표 데이터 구성
          Map<String, dynamic> timetable = {};
          
          for (var item in data['hisTimetable'][1]['row']) {
            String day = _convertDayOfWeekToKorean(item['ALL_TI_YMD']);
            int period = int.parse(item['PERIO']);
            String subject = item['ITRT_CNTNT'];
            
            // 2학년이고 제2외국어 과목인 경우 사용자가 선택한 제2외국어로 교체
            if (_selectedGrade == 2) {
              subject = _convertSecondLanguageSubject(subject);
            }
            
            if (timetable[day] == null) {
              timetable[day] = {};
            }
            
            timetable[day][period.toString()] = {
              'subject': subject,
              'room': item['CLRM_NM'] ?? '미정'
            };
          }
          
          setState(() {
            _timetableData = timetable;
            _isLoading = false;
          });
        
        } else {
          // 시간표 데이터가 없을 경우 빈 맵 설정
          setState(() {
            _timetableData = {};
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        print('API 오류: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('데이터 가져오기 실패: $e');
    }
  }

  // API 응답 데이터 저장
  Future<void> _saveApiResponseData(String responseBody) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String dateKey = DateFormat('yyyyMMdd').format(_selectedDate);
      String prefKey = 'api_response_${_selectedGrade}_${_selectedClass}_$dateKey';
      await prefs.setString(prefKey, responseBody);
      print('API 응답 데이터 저장 완료: $prefKey');
    } catch (e) {
      print('API 응답 데이터 저장 실패: $e');
    }
  }
  
  // 날짜 형식에서 요일을 한글 요일로 변환
  String _convertDayOfWeekToKorean(String dateString) {
    DateTime date = DateTime.parse(dateString);
    int dayIndex = date.weekday - 1;
    
    if (dayIndex >= 0 && dayIndex < 5) {
      return _koreanDays[dayIndex];
    } else if (dayIndex == 5) {
      return '토';
    } else {
      return '일';
    }
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
            _buildDateSelector(),
            SizedBox(height: 16),
            _isLoading
                ? Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  )
                : Expanded(child: _buildTimetable()),
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
              '천안중앙고등학교 시간표',
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
              onPressed: () => _showSubjectSelectionDialog(context),
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
      padding: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Row(
        children: [
          // 학년/학급/커스텀 모드 정보 표시
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '$_selectedGrade학년 $_selectedClass반',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                if (_selectedGrade == 3 && _isCustomTimetable)
                  Text(
                    ' (커스텀)',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                SizedBox(width: 16),
                Container(
                  height: 24,
                  width: 1,
                  color: Colors.grey.withOpacity(0.3),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: Color(0xFF0D47A1)),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(Duration(days: 1));
                    });
                    _fetchTimetableData();
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
                    _fetchTimetableData();
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
          ),
        ],
      ),
    );
  }

  String _getDayText() {
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
      _fetchTimetableData();
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
          ..._koreanDays.map((day) => _buildHeaderCell(day)),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {bool isFirst = false}) {
    return Expanded(
      flex: isFirst ? 2 : 3, // 교시 열의 너비를 줄이고 요일 열의 너비를 늘림
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
          ..._koreanDays.asMap().entries.map((entry) {
            final int dayIndex = entry.key;
            final String day = entry.value;
            final String period = (rowIndex + 1).toString();
            return _buildLessonCell(day, period, dayIndex);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPeriodCell(String text) {
    return Expanded(
      flex: 2, // 교시 열의 너비를 줄임
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
  
  Widget _buildLessonCell(String day, String period, int dayIndex) {
    // 커스텀 모드인 경우 (3학년 커스텀 모드)
    if (_selectedGrade == 3 && _isCustomTimetable) {
      String subject = _customTimetable[day]![period] ?? '';
      String room = '3-${_selectedClass}';
      
      Widget cellContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (subject.isNotEmpty) ...[
              Text(
                subject,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
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
            ] else
              Icon(
                Icons.block,
                color: Colors.grey.withOpacity(0.3),
                size: 16,
              ),
          ],
        ),
      );
      
      Widget cell = Expanded(
        flex: 3, // 요일 열의 너비를 늘림
        child: GestureDetector(
          onTap: () => _showSubjectSelector(day, period),
          child: Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1),
              ),
              color: Color(0xFFF5F5FF), // 커스텀 셀 배경색
            ),
            child: cellContent,
          ),
        ),
      );
      
      return cell;
    }
    
    // API 기반 시간표 시스템 (1, 2학년 및 3학년 기본 모드)
    // API 데이터가 있는지 확인
    if (_timetableData.isNotEmpty && 
        _timetableData[day] != null && 
        _timetableData[day][period] != null) {
      
      final lessonData = _timetableData[day][period];
      final String subject = lessonData['subject'];
      final String room = lessonData['room'];
      
      return Expanded(
        flex: 3, // 요일 열의 너비를 늘림
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
                SizedBox(height: 4),
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
    } else {
      // 빈 셀 표시
      return Expanded(
        flex: 3,
        child: Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1),
            ),
          ),
          child: Center(
            child: Text(
              '-',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }
  }
  
  // 과목 선택 다이얼로그
  Future<void> _showSubjectSelectionDialog(BuildContext context) async {
    int tempGrade = _selectedGrade;
    String tempClass = _selectedClass;
    bool tempIsCustomTimetable = _isCustomTimetable;
    String tempSelectedLanguage = _selectedSubjects["제2외국어"]!;
    
    // 학급 목록
    final List<String> classesByGrade = List.generate(13, (index) => (index + 1).toString());
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                '학년/학급 선택',
                style: TextStyle(
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Container(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 학년 선택
                      Text(
                        '학년 선택',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [1, 2, 3].map((grade) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: tempGrade == grade
                                      ? Color(0xFF0D47A1)
                                      : Colors.white,
                                  foregroundColor: tempGrade == grade
                                      ? Colors.white
                                      : Color(0xFF0D47A1),
                                  side: BorderSide(
                                    color: Color(0xFF0D47A1),
                                    width: 1,
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    tempGrade = grade;
                                    // 학년 변경 시 커스텀 모드 초기화 (3학년 아닌 경우)
                                    if (grade != 3) {
                                      tempIsCustomTimetable = false;
                                    }
                                  });
                                },
                                child: Text('$grade학년'),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16),
                      
                      // 학급 선택 (모든 학년에 대해 학급 선택 표시)
                      Text(
                        '학급 선택',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: tempClass,
                          isExpanded: true,
                          underline: SizedBox(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                tempClass = newValue;
                              });
                            }
                          },
                          items: classesByGrade
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text('$value반'),
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // 2학년인 경우에만 제2외국어 선택 표시
                      if (tempGrade == 2) ...[
                        Text(
                          '제2외국어 선택',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: ["일본어", "중국어"].map((language) {
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: tempSelectedLanguage == language
                                        ? Color(0xFF0D47A1)
                                        : Colors.white,
                                    foregroundColor: tempSelectedLanguage == language
                                        ? Colors.white
                                        : Color(0xFF0D47A1),
                                    side: BorderSide(
                                      color: Color(0xFF0D47A1),
                                      width: 1,
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      tempSelectedLanguage = language;
                                    });
                                  },
                                  child: Text(language),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      
                      // 3학년일 경우 커스텀 모드 선택 표시
                      if (tempGrade == 3) ...[
                        SizedBox(height: 16),
                        Text(
                          '시간표 모드',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<bool>(
                                title: Text('기본 모드'),
                                value: false,
                                groupValue: tempIsCustomTimetable,
                                onChanged: (bool? value) {
                                  setState(() {
                                    tempIsCustomTimetable = value ?? false;
                                  });
                                },
                                activeColor: Color(0xFF0D47A1),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<bool>(
                                title: Text('커스텀 모드'),
                                value: true,
                                groupValue: tempIsCustomTimetable,
                                onChanged: (bool? value) {
                                  setState(() {
                                    tempIsCustomTimetable = value ?? true;
                                  });
                                },
                                activeColor: Color(0xFF0D47A1),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        
                        if (tempIsCustomTimetable) ...[
                          Text(
                            '커스텀 모드 안내',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '저장 후 시간표 화면의 셀을 탭하여 과목을 선택할 수 있습니다.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    '취소',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0D47A1),
                  ),
                  onPressed: () {
                    // 메인 위젯 상태 업데이트
                    this.setState(() {
                      _selectedGrade = tempGrade;
                      _selectedClass = tempClass;
                      _isCustomTimetable = tempIsCustomTimetable;
                      _selectedSubjects["제2외국어"] = tempSelectedLanguage;
                    });
                    _saveUserPreferences();
                    _fetchTimetableData();
                    Navigator.of(context).pop();
                    
                    // 커스텀 모드인 경우 안내 메시지 표시
                    if (_selectedGrade == 3 && _isCustomTimetable) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('커스텀 모드에서는 시간표 화면의 셀을 탭하여 과목을 직접 편집할 수 있습니다.'),
                          backgroundColor: Color(0xFF0D47A1),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  child: Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  // 과목 선택 다이얼로그 (커스텀 모드용)
  void _showSubjectSelector(String day, String period) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$day요일 $period교시 과목 선택',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _availableSubjects.length + 1, // +1 for the "None" option
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // "None" option
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _customTimetable[day]![period] = '';
                          });
                          Navigator.pop(context);
                          _saveUserPreferences();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.3),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '없음',
                              style: TextStyle(
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    
                    String subject = _availableSubjects[index - 1];
                    bool isSelected = _customTimetable[day]![period] == subject;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _customTimetable[day]![period] = subject;
                        });
                        Navigator.pop(context);
                        _saveUserPreferences();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Color(0xFFE3F2FD) : Colors.white,
                          border: Border.all(
                            color: isSelected 
                                ? Color(0xFF0D47A1) 
                                : Colors.grey.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            subject,
                            style: TextStyle(
                              color: isSelected ? Color(0xFF0D47A1) : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // 캐시된 시간표 데이터 로드
  Future<bool> _loadCachedTimetableData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String dateKey = DateFormat('yyyyMMdd').format(_selectedDate);
      String prefKey = 'api_response_${_selectedGrade}_${_selectedClass}_$dateKey';
      
      String? cachedData = prefs.getString(prefKey);
      if (cachedData != null) {
        var data = json.decode(cachedData);
        print('캐시된 데이터 로드: $prefKey');
        
        // 데이터 파싱 및 저장
        if (data['hisTimetable'] != null && data['hisTimetable'][1]['row'] != null) {
          // 시간표 데이터 구성
          Map<String, dynamic> timetable = {};
          
          for (var item in data['hisTimetable'][1]['row']) {
            String day = _convertDayOfWeekToKorean(item['ALL_TI_YMD']);
            int period = int.parse(item['PERIO']);
            String subject = item['ITRT_CNTNT'];
            
            // 2학년이고 제2외국어 과목인 경우 사용자가 선택한 제2외국어로 교체
            if (_selectedGrade == 2) {
              subject = _convertSecondLanguageSubject(subject);
            }
            
            if (timetable[day] == null) {
              timetable[day] = {};
            }
            
            timetable[day][period.toString()] = {
              'subject': subject,
              'room': item['CLRM_NM'] ?? '미정'
            };
          }
          
          setState(() {
            _timetableData = timetable;
            _isLoading = false;
          });
          
          return true;
        }
      }
    } catch (e) {
      print('캐시된 데이터 로드 실패: $e');
    }
    
    return false;
  }
  
  // 앱 종료 시 데이터 저장
  @override
  void dispose() {
    _saveUserPreferences();
    super.dispose();
  }
}