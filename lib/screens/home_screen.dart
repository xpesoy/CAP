import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  // 탭 선택 콜백 함수 추가
  final Function(int)? onTabSelected;
  
  HomeScreen({this.onTabSelected});
  
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
                child: _buildMainButtons(),
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
            icon: Icon(Icons.settings_outlined, color: Color(0xFF0D47A1)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMainButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              // 콜백 함수를 호출하여 시간표 탭(인덱스 1)으로 이동
              if (widget.onTabSelected != null) {
                widget.onTabSelected!(1);
              }
            },
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 64,
                    color: Color(0xFF0D47A1),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '시간표',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '오늘의 수업 일정 확인',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              // 콜백 함수를 호출하여 급식 탭(인덱스 2)으로 이동
              if (widget.onTabSelected != null) {
                widget.onTabSelected!(2);
              }
            },
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant,
                    size: 64,
                    color: Color(0xFF0D47A1),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '급식',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '오늘의 식단 확인',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}