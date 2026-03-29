import 'package:flutter/material.dart';
import '../models/participant.dart';

/// A small tappable avatar chip used inside item rows.
/// Filled when the participant is assigned, outlined when not.
class ParticipantAvatar extends StatelessWidget {
  final Participant participant;
  final bool isAssigned;
  final VoidCallback onTap;

  const ParticipantAvatar({
    super.key,
    required this.participant,
    required this.isAssigned,
    required this.onTap,
  });

  String get _initials {
    final parts = participant.name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return participant.name.substring(0, participant.name.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isAssigned ? participant.avatarColor : Colors.transparent,
          border: Border.all(
            color: participant.avatarColor,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          _initials,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isAssigned ? Colors.white : participant.avatarColor,
          ),
        ),
      ),
    );
  }
}
