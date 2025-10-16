import 'package:flutter/material.dart';
import 'package:flutter_application_1/page/user/main_user.dart';

class UserRecord extends StatefulWidget {
  const UserRecord({super.key});

  @override
  State<UserRecord> createState() => _UserRecordState();
}

class _UserRecordState extends State<UserRecord>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const kGreen = Color(0xFF2ECC71);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ส่วนหัวสีเขียว
          Container(
            width: double.infinity,
            color: kGreen,
            padding: const EdgeInsets.only(top: 45, bottom: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Center(
                  child: Text(
                    'ZapGo',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MainUser(userid: 3),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // แถบ TabBar (รับของ / ส่งของ)
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.black,
              indicatorWeight: 2,
              tabs: const [
                Tab(text: 'รับของ'),
                Tab(text: 'ส่งของ'),
              ],
            ),
          ),

          // เนื้อหาในแต่ละแท็บ
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [ReceiveTab(), SendTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------- หน้ารับของ ------------------------
class ReceiveTab extends StatelessWidget {
  const ReceiveTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'ประวัติการรับของ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        DeliveryCard(
          imagePath: 'assets/images/phone_14.png',
          model: 'IPhone 14 Pro max',
        ),
        DeliveryCard(
          imagePath: 'assets/images/phone_14.png',
          model: 'IPhone 14',
        ),
      ],
    );
  }
}

// ---------------------- หน้าส่งของ ------------------------
class SendTab extends StatelessWidget {
  const SendTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'ประวัติการส่งของ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        DeliveryCard(
          imagePath: 'assets/images/phone_14.png',
          model: 'IPhone 14 Pro max',
        ),
      ],
    );
  }
}

// ---------------------- การ์ดสินค้า ------------------------
class DeliveryCard extends StatelessWidget {
  final String imagePath;
  final String model;

  const DeliveryCard({super.key, required this.imagePath, required this.model});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Colors.black26),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Image.asset(imagePath, width: 70, height: 120, fit: BoxFit.contain),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'รายละเอียด',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text('รุ่น $model'),
                  const Row(
                    children: [
                      Text('ผู้รับ  '),
                      Text('ฟ้า'),
                      SizedBox(width: 10),
                      Text('ที่อยู่ผู้รับ...'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
