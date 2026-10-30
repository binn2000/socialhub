import 'package:flutter/material.dart';
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/mock_image.dart';

class UserAvatar extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final bool showBorder;
  final List<Color>? borderColors;

  const UserAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 24,
    this.showBorder = false,
    this.borderColors,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final fallback = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: palette.brandSoft,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person_rounded, size: radius, color: palette.brand),
    );
    final canLoadAsset = canLoadAssetImage(imageUrl);
    final avatar = ClipOval(
      child: isNetworkImage(imageUrl)
          ? Image.network(
              imageUrl,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback,
            )
          : canLoadAsset
          ? Image.asset(
              imageUrl,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback,
            )
          : fallback,
    );

    if (!showBorder) {
      return avatar;
    }

    final ringColor = (borderColors != null && borderColors!.isNotEmpty)
        ? borderColors!.first
        : palette.brand;

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2),
      ),
      child: avatar,
    );
  }
}
