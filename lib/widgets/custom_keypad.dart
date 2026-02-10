import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../utils/app_constants.dart';

class CustomKeypad extends StatefulWidget {
  final int pinLength;
  final Function(String) onPinEntered;
  final String? errorMessage;
  final VoidCallback onCancel;

  const CustomKeypad({
    super.key,
    this.pinLength = 4,
    required this.onPinEntered,
    this.errorMessage,
    required this.onCancel,
  });

  @override
  State<CustomKeypad> createState() => _CustomKeypadState();
}

class _CustomKeypadState extends State<CustomKeypad> {
  String _inputPin = "";

  void _onKeyPress(String val) {
    if (_inputPin.length < widget.pinLength) {
      HapticFeedback.lightImpact();
      setState(() {
        _inputPin += val;
      });
      if (_inputPin.length == widget.pinLength) {
        widget.onPinEntered(_inputPin);
        // We don't clear immediately to allow parent to show error or close
        // If error, parent rebuilds with errorMessage. We might want to clear on error though.
        // For better UX, let's keep it until parent decides.
        // Actually, usually we clear after a short delay if error, or immediately.
        // Let's rely on parent passing back a new state if it failed.
      }
    }
  }

  void _onDelete() {
    if (_inputPin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _inputPin = _inputPin.substring(0, _inputPin.length - 1);
      });
    }
  }

  @override
  void didUpdateWidget(CustomKeypad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorMessage != null && widget.errorMessage != oldWidget.errorMessage) {
      // If a new error message comes in, clear the pin after a short delay or immediately?
      // Typically, you show the error and clear the dots.
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            _inputPin = "";
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : AppColors.textDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black : AppColors.softCream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header / PIN Dots
          const SizedBox(height: 16),
          Text(
            "enter pin",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.pinLength, (index) {
              final isFilled = index < _inputPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? AppColors.primaryPink : Colors.transparent,
                  border: Border.all(
                    color: isFilled ? AppColors.primaryPink : textColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // Error Message Area
          SizedBox(
            height: 20,
            child: widget.errorMessage != null
                ? Text(
                    widget.errorMessage!,
                    style: GoogleFonts.quicksand(
                      color: AppColors.errorRed,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 24),
          // Keypad Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 1.5,
            mainAxisSpacing: 16,
            crossAxisSpacing: 24,
            children: [
              ...List.generate(9, (index) => _buildNumberKey('${index + 1}', textColor)),
              // Bottom Row
              TextButton(
                onPressed: widget.onCancel,
                child: Text(
                  "cancel",
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    color: textColor.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildNumberKey('0', textColor),
              IconButton(
                onPressed: _onDelete,
                icon: Icon(Icons.backspace_rounded, color: textColor.withOpacity(0.6)),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNumberKey(String number, Color textColor) {
    return InkWell(
      onTap: () => _onKeyPress(number),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: textColor.withOpacity(0.05),
        ),
        child: Text(
          number,
          style: GoogleFonts.quicksand(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}