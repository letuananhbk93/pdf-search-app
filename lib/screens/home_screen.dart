import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TLC DRAWINGS SEARCH APP',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFC00000),  // Bordeaux theme 
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.palette,  // Icon màu sắc
              size: 80,
              color: Color(0xFFC00000),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chọn module:',
              style: TextStyle(fontSize: 20, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/colors');  // Navigate đến Color Table
              },
              icon: const Icon(Icons.color_lens),
              label: const Text('COLOR TABLE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC00000),
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/search');  // Navigate đến PDF Search
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('DRAWINGS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC00000),
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/dims');  // Navigate to Package Dims
              },
              icon: const Icon(Icons.inventory_2),
              label: const Text('PACKAGE DIMS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC00000),
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/projects');  // Navigate to Process
              },
              icon: const Icon(Icons.account_tree),
              label: const Text('PROCESS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC00000),
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}