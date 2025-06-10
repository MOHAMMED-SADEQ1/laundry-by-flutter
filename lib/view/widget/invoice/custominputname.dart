import 'package:flutter/material.dart';

class CustomInputName extends StatelessWidget {
  TextEditingController valueinput = TextEditingController();
  CustomInputName({super.key, required this.valueinput});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: TextFormField(
        controller: valueinput,
        decoration: InputDecoration(
          label: Align(
            alignment: Alignment.center,
            child: Text(
              'اسم الزبون',
              style: TextStyle(
                fontFamily: 'cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          floatingLabelAlignment: FloatingLabelAlignment.center,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
      ),
    );
  }
}
