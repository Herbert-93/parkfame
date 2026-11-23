import 'package:flutter/material.dart';
import '../theme.dart';

class PlateBadge extends StatelessWidget {
  final String plate;
  final double size;
  const PlateBadge(this.plate, {super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.7, vertical: size * 0.32),
      decoration: BoxDecoration(
        color: Brand.amber,
        borderRadius: BorderRadius.circular(size * 0.4),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Text(plate,
          style: TextStyle(color: Colors.black, fontSize: size, fontWeight: FontWeight.w900, letterSpacing: size * 0.09)),
    );
  }
}

IconData sizeIcon(String s) {
  switch (s) {
    case 'motorcycle':
      return Icons.two_wheeler_rounded;
    case 'medium':
      return Icons.directions_car_filled_rounded;
    case 'large':
      return Icons.airport_shuttle_rounded;
    case 'truck':
      return Icons.local_shipping_rounded;
    default:
      return Icons.directions_car_rounded;
  }
}
