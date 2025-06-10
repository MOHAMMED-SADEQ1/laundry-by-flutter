import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String lable;
  final IconData icon;
  final Color color;

  const CustomButton({super.key,required this.lable,required this.icon,required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 10,
      margin: EdgeInsets.all(15),
      color: color,
      child: ListTile(
        title: Text(
          lable,
          style: TextStyle(
            fontFamily: 'cairo',
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        leading: Icon(icon, color: Colors.white),
        onTap: () {},
      ),
    );
  }
}
