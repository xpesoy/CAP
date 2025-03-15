import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// API 응답을 파싱하기 위한 모델 클래스
class MealResponse {
  final List<MealInfo> mealServiceDietInfo;

  MealResponse({required this.mealServiceDietInfo});

  factory MealResponse.fromJson(Map<String, dynamic> json) {
    List<dynamic> rows = [];
    
    // API 응답 구조에 따라 데이터 추출
    if (json.containsKey('mealServiceDietInfo')) {
      final List<dynamic> infoList = json['mealServiceDietInfo'];
      for (var info in infoList) {
        if (info.containsKey('row')) {
          rows.addAll(info['row']);
        }
      }
    }
    
    return MealResponse(
      mealServiceDietInfo: rows.map((e) => MealInfo.fromJson(e)).toList(),
    );
  }
}

class MealInfo {
  final String mealDate;       // 급식일자
  final String mealType;       // 식사코드
  final String mealName;       // 식사명
  final String mealContents;   // 급식내용

  MealInfo({
    required this.mealDate,
    required this.mealType,
    required this.mealName, 
    required this.mealContents
  });

  factory MealInfo.fromJson(Map<String, dynamic> json) {
    return MealInfo(
      mealDate: json['MLSV_YMD'] ?? '',
      mealType: json['MMEAL_SC_CODE'] ?? '',
      mealName: json['MMEAL_SC_NM'] ?? '',
      mealContents: json['DDISH_NM'] ?? '',
    );
  }

  // 급식 내용을 리스트로 변환 (각 메뉴 항목을 분리)
  List<String> getMealContentsList() {
    return mealContents
        .replaceAll('<br/>', '\n')
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

// API 서비스 클래스
class MealApiService {
  static const String baseUrl = 'https://open.neis.go.kr/hub/mealServiceDietInfo';
  static const String apiKey = 'd07f995a158c46b4abd01cf3acc903d9'; // 실제 사용 시 발급받은 API 키로 변경 필요

  // 시작일부터 종료일까지의 급식 데이터 조회
  static Future<List<MealInfo>> getMealsByPeriod({
    required String atptOfcdcScCode, // 시도교육청코드
    required String sdSchulCode,     // 학교코드
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final String fromDateStr = DateFormat('yyyyMMdd').format(fromDate);
    final String toDateStr = DateFormat('yyyyMMdd').format(toDate);

    final response = await http.get(Uri.parse(
      '$baseUrl?KEY=$apiKey&Type=json&pIndex=1&pSize=100'
      '&ATPT_OFCDC_SC_CODE=$atptOfcdcScCode'
      '&SD_SCHUL_CODE=$sdSchulCode'
      '&MLSV_FROM_YMD=$fromDateStr'
      '&MLSV_TO_YMD=$toDateStr'
    ));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      
      // 에러 응답 처리
      if (data.containsKey('RESULT')) {
        if (data['RESULT']['CODE'] != 'INFO-000') {
          throw Exception('API 에러: ${data['RESULT']['MESSAGE']}');
        }
      }
      
      // 데이터가 없는 경우
      if (!data.containsKey('mealServiceDietInfo')) {
        return [];
      }
      
      return MealResponse.fromJson(data).mealServiceDietInfo;
    } else {
      throw Exception('급식 데이터를 불러오는데 실패했습니다');
    }
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
  final List<String> _mealTypes = ['조식', '중식', '석식'];
  final Map<String, String> _mealTypeCodes = {'조식': '1', '중식': '2', '석식': '3'};
  
  // API 요청 관련 상수
  final String _atptOfcdcScCode = 'J10'; // 충청남도교육청 (실제 코드로 변경 필요)
  final String _sdSchulCode = '8140089'; // 천안중앙고등학교 (실제 코드로 변경 필요)
  
  // 급식 데이터 저장
  List<MealInfo> _mealInfoList = [];
  bool _isLoading = false;
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _weekDays = _getWeekDays(_selectedDate);
    _fetchMealData();
  }

  // 급식 데이터 불러오기
  Future<void> _fetchMealData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final fromDate = _weekDays.first;
      final toDate = _weekDays.last;
      
      final mealData = await MealApiService.getMealsByPeriod(
        atptOfcdcScCode: _atptOfcdcScCode,
        sdSchulCode: _sdSchulCode,
        fromDate: fromDate,
        toDate: toDate,
      );
      
      setState(() {
        _mealInfoList = mealData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '급식 정보를 불러오는데 실패했습니다: ${e.toString()}';
        _isLoading = false;
      });
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
            _buildWeekSelector(),
            SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? _buildErrorView()
                      : _buildMealTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[700]),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchMealData,
              child: Text('다시 시도'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0D47A1),
                foregroundColor: Colors.white,
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
            '천안중앙고등학교 급식표',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
            ),
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.refresh, color: Color(0xFF0D47A1)),
            onPressed: _fetchMealData,
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: Color(0xFF0D47A1)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  List<DateTime> _getWeekDays(DateTime date) {
    int weekday = date.weekday;
    DateTime monday = date.subtract(Duration(days: weekday - 1));
    List<DateTime> weekDays = List.generate(
      5, 
      (index) => monday.add(Duration(days: index))
    );
    return weekDays;
  }

  DateTime _handleWeekendSelection(DateTime date) {
    if (date.weekday == 6) {
      return date.add(Duration(days: 2));
    } else if (date.weekday == 7) {
      return date.add(Duration(days: 1));
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
                _fetchMealData();
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
                _selectedDate = _weekDays.last.add(Duration(days: 3));
                _weekDays = _getWeekDays(_selectedDate);
                _fetchMealData();
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
        _selectedDate = _handleWeekendSelection(picked);
        _weekDays = _getWeekDays(_selectedDate);
        _fetchMealData();
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
      height: rowIndex == 1 ? 200 : 100,  // 중식 칸을 더 크게 만듦
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
    String formattedDate = DateFormat('yyyyMMdd').format(cellDate);
    String mealTypeCode = _mealTypeCodes[_mealTypes[mealTypeIndex]] ?? '';
    
    // API에서 가져온 데이터 중 해당 날짜, 해당 식사 유형에 맞는 데이터 찾기
    MealInfo? mealInfo = _mealInfoList.firstWhere(
      (meal) => meal.mealDate == formattedDate && meal.mealType == mealTypeCode,
      orElse: () => MealInfo(
        mealDate: formattedDate,
        mealType: mealTypeCode,
        mealName: _mealTypes[mealTypeIndex],
        mealContents: '',
      ),
    );
    
    List<String> mealContents = mealInfo.getMealContentsList();
    if (mealContents.isEmpty) {
      mealContents = ['급식 정보가 없습니다'];
    }
    
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
            ...mealContents.map((menu) => 
              Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  menu,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: menu == mealContents.first ? FontWeight.w500 : FontWeight.normal,
                    color: menu == mealContents.first 
                        ? Colors.black.withOpacity(0.8) 
                        : Colors.black.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            ).toList(),
          ],
        ),
      ),
    );
  }
  
  bool _isToday(DateTime date) {
    DateTime now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}

// 앱의 메인 진입점
void main() {
  runApp(MaterialApp(
    title: '학교 급식 정보',
    theme: ThemeData(
      primaryColor: Color(0xFF0D47A1),
      scaffoldBackgroundColor: Color(0xFFF5F7FA),
      fontFamily: 'NotoSansKR',
    ),
    home: MealScreen(),
    debugShowCheckedModeBanner: false,
  ));
}