  import 'package:flutter/material.dart';

  class HomeScreen extends StatefulWidget {
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
                  child: Column(
                    children: [
                      _buildNoticeSection(),
                      SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: _buildTimetablePreview()),
                            SizedBox(width: 16),
                            Expanded(child: _buildMealPreview()),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                fit: BoxFit.cover, // 로고를 박스 크기에 맞게 조절
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

    Widget _buildNoticeSection() {
      return Container(
        height: 120,
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
            Container(
              height: 40,
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.campaign_outlined, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    '공지사항',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      '더보기',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: 2,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Color(0xFF0D47A1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            index == 0 
                                ? '3월 학교 축제 안내' 
                                : '2025학년도 1학기 시간표 공지',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 16),
                        Text(
                          '2025.02.19',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
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

    Widget _buildTimetablePreview() {
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
            Container(
              height: 40,
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_outlined, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    '오늘의 시간표',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () {
                      // Navigate to TimetableScreen
                    },
                    child: Text(
                      '전체보기',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(12),
                itemCount: 5,
                itemBuilder: (context, index) {
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
                            child: Row(
                              children: [
                                Text(
                                  ['수학', '국어', '영어', '과학', '사회'][index],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  ['1-1', '2-1', '1-2', '3-1', '2-2'][index],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF0D47A1),
                                  ),
                                ),
                              ],
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

    Widget _buildMealPreview() {
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
            Container(
              height: 40,
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.restaurant_outlined, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    '오늘의 급식',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () {
                      // Navigate to MealScreen
                    },
                    child: Text(
                      '전체보기',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(12),
                itemCount: 3,
                itemBuilder: (context, index) {
                  final mealTypes = ['조식', '중식', '석식'];
                  final sampleMeals = [
                    ['백미밥', '미역국', '계란말이'],
                    ['백미밥', '육개장', '야채튀김', '배추김치', '요구르트'],
                    ['백미밥', '시금치국', '고등어구이'],
                  ];
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: index.isEven ? Color(0xFFF5F7FA) : Colors.white,
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFFEBF3F5),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                mealTypes[index],
                                style: TextStyle(
                                  color: Color(0xFF0D47A1),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              if (index == 1) ...[
                                Spacer(),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '알러지: 1,5,6',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF0D47A1),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Wrap(
                            spacing: 8,
                            children: sampleMeals[index].map((meal) => Text(
                              meal,
                              style: TextStyle(fontSize: 13),
                            )).toList(),
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
  }