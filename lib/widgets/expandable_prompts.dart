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
    if (widget.prompts.isEmpty) return const SizedBox.shrink();

    const primary = Color(0xFF3B2357);
    const secondary = Color(0xFF6D4B86);
    const border = Color(0xFFE8E0F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.prompts.asMap().entries.map((entry) {
          final index = entry.key;
          final prompt = entry.value;
          final isExpanded = _expandedPromptIndex == index;

          final question = (prompt['question'] ?? '') as String;
          final answer = (prompt['answer'] ?? '') as String;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _expandedPromptIndex = isExpanded ? null : index;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              question,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: primary,
                                height: 1.25,
                              ),
                            ),
                          ),
                          AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeInOut,
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 22,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState:
                        isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1, color: border),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          child: SelectableText(
                            answer,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400,
                              fontSize: 15,
                              color: secondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}
