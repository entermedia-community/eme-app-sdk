import 'package:flutter/material.dart';
import 'dart:math';

//A render accident that become the logo - Mando - Oct 14th 2020
class EmLogo extends StatelessWidget {
  const EmLogo({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.table_rows_rounded, color: Colors.white),
        Expanded(
          child: Transform.rotate(
            angle: 90 * pi / 180,
            child: const Icon(Icons.table_rows_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
