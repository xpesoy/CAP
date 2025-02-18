import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('학교 앱 홈'),
        backgroundColor: Colors.blue, // 앱바 색상
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 앱 이름 또는 로고
            Text(
              '학교 생활을 편리하게!',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20), // 간격

            // 오늘의 일정 카드
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: Icon(Icons.schedule, size: 40, color: Colors.blue),
                title: Text('오늘의 일정'),
                subtitle: Text('1교시: 수학, 2교시: 과학 ...'),
                onTap: () {
                  // 시간표 화면으로 이동할 수 있도록
                },
              ),
            ),
            SizedBox(height: 20), // 간격

            // 급식 정보 카드
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: Icon(Icons.restaurant, size: 40, color: Colors.green),
                title: Text('오늘의 급식'),
                subtitle: Text('점심: 비빔밥, 저녁: 떡볶이'),
                onTap: () {
                  // 급식표 화면으로 이동할 수 있도록
                },
              ),
            ),
            SizedBox(height: 20), // 간격

            // 하단에 버튼 추가
            ElevatedButton(
              onPressed: () {
                // 버튼 클릭 시 다른 화면으로 이동
              },
              child: Text('기타 기능'),
            ),
          ],
        ),
      ),
    );
  }
}
