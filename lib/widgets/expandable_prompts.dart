import 'package:flutter/material.dart';

class ExpandablePrompts extends StatefulWidget {
  final List<Map<String, dynamic>> prompts;

  const ExpandablePrompts({
    super.key,
    required this.prompts,
  });

  @override
  State<ExpandablePrompts> createState() => _ExpandablePromptsState();
}

class _ExpandablePromptsState extends State<ExpandablePrompts> {
  int? _expandedPromptIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.prompts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(alignment: Alignment.center,),
        const SizedBox(height: 16),
        ...widget.prompts.asMap().entries.map((entry) {
          final index = entry.key;
          final prompt = entry.value;
          final isExpanded = _expandedPromptIndex == index;
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: const Color(0xFFE8E0F0),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedPromptIndex = null; // Collapse if already expanded
                      } else {
                        _expandedPromptIndex = index; // Expand this one, collapse others
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            prompt['question'],
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Color(0xFF3B2357),
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: isExpanded ? 0.125 : 0, // 45 degrees rotation
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            Icons.add,
                            color: const Color(0xFF3B2357),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    children: [
                      const Divider(
                        height: 1,
                        color: Color(0xFFE8E0F0),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          prompt['answer'],
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w400,
                            fontSize: 15,
                            color: Color(0xFF6D4B86),
                          ),
                        ),
                      ),
                    ],
                  ),
                  crossFadeState: isExpanded 
                      ? CrossFadeState.showSecond 
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                  firstCurve: Curves.easeInOut,
                  secondCurve: Curves.easeInOut,
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
