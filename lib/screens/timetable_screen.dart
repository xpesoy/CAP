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
  final String _apiKey = "d07f995a158c46b4abd01cf3acc903d9"; // 여기에 실제 API 키를 넣으세요
  final String _schoolCode = "8140070"; // 여기에 학교 코드를 넣으세요
  final String _eduOfficeCode = "N10"; // 여기에 교육청 코드를 넣으세요
  
  // 학년 및 과목 선택 관련 변수
  int _selectedGrade = 1;
  String _selectedClass = "1";
  Map<String, String> _selectedSubjects = {
    "수학": "수학 1",
    "국어": "국어",
    "영어": "영어 1",
    "과학": "물리학 1",
    "사회": "한국사",
    "제2외국어": "일본어",
  };
  
  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _fetchTimetableData();
  }
 
  Future<void> _loadUserPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedGrade = prefs.getInt('grade') ?? 1;
      _selectedClass = prefs.getString('class') ?? "1";
      
      // 저장된 과목 불러오기
      for (String category in _selectedSubjects.keys) {
        String? savedSubject = prefs.getString('subject_$category');
        if (savedSubject != null) {
          _selectedSubjects[category] = savedSubject;
        }
      }
    });
  }
  
  Future<void> _saveUserPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('grade', _selectedGrade);
    await prefs.setString('class', _selectedClass);
    
    // 과목 저장하기
    for (String category in _selectedSubjects.keys) {
      await prefs.setString('subject_$category', _selectedSubjects[category]!);
    }
  }

Future<void> _fetchTimetableData() async {
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
        
        // 데이터 없음 알림
        _showNoDataSnackbar();
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

// 데이터 없음 알림 Snackbar
void _showNoDataSnackbar() {
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  
  // 이전 Snackbar 닫기
  scaffoldMessenger.hideCurrentSnackBar();
  
  scaffoldMessenger.showSnackBar(
    SnackBar(
      content: Text(
        '해당 학년/학급/주간의 시간표 데이터가 없습니다. 샘플 시간표를 표시합니다.',
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
                fit: BoxFit.cover,
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF0D47A1)),
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
  final String day = _koreanDays[dayIndex];
  final int period = rowIndex + 1;
  
  // API 데이터가 있는지 확인
  if (_timetableData.isNotEmpty && 
      _timetableData[day] != null && 
      _timetableData[day][period.toString()] != null) {
    
    final lessonData = _timetableData[day][period.toString()];
    final String subject = lessonData['subject'];
    final String room = lessonData['room'];
    
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
    // 데이터가 없는 경우 빈 셀 반환
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
}
  
  // 과목 선택 다이얼로그
  Future<void> _showSubjectSelectionDialog(BuildContext context) async {
    int tempGrade = _selectedGrade;
    String tempClass = _selectedClass;
    Map<String, String> tempSelectedSubjects = Map.from(_selectedSubjects);
    
    // 학년별 과목 목록
    final Map<String, List<String>> subjectsByCategory = {
      "수학": ["수학 1", "수학 2", "미적분", "확률과 통계", "기하"],
      "국어": ["국어", "문학", "화법과 작문", "독서", "언어와 매체"],
      "영어": ["영어 1", "영어 2", "영어 회화", "영어 독해와 작문"],
      "과학": ["물리학 1", "화학 1", "생명과학 1", "지구과학 1", "물리학 2", "화학 2", "생명과학 2", "지구과학 2"],
      "사회": ["한국사", "통합사회", "경제", "정치와 법", "사회문화", "생활과 윤리", "세계지리", "한국지리", "세계사", "동아시아사"],
      "제2외국어": ["일본어", "중국어"],
    };
    
    // 학급 목록
    final List<String> classesByGrade = List.generate(13, (index) => (index + 1).toString());
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                '학년/학급/과목 선택',
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
                                  primary: tempGrade == grade
                                      ? Color(0xFF0D47A1)
                                      : Colors.white,
                                  onPrimary: tempGrade == grade
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
                      
                      // 학년별 과목 선택 섹션
                      if (tempGrade >= 1) ...[
                        Text(
                          '과목 선택',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        
                        // 1학년인 경우 과목 선택 UI 생략 (학년/학급 선택만 표시)
                        if (tempGrade == 1) ...[
                          Text(
                            '1학년은 공통 과목으로 구성되어 있습니다.',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 8),
                        ],
                        
                        // 2학년은 제2외국어만 표시
                        if (tempGrade == 2) ...[
                          Text(
                            '제2외국어 과목 선택',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
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
                              value: tempSelectedSubjects["제2외국어"],
                              isExpanded: true,
                              underline: SizedBox(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    tempSelectedSubjects["제2외국어"] = newValue;
                                  });
                                }
                              },
                              items: subjectsByCategory["제2외국어"]!
                                  .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '기타 과목은 공통 교육과정으로 진행됩니다.',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        
                        // 3학년은 모든 과목군 표시
                        if (tempGrade == 3) ...[
                          ...subjectsByCategory.entries.map((entry) {
                            final category = entry.key;
                            final subjects = entry.value;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$category 과목군',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<String>(
                                    value: tempSelectedSubjects[category],
                                    isExpanded: true,
                                    underline: SizedBox(),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          tempSelectedSubjects[category] = newValue;
                                        });
                                      }
                                    },
                                    items: subjects
                                        .map<DropdownMenuItem<String>>((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                SizedBox(height: 12),
                              ],
                            );
                          }).toList(),
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
                    primary: Color(0xFF0D47A1),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedGrade = tempGrade;
                      _selectedClass = tempClass;
                      _selectedSubjects = tempSelectedSubjects;
                    });
                    _saveUserPreferences();
                    _fetchTimetableData();
                    Navigator.of(context).pop();
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
  
  // 캐시된 시간표 데이터 로드
  Future<bool> _loadCachedTimetableData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String dateKey = DateFormat('yyyyMMdd').format(_selectedDate);
    String prefKey = 'api_response_${_selectedGrade}_${_selectedClass}_$dateKey';
    
    String? cachedData = prefs.getString(prefKey);
    if (cachedData != null) {
      try {
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
            
            if (timetable[day] == null) {
              timetable[day] = {};
            }
            
            timetable[day][period.toString()] = {
              'subject': subject,
              'teacher': item['TCHR_NM'] ?? '미정',
              'room': item['CLRM_NM'] ?? '미정'
            };
          }
          
          setState(() {
            _timetableData = timetable;
          });
          
          return true;
        }
      } catch (e) {
        print('캐시된 데이터 로드 실패: $e');
      }
    }
    
    return false;
  }
  
  // 학년별 시간표 데이터 초기화
  void _resetTimetableData() {
    setState(() {
      _timetableData = {};
    });
  }
  
  // 과목명 포맷팅 (API 데이터와 선택된 과목 매핑)
  String _formatSubjectName(String originalName) {
    // 과목명 매핑 로직 구현
    // 예: "수1" -> "수학 1"
    Map<String, String> subjectMapping = {
      "수1": "수학 1",
      "수2": "수학 2",
      "국어": "국어",
      "문학": "문학",
      "영1": "영어 1",
      "영2": "영어 2",
      "물1": "물리학 1",
      "화1": "화학 1",
      "생1": "생명과학 1",
      "지1": "지구과학 1",
      "한국사": "한국사",
      "한국지리": "한국지리",
      "일본어": "일본어",
      "중국어": "중국어",
    };
    
    return subjectMapping[originalName] ?? originalName;
  }
  
  // 앱 종료 시 데이터 저장
  @override
  void dispose() {
    _saveUserPreferences();
    super.dispose();
  }
}